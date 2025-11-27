import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'unit_details_page.dart';

enum SortOption {
  expirationAsc,
  expirationDesc,
  tenantAsc,
  tenantDesc,
  unitAsc,
  unitDesc,
}

class LeasesPage extends StatefulWidget {
  const LeasesPage({super.key});

  @override
  State<LeasesPage> createState() => _LeasesPageState();
}

class _LeasesPageState extends State<LeasesPage> with SingleTickerProviderStateMixin {
  final supabase = Supabase.instance.client;
  late TabController _tabController;
  
  List<Map<String, dynamic>> allLeases = [];
  List<Map<String, dynamic>> filteredLeases = [];
  bool isLoading = true;
  String searchQuery = '';
  SortOption _currentSort = SortOption.expirationAsc; // Default sort

  final currency = NumberFormat.currency(locale: 'en_PH', symbol: '₱', decimalDigits: 2);
  final dateFmt = DateFormat('MMM d, yyyy');

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_applyFiltersAndSort);
    fetchLeases();
  }

  Future<void> fetchLeases() async {
    try {
      final response = await supabase
          .from('leases')
          .select('*, tenants(name), units(building, unit_number)')
          .order('end_date', ascending: true); 

      if (mounted) {
        setState(() {
          allLeases = List<Map<String, dynamic>>.from(response);
          _applyFiltersAndSort();
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading leases: $e')),
        );
      }
    }
  }

  void _applyFiltersAndSort() {
    if (!mounted) return;
    
    final index = _tabController.index;
    List<Map<String, dynamic>> temp;

    // 1. Filter by Tab Status
    // 0: Active, 1: Expiring Soon (< 60 days), 2: Ended
    if (index == 0) {
      temp = allLeases.where((l) => l['status'] == 'Active').toList();
    } else if (index == 1) {
      final now = DateTime.now();
      final sixtyDays = now.add(const Duration(days: 60));
      temp = allLeases.where((l) {
        if (l['status'] != 'Active') return false;
        if (l['end_date'] == null) return false;
        final end = DateTime.parse(l['end_date']);
        return end.isBefore(sixtyDays);
      }).toList();
    } else {
      temp = allLeases.where((l) => l['status'] != 'Active').toList();
    }

    // 2. Filter by Search Query
    if (searchQuery.isNotEmpty) {
      final q = searchQuery.toLowerCase();
      temp = temp.where((l) {
        final tenant = (l['tenants']?['name'] ?? '').toString().toLowerCase();
        final unitB = (l['units']?['building'] ?? '').toString().toLowerCase();
        final unitN = (l['units']?['unit_number'] ?? '').toString().toLowerCase();
        return tenant.contains(q) || unitB.contains(q) || unitN.contains(q);
      }).toList();
    }

    // 3. Sort
    temp.sort((a, b) {
      switch (_currentSort) {
        case SortOption.expirationAsc:
          final dA = a['end_date'] != null ? DateTime.parse(a['end_date']) : DateTime(2100);
          final dB = b['end_date'] != null ? DateTime.parse(b['end_date']) : DateTime(2100);
          return dA.compareTo(dB);
        case SortOption.expirationDesc:
          final dA = a['end_date'] != null ? DateTime.parse(a['end_date']) : DateTime(1900);
          final dB = b['end_date'] != null ? DateTime.parse(b['end_date']) : DateTime(1900);
          return dB.compareTo(dA);
        case SortOption.tenantAsc:
          final tA = (a['tenants']?['name'] ?? '').toString().toLowerCase();
          final tB = (b['tenants']?['name'] ?? '').toString().toLowerCase();
          return tA.compareTo(tB);
        case SortOption.tenantDesc:
          final tA = (a['tenants']?['name'] ?? '').toString().toLowerCase();
          final tB = (b['tenants']?['name'] ?? '').toString().toLowerCase();
          return tB.compareTo(tA);
        case SortOption.unitAsc:
          final uA = _getUnitSortString(a);
          final uB = _getUnitSortString(b);
          return uA.compareTo(uB);
        case SortOption.unitDesc:
          final uA = _getUnitSortString(a);
          final uB = _getUnitSortString(b);
          return uB.compareTo(uA);
      }
    });

    setState(() {
      filteredLeases = temp;
    });
  }

  String _getUnitSortString(Map<String, dynamic> lease) {
    final b = (lease['units']?['building'] ?? '').toString();
    final n = (lease['units']?['unit_number'] ?? '').toString();
    // Simple sort key: Building + Unit Number padded
    return '$b $n'.toLowerCase();
  }

  double get _totalActiveRent {
    return allLeases
        .where((l) => l['status'] == 'Active')
        .fold(0.0, (sum, l) => sum + (l['rent_amount'] as num? ?? 0).toDouble());
  }

  void _onSearch(String val) {
    searchQuery = val;
    _applyFiltersAndSort();
  }

  void _changeSort(SortOption? option) {
    if (option != null) {
      setState(() {
        _currentSort = option;
      });
      _applyFiltersAndSort();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Lease Contracts"),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Active'),
            Tab(text: 'Expiring Soon'),
            Tab(text: 'Ended'),
          ],
        ),
        actions: [
          PopupMenuButton<SortOption>(
            icon: const Icon(Icons.sort),
            tooltip: 'Sort Leases',
            onSelected: _changeSort,
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: SortOption.expirationAsc,
                child: Text('Expiration (Earliest First)'),
              ),
              const PopupMenuItem(
                value: SortOption.expirationDesc,
                child: Text('Expiration (Latest First)'),
              ),
              const PopupMenuItem(
                value: SortOption.tenantAsc,
                child: Text('Tenant (A-Z)'),
              ),
              const PopupMenuItem(
                value: SortOption.tenantDesc,
                child: Text('Tenant (Z-A)'),
              ),
              const PopupMenuItem(
                value: SortOption.unitAsc,
                child: Text('Unit (A-Z)'),
              ),
              const PopupMenuItem(
                value: SortOption.unitDesc,
                child: Text('Unit (Z-A)'),
              ),
            ],
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: TextField(
                    onChanged: _onSearch,
                    decoration: InputDecoration(
                      hintText: 'Search tenant or unit...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                  ),
                ),
                if (_tabController.index == 0)
                  Container(
                    width: double.infinity,
                    color: Colors.grey[200],
                    padding: const EdgeInsets.all(12.0),
                    child: Text(
                      'Total Monthly Rent (Active): ${currency.format(_totalActiveRent)}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                  ),
                Expanded(
                  child: filteredLeases.isEmpty
                      ? const Center(child: Text("No contracts found."))
                      : ListView.builder(
                          itemCount: filteredLeases.length,
                          itemBuilder: (context, index) {
                            final lease = filteredLeases[index];
                            return _buildLeaseCard(lease);
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildLeaseCard(Map<String, dynamic> lease) {
    final tenantName = lease['tenants']?['name'] ?? 'Unknown';
    final building = lease['units']?['building'] ?? '';
    final unitNum = lease['units']?['unit_number'] ?? '';
    final unitDisplay = unitNum.isEmpty ? building : '$building $unitNum';
    
    final startStr = lease['start_date'] != null 
        ? dateFmt.format(DateTime.parse(lease['start_date'])) 
        : '-';
    final endStr = lease['end_date'] != null 
        ? dateFmt.format(DateTime.parse(lease['end_date'])) 
        : '-';
    final rent = currency.format(lease['rent_amount'] ?? 0);
    final status = lease['status'] ?? 'Unknown';

    Color statusColor = Colors.grey;
    if (status == 'Active') statusColor = Colors.green;
    if (status == 'Ended') statusColor = Colors.red;

    if (status == 'Active' && lease['end_date'] != null) {
      final end = DateTime.parse(lease['end_date']);
      if (end.difference(DateTime.now()).inDays < 60) {
        statusColor = Colors.orange;
      }
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: ListTile(
        title: Text(tenantName, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.apartment, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Text(unitDisplay),
              ],
            ),
            const SizedBox(height: 2),
            Text("$startStr — $endStr"),
            Text("Rent: $rent"),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: statusColor),
              ),
              child: Text(
                status,
                style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
          ],
        ),
        onTap: () {
          if (lease['unit_id'] != null) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => UnitDetailsPage(
                  unitId: lease['unit_id'].toString(),
                  building: building,
                  unitNumber: unitNum,
                ),
              ),
            );
          }
        },
      ),
    );
  }
}

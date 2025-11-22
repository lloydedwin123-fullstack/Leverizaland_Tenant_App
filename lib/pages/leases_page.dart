import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'unit_details_page.dart';

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

  final currency = NumberFormat.currency(locale: 'en_PH', symbol: '₱', decimalDigits: 2);
  final dateFmt = DateFormat('MMM d, yyyy');

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_filterByTab);
    fetchLeases();
  }

  Future<void> fetchLeases() async {
    try {
      final response = await supabase
          .from('leases')
          .select('*, tenants(name), units(building, unit_number)')
          .order('end_date', ascending: true); // Show expiring first

      setState(() {
        allLeases = List<Map<String, dynamic>>.from(response);
        _filterByTab(); // Apply initial filter
        isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading leases: $e')),
        );
      }
    }
  }

  void _filterByTab() {
    if (!mounted) return;
    
    final index = _tabController.index;
    List<Map<String, dynamic>> temp;

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

    // Apply search query if any
    if (searchQuery.isNotEmpty) {
      final q = searchQuery.toLowerCase();
      temp = temp.where((l) {
        final tenant = (l['tenants']?['name'] ?? '').toString().toLowerCase();
        final unitB = (l['units']?['building'] ?? '').toString().toLowerCase();
        final unitN = (l['units']?['unit_number'] ?? '').toString().toLowerCase();
        return tenant.contains(q) || unitB.contains(q) || unitN.contains(q);
      }).toList();
    }

    setState(() {
      filteredLeases = temp;
    });
  }

  void _onSearch(String val) {
    searchQuery = val;
    _filterByTab();
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

    // Check if expiring soon for coloring
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
          // Navigate to Unit Details since that's where we edit leases
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

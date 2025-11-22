import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../widgets/property_card.dart';
import 'unit_details_page.dart';

class ReportsPage extends StatefulWidget {
  final int initialIndex; 

  const ReportsPage({
    super.key, 
    this.initialIndex = 0,
  });

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> with SingleTickerProviderStateMixin {
  final supabase = Supabase.instance.client;
  late TabController _tabController;

  final currency = NumberFormat.currency(locale: 'en_PH', symbol: '₱', decimalDigits: 2);
  final dateFmt = DateFormat('MMMM d, yyyy');

  // ===== All Units tab =====
  bool isLoadingUnits = true;
  List<Map<String, dynamic>> allUnits = [];          
  Map<String, dynamic> perUnitExtras = {};           
  List<Map<String, dynamic>> filteredUnits = [];
  String unitsSearch = '';

  // ===== Arrears tab =====
  bool isLoadingArrears = true;
  List<Map<String, dynamic>> arrearsPerUnit = [];    
  String arrearsSearch = '';
  List<Map<String, dynamic>> filteredArrears = [];
  double totalArrearsSum = 0.0; 

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this, initialIndex: widget.initialIndex);
    _loadAllUnitsTab();
    _loadArrearsTab();
  }

  String displayName(String building, String? unitNumber) {
    final u = (unitNumber ?? '').trim();
    return u.isEmpty ? building : '$building $u';
  }

  String monthYear(DateTime d) => DateFormat('MMMM yyyy').format(d);

  double toDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0.0;
  }

  // ---------------- All Units loader ----------------
  Future<void> _loadAllUnitsTab() async {
    setState(() => isLoadingUnits = true);
    try {
      final unitsRes = await supabase
          .from('units')
          .select('id, building, unit_number, current_rent_amount, tenants(name)')
          .order('building', ascending: true);

      final units = List<Map<String, dynamic>>.from(unitsRes);

      final ipsRes = await supabase
          .from('invoice_payment_status')
          .select('unit_id, balance, due_date, lease_status')
          .gt('balance', 0)
          .eq('lease_status', 'Active');

      final ips = List<Map<String, dynamic>>.from(ipsRes);

      final Map<String, Map<String, dynamic>> extras = {};
      for (final r in ips) {
        final uid = (r['unit_id'] ?? '').toString();
        final bal = toDouble(r['balance']);
        final due = r['due_date'] != null ? DateTime.parse(r['due_date']) : null;

        final obj = extras.putIfAbsent(uid, () => {
          'balance': 0.0,
          'minDue': null,
          'maxDue': null,
        });

        final currentBal = (obj['balance'] is num) ? obj['balance'].toDouble() : 0.0;
        obj['balance'] = currentBal + bal;

        if (due != null) {
          final DateTime? min = obj['minDue'];
          final DateTime? max = obj['maxDue'];
          obj['minDue'] = (min == null || due.isBefore(min)) ? due : min;
          obj['maxDue'] = (max == null || due.isAfter(max)) ? due : max;
        }
      }

      units.sort((a, b) {
        final ab = (a['building'] ?? '').toString().compareTo((b['building'] ?? '').toString());
        if (ab != 0) return ab;
        return (a['unit_number'] ?? '').toString().compareTo((b['unit_number'] ?? '').toString());
      });

      setState(() {
        allUnits = units;
        perUnitExtras = extras;
        filteredUnits = List<Map<String, dynamic>>.from(units);
        isLoadingUnits = false;
      });
    } catch (e) {
      setState(() => isLoadingUnits = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading units: $e')));
    }
  }

  void _filterUnits(String q) {
    final qq = q.toLowerCase();
    setState(() {
      unitsSearch = q;
      filteredUnits = allUnits.where((u) {
        final b = (u['building'] ?? '').toString().toLowerCase();
        final un = (u['unit_number'] ?? '').toString().toLowerCase();
        final t = (u['tenants']?['name'] ?? 'Vacant').toString().toLowerCase();
        final r = (u['current_rent_amount'] ?? '').toString().toLowerCase();
        return b.contains(qq) || un.contains(qq) || t.contains(qq) || r.contains(qq);
      }).toList();
      filteredUnits.sort((a, b) {
        final ab = (a['building'] ?? '').toString().compareTo((b['building'] ?? '').toString());
        if (ab != 0) return ab;
        return (a['unit_number'] ?? '').toString().compareTo((b['unit_number'] ?? '').toString());
      });
    });
  }

  // ---------------- Arrears loader ----------------
  Future<void> _loadArrearsTab() async {
    setState(() => isLoadingArrears = true);
    try {
      final ipsRes = await supabase
          .from('invoice_payment_status')
          .select('tenant_id, tenant_name, unit_id, building, unit_name, due_date, amount_due, total_paid, balance, lease_status')
          .gt('balance', 0)
          .eq('lease_status', 'Active')
          .order('due_date', ascending: true);

      final ips = List<Map<String, dynamic>>.from(ipsRes);

      if (ips.isEmpty) {
        setState(() {
          arrearsPerUnit = [];
          filteredArrears = [];
          totalArrearsSum = 0.0;
          isLoadingArrears = false;
        });
        return;
      }

      final unitsRes = await supabase
          .from('units')
          .select('id, building, unit_number, current_rent_amount');

      final units = List<Map<String, dynamic>>.from(unitsRes);
      final Map<String, Map<String, dynamic>> unitById = {
        for (final u in units) (u['id']).toString(): u,
      };

      final leasesRes = await supabase
          .from('leases')
          .select('id, unit_id, status, rent_amount')
          .eq('status', 'Active');

      final leases = List<Map<String, dynamic>>.from(leasesRes);
      final Map<String, double> rentByUnitId = {};
      for (final l in leases) {
        final uid = (l['unit_id']).toString();
        final ra = toDouble(l['rent_amount']);
        if (ra > 0) rentByUnitId[uid] = ra;
      }

      final Map<String, List<Map<String, dynamic>>> byUnit = {};
      for (final row in ips) {
        final uid = (row['unit_id']).toString();
        (byUnit[uid] ??= []).add(row);
      }

      double globalSum = 0.0;

      final List<Map<String, dynamic>> rolled = [];
      for (final entry in byUnit.entries) {
        final unitId = entry.key;
        final rows = entry.value..sort((a, b) {
          final da = a['due_date'] != null ? DateTime.parse(a['due_date']) : DateTime(1900);
          final db = b['due_date'] != null ? DateTime.parse(b['due_date']) : DateTime(1900);
          return da.compareTo(db);
        });

        final building = (rows.first['building'] ?? '').toString();
        final unitName = (rows.first['unit_name'] ?? '').toString();
        final tenantName = (rows.first['tenant_name'] ?? '').toString();

        double totalBal = 0;
        DateTime? firstDue;
        DateTime? lastDue;
        for (final r in rows) {
          totalBal += toDouble(r['balance']);
          if (r['due_date'] != null) {
            final d = DateTime.parse(r['due_date']);
            firstDue ??= d;
            lastDue = d;
          }
        }
        globalSum += totalBal;

        String coverageText = '-';
        if (firstDue != null && lastDue != null) {
          if (firstDue.year == lastDue.year && firstDue.month == lastDue.month) {
            coverageText = monthYear(firstDue);
          } else {
            coverageText = '${monthYear(firstDue)} to ${monthYear(lastDue)}';
          }
        }

        double rent = 0.0;
        if (rentByUnitId.containsKey(unitId)) {
          rent = rentByUnitId[unitId]!;
        } else {
          final u = unitById[unitId];
          if (u != null) rent = toDouble(u['current_rent_amount']);
        }

        rolled.add({
          'unit_id': unitId,
          'building': building,
          'unit_name': unitName,
          'tenant_name': tenantName,
          'rent_amount': rent,
          'total_balance': totalBal,
          'coverage': coverageText,
        });
      }

      rolled.sort((a, b) {
        final ab = (a['building'] ?? '').toString().compareTo((b['building'] ?? '').toString());
        if (ab != 0) return ab;
        return (a['unit_name'] ?? '').toString().compareTo((b['unit_name'] ?? '').toString());
      });

      setState(() {
        arrearsPerUnit = rolled;
        filteredArrears = List<Map<String, dynamic>>.from(rolled);
        totalArrearsSum = globalSum;
        isLoadingArrears = false;
      });
    } catch (e) {
      setState(() => isLoadingArrears = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading arrears: $e')));
    }
  }

  void _filterArrears(String q) {
    final qq = q.toLowerCase();
    final filtered = arrearsPerUnit.where((row) {
      final building = (row['building'] ?? '').toString().toLowerCase();
      final unitName = (row['unit_name'] ?? '').toString().toLowerCase();
      final tenant = (row['tenant_name'] ?? '').toString().toLowerCase();
      final rent = (row['rent_amount'] ?? '').toString().toLowerCase();
      final bal = (row['total_balance'] ?? '').toString().toLowerCase();
      final cov = (row['coverage'] ?? '').toString().toLowerCase();
      return building.contains(qq) ||
          unitName.contains(qq) ||
          tenant.contains(qq) ||
          rent.contains(qq) ||
          bal.contains(qq) ||
          cov.contains(qq);
    }).toList();

    double filteredSum = 0.0;
    for(var row in filtered) {
      filteredSum += toDouble(row['total_balance']);
    }

    setState(() {
      arrearsSearch = q;
      filteredArrears = filtered;
      totalArrearsSum = filteredSum;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _loadAllUnitsTab();
              _loadArrearsTab();
            },
          )
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [Tab(text: 'All Units'), Tab(text: 'Arrears')],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildAllUnits(),
          _buildArrears(),
        ],
      ),
    );
  }

  Widget _buildAllUnits() {
    if (isLoadingUnits) return const Center(child: CircularProgressIndicator());
    if (allUnits.isEmpty) return const Center(child: Text('No units found'));

    return RefreshIndicator(
      onRefresh: _loadAllUnitsTab,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: TextField(
              onChanged: _filterUnits,
              decoration: InputDecoration(
                hintText: 'Search by building, unit, tenant, rent…',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: filteredUnits.length,
              itemBuilder: (context, i) {
                final u = filteredUnits[i];
                final unitId = (u['id']).toString();
                final building = (u['building'] ?? '').toString();
                final unitNum = (u['unit_number'] ?? '').toString();
                final title = displayName(building, unitNum);
                final tenantName = (u['tenants']?['name'] ?? 'Vacant').toString();
                final rent = currency.format(toDouble(u['current_rent_amount']));

                String? coverageText;
                String? balanceText;
                final ex = perUnitExtras[unitId];
                if (ex != null) {
                  final bal = toDouble(ex['balance']);
                  if (bal > 0) {
                    balanceText = currency.format(bal);
                    final DateTime? minDue = ex['minDue'];
                    final DateTime? maxDue = ex['maxDue'];
                    if (minDue != null && maxDue != null) {
                      coverageText = (minDue.year == maxDue.year && minDue.month == maxDue.month)
                          ? monthYear(minDue)
                          : '${monthYear(minDue)} to ${monthYear(maxDue)}';
                    }
                  }
                }

                if (tenantName.trim().toLowerCase() == 'vacant') {
                  balanceText = null;
                  coverageText = null;
                }

                return PropertyCard(
                  title: title,
                  tenantName: tenantName,
                  rentText: rent,
                  balanceText: balanceText,
                  coverageText: coverageText,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => UnitDetailsPage(
                          unitId: unitId,
                          building: building,
                          unitNumber: unitNum,
                          showFinanceChips: true,
                          initialChip: 'arrears',
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildArrears() {
    if (isLoadingArrears) return const Center(child: CircularProgressIndicator());
    if (arrearsPerUnit.isEmpty) return const Center(child: Text('No arrears 🎉'));

    return RefreshIndicator(
      onRefresh: _loadArrearsTab,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor, // ✅ Themed color
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Theme.of(context).dividerColor),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(Theme.of(context).brightness == Brightness.dark ? 0.2 : 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.account_balance_wallet_outlined, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6), size: 18),
                      const SizedBox(width: 8),
                      Text(
                        "TOTAL OUTSTANDING",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.0,
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    currency.format(totalArrearsSum),
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              onChanged: _filterArrears,
              decoration: InputDecoration(
                hintText: 'Search arrears...',
                prefixIcon: Icon(Icons.search, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5), // ✅ Themed search bar
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
              ),
            ),
          ),
          
          const SizedBox(height: 4),
          
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              itemCount: filteredArrears.length,
              itemBuilder: (context, i) {
                final row = filteredArrears[i];
                final unitId = (row['unit_id']).toString();
                final building = (row['building'] ?? '').toString();
                final unitName = (row['unit_name'] ?? '').toString();
                final title = displayName(building, unitName);
                final tenantName = (row['tenant_name'] ?? '').toString();
                final rentText = currency.format(toDouble(row['rent_amount']));
                final balText = currency.format(toDouble(row['total_balance']));
                final coverage = (row['coverage'] ?? '').toString();

                return PropertyCard(
                  title: title,
                  tenantName: tenantName,
                  rentText: rentText,
                  balanceText: balText,
                  coverageText: coverage,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => UnitDetailsPage(
                          unitId: unitId,
                          building: building,
                          unitNumber: unitName,
                          showFinanceChips: true,
                          initialChip: 'arrears',
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

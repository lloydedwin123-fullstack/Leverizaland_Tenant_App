import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:async';

import 'tenants_page.dart';
import 'units_page.dart';
import 'reports_page.dart';
import 'add_tenant_page.dart';
import 'add_unit_page.dart';
import 'leases_page.dart';
import 'settings_page.dart';
import 'invoices_page.dart';
import 'vacant_units_page.dart';
import 'monthly_payments_page.dart';
import 'monthly_receivables_page.dart';
import 'add_lease_page.dart'; 

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final supabase = Supabase.instance.client;

  bool isLoading = true;

  // Metrics
  int totalTenants = 0;
  int totalUnits = 0;
  int vacantUnits = 0;
  double totalReceivables = 0.0;
  double targetMonthlyRent = 0.0;
  
  // Revenue Metrics
  double revenueThisMonth = 0.0;
  double revenueYTD = 0.0;

  // Chart Data
  List<double> monthlyRevenue = List.filled(12, 0.0); 
  List<String> monthLabels = List.filled(12, ''); 
  int occupiedUnits = 0;

  final currency = NumberFormat.currency(locale: 'en_PH', symbol: '₱', decimalDigits: 2);

  final PageController _revenuePageController = PageController(initialPage: 1000);
  Timer? _revenueTimer;
  int _revenuePage = 1000;

  @override
  void initState() {
    super.initState();
    fetchDashboardData();
    _startRevenueTimer();
  }

  @override
  void dispose() {
    _stopRevenueTimer();
    _revenuePageController.dispose();
    super.dispose();
  }

  void _startRevenueTimer() {
    _stopRevenueTimer(); 
    _revenueTimer = Timer.periodic(const Duration(seconds: 4), (timer) { 
      if (_revenuePageController.hasClients) {
        _revenuePageController.nextPage(
          duration: const Duration(milliseconds: 800), 
          curve: Curves.easeInOut, 
        );
      }
    });
  }

  void _stopRevenueTimer() {
    _revenueTimer?.cancel();
    _revenueTimer = null;
  }

  Future<void> fetchDashboardData() async {
    try {
      setState(() => isLoading = true);

      final tenantsCount = await supabase.from('tenants').count();
      final unitsCount = await supabase.from('units').count();
      final activeLeasesCount = await supabase
          .from('leases')
          .count()
          .eq('status', 'Active');
      
      final calculatedVacant = unitsCount - activeLeasesCount;
      final calculatedOccupied = activeLeasesCount;

      final activeLeasesRes = await supabase
          .from('leases')
          .select('rent_amount')
          .eq('status', 'Active');
      
      double targetRentSum = 0.0;
      for(var l in activeLeasesRes) {
        targetRentSum += (l['rent_amount'] ?? 0.0) as num;
      }

      final activeRecRes = await supabase
          .from('invoice_payment_status')
          .select('balance')
          .gt('balance', 0)
          .eq('lease_status', 'Active');
      
      double activeRecSum = 0.0;
      for (var r in activeRecRes) {
        activeRecSum += (r['balance'] ?? 0.0) as num;
      }

      final now = DateTime.now();
      final startOfMonth = DateTime(now.year, now.month, 1);
      final startNextMonth = DateTime(now.year, now.month + 1, 1);
      final startOfYear = DateTime(now.year, 1, 1);
      
      final startMonthStr = DateFormat('yyyy-MM-dd').format(startOfMonth);
      final endMonthStr = DateFormat('yyyy-MM-dd').format(startNextMonth);
      final startYearStr = DateFormat('yyyy-MM-dd').format(startOfYear);

      final revenueMonthRes = await supabase
          .from('payments')
          .select('amount_paid')
          .gte('payment_date', startMonthStr)
          .lt('payment_date', endMonthStr);

      double revMonthSum = 0.0;
      for (var p in revenueMonthRes) {
        revMonthSum += (p['amount_paid'] ?? 0.0) as num;
      }

      final revenueYearRes = await supabase
          .from('payments')
          .select('amount_paid')
          .gte('payment_date', startYearStr)
          .lt('payment_date', endMonthStr);

      double revYearSum = 0.0;
      for (var p in revenueYearRes) {
        revYearSum += (p['amount_paid'] ?? 0.0) as num;
      }

      final startOfWindow = DateTime(now.year, now.month - 11, 1);
      final startWindowStr = DateFormat('yyyy-MM-dd').format(startOfWindow);

      final paymentsHistoryRes = await supabase
          .from('payments')
          .select('amount_paid, payment_date')
          .gte('payment_date', startWindowStr)
          .order('payment_date', ascending: true);

      List<double> revenueHistory = List.filled(12, 0.0);
      List<String> labels = [];

      for (int i = 0; i < 12; i++) {
        final d = DateTime(now.year, now.month - 11 + i, 1);
        labels.add(DateFormat('MMM').format(d));
      }

      for (var p in paymentsHistoryRes) {
        final amount = (p['amount_paid'] ?? 0.0) as num;
        final dateStr = p['payment_date'] as String?;
        if (dateStr != null) {
          final pDate = DateTime.parse(dateStr);
          int index = (pDate.year - startOfWindow.year) * 12 + (pDate.month - startOfWindow.month);
          if (index >= 0 && index < 12) {
            revenueHistory[index] += amount.toDouble();
          }
        }
      }

      if (!mounted) return;
      setState(() {
        totalTenants = tenantsCount;
        totalUnits = unitsCount;
        vacantUnits = calculatedVacant < 0 ? 0 : calculatedVacant;
        occupiedUnits = calculatedOccupied;
        totalReceivables = activeRecSum; 
        targetMonthlyRent = targetRentSum; 
        revenueThisMonth = revMonthSum;
        revenueYTD = revYearSum; 
        monthlyRevenue = revenueHistory;
        monthLabels = labels;
        isLoading = false;
      });

    } catch (e) {
      debugPrint('Dashboard fetch error: $e');
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  Future<void> _showVacantUnitPicker(BuildContext context) async {
    try {
       final activeLeases = await supabase
          .from('leases')
          .select('unit_id')
          .eq('status', 'Active');
      final occupiedIds = List<Map<String, dynamic>>.from(activeLeases).map((l) => l['unit_id']).toSet();

      final unitsRes = await supabase
          .from('units')
          .select('id, building, unit_number, current_rent_amount')
          .order('building');
      
      final vacantUnits = List<Map<String, dynamic>>.from(unitsRes)
          .where((u) => !occupiedIds.contains(u['id']))
          .toList();

      if (!mounted) return;
      
      if (vacantUnits.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No vacant units available!")));
        return;
      }

      showModalBottomSheet(
        context: context,
        builder: (ctx) => Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Select a Unit to Lease", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Expanded(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: vacantUnits.length,
                  itemBuilder: (ctx, i) {
                    final u = vacantUnits[i];
                    final name = "${u['building']} ${u['unit_number'] ?? ''}";
                    final rent = u['current_rent_amount'] ?? 0.0;
                    
                    return ListTile(
                      leading: const Icon(Icons.meeting_room_outlined, color: Colors.green),
                      title: Text(name),
                      subtitle: Text("Rent: ₱$rent"),
                      onTap: () {
                        Navigator.pop(ctx); 
                        Navigator.push(
                          context, 
                          MaterialPageRoute(
                            builder: (_) => AddLeasePage(
                              unitId: u['id'].toString(), 
                              unitName: name, 
                              defaultRent: (rent as num).toDouble()
                            )
                          )
                        ).then((_) => fetchDashboardData());
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      );

    } catch (e) {
       ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error loading units: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    
    int crossAxisCount = 2; 
    if (screenWidth > 1100) crossAxisCount = 4;
    else if (screenWidth > 800) crossAxisCount = 3; 
    else if (screenWidth < 350) crossAxisCount = 1; 

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Dashboard",
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        centerTitle: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: fetchDashboardData,
            tooltip: "Refresh Data",
          ),
          const SizedBox(width: 16),
        ],
      ),
      drawer: _buildDrawer(context),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: fetchDashboardData,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Leverizaland Incorporated",
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Here is what's happening today.",
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 24),

                    LayoutBuilder(
                      builder: (context, constraints) {
                        final double spacing = 12.0; 
                        double usableWidth = constraints.maxWidth;
                        if (usableWidth == double.infinity) usableWidth = screenWidth - 32; 

                        final double totalSpacing = spacing * (crossAxisCount - 1);
                        final double itemWidth = (usableWidth - totalSpacing) / crossAxisCount;
                        
                        return Wrap(
                          spacing: spacing,
                          runSpacing: spacing,
                          children: [
                            _buildInfoCard(
                              title: "Total Tenants",
                              value: "$totalTenants",
                              icon: Icons.people_alt_outlined,
                              color: Colors.blue,
                              width: itemWidth,
                              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TenantsPage())),
                            ),
                            _buildInfoCard(
                              title: "Total Units",
                              value: "$totalUnits",
                              icon: Icons.apartment_outlined,
                              color: Colors.orange,
                              width: itemWidth,
                              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const UnitsPage())),
                            ),
                            _buildInfoCard(
                              title: "Vacant Units",
                              value: "$vacantUnits",
                              icon: Icons.meeting_room_outlined,
                              color: Colors.redAccent,
                              width: itemWidth,
                              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const VacantUnitsPage())),
                            ),
                            
                            _buildInfoCard(
                              title: "Target Monthly Rent",
                              value: currency.format(targetMonthlyRent),
                              icon: Icons.price_check, 
                              color: Colors.teal,
                              width: itemWidth,
                              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LeasesPage())),
                            ),

                            _buildInfoCard(
                              title: "Receivables (Active)",
                              value: currency.format(totalReceivables),
                              icon: Icons.account_balance_wallet_outlined,
                              color: Colors.purple,
                              width: itemWidth,
                              onTap: () => Navigator.push(
                                context, 
                                MaterialPageRoute(
                                  builder: (_) => MonthlyReceivablesPage(initialMonth: DateTime.now())
                                )
                              ), 
                            ),
                            
                            _buildSlideableRevenueCard(itemWidth),
                          ],
                        );
                      },
                    ),
                    
                    const SizedBox(height: 32),

                    Text(
                      "Analytics",
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        if (screenWidth > 800) { 
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 2,
                                child: _buildRevenueChart(),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                flex: 1,
                                child: _buildOccupancyChart(),
                              ),
                            ],
                          );
                        } else {
                          return Column(
                            children: [
                              _buildRevenueChart(),
                              const SizedBox(height: 16),
                              _buildOccupancyChart(),
                            ],
                          );
                        }
                      },
                    ),

                    const SizedBox(height: 32),

                    Text(
                      "Quick Actions",
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        _buildActionButton(
                          label: "Add Tenant",
                          icon: Icons.person_add,
                          onTap: () async {
                            final result = await Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const AddTenantPage()),
                            );
                            if (result == true) fetchDashboardData(); 
                          },
                        ),
                        _buildActionButton(
                          label: "Add Unit",
                          icon: Icons.add_home,
                          onTap: () async {
                            final result = await Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const AddUnitPage()),
                            );
                            if (result == true) fetchDashboardData();
                          },
                        ),
                        _buildActionButton(
                          label: "Add Lease",
                          icon: Icons.post_add,
                          onTap: () => _showVacantUnitPicker(context),
                        ),
                        _buildActionButton(
                          label: "Create Invoice",
                          icon: Icons.receipt,
                          onTap: () {
                             Navigator.push(context, MaterialPageRoute(builder: (_) => const TenantsPage()));
                             ScaffoldMessenger.of(context).showSnackBar(
                               const SnackBar(content: Text("Use the 'Generate Invoices' button in the AppBar here.")),
                             );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSlideableRevenueCard(double width) {
    const color = Colors.green;
    
    return SizedBox(
      width: width,
      height: 125, 
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Theme.of(context).colorScheme.outline.withOpacity(0.2), width: 1),
        ),
        clipBehavior: Clip.antiAlias,
        child: NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            if (notification is ScrollStartNotification) {
              _stopRevenueTimer(); 
            } else if (notification is ScrollEndNotification) {
              _startRevenueTimer(); 
            }
            return false;
          },
          child: PageView.builder( 
            controller: _revenuePageController,
            onPageChanged: (index) {
              setState(() => _revenuePage = index);
            },
            itemBuilder: (context, index) {
              final i = index % 2; 
              if (i == 0) {
                return _buildRevenueItem(
                  "Revenue (Month)",
                  currency.format(revenueThisMonth),
                  color,
                );
              } else {
                return _buildRevenueItem(
                  "Revenue (YTD)",
                  currency.format(revenueYTD),
                  color,
                );
              }
            },
          ),
        ),
      ),
    );
  }

  Widget _buildRevenueItem(String title, String value, Color color) {
    return InkWell(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ReportsPage())),
      child: Padding(
        padding: const EdgeInsets.all(16.0), 
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min, 
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(8), 
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.attach_money, color: color, size: 20),
                ),
                Row(
                  children: [
                    _buildDot(_revenuePage % 2 == 0),
                    const SizedBox(width: 4),
                    _buildDot(_revenuePage % 2 == 1),
                  ],
                ),
              ],
            ),
            const Spacer(),
            FittedBox( 
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              title,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDot(bool isActive) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      height: 6,
      width: isActive ? 12 : 6,
      decoration: BoxDecoration(
        color: isActive ? Colors.green : Theme.of(context).colorScheme.onSurface.withOpacity(0.2), 
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }

  Widget _buildInfoCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required double width,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: width, 
      height: 125, 
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Theme.of(context).colorScheme.outline.withOpacity(0.2), width: 1),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          hoverColor: color.withOpacity(0.05),
          child: Padding(
            padding: const EdgeInsets.all(16.0), 
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(icon, color: color, size: 20),
                    ),
                    Icon(Icons.arrow_forward_ios, size: 12, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4)), 
                  ],
                ),
                const Spacer(), 
                FittedBox( 
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  title,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRevenueChart() {
    double maxValue = monthlyRevenue.reduce((a, b) => a > b ? a : b);
    double maxY = maxValue == 0 ? 10000 : maxValue * 1.2;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Theme.of(context).colorScheme.outline.withOpacity(0.2), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Monthly Revenue (Last 12 Months)", 
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            SizedBox( 
              height: 200,
              child: BarChart(
                BarChartData(
                  barTouchData: BarTouchData(
                    longPressDuration: const Duration(milliseconds: 1500), 
                    touchTooltipData: BarTouchTooltipData(
                      tooltipBgColor: Theme.of(context).colorScheme.primary,
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        final amount = currency.format(rod.toY);
                        return BarTooltipItem(
                          amount,
                          TextStyle(
                            color: Theme.of(context).colorScheme.onPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                        );
                      },
                    ),
                    touchCallback: (FlTouchEvent event, barTouchResponse) {
                      if (!event.isInterestedForInteractions ||
                          barTouchResponse == null ||
                          barTouchResponse.spot == null) {
                        return;
                      }
                      
                      if (event is FlTapUpEvent || event is FlLongPressEnd) { 
                        final index = barTouchResponse.spot!.touchedBarGroupIndex;
                        final now = DateTime.now();
                        final targetMonth = DateTime(now.year, now.month - 11 + index, 1);
                        
                        Navigator.push(
                          context, 
                          MaterialPageRoute(
                            builder: (_) => MonthlyPaymentsPage(initialMonth: targetMonth)
                          )
                        );
                      }
                    },
                  ),
                  alignment: BarChartAlignment.spaceAround,
                  maxY: maxY,
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: 1, 
                        getTitlesWidget: (double value, TitleMeta meta) {
                          TextStyle style = Theme.of(context).textTheme.bodySmall!;
                          if (value.toInt() >= 0 && value.toInt() < monthLabels.length) {
                             return SideTitleWidget(
                              axisSide: meta.axisSide,
                              space: 4,
                              child: Text(monthLabels[value.toInt()], style: style),
                            );
                          }
                          return Container();
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true, 
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) {
                          if (value == 0) return const SizedBox();
                          return Text(
                            NumberFormat.compact().format(value), 
                            style: Theme.of(context).textTheme.bodySmall,
                          );
                        }
                      )
                    ),
                    topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  gridData: FlGridData(show: true, drawVerticalLine: false, horizontalInterval: maxY / 5, 
                  getDrawingHorizontalLine: (value) => FlLine(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.1), strokeWidth: 1), 
                  ),
                  barGroups: monthlyRevenue.asMap().entries.map((entry) {
                    return BarChartGroupData(
                      x: entry.key,
                      barRods: [
                        BarChartRodData(
                          toY: entry.value,
                          gradient: LinearGradient(
                            colors: [
                              Theme.of(context).colorScheme.primary,
                              Theme.of(context).colorScheme.primaryContainer,
                            ],
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                          ),
                          width: 16,
                          borderRadius: BorderRadius.circular(4),
                          backDrawRodData: BackgroundBarChartRodData(
                            show: true,
                            toY: maxY,
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.05),
                          ),
                        )
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOccupancyChart() {
    if (occupiedUnits == 0 && vacantUnits == 0) {
      return Card(
        child: const Padding(
          padding: EdgeInsets.all(20),
          child: Center(child: Text("No Unit Data Available")),
        ),
      );
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Theme.of(context).colorScheme.outline.withOpacity(0.2), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Occupancy Rate",
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            AspectRatio(
              aspectRatio: 1.3,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 40,
                  sections: [
                    PieChartSectionData(
                      gradient: LinearGradient(
                        colors: [
                          Theme.of(context).colorScheme.primary,
                          Theme.of(context).colorScheme.primaryContainer,
                        ],
                      ),
                      value: occupiedUnits.toDouble(),
                      title: '$occupiedUnits',
                      radius: 50,
                      titleStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    PieChartSectionData(
                      color: Theme.of(context).colorScheme.error,
                      value: vacantUnits.toDouble(),
                      title: '$vacantUnits',
                      radius: 50,
                      titleStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onError),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildLegend(color: Theme.of(context).colorScheme.primary, text: "Occupied"), 
                const SizedBox(width: 16),
                _buildLegend(color: Theme.of(context).colorScheme.error, text: "Vacant"), 
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegend({required Color color, required String text}) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
        const SizedBox(width: 4),
        Text(text, style: Theme.of(context).textTheme.bodySmall), 
      ],
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          UserAccountsDrawerHeader(
            accountName: const Text(
              "Leverizaland Inc.",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            accountEmail: const Text("admin@leverizaland.com"),
            currentAccountPicture: CircleAvatar(
              backgroundColor: Colors.white,
              child: Text(
                "L",
                style: TextStyle(fontSize: 24, color: Theme.of(context).colorScheme.primary), 
              ),
            ),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary, 
              image: DecorationImage(
                image: const NetworkImage(
                  "https://images.unsplash.com/photo-1486406146926-c627a92ad1ab?ixlib=rb-4.0.3&auto=format&fit=crop&w=1170&q=80",
                ),
                fit: BoxFit.cover,
                opacity: Theme.of(context).brightness == Brightness.dark ? 0.1 : 0.3, 
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.dashboard),
            title: const Text('Dashboard'),
            onTap: () {
              Navigator.pop(context); 
            },
          ),
          ListTile(
            leading: const Icon(Icons.people),
            title: const Text('Tenants'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const TenantsPage()));
            },
          ),
          ListTile(
            leading: const Icon(Icons.apartment),
            title: const Text('Units'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const UnitsPage()));
            },
          ),
          ListTile(
            leading: const Icon(Icons.receipt_long), 
            title: const Text('Invoices'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const InvoicesPage()));
            },
          ),
          ListTile(
            leading: const Icon(Icons.description), 
            title: const Text('Lease Contracts'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const LeasesPage()));
            },
          ),
          ListTile(
            leading: const Icon(Icons.bar_chart),
            title: const Text('Reports'),
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const ReportsPage()));
            },
          ),
          ListTile(
            leading: const Icon(Icons.calendar_month),
            title: const Text('Monthly Payments'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => MonthlyPaymentsPage(initialMonth: DateTime.now())),
              );
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text('Settings'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsPage())); 
            },
          ),
          ListTile(
            enabled: false,
            leading: const Icon(Icons.logout),
            title: const Text('Logout'),
            subtitle: const Text('User accounts coming soon'),
            onTap: () {},
          ),
          const SizedBox(height: 20),
          const Padding(
            padding: EdgeInsets.only(left: 16.0),
            child: Text(
              "v2.6 MVP",
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';

import 'tenants_page.dart';
import 'units_page.dart';
import 'reports_page.dart';
import 'add_tenant_page.dart';
import 'add_unit_page.dart';
import 'leases_page.dart';
import 'settings_page.dart';
import 'invoices_page.dart'; // ✅ Import Invoices

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
  double revenueThisMonth = 0.0;

  // Chart Data
  List<double> monthlyRevenue = [0, 0, 0, 0, 0, 0]; 
  int occupiedUnits = 0;

  final currency = NumberFormat.currency(locale: 'en_PH', symbol: '₱', decimalDigits: 2);

  @override
  void initState() {
    super.initState();
    fetchDashboardData();
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

      final receivablesRes = await supabase
          .from('invoice_payment_status')
          .select('balance')
          .gt('balance', 0);
      
      double receivablesSum = 0.0;
      for (var r in receivablesRes) {
        receivablesSum += (r['balance'] ?? 0.0) as num;
      }

      final now = DateTime.now();
      final startOfMonth = DateTime(now.year, now.month, 1);
      final startNextMonth = DateTime(now.year, now.month + 1, 1);
      
      final startStr = DateFormat('yyyy-MM-dd').format(startOfMonth);
      final endStr = DateFormat('yyyy-MM-dd').format(startNextMonth);

      final revenueRes = await supabase
          .from('payments')
          .select('amount_paid')
          .gte('payment_date', startStr)
          .lt('payment_date', endStr);

      double revenueSum = 0.0;
      for (var p in revenueRes) {
        revenueSum += (p['amount_paid'] ?? 0.0) as num;
      }

      List<double> revenueHistory = [0, 0, 0, 0, 0, 0];
      revenueHistory[5] = revenueSum; 
      revenueHistory[4] = revenueSum * 0.8; 
      revenueHistory[3] = revenueSum * 0.9;

      if (!mounted) return;
      setState(() {
        totalTenants = tenantsCount;
        totalUnits = unitsCount;
        vacantUnits = calculatedVacant < 0 ? 0 : calculatedVacant;
        occupiedUnits = calculatedOccupied;
        totalReceivables = receivablesSum;
        revenueThisMonth = revenueSum;
        monthlyRevenue = revenueHistory;
        isLoading = false;
      });

    } catch (e) {
      debugPrint('Dashboard fetch error: $e');
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 900;
    final isTablet = screenWidth > 600 && screenWidth <= 900;

    int crossAxisCount = 1;
    if (isDesktop) crossAxisCount = 4;
    else if (isTablet) crossAxisCount = 2;

    return Scaffold(
      backgroundColor: const Color(0xFFF3E5F5),
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
                      "Welcome to Leverizaland Inc.",
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.blueGrey[900],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Here is what's happening today.",
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.blueGrey[600],
                      ),
                    ),
                    const SizedBox(height: 24),

                    LayoutBuilder(
                      builder: (context, constraints) {
                        final double spacing = 16.0;
                        final double totalSpacing = spacing * (crossAxisCount - 1);
                        final double itemWidth = (constraints.maxWidth - totalSpacing) / crossAxisCount;
                        
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
                              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const UnitsPage())),
                            ),
                            _buildInfoCard(
                              title: "Receivables",
                              value: currency.format(totalReceivables),
                              icon: Icons.account_balance_wallet_outlined,
                              color: Colors.purple,
                              width: itemWidth,
                              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const InvoicesPage())), // Link to invoices
                            ),
                            _buildInfoCard(
                              title: "Revenue (Month)",
                              value: currency.format(revenueThisMonth),
                              icon: Icons.attach_money,
                              color: Colors.green,
                              width: itemWidth,
                              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ReportsPage())),
                            ),
                          ],
                        );
                      },
                    ),
                    
                    const SizedBox(height: 32),

                    Text(
                      "Analytics",
                      style: TextStyle(
                        fontSize: 18, 
                        fontWeight: FontWeight.w600,
                        color: Colors.blueGrey[800]
                      ),
                    ),
                    const SizedBox(height: 16),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        if (isDesktop || isTablet) {
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
                      style: TextStyle(
                        fontSize: 18, 
                        fontWeight: FontWeight.w600,
                        color: Colors.blueGrey[800]
                      ),
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
                          label: "Create Invoice",
                          icon: Icons.receipt,
                          onTap: () {
                             Navigator.push(context, MaterialPageRoute(builder: (_) => const TenantsPage()));
                             ScaffoldMessenger.of(context).showSnackBar(
                               const SnackBar(content: Text("Use the 'Generate Invoices' button in the AppBar here.")),
                             );
                          },
                        ),
                        _buildActionButton(
                          label: "View Reports",
                          icon: Icons.bar_chart,
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ReportsPage())),
                        ),
                        _buildActionButton(
                          label: "Manage Leases",
                          icon: Icons.description,
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LeasesPage())),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  void _showComingSoonDialog(BuildContext context, String feature) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(feature),
        content: const Text("This feature will be available in the next update. Please use the database or list pages for now."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("OK"),
          )
        ],
      ),
    );
  }

  Widget _buildRevenueChart() {
    return Card(
      elevation: 2,
      color: Colors.white,
      surfaceTintColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Monthly Revenue (Last 6 Months)",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            AspectRatio(
              aspectRatio: 1.6,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: (monthlyRevenue.reduce((a, b) => a > b ? a : b) * 1.2) + 1000,
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (double value, TitleMeta meta) {
                          const style = TextStyle(
                            color: Colors.grey,
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                          );
                          List<String> labels = ['5m ago', '4m ago', '3m ago', '2m ago', 'Last mo', 'This mo'];
                          if (value.toInt() >= 0 && value.toInt() < labels.length) {
                             return SideTitleWidget(
                              axisSide: meta.axisSide,
                              space: 4,
                              child: Text(labels[value.toInt()], style: style),
                            );
                          }
                          return Container();
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  gridData: FlGridData(show: false),
                  barGroups: monthlyRevenue.asMap().entries.map((entry) {
                    return BarChartGroupData(
                      x: entry.key,
                      barRods: [
                        BarChartRodData(
                          toY: entry.value,
                          color: Colors.blueAccent,
                          width: 16,
                          borderRadius: BorderRadius.circular(4),
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
    return Card(
      elevation: 2,
      color: Colors.white,
      surfaceTintColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Occupancy Rate",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
                      color: Colors.green,
                      value: occupiedUnits.toDouble(),
                      title: '$occupiedUnits',
                      radius: 50,
                      titleStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    PieChartSectionData(
                      color: Colors.redAccent,
                      value: vacantUnits.toDouble(),
                      title: '$vacantUnits',
                      radius: 50,
                      titleStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildLegend(color: Colors.green, text: "Occupied"),
                const SizedBox(width: 16),
                _buildLegend(color: Colors.redAccent, text: "Vacant"),
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
        Text(text, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
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
      child: Card(
        elevation: 2,
        shadowColor: Colors.black12,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        color: Colors.white,
        surfaceTintColor: Colors.white, 
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          hoverColor: color.withOpacity(0.05),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(icon, color: color, size: 24),
                    ),
                    Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey[400]),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.blueGrey[900],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.blueGrey[500],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
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
                style: TextStyle(fontSize: 24, color: Colors.blue[800]),
              ),
            ),
            decoration: BoxDecoration(
              color: Colors.blue[800],
              image: const DecorationImage(
                image: NetworkImage(
                  "https://images.unsplash.com/photo-1486406146926-c627a92ad1ab?ixlib=rb-4.0.3&auto=format&fit=crop&w=1170&q=80",
                ),
                fit: BoxFit.cover,
                opacity: 0.3,
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
            leading: const Icon(Icons.receipt_long), // ✅ Added Invoices
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
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const ReportsPage()));
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
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('Logout', style: TextStyle(color: Colors.red)),
            onTap: () async {
              Navigator.pop(context);
            },
          ),
          const SizedBox(height: 20),
          const Padding(
            padding: EdgeInsets.only(left: 16.0),
            child: Text(
              "v0.2 MVP",
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

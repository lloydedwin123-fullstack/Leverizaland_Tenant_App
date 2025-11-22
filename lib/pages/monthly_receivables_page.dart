import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'property_arrears_page.dart';

class MonthlyReceivablesPage extends StatefulWidget {
  final DateTime initialMonth;

  const MonthlyReceivablesPage({super.key, required this.initialMonth});

  @override
  State<MonthlyReceivablesPage> createState() => _MonthlyReceivablesPageState();
}

class _MonthlyReceivablesPageState extends State<MonthlyReceivablesPage> {
  final supabase = Supabase.instance.client;
  late DateTime currentMonth;
  bool isLoading = true;
  List<Map<String, dynamic>> receivables = [];
  double totalOutstandingMonth = 0.0;
  double totalOutstandingOverall = 0.0;

  final currency = NumberFormat.currency(locale: 'en_PH', symbol: '₱', decimalDigits: 2);
  final dateFmt = DateFormat('MMM d, yyyy');
  final monthTitleFmt = DateFormat('MMMM yyyy');

  // ✅ Exact Red from Reports Page context (Darker Professional Red)
  final Color arrearsRed = const Color(0xFFAF2626); 

  @override
  void initState() {
    super.initState();
    currentMonth = widget.initialMonth;
    fetchReceivables();
  }

  Future<void> fetchReceivables() async {
    setState(() => isLoading = true);
    try {
      final startOfMonth = DateTime(currentMonth.year, currentMonth.month, 1);
      final startOfNextMonth = DateTime(currentMonth.year, currentMonth.month + 1, 1);
      
      final startStr = DateFormat('yyyy-MM-dd').format(startOfMonth);
      final endStr = DateFormat('yyyy-MM-dd').format(startOfNextMonth);

      final responseMonth = await supabase
          .from('invoice_payment_status')
          .select('*')
          .gt('balance', 0) 
          .eq('lease_status', 'Active') 
          .gte('due_date', startStr)
          .lt('due_date', endStr)
          .order('due_date', ascending: true);

      double sumMonth = 0.0;
      for (var r in responseMonth) {
        sumMonth += (r['balance'] ?? 0.0) as num;
      }

      final responseOverall = await supabase
          .from('invoice_payment_status')
          .select('balance')
          .gt('balance', 0)
          .eq('lease_status', 'Active');

      double sumOverall = 0.0;
      for (var r in responseOverall) {
        sumOverall += (r['balance'] ?? 0.0) as num;
      }

      if (mounted) {
        setState(() {
          receivables = List<Map<String, dynamic>>.from(responseMonth);
          totalOutstandingMonth = sumMonth;
          totalOutstandingOverall = sumOverall;
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading receivables: $e')),
        );
      }
    }
  }

  void _changeMonth(int monthsToAdd) {
    setState(() {
      currentMonth = DateTime(currentMonth.year, currentMonth.month + monthsToAdd, 1);
    });
    fetchReceivables();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA), 
      appBar: AppBar(
        title: Text(
          "Receivables: ${monthTitleFmt.format(currentMonth)}",
          style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w600, fontSize: 18),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today, color: Colors.black54),
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: currentMonth,
                firstDate: DateTime(2020),
                lastDate: DateTime.now().add(const Duration(days: 365)),
              );
              if (picked != null) {
                setState(() => currentMonth = picked);
                fetchReceivables();
              }
            },
          )
        ],
      ),
      body: Column(
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: Icon(Icons.chevron_left, color: Colors.grey.shade600),
                      onPressed: () => _changeMonth(-1),
                    ),
                    Column(
                      children: [
                        const Text(
                          "TOTAL DUE THIS MONTH",
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          currency.format(totalOutstandingMonth),
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.blueGrey.shade900, 
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: Icon(Icons.chevron_right, color: Colors.grey.shade600),
                      onPressed: () => _changeMonth(1),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                // Overall Indicator
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.08), 
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: Colors.orange.withOpacity(0.2)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.info_outline, size: 14, color: Colors.orange.shade800),
                      const SizedBox(width: 8),
                      Text(
                        "Total Active Arrears: ${currency.format(totalOutstandingOverall)}",
                        style: TextStyle(
                          color: Colors.orange.shade900,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // List
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : receivables.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.check_circle_outline, size: 64, color: Colors.green.shade200),
                            const SizedBox(height: 16),
                            Text(
                              "No outstanding receivables",
                              style: TextStyle(color: Colors.blueGrey.shade400, fontSize: 16),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.only(top: 12),
                        itemCount: receivables.length,
                        itemBuilder: (context, index) {
                          final r = receivables[index];
                          final tenantName = r['tenant_name'] ?? 'Unknown';
                          final unitName = r['unit_name'] ?? r['building'] ?? '';
                          final dateStr = r['due_date'] != null
                              ? dateFmt.format(DateTime.parse(r['due_date']))
                              : '-';
                          final balance = (r['balance'] ?? 0.0) as num;
                          final total = (r['amount_due'] ?? 0.0) as num;

                          return Container(
                            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.grey.withOpacity(0.05),
                                  spreadRadius: 1,
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              leading: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: arrearsRed.withOpacity(0.1), // ✅ Matches new red
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(Icons.priority_high, color: arrearsRed, size: 18),
                              ),
                              title: Text(
                                tenantName,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                  color: Colors.blueGrey.shade900
                                ),
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 4.0),
                                child: Row(
                                  children: [
                                    Icon(Icons.home_work_outlined, size: 14, color: Colors.blueGrey.shade400),
                                    const SizedBox(width: 4),
                                    Text(unitName, style: TextStyle(fontSize: 13, color: Colors.blueGrey.shade600)),
                                    const SizedBox(width: 12),
                                    Icon(Icons.calendar_today, size: 14, color: Colors.blueGrey.shade400),
                                    const SizedBox(width: 4),
                                    Text(dateStr, style: TextStyle(fontSize: 13, color: Colors.blueGrey.shade600)),
                                  ],
                                ),
                              ),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    currency.format(balance),
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: arrearsRed, // ✅ Applied Exact Red Here
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    "of ${currency.format(total)}",
                                    style: TextStyle(fontSize: 12, color: Colors.blueGrey.shade400),
                                  ),
                                ],
                              ),
                              onTap: () {
                                // Drill down logic
                              },
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

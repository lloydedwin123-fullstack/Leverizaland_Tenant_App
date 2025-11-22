import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'payment_details_page.dart'; 

class MonthlyPaymentsPage extends StatefulWidget {
  final DateTime initialMonth;

  const MonthlyPaymentsPage({super.key, required this.initialMonth});

  @override
  State<MonthlyPaymentsPage> createState() => _MonthlyPaymentsPageState();
}

class _MonthlyPaymentsPageState extends State<MonthlyPaymentsPage> {
  final supabase = Supabase.instance.client;
  late DateTime currentMonth;
  bool isLoading = true;
  List<Map<String, dynamic>> payments = [];
  double totalCollected = 0.0;

  final currency = NumberFormat.currency(locale: 'en_PH', symbol: '₱', decimalDigits: 2);
  final dateFmt = DateFormat('MMM d, yyyy');
  final monthTitleFmt = DateFormat('MMMM yyyy');

  @override
  void initState() {
    super.initState();
    currentMonth = widget.initialMonth;
    fetchPayments();
  }

  Future<void> fetchPayments() async {
    setState(() => isLoading = true);
    try {
      final startOfMonth = DateTime(currentMonth.year, currentMonth.month, 1);
      final startOfNextMonth = DateTime(currentMonth.year, currentMonth.month + 1, 1);
      
      final startStr = DateFormat('yyyy-MM-dd').format(startOfMonth);
      final endStr = DateFormat('yyyy-MM-dd').format(startOfNextMonth);

      // ✅ FIXED QUERY: Join 'tenants' via 'tenant_id'
      final response = await supabase
          .from('payments')
          .select('*, tenants(name)') // This fetches the name using the FK
          .gte('payment_date', startStr)
          .lt('payment_date', endStr)
          .order('payment_date', ascending: false);

      double sum = 0.0;
      for (var p in response) {
        sum += (p['amount_paid'] ?? 0.0) as num;
      }

      if (mounted) {
        setState(() {
          payments = List<Map<String, dynamic>>.from(response);
          totalCollected = sum;
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading payments: $e')),
        );
      }
    }
  }

  void _changeMonth(int monthsToAdd) {
    setState(() {
      currentMonth = DateTime(currentMonth.year, currentMonth.month + monthsToAdd, 1);
    });
    fetchPayments();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(monthTitleFmt.format(currentMonth)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: currentMonth,
                firstDate: DateTime(2020),
                lastDate: DateTime.now().add(const Duration(days: 365)),
              );
              if (picked != null) {
                setState(() => currentMonth = picked);
                fetchPayments();
              }
            },
          )
        ],
      ),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left),
                      onPressed: () => _changeMonth(-1),
                    ),
                    Text(
                      currency.format(totalCollected),
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right),
                      onPressed: () => _changeMonth(1),
                    ),
                  ],
                ),
                const Text(
                  "Total Collected",
                  style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : payments.isEmpty
                    ? const Center(child: Text("No payments received this month."))
                    : ListView.builder(
                        itemCount: payments.length,
                        itemBuilder: (context, index) {
                          final p = payments[index];
                          final amount = currency.format(p['amount_paid']);
                          final dateStr = p['payment_date'] != null
                              ? dateFmt.format(DateTime.parse(p['payment_date']))
                              : '-';
                          
                          // ✅ Correctly extract name from joined object
                          String tenantName = 'Unknown Tenant';
                          if (p['tenants'] != null) {
                            tenantName = p['tenants']['name'] ?? 'Unknown Tenant';
                          }

                          final method = p['method'] ?? 'Cash';

                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            elevation: 1,
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Colors.blue[50],
                                child: const Icon(Icons.payment, color: Colors.blue, size: 20),
                              ),
                              title: Text(tenantName, style: const TextStyle(fontWeight: FontWeight.w600)),
                              subtitle: Text("$dateStr • $method"),
                              trailing: Text(
                                amount,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => PaymentDetailsPage(payment: p),
                                  ),
                                );
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

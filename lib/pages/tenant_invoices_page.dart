import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class TenantInvoicesPage extends StatefulWidget {
  final String tenantId;
  final String tenantName;

  const TenantInvoicesPage({
    super.key,
    required this.tenantId,
    required this.tenantName,
  });

  @override
  State<TenantInvoicesPage> createState() => _TenantInvoicesPageState();
}

class _TenantInvoicesPageState extends State<TenantInvoicesPage> {
  final supabase = Supabase.instance.client;
  String _filter = "unpaid"; // default filter
  final currencyFormatter = NumberFormat.currency(locale: 'en_PH', symbol: '₱');

  Future<List<Map<String, dynamic>>> fetchInvoices() async {
    try {
      dynamic response;

      if (_filter == "unpaid") {
        response = await supabase
            .from('invoice_payment_status')
            .select('invoice_id, tenant_name, due_date, amount_due, total_paid, balance')
            .eq('tenant_id', widget.tenantId)
            .gt('balance', 0) // unpaid invoices
            .order('due_date', ascending: true);
      } else if (_filter == "paid") {
        response = await supabase
            .from('invoice_payment_status')
            .select('invoice_id, tenant_name, due_date, amount_due, total_paid, balance')
            .eq('tenant_id', widget.tenantId)
            .eq('balance', 0) // fully paid invoices
            .order('due_date', ascending: true);
      } else {
        response = await supabase
            .from('invoice_payment_status')
            .select('invoice_id, tenant_name, due_date, amount_due, total_paid, balance')
            .eq('tenant_id', widget.tenantId)
            .order('due_date', ascending: true); // all invoices
      }

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error loading invoices: $e")),
      );
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("${widget.tenantName} - Invoices"),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // 🔘 Filter chips
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Wrap(
              spacing: 8,
              alignment: WrapAlignment.center,
              children: [
                ChoiceChip(
                  label: const Text("Unpaid"),
                  selected: _filter == "unpaid",
                  onSelected: (_) => setState(() => _filter = "unpaid"),
                ),
                ChoiceChip(
                  label: const Text("Paid"),
                  selected: _filter == "paid",
                  onSelected: (_) => setState(() => _filter = "paid"),
                ),
                ChoiceChip(
                  label: const Text("All"),
                  selected: _filter == "all",
                  onSelected: (_) => setState(() => _filter = "all"),
                ),
              ],
            ),
          ),

          // 📋 Invoice list
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: fetchInvoices(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text("Error: ${snapshot.error}"));
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text("No invoices found"));
                }

                final invoices = snapshot.data!;

                return RefreshIndicator(
                  onRefresh: fetchInvoices,
                  child: ListView.builder(
                    itemCount: invoices.length,
                    itemBuilder: (context, index) {
                      final invoice = invoices[index];

                      final dueDate = invoice['due_date'] != null
                          ? DateFormat("MMM dd, yyyy")
                          .format(DateTime.parse(invoice['due_date']))
                          : "-";

                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        child: ListTile(
                          title: Text(
                            invoice['tenant_name'] ?? "Unnamed Tenant",
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Due Date: $dueDate"),
                              Text(
                                "Amount Due: ${currencyFormatter.format(invoice['amount_due'] ?? 0)}",
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              Text(
                                "Paid: ${currencyFormatter.format(invoice['total_paid'] ?? 0)}",
                                style: const TextStyle(color: Colors.blueGrey),
                              ),
                              Text(
                                "Balance: ${currencyFormatter.format(invoice['balance'] ?? 0)}",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: (invoice['balance'] ?? 0) > 0
                                      ? const Color(0xFFAF2626)
                                      : Colors.green,
                                ),
                              ),
                            ],
                          ),
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

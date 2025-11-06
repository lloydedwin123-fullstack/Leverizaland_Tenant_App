import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../widgets/file_section_widget.dart';
import 'edit_arrear_details_page.dart';
import 'add_payment_page.dart';

class ArrearDetailsPage extends StatefulWidget {
  final Map<String, dynamic> arrear;

  const ArrearDetailsPage({super.key, required this.arrear});

  @override
  State<ArrearDetailsPage> createState() => _ArrearDetailsPageState();
}

class _ArrearDetailsPageState extends State<ArrearDetailsPage> {
  late Map<String, dynamic> _arrearData;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _arrearData = widget.arrear;
  }

  Future<void> _fetchArrearDetails({bool popOnSuccess = false}) async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final response = await Supabase.instance.client
          .from('invoice_payment_status')
          .select('*')
          .eq('invoice_id', _arrearData['invoice_id'])
          .single();

      if (mounted) {
        // If the balance is now zero, it means the invoice has been fully paid.
        final newBalance = response['balance'] ?? 0.0;
        if (newBalance <= 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Invoice has been fully paid!')),
          );
          // Pop back and signal a refresh is needed.
          Navigator.pop(context, true); 
          return;
        }

        setState(() {
          _arrearData = response;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching details: $e')),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormatter = NumberFormat.currency(locale: 'en_PH', symbol: '₱');
    final dueDate = _arrearData['due_date'] != null
        ? DateFormat('MMMM d, yyyy').format(DateTime.parse(_arrearData['due_date']))
        : '-';
    final propertyName =
        "${_arrearData['building'] ?? ''}${(_arrearData['unit_name'] ?? '').toString().trim().isNotEmpty ? ' ${_arrearData['unit_name']}' : ''}";
    final isPaid = (_arrearData['balance'] ?? 0) <= 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Arrear Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: 'Edit Invoice',
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => EditArrearDetailsPage(arrear: _arrearData),
                ),
              );

              if (result is Map<String, dynamic> && mounted) {
                setState(() {
                  _arrearData.addAll(result);
                });
              }
            },
          )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (propertyName.isNotEmpty && propertyName != '-')
                    Text(
                      propertyName,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                  const SizedBox(height: 8),
                  Text("Due Date: $dueDate", style: const TextStyle(fontSize: 16)),
                  Text("Category: ${_arrearData['category'] ?? 'N/A'}", style: const TextStyle(fontSize: 16)),
                  Text("Amount Due: ${currencyFormatter.format(_arrearData['amount_due'] ?? 0)}", style: const TextStyle(fontSize: 16)),
                  Text("Total Paid: ${currencyFormatter.format(_arrearData['total_paid'] ?? 0)}", style: const TextStyle(fontSize: 16)),
                  Text(
                    "Balance: ${currencyFormatter.format(_arrearData['balance'] ?? 0)}",
                    style: TextStyle(
                      color: isPaid ? Colors.green : const Color(0xFFAF2626),
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text("Remarks: ${_arrearData['remarks'] ?? '-'}", style: const TextStyle(fontSize: 14)),
                  const Divider(height: 30),
                  FileSectionWidget(
                    category: 'invoice_documents',
                    referenceId: _arrearData['invoice_id'].toString(),
                    isPublic: false,
                    title: 'Attached Documents',
                    canEdit: false,
                  ),
                  const SizedBox(height: 20),
                  // Only show the Add Payment button if there is a balance
                  if (!isPaid)
                    ElevatedButton.icon(
                      icon: const Icon(Icons.payment),
                      label: const Text('Add Payment'),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 50),
                      ),
                      onPressed: () async {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => AddPaymentPage(
                              tenantId: _arrearData['tenant_id'].toString(),
                              invoiceId: _arrearData['invoice_id'].toString(),
                            ),
                          ),
                        );

                        // If a payment was successfully added, re-fetch the details
                        if (result == true) {
                          _fetchArrearDetails();
                        }
                      },
                    ),
                ],
              ),
            ),
    );
  }
}

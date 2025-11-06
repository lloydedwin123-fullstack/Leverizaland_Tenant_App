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

  @override
  void initState() {
    super.initState();
    _arrearData = widget.arrear;
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
      body: SingleChildScrollView(
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
                  if (!isPaid)
                    ElevatedButton.icon(
                      icon: const Icon(Icons.payment),
                      label: const Text('Add Payment'),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 50),
                      ),
                      onPressed: () async {
                        final paymentAmount = await Navigator.push<double>(
                          context,
                          MaterialPageRoute(
                            builder: (context) => AddPaymentPage(
                              tenantId: _arrearData['tenant_id'].toString(),
                              invoiceId: _arrearData['invoice_id'].toString(),
                            ),
                          ),
                        );

                        if (paymentAmount != null && paymentAmount > 0 && mounted) {
                          final newTotalPaid = (_arrearData['total_paid'] ?? 0.0) + paymentAmount;
                          final newBalance = (_arrearData['amount_due'] ?? 0.0) - newTotalPaid;

                          if (newBalance <= 0) {
                             ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Invoice has been fully paid!')),
                            );
                            Navigator.pop(context, true); // Pop and signal a refresh
                          } else {
                            setState(() {
                              _arrearData['total_paid'] = newTotalPaid;
                              _arrearData['balance'] = newBalance;
                            });
                          }
                        }
                      },
                    ),
                ],
              ),
            ),
    );
  }
}

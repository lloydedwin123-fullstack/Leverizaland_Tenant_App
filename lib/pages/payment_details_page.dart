import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../widgets/file_section_widget.dart'; // 🧩 our reusable file widget
import 'edit_payment_page.dart';

class PaymentDetailsPage extends StatefulWidget {
  final Map<String, dynamic> payment;

  const PaymentDetailsPage({super.key, required this.payment});

  @override
  State<PaymentDetailsPage> createState() => _PaymentDetailsPageState();
}

class _PaymentDetailsPageState extends State<PaymentDetailsPage> {
  late Map<String, dynamic> _payment;

  @override
  void initState() {
    super.initState();
    _payment = widget.payment;
  }

  double _toDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0.0;
  }

  @override
  Widget build(BuildContext context) {
    final paymentId = _payment['id']?.toString() ?? '';
    final currency = NumberFormat.currency(locale: 'en_PH', symbol: '₱');
    final dateFmt = DateFormat('MMMM d, yyyy');

    final amount = _toDouble(_payment['amount_paid']);
    final method = _payment['method'] ?? '-';
    final ref = _payment['reference_no'] ?? '-';
    final remarks = _payment['remarks'] ?? '-';
    final date = _payment['payment_date'] != null
        ? dateFmt.format(DateTime.parse(_payment['payment_date']))
        : '-';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment Details'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => EditPaymentPage(payment: _payment),
                ),
              );
              if (result == true && mounted) {
                // Refetch the payment data if it was edited
                // For simplicity, we just pop for now. A better implementation
                // would be to pass back the updated payment data.
                Navigator.pop(context, true);
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ====== Payment Info Card ======
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Payment Information',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _buildRow(
                      'Amount Paid',
                      currency.format(amount),
                      Colors.green[800],
                    ),
                    _buildRow('Method', method),
                    _buildRow('Reference Code', ref),
                    _buildRow('Remarks', remarks),
                    _buildRow('Payment Date', date),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // ====== Attached Files Section (Reusable Widget) ======
            if (paymentId.isNotEmpty)
              FileSectionWidget(
                category: 'payment_proofs', // 🧩 unified category
                referenceId: paymentId,
                isPublic: false,             // 🛡️ private bucket
                title: 'Payment Proofs',     // section title
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRow(String label, String value, [Color? valueColor]) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                color: valueColor ?? Colors.black87,
                fontWeight:
                valueColor != null ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

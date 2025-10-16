import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/file_service.dart'; // ✅ Import FileService
import 'package:supabase_flutter/supabase_flutter.dart';

class PaymentDetailsPage extends StatelessWidget {
  final Map<String, dynamic> payment;

  const PaymentDetailsPage({super.key, required this.payment});

  double _toDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0.0;
  }

  @override
  Widget build(BuildContext context) {
    print('✅ Payment Data: $payment');

    final currency = NumberFormat.currency(locale: 'en_PH', symbol: '₱');
    final dateFmt = DateFormat('MMMM d, yyyy');

    final amount = _toDouble(payment['amount_paid']);
    final method = payment['method'] ?? '-';
    final ref = payment['reference_no'] ?? '-';
    final remarks = payment['remarks'] ?? '-';
    final date = payment['payment_date'] != null
        ? dateFmt.format(DateTime.parse(payment['payment_date']))
        : '-';

    final paymentId = payment['id']?.toString() ?? ''; // ✅ Important: ID used to fetch files
    final fileService = FileService(); // ✅ Initialize service

    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment Details'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
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

            // ====== Attached Files Section ======
            if (paymentId.isNotEmpty)
              Card(
                elevation: 1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: FutureBuilder<List<Map<String, dynamic>>>(
                    future: fileService.getFiles('payment', paymentId),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snapshot.hasError) {
                        return Text('Error loading files: ${snapshot.error}');
                      }

                      final files = snapshot.data ?? [];
                      if (files.isEmpty) {
                        return const Text(
                          'No attached files found.',
                          style: TextStyle(color: Colors.black54),
                        );
                      }

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Attached Files',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ...files.map((file) {
                            final fileName = file['file_name'] ?? 'Unnamed file';
                            final fileUrl = file['file_url'] ?? '';

                            return TextButton.icon(
                              icon: const Icon(Icons.attach_file, size: 20),
                              label: Text(
                                fileName,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.blue,
                                ),
                              ),
                              onPressed: () async {
                                final uri = Uri.parse(fileUrl);
                                if (await canLaunchUrl(uri)) {
                                  await launchUrl(
                                    uri,
                                    mode: LaunchMode.externalApplication,
                                  );
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Could not open the file link.'),
                                    ),
                                  );
                                }
                              },
                            );
                          }),
                        ],
                      );
                    },
                  ),
                ),
              ),

            const SizedBox(height: 12),
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

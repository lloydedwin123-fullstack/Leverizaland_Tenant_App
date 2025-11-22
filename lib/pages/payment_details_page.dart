import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/file_section_widget.dart';
import 'edit_payment_page.dart'; // ✅ Import EditPaymentPage

class PaymentDetailsPage extends StatefulWidget {
  final Map<String, dynamic> payment;

  const PaymentDetailsPage({super.key, required this.payment});

  @override
  State<PaymentDetailsPage> createState() => _PaymentDetailsPageState();
}

class _PaymentDetailsPageState extends State<PaymentDetailsPage> {
  late Map<String, dynamic> _paymentData;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _paymentData = widget.payment;
  }

  // ✅ Function to refetch payment details
  Future<void> _refreshPaymentDetails() async {
    setState(() => _isLoading = true);
    try {
      final response = await Supabase.instance.client
          .from('payments')
          .select()
          .eq('id', _paymentData['id'])
          .single();
      
      if (mounted) {
        setState(() {
          _paymentData = response;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error refreshing payment: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(locale: 'en_PH', symbol: '₱', decimalDigits: 2);
    final dateFmt = DateFormat('MMMM d, yyyy');

    final amount = (_paymentData['amount_paid'] ?? 0.0) as num;
    final method = _paymentData['method'] ?? 'N/A';
    final ref = _paymentData['reference_no'] ?? 'N/A';
    final remarks = _paymentData['remarks'] ?? 'N/A';
    final dateStr = _paymentData['payment_date'] != null
        ? dateFmt.format(DateTime.parse(_paymentData['payment_date']))
        : 'N/A';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () async {
              // ✅ Navigate to Edit Page and wait for result
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => EditPaymentPage(payment: _paymentData),
                ),
              );

              // If edit page returns true, refresh the data
              if (result == true && mounted) {
                _refreshPaymentDetails();
              }
            },
          ),
        ],
      ),
      body: _isLoading
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                // Payment Information Card
                Card(
                  elevation: 1,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Payment Information',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const Divider(height: 20),
                        _buildDetailRow(context, 'Amount Paid:', currency.format(amount), isAmount: true),
                        _buildDetailRow(context, 'Method:', method),
                        _buildDetailRow(context, 'Reference Code:', ref),
                        _buildDetailRow(context, 'Remarks:', remarks),
                        _buildDetailRow(context, 'Payment Date:', dateStr),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 20),

                // Payment Proofs Section
                FileSectionWidget(
                  category: 'payment_proofs',
                  referenceId: _paymentData['id'].toString(),
                  isPublic: false, // Payment proofs should be private
                  title: 'Payment Proofs',
                ),
              ],
            ),
          ),
    );
  }

  Widget _buildDetailRow(BuildContext context, String label, String value, {bool isAmount = false}) {
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: textTheme.bodyMedium?.copyWith(
              color: textTheme.bodyMedium?.color?.withOpacity(0.7),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: textTheme.bodyLarge?.copyWith(
                fontWeight: isAmount ? FontWeight.bold : FontWeight.normal,
                color: isAmount ? Colors.green : textTheme.bodyLarge?.color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

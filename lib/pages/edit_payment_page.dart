import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

import '../widgets/file_section_widget.dart';

class EditPaymentPage extends StatefulWidget {
  final Map<String, dynamic> payment;

  const EditPaymentPage({super.key, required this.payment});

  @override
  State<EditPaymentPage> createState() => _EditPaymentPageState();
}

class _EditPaymentPageState extends State<EditPaymentPage> {
  final supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();
  bool isSaving = false;

  // Text Controllers
  late TextEditingController _amountCtrl;
  late TextEditingController _paymentDateCtrl;
  late TextEditingController _methodCtrl;
  late TextEditingController _referenceNoCtrl;
  late TextEditingController _remarksCtrl;

  @override
  void initState() {
    super.initState();
    _amountCtrl = TextEditingController(text: widget.payment['amount_paid']?.toString());
    _paymentDateCtrl = TextEditingController(text: widget.payment['payment_date']);
    _methodCtrl = TextEditingController(text: widget.payment['method']);
    _referenceNoCtrl = TextEditingController(text: widget.payment['reference_no']);
    _remarksCtrl = TextEditingController(text: widget.payment['remarks']);
  }

  Future<void> _savePayment() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => isSaving = true);

    try {
      await supabase.from('payments').update({
        'amount_paid': double.tryParse(_amountCtrl.text) ?? 0,
        'payment_date': _paymentDateCtrl.text,
        'method': _methodCtrl.text,
        'reference_no': _referenceNoCtrl.text,
        'remarks': _remarksCtrl.text,
      }).eq('id', widget.payment['id']);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payment updated successfully!')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating payment: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Payment'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: isSaving ? null : _savePayment,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _amountCtrl,
                decoration: const InputDecoration(labelText: 'Amount Paid'),
                keyboardType: TextInputType.number,
                validator: (value) => value!.isEmpty ? 'Please enter an amount' : null,
              ),
              TextFormField(
                controller: _paymentDateCtrl,
                decoration: const InputDecoration(labelText: 'Payment Date (YYYY-MM-DD)'),
                validator: (value) => value!.isEmpty ? 'Please enter a date' : null,
              ),
              TextFormField(
                controller: _methodCtrl,
                decoration: const InputDecoration(labelText: 'Payment Method'),
              ),
              TextFormField(
                controller: _referenceNoCtrl,
                decoration: const InputDecoration(labelText: 'Reference Number'),
              ),
              TextFormField(
                controller: _remarksCtrl,
                decoration: const InputDecoration(labelText: 'Remarks'),
                maxLines: 3,
              ),
              const SizedBox(height: 20),
              FileSectionWidget(
                category: 'payment_proofs',
                referenceId: widget.payment['id'].toString(),
                isPublic: false,
                title: 'Payment Proofs',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

import '../widgets/file_section_widget.dart';
import '../services/file_service.dart';

class AddPaymentPage extends StatefulWidget {
  final String tenantId;
  final String? invoiceId;

  const AddPaymentPage({super.key, required this.tenantId, this.invoiceId});

  @override
  State<AddPaymentPage> createState() => _AddPaymentPageState();
}

class _AddPaymentPageState extends State<AddPaymentPage> {
  final supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();
  final _fileService = FileService();
  bool isSaving = false;

  // Text Controllers
  late TextEditingController _amountCtrl;
  late TextEditingController _paymentDateCtrl;
  late TextEditingController _methodCtrl;
  late TextEditingController _referenceNoCtrl;
  late TextEditingController _remarksCtrl;
  final List<String> _paymentMethods = ['Cash', 'Check', 'Bank Transfer', 'GCash', 'GoTyme', 'Other'];

  late Future<double?> _invoiceBalanceFuture;
  File? _selectedFile;

  @override
  void initState() {
    super.initState();
    _amountCtrl = TextEditingController();
    _paymentDateCtrl = TextEditingController(text: DateFormat('yyyy-MM-dd').format(DateTime.now()));
    _methodCtrl = TextEditingController(text: _paymentMethods.first);
    _referenceNoCtrl = TextEditingController();
    _remarksCtrl = TextEditingController();

    _invoiceBalanceFuture = _fetchInvoiceBalance();
  }

  Future<double?> _fetchInvoiceBalance() async {
    if (widget.invoiceId == null) return null;

    try {
      final response = await supabase
          .from('invoice_payment_status')
          .select('balance')
          .eq('invoice_id', widget.invoiceId!)
          .single();
      
      final balance = response['balance'] ?? 0.0;
      if (mounted) {
        _amountCtrl.text = balance.toString();
      }
      return balance;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching invoice balance: $e')),
        );
      }
      return null;
    }
  }

  DateTime? _tryParseDate(String input) {
    final formats = [
      'yyyy-MM-dd',
      'MM/dd/yyyy',
      'dd/MM/yyyy',
      'MM-dd-yyyy',
      'dd-MM-yyyy',
      'MMM d, yyyy',
      'MMMM d, yyyy',
    ];

    for (final format in formats) {
      try {
        return DateFormat(format).parseStrict(input);
      } catch (e) {
        // Try the next format
      }
    }

    final lowerCaseInput = input.toLowerCase();
    if (lowerCaseInput == 'today') {
      return DateTime.now();
    }
    if (lowerCaseInput == 'tomorrow') {
      return DateTime.now().add(const Duration(days: 1));
    }

    return null;
  }

  Future<void> _savePayment() async {
    if (mounted && !_formKey.currentState!.validate()) return;

    setState(() => isSaving = true);
    final amountPaid = double.tryParse(_amountCtrl.text) ?? 0;

    try {
      final parsedDate = _tryParseDate(_paymentDateCtrl.text);
      if (parsedDate == null) {
        throw Exception('Invalid date format.');
      }

      // Phase 1: Save the payment record and get the new ID
      final newPayment = await supabase.from('payments').insert({
        'tenant_id': widget.tenantId,
        'invoice_id': widget.invoiceId,
        'amount_paid': amountPaid,
        'payment_date': DateFormat('yyyy-MM-dd').format(parsedDate),
        'method': _methodCtrl.text,
        'reference_no': _referenceNoCtrl.text,
        'remarks': _remarksCtrl.text,
      }).select('id').single();

      final newPaymentId = newPayment['id'];

      // Phase 2: If a file was selected, upload it and link it to the new payment
      if (_selectedFile != null) {
        await _fileService.uploadFile(
          category: 'payment_proofs',
          referenceId: newPaymentId,
          file: _selectedFile!,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payment added successfully!')),
        );
        // Return the amount paid so the previous screen can update its state instantly
        Navigator.pop(context, amountPaid);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving payment: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => isSaving = false);
      }
    }
  }

  Future<void> _pickFile() async {
    final file = await _fileService.pickFile(context);
    if (file != null) {
      setState(() {
        _selectedFile = file;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Payment'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: isSaving ? null : _savePayment,
          ),
        ],
      ),
      body: FutureBuilder<double?>(
        future: _invoiceBalanceFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          return SingleChildScrollView(
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
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _paymentDateCtrl,
                    decoration: InputDecoration(
                      labelText: 'Payment Date',
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.calendar_today),
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _tryParseDate(_paymentDateCtrl.text) ?? DateTime.now(),
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2101),
                          );
                          if (picked != null && mounted) {
                            setState(() {
                              _paymentDateCtrl.text = DateFormat('yyyy-MM-dd').format(picked);
                            });
                          }
                        },
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Please enter a date';
                      if (_tryParseDate(value) == null) return 'Invalid date format';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _methodCtrl,
                    decoration: InputDecoration(
                      labelText: 'Payment Method',
                      suffixIcon: PopupMenuButton<String>(
                        icon: const Icon(Icons.arrow_drop_down),
                        onSelected: (String value) {
                          setState(() {
                            _methodCtrl.text = value;
                          });
                        },
                        itemBuilder: (BuildContext context) {
                          return _paymentMethods.map((String choice) {
                            return PopupMenuItem<String>(
                              value: choice,
                              child: Text(choice),
                            );
                          }).toList();
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _referenceNoCtrl,
                    decoration: const InputDecoration(labelText: 'Reference Number'),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _remarksCtrl,
                    decoration: const InputDecoration(labelText: 'Remarks'),
                    maxLines: 3,
                  ),
                  const Divider(height: 40),
                  // --- Payment Proofs ---
                  Card(
                    elevation: 1,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Payment Proofs',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              IconButton(
                                icon: const Icon(Icons.upload_file, color: Colors.blue),
                                tooltip: 'Attach File',
                                onPressed: _pickFile,
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          if (_selectedFile == null)
                            const Text('No file selected.')
                          else
                            ListTile(
                              leading: const Icon(Icons.attach_file),
                              title: Text(_selectedFile!.path.split('/').last),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () {
                                  setState(() {
                                    _selectedFile = null;
                                  });
                                },
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

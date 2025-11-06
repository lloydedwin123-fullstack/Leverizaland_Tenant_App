import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

import '../widgets/file_section_widget.dart';

class AddInvoicePage extends StatefulWidget {
  final String tenantId;
  final String tenantName;

  const AddInvoicePage({super.key, required this.tenantId, required this.tenantName});

  @override
  State<AddInvoicePage> createState() => _AddInvoicePageState();
}

class _AddInvoicePageState extends State<AddInvoicePage> {
  final supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();
  bool isSaving = false;

  // Text Controllers
  late TextEditingController _amountCtrl;
  late TextEditingController _dueDateCtrl;
  late TextEditingController _remarksCtrl;
  String? _selectedCategory;
  final List<String> _categories = ['Rent', 'Water', 'Electricity', 'Repairs', 'Other'];

  @override
  void initState() {
    super.initState();
    _amountCtrl = TextEditingController();
    _dueDateCtrl = TextEditingController();
    _remarksCtrl = TextEditingController();
    _selectedCategory = _categories.first; // Default to 'Rent'
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

  Future<void> _saveInvoice() async {
    if (mounted && !_formKey.currentState!.validate()) return;

    setState(() => isSaving = true);

    try {
      final parsedDate = _tryParseDate(_dueDateCtrl.text);
      if (parsedDate == null) {
        throw Exception('Invalid date format. Please use a recognizable date.');
      }
      final formattedDate = DateFormat('yyyy-MM-dd').format(parsedDate);

      // First, get the active lease for the tenant
      final leases = await supabase
          .from('leases')
          .select('id')
          .eq('tenant_id', widget.tenantId)
          .eq('status', 'Active');

      if (leases.isEmpty) {
        throw Exception('No active lease found for this tenant.');
      }

      final leaseId = leases[0]['id'];

      await supabase.from('invoices').insert({
        'tenant_id': widget.tenantId,
        'lease_id': leaseId,
        'amount_due': double.tryParse(_amountCtrl.text) ?? 0,
        'due_date': formattedDate,
        'remarks': _remarksCtrl.text,
        'category': _selectedCategory,
      }).select('id').single();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invoice added successfully!')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving invoice: $e')),
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
        title: Text('Add Invoice for ${widget.tenantName}'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DropdownButtonFormField<String>(
                value: _selectedCategory,
                items: _categories.map((String category) {
                  return DropdownMenuItem<String>(
                    value: category,
                    child: Text(category),
                  );
                }).toList(),
                onChanged: (newValue) {
                  setState(() {
                    _selectedCategory = newValue;
                  });
                },
                decoration: const InputDecoration(labelText: 'Category'),
              ),
              TextFormField(
                controller: _amountCtrl,
                decoration: const InputDecoration(labelText: 'Amount'),
                keyboardType: TextInputType.number,
                validator: (value) => value!.isEmpty ? 'Please enter an amount' : null,
              ),
              TextFormField(
                controller: _dueDateCtrl,
                decoration: InputDecoration(
                  labelText: 'Due Date',
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.calendar_today),
                    onPressed: () async {
                      FocusScope.of(context).unfocus(); // Hide keyboard
                      DateTime? pickedDate = await showDatePicker(
                        context: context,
                        initialDate: _tryParseDate(_dueDateCtrl.text) ?? DateTime.now(),
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2101),
                      );

                      if (pickedDate != null && mounted) {
                        String formattedDate = DateFormat('yyyy-MM-dd').format(pickedDate);
                        setState(() {
                          _dueDateCtrl.text = formattedDate;
                        });
                      }
                    },
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a due date';
                  }
                  if (_tryParseDate(value) == null) {
                    return 'Invalid date format';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _remarksCtrl,
                decoration: const InputDecoration(labelText: 'Remarks'),
                maxLines: 3,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: isSaving ? null : _saveInvoice,
                child: const Text('Save Invoice'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

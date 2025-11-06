import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../widgets/file_section_widget.dart';

class EditArrearDetailsPage extends StatefulWidget {
  final Map<String, dynamic> arrear;

  const EditArrearDetailsPage({super.key, required this.arrear});

  @override
  State<EditArrearDetailsPage> createState() => _EditArrearDetailsPageState();
}

class _EditArrearDetailsPageState extends State<EditArrearDetailsPage> {
  final _formKey = GlobalKey<FormState>();
  final supabase = Supabase.instance.client;
  bool isSaving = false;

  // Controllers for editing
  late TextEditingController _amountCtrl;
  late TextEditingController _dueDateCtrl;
  late TextEditingController _remarksCtrl;
  String? _selectedCategory;
  final List<String> _categories = ['Rent', 'Water', 'Electricity', 'Repairs', 'Other'];

  @override
  void initState() {
    super.initState();
    // Initialize controllers with existing arrear data
    _amountCtrl = TextEditingController(text: widget.arrear['amount_due']?.toString() ?? '');
    _dueDateCtrl = TextEditingController(text: widget.arrear['due_date'] ?? '');
    _remarksCtrl = TextEditingController(text: widget.arrear['remarks'] ?? '');
    _selectedCategory = widget.arrear['category'];
    if (!_categories.contains(_selectedCategory)) {
      _selectedCategory = 'Other'; // Default to 'Other' if category is not in the list
    }
  }

  Future<void> _saveChanges() async {
    if (mounted && !_formKey.currentState!.validate()) return;

    setState(() => isSaving = true);

    try {
      final updatedData = {
        'amount_due': double.tryParse(_amountCtrl.text) ?? 0,
        'due_date': _dueDateCtrl.text,
        'remarks': _remarksCtrl.text,
        'category': _selectedCategory,
      };

      await supabase
          .from('invoices')
          .update(updatedData)
          .eq('id', widget.arrear['invoice_id']);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invoice updated successfully!')),
        );
        // Return the updated data to the previous screen
        Navigator.pop(context, updatedData);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating invoice: $e')),
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
        title: const Text('Edit Invoice'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: isSaving ? null : _saveChanges,
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
              // --- Editable Invoice Details ---
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
              const SizedBox(height: 16),
              TextFormField(
                controller: _amountCtrl,
                decoration: const InputDecoration(labelText: 'Amount Due'),
                keyboardType: TextInputType.number,
                validator: (value) => value!.isEmpty ? 'Please enter an amount' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _dueDateCtrl,
                readOnly: true,
                decoration: const InputDecoration(
                  labelText: 'Due Date',
                ),
                onTap: () async {
                  DateTime? pickedDate = await showDatePicker(
                    context: context,
                    initialDate: DateTime.tryParse(_dueDateCtrl.text) ?? DateTime.now(),
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2101),
                  );
                  if (pickedDate != null && mounted) {
                    setState(() {
                      _dueDateCtrl.text = DateFormat('yyyy-MM-dd').format(pickedDate);
                    });
                  }
                },
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Please enter a due date';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _remarksCtrl,
                decoration: const InputDecoration(labelText: 'Remarks'),
                maxLines: 3,
              ),
              const Divider(height: 40),

              // --- Actions ---
              FileSectionWidget(
                category: 'invoice_documents',
                referenceId: widget.arrear['invoice_id'].toString(),
                isPublic: false,
                title: 'Attached Documents',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

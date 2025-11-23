import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../services/file_service.dart';

class AddExpensePage extends StatefulWidget {
  const AddExpensePage({super.key});

  @override
  State<AddExpensePage> createState() => _AddExpensePageState();
}

class _AddExpensePageState extends State<AddExpensePage> {
  final supabase = Supabase.instance.client;
  final fileService = FileService();
  final _formKey = GlobalKey<FormState>();
  bool isSaving = false;

  // Controllers
  final _titleCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  DateTime selectedDate = DateTime.now();
  String? selectedCategory;
  String? selectedUnitId;
  File? _receiptFile;

  final List<String> categories = [
    'Maintenance & Repairs',
    'Utilities',
    'Taxes & Licenses',
    'Insurance',
    'Legal & Professional',
    'Supplies',
    'Advertising',
    'Other',
  ];

  List<Map<String, dynamic>> units = [];

  @override
  void initState() {
    super.initState();
    fetchUnits();
  }

  Future<void> fetchUnits() async {
    try {
      final response = await supabase
          .from('units')
          .select('id, building, unit_number')
          .order('building');
      
      if (mounted) {
        setState(() {
          units = List<Map<String, dynamic>>.from(response);
        });
      }
    } catch (e) {
      debugPrint('Error loading units: $e');
    }
  }

  Future<void> _pickReceipt() async {
    final file = await fileService.pickFile(context);
    if (file != null) {
      setState(() => _receiptFile = file);
    }
  }

  Future<void> _saveExpense() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => isSaving = true);

    try {
      // 1. Insert Expense
      final response = await supabase.from('expenses').insert({
        'title': _titleCtrl.text.trim(),
        'amount': double.tryParse(_amountCtrl.text) ?? 0.0,
        'date': DateFormat('yyyy-MM-dd').format(selectedDate),
        'category': selectedCategory,
        'unit_id': selectedUnitId,
        'notes': _notesCtrl.text.trim(),
      }).select('id').single();

      final newExpenseId = response['id'].toString();

      // 2. Upload Receipt if selected
      if (_receiptFile != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Uploading receipt...')),
          );
        }
        await fileService.uploadFile(
          category: 'expense_receipts',
          referenceId: newExpenseId,
          file: _receiptFile!,
          isPublic: false,
          documentType: 'Receipt',
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Expense saved successfully!')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving expense: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Log Expense')),
      body: isSaving
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    TextFormField(
                      controller: _titleCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Expense Title',
                        hintText: 'e.g. Aircon Repair',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.title),
                      ),
                      validator: (v) => v!.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),

                    // Amount & Date
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _amountCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Amount (₱)',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.attach_money),
                            ),
                            validator: (v) => v!.isEmpty ? 'Required' : null,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: selectedDate,
                                firstDate: DateTime(2020),
                                lastDate: DateTime.now(),
                              );
                              if (picked != null) {
                                setState(() => selectedDate = picked);
                              }
                            },
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'Date',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.calendar_today),
                              ),
                              child: Text(DateFormat('MMM d, yyyy').format(selectedDate)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Category
                    DropdownButtonFormField<String>(
                      value: selectedCategory,
                      decoration: const InputDecoration(
                        labelText: 'Category',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.category),
                      ),
                      items: categories.map((c) {
                        return DropdownMenuItem(value: c, child: Text(c));
                      }).toList(),
                      onChanged: (val) => setState(() => selectedCategory = val),
                      validator: (v) => v == null ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),

                    // Unit Link (Optional)
                    DropdownButtonFormField<String>(
                      value: selectedUnitId,
                      decoration: const InputDecoration(
                        labelText: 'Linked Unit (Optional)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.apartment),
                        helperText: 'Leave blank for general property expenses',
                      ),
                      items: units.map((u) {
                        final name = "${u['building']} ${u['unit_number'] ?? ''}";
                        return DropdownMenuItem(
                          value: u['id'].toString(),
                          child: Text(name),
                        );
                      }).toList(),
                      onChanged: (val) => setState(() => selectedUnitId = val),
                    ),
                    const SizedBox(height: 16),

                    // Notes
                    TextFormField(
                      controller: _notesCtrl,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Notes / Description',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.notes),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Receipt Attachment
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Theme.of(context).dividerColor),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Receipt / Invoice (Optional)", style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.receipt_long),
                            title: Text(_receiptFile == null ? "No receipt attached" : _receiptFile!.path.split('/').last),
                            trailing: TextButton.icon(
                              onPressed: _pickReceipt,
                              icon: Icon(_receiptFile == null ? Icons.upload_file : Icons.change_circle),
                              label: Text(_receiptFile == null ? "Attach" : "Change"),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: _saveExpense,
                        icon: const Icon(Icons.check),
                        label: const Text('Save Expense'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.primary,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

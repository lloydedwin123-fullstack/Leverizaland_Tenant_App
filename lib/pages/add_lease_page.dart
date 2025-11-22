import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../services/file_service.dart'; // ✅ Import File Service

class AddLeasePage extends StatefulWidget {
  final String unitId;
  final String unitName;
  final double defaultRent;

  const AddLeasePage({
    super.key,
    required this.unitId,
    required this.unitName,
    required this.defaultRent,
  });

  @override
  State<AddLeasePage> createState() => _AddLeasePageState();
}

class _AddLeasePageState extends State<AddLeasePage> {
  final supabase = Supabase.instance.client;
  final fileService = FileService(); // ✅ Init File Service
  final _formKey = GlobalKey<FormState>();
  bool isSaving = false;

  // Form Fields
  String? selectedTenantId;
  String? selectedTenantName;
  
  late TextEditingController _rentCtrl;
  late TextEditingController _depositCtrl;
  late TextEditingController _advanceCtrl;
  late TextEditingController _escalationRateCtrl;
  late TextEditingController _escalationPeriodCtrl;

  DateTime startDate = DateTime.now();
  DateTime endDate = DateTime.now().add(const Duration(days: 365)); // Default 1 year

  final dateFmt = DateFormat('yyyy-MM-dd');

  List<Map<String, dynamic>> tenants = [];
  File? _leaseDoc; // ✅ Holds the picked file

  @override
  void initState() {
    super.initState();
    _rentCtrl = TextEditingController(text: widget.defaultRent.toString());
    _depositCtrl = TextEditingController(text: '0');
    _advanceCtrl = TextEditingController(text: '0');
    _escalationRateCtrl = TextEditingController(text: '0');
    _escalationPeriodCtrl = TextEditingController(text: '1');
    
    fetchTenants();
  }

  Future<void> fetchTenants() async {
    try {
      final response = await supabase
          .from('tenants')
          .select('id, name')
          .eq('active', true)
          .order('name', ascending: true);
      
      if (mounted) {
        setState(() {
          tenants = List<Map<String, dynamic>>.from(response);
        });
      }
    } catch (e) {
      debugPrint('Error fetching tenants: $e');
    }
  }

  // ✅ Pick File Function
  Future<void> _pickFile() async {
    final file = await fileService.pickFile(context);
    if (file != null) {
      setState(() => _leaseDoc = file);
    }
  }

  Future<void> _saveLease() async {
    if (!_formKey.currentState!.validate()) return;
    if (selectedTenantId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a tenant.')),
      );
      return;
    }

    setState(() => isSaving = true);

    try {
      // 1. Insert Lease and RETURN ID
      final response = await supabase.from('leases').insert({
        'unit_id': widget.unitId,
        'tenant_id': selectedTenantId,
        'start_date': dateFmt.format(startDate),
        'end_date': dateFmt.format(endDate),
        'rent_amount': double.tryParse(_rentCtrl.text) ?? 0,
        'security_deposit': double.tryParse(_depositCtrl.text) ?? 0,
        'advance_rent': double.tryParse(_advanceCtrl.text) ?? 0,
        'escalation_rate': double.tryParse(_escalationRateCtrl.text) ?? 0,
        'escalation_period_years': int.tryParse(_escalationPeriodCtrl.text) ?? 1,
        'status': 'Active',
        'tenant_name': selectedTenantName,
      }).select('id').single(); // ✅ Select ID

      final newLeaseId = response['id'].toString();

      // 2. Upload File if selected
      if (_leaseDoc != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Uploading document...')),
          );
        }
        await fileService.uploadFile(
          category: 'lease_documents', // Matches standard lease doc category
          referenceId: newLeaseId,
          file: _leaseDoc!,
          isPublic: false, // Private by default
          documentType: 'Lease Contract',
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Lease created successfully!')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating lease: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

  Future<void> _pickDate(bool isStart) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? startDate : endDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          startDate = picked;
          if (endDate.isBefore(startDate)) {
            endDate = startDate.add(const Duration(days: 365));
          }
        } else {
          endDate = picked;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Add New Lease")),
      body: isSaving
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Unit: ${widget.unitName}", 
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                    const SizedBox(height: 20),

                    // Tenant Selector
                    DropdownButtonFormField<String>(
                      value: selectedTenantId,
                      decoration: const InputDecoration(
                        labelText: "Select Tenant",
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person),
                      ),
                      items: tenants.map((t) {
                        return DropdownMenuItem<String>(
                          value: t['id'].toString(),
                          child: Text(t['name']),
                        );
                      }).toList(),
                      onChanged: (val) {
                        setState(() {
                          selectedTenantId = val;
                          selectedTenantName = tenants.firstWhere((t) => t['id'].toString() == val)['name'];
                        });
                      },
                      validator: (v) => v == null ? "Required" : null,
                    ),
                    const SizedBox(height: 16),

                    // Dates Row
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () => _pickDate(true),
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                labelText: "Start Date",
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.calendar_today),
                              ),
                              child: Text(dateFmt.format(startDate)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: InkWell(
                            onTap: () => _pickDate(false),
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                labelText: "End Date",
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.event),
                              ),
                              child: Text(dateFmt.format(endDate)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Financials
                    TextFormField(
                      controller: _rentCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: "Monthly Rent (₱)",
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.money),
                      ),
                      validator: (v) => v!.isEmpty ? "Required" : null,
                    ),
                    const SizedBox(height: 16),
                    
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _depositCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: "Security Deposit",
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: _advanceCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: "Advance Rent",
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Escalation
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _escalationRateCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: "Escalation Rate (%)",
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: _escalationPeriodCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: "Every (Years)",
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // ✅ Lease Document Section
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Lease Document (Contract)", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                          const SizedBox(height: 8),
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.description, color: Colors.blue),
                            title: Text(_leaseDoc == null ? "No file attached" : _leaseDoc!.path.split('/').last),
                            trailing: TextButton.icon(
                              onPressed: _pickFile,
                              icon: Icon(_leaseDoc == null ? Icons.upload_file : Icons.change_circle),
                              label: Text(_leaseDoc == null ? "Attach File" : "Change"),
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
                        onPressed: _saveLease,
                        icon: const Icon(Icons.check),
                        label: const Text("Create Lease"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
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

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AddUnitPage extends StatefulWidget {
  const AddUnitPage({super.key});

  @override
  State<AddUnitPage> createState() => _AddUnitPageState();
}

class _AddUnitPageState extends State<AddUnitPage> {
  final supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();
  bool isSaving = false;

  // Controllers
  final _buildingCtrl = TextEditingController();
  final _unitNumberCtrl = TextEditingController();
  final _rentCtrl = TextEditingController();
  final _waterAccountCtrl = TextEditingController();
  final _waterMeterCtrl = TextEditingController();
  final _electricAccountCtrl = TextEditingController();
  final _electricMeterCtrl = TextEditingController();

  Future<void> _saveUnit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => isSaving = true);

    try {
      await supabase.from('units').insert({
        'building': _buildingCtrl.text.trim(),
        'unit_number': _unitNumberCtrl.text.trim(),
        'current_rent_amount': double.tryParse(_rentCtrl.text) ?? 0.0,
        'water_account_no': _waterAccountCtrl.text.trim(),
        'water_meter_no': _waterMeterCtrl.text.trim(),
        'electric_account_no': _electricAccountCtrl.text.trim(),
        'electric_meter_no': _electricMeterCtrl.text.trim(),
        'created_at': DateTime.now().toIso8601String(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unit added successfully!')),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding unit: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

  @override
  void dispose() {
    _buildingCtrl.dispose();
    _unitNumberCtrl.dispose();
    _rentCtrl.dispose();
    _waterAccountCtrl.dispose();
    _waterMeterCtrl.dispose();
    _electricAccountCtrl.dispose();
    _electricMeterCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Add New Unit")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              _buildTextField("Building Name *", _buildingCtrl, required: true),
              _buildTextField("Unit Number", _unitNumberCtrl),
              _buildTextField("Current Rent (₱) *", _rentCtrl, isNumber: true, required: true),
              const Divider(height: 32),
              _buildTextField("Water Account #", _waterAccountCtrl),
              _buildTextField("Water Meter #", _waterMeterCtrl),
              _buildTextField("Electric Account #", _electricAccountCtrl),
              _buildTextField("Electric Meter #", _electricMeterCtrl),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: isSaving ? null : _saveUnit,
                  icon: isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.save),
                  label: Text(isSaving ? "Saving..." : "Save Unit"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController ctrl,
      {bool isNumber = false, bool required = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: ctrl,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        validator: (v) {
          if (required && (v == null || v.trim().isEmpty)) {
            return "$label is required";
          }
          return null;
        },
      ),
    );
  }
}

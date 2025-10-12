import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class EditUnitPage extends StatefulWidget {
  final Map<String, dynamic> unit;

  const EditUnitPage({super.key, required this.unit});

  @override
  State<EditUnitPage> createState() => _EditUnitPageState();
}

class _EditUnitPageState extends State<EditUnitPage> {
  final supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _buildingCtrl;
  late TextEditingController _unitNumberCtrl;
  late TextEditingController _rentCtrl;
  late TextEditingController _rentalStartCtrl;
  late TextEditingController _waterMeterCtrl;
  late TextEditingController _electricMeterCtrl;
  late TextEditingController _waterAccountCtrl;
  late TextEditingController _electricAccountCtrl;

  bool isSaving = false;

  @override
  void initState() {
    super.initState();
    final u = widget.unit;
    _buildingCtrl = TextEditingController(text: u['building'] ?? '');
    _unitNumberCtrl = TextEditingController(text: u['unit_number'] ?? '');
    _rentCtrl = TextEditingController(
        text: u['current_rent_amount']?.toString() ?? '');
    _rentalStartCtrl = TextEditingController(
        text: u['rental_start_date'] ?? '');
    _waterMeterCtrl = TextEditingController(text: u['water_meter_no'] ?? '');
    _electricMeterCtrl = TextEditingController(text: u['electric_meter_no'] ?? '');
    _waterAccountCtrl = TextEditingController(text: u['water_account_no'] ?? '');
    _electricAccountCtrl = TextEditingController(text: u['electric_account_no'] ?? '');
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => isSaving = true);

    try {
      await supabase.from('units').update({
        'building': _buildingCtrl.text.trim(),
        'unit_number': _unitNumberCtrl.text.trim(),
        'current_rent_amount': double.tryParse(_rentCtrl.text) ?? 0,
        'rental_start_date': _rentalStartCtrl.text.isNotEmpty
            ? _rentalStartCtrl.text
            : null,
        'water_meter_no': _waterMeterCtrl.text.trim(),
        'electric_meter_no': _electricMeterCtrl.text.trim(),
        'water_account_no': _waterAccountCtrl.text.trim(),
        'electric_account_no': _electricAccountCtrl.text.trim(),
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', widget.unit['id']);

      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Unit updated successfully.')));
      Navigator.pop(context, true);
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error updating unit: $e')));
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

  @override
  void dispose() {
    _buildingCtrl.dispose();
    _unitNumberCtrl.dispose();
    _rentCtrl.dispose();
    _rentalStartCtrl.dispose();
    _waterMeterCtrl.dispose();
    _electricMeterCtrl.dispose();
    _waterAccountCtrl.dispose();
    _electricAccountCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Unit Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: isSaving ? null : _saveChanges,
          )
        ],
      ),
      body: isSaving
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              _buildField('Building', _buildingCtrl),
              _buildField('Unit Number', _unitNumberCtrl),
              _buildField('Rent Amount (₱)', _rentCtrl, keyboardType: TextInputType.number),
              _buildField('Rental Start Date (YYYY-MM-DD)', _rentalStartCtrl),
              const SizedBox(height: 10),
              const Divider(),
              _buildField('Water Meter #', _waterMeterCtrl),
              _buildField('Electric Meter #', _electricMeterCtrl),
              _buildField('Water Account #', _waterAccountCtrl),
              _buildField('Electric Account #', _electricAccountCtrl),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                icon: const Icon(Icons.save),
                label: const Text('Save Changes'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                ),
                onPressed: isSaving ? null : _saveChanges,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildField(String label, TextEditingController controller,
      {TextInputType keyboardType = TextInputType.text}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
        validator: (v) {
          if (label == 'Rent Amount (₱)' && (v == null || v.isEmpty)) {
            return 'Enter rent amount';
          }
          return null;
        },

      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class EditLeasePage extends StatefulWidget {
  final Map<String, dynamic> lease;

  const EditLeasePage({super.key, required this.lease});

  @override
  State<EditLeasePage> createState() => _EditLeasePageState();
}

class _EditLeasePageState extends State<EditLeasePage> {
  final supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();

  // Controllers
  late TextEditingController _startDateCtrl;
  late TextEditingController _endDateCtrl;
  late TextEditingController _rentCtrl;
  late TextEditingController _securityDepositCtrl;
  late TextEditingController _advanceRentCtrl;
  late TextEditingController _advanceEffectivityCtrl;
  late TextEditingController _escalationRateCtrl;
  late TextEditingController _escalationPeriodCtrl;
  late TextEditingController _notesCtrl;
  late TextEditingController _statusCtrl;

  bool isSaving = false;
  final dateFmt = DateFormat('yyyy-MM-dd');

  @override
  void initState() {
    super.initState();
    final l = widget.lease;
    _startDateCtrl = TextEditingController(text: l['start_date'] ?? '');
    _endDateCtrl = TextEditingController(text: l['end_date'] ?? '');
    _rentCtrl = TextEditingController(text: l['rent_amount']?.toString() ?? '');
    _securityDepositCtrl = TextEditingController(text: l['security_deposit']?.toString() ?? '');
    _advanceRentCtrl = TextEditingController(text: l['advance_rent']?.toString() ?? '');
    _advanceEffectivityCtrl = TextEditingController(text: l['advance_effectivity'] ?? '');
    _escalationRateCtrl = TextEditingController(text: l['escalation_rate']?.toString() ?? '');
    _escalationPeriodCtrl = TextEditingController(text: l['escalation_period_years']?.toString() ?? '');
    _notesCtrl = TextEditingController(text: l['notes'] ?? '');
    _statusCtrl = TextEditingController(text: l['status'] ?? 'Active');
  }

  @override
  void dispose() {
    _startDateCtrl.dispose();
    _endDateCtrl.dispose();
    _rentCtrl.dispose();
    _securityDepositCtrl.dispose();
    _advanceRentCtrl.dispose();
    _advanceEffectivityCtrl.dispose();
    _escalationRateCtrl.dispose();
    _escalationPeriodCtrl.dispose();
    _notesCtrl.dispose();
    _statusCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => isSaving = true);

    try {
      final Map<String, dynamic> updateData = {
        'start_date': _startDateCtrl.text.isNotEmpty ? _startDateCtrl.text : null,
        'end_date': _endDateCtrl.text.isNotEmpty ? _endDateCtrl.text : null,
        'rent_amount': double.tryParse(_rentCtrl.text) ?? 0,
        'security_deposit': double.tryParse(_securityDepositCtrl.text) ?? 0,
        'advance_rent': double.tryParse(_advanceRentCtrl.text) ?? 0,
        'advance_effectivity': _advanceEffectivityCtrl.text.isNotEmpty
            ? _advanceEffectivityCtrl.text
            : null,
        'escalation_rate': double.tryParse(_escalationRateCtrl.text) ?? 0,
        'notes': _notesCtrl.text.trim(),
        'status': _statusCtrl.text.trim(),
      };

      // ✅ Handle escalation_period_years safely
      final oldValue = widget.lease['escalation_period_years'];
      final newValueText = _escalationPeriodCtrl.text.trim();

      if (newValueText.isEmpty) {
        if (oldValue != null) {
          updateData['escalation_period_years'] = null;
        }
      } else {
        final parsedValue = int.tryParse(newValueText);
        if (parsedValue != oldValue) {
          updateData['escalation_period_years'] = parsedValue;
        }
      }

      await supabase.from('leases').update(updateData).eq('id', widget.lease['id']);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lease updated successfully.')),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error updating lease: $e')));
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

  Widget _buildField(String label, TextEditingController controller,
      {TextInputType keyboardType = TextInputType.text, int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  Widget _buildDateField(
      String label,
      TextEditingController controller, {
        bool allowCustomText = false,
      }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: controller,
        readOnly: false, // ✅ allow manual typing
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          suffixIcon: IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: () async {
              FocusScope.of(context).unfocus();
              final now = DateTime.now();
              final picked = await showDatePicker(
                context: context,
                initialDate: DateTime.tryParse(controller.text) ?? now,
                firstDate: DateTime(2000),
                lastDate: DateTime(2100),
              );
              if (picked != null) {
                controller.text = DateFormat('yyyy-MM-dd').format(picked);
              }
            },
          ),
        ),
        onChanged: (value) {
          if (!allowCustomText) {
            // Normalize manually typed date formats
            final normalized = value.replaceAll('/', '-').trim();
            if (normalized != value) {
              controller.value = TextEditingValue(
                text: normalized,
                selection: TextSelection.collapsed(offset: normalized.length),
              );
            }
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Lease Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: isSaving ? null : _saveChanges,
          ),
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
              _buildDateField('Start Date', _startDateCtrl),
              _buildDateField('End Date', _endDateCtrl),
              _buildField('Base Rent (₱)', _rentCtrl, keyboardType: TextInputType.number),
              _buildField('Security Deposit', _securityDepositCtrl,
                  keyboardType: TextInputType.number),
              _buildField('Advance Rent', _advanceRentCtrl,
                  keyboardType: TextInputType.number),
              _buildDateField(
                'Advance Effectivity',
                _advanceEffectivityCtrl,
                allowCustomText: true, // ✅ free text allowed here
              ),
              _buildField('Escalation Rate (%)', _escalationRateCtrl,
                  keyboardType: TextInputType.number),
              _buildField('Escalation Period (Years)', _escalationPeriodCtrl,
                  keyboardType: TextInputType.number),
              _buildField('Status', _statusCtrl),
              _buildField('Notes', _notesCtrl, maxLines: 3),
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
}

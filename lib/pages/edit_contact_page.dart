import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EditContactPage extends StatefulWidget {
  final Map<String, dynamic>? contact; // null means "Add" mode
  final String tenantId;

  const EditContactPage({
    super.key,
    this.contact,
    required this.tenantId,
  });

  @override
  State<EditContactPage> createState() => _EditContactPageState();
}

class _EditContactPageState extends State<EditContactPage> {
  final supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameCtrl;
  late TextEditingController _positionCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _notesCtrl;
  bool _isPrimary = false;
  bool isSaving = false;

  bool get isEditing => widget.contact != null;

  @override
  void initState() {
    super.initState();
    final c = widget.contact;
    _nameCtrl = TextEditingController(text: c?['name'] ?? '');
    _positionCtrl = TextEditingController(text: c?['position'] ?? '');
    _emailCtrl = TextEditingController(text: c?['email'] ?? '');
    _phoneCtrl = TextEditingController(text: c?['phone_number'] ?? '');
    _notesCtrl = TextEditingController(text: c?['notes'] ?? '');
    _isPrimary = c?['is_primary'] ?? false;
  }

  Future<void> _saveContact() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => isSaving = true);
    try {
      final data = {
        'tenant_id': widget.tenantId,
        'name': _nameCtrl.text.trim(),
        'position': _positionCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'phone_number': _phoneCtrl.text.trim(),
        'notes': _notesCtrl.text.trim(),
        'is_primary': _isPrimary,
      };

      if (isEditing) {
        final contactId = widget.contact?['id'];
        if (contactId == null) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Contact has no ID — refresh and try again.')),
          );
          return;
        }

        await supabase
            .from('contact_persons')
            .update(data)
            .eq('id', contactId)
            .select(); // ensure non-null response
      } else {
        await supabase
            .from('contact_persons')
            .insert(data)
            .select(); // ensure non-null response
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isEditing ? 'Contact updated.' : 'Contact added.')),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _positionCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Contact' : 'Add Contact'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: isSaving ? null : _saveContact,
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
              _buildField('Name', _nameCtrl, required: true),
              _buildField('Position', _positionCtrl),
              _buildField('Email', _emailCtrl, keyboardType: TextInputType.emailAddress),
              _buildField('Phone Number', _phoneCtrl, keyboardType: TextInputType.phone),
              _buildField('Notes', _notesCtrl, maxLines: 3),
              const SizedBox(height: 8),
              Row(
                children: [
                  Switch(
                    value: _isPrimary,
                    onChanged: (v) => setState(() => _isPrimary = v),
                  ),
                  const Text('Primary Contact'),
                ],
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                icon: const Icon(Icons.save),
                label: Text(isEditing ? 'Save Changes' : 'Add Contact'),
                style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
                onPressed: isSaving ? null : _saveContact,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildField(String label, TextEditingController controller,
      {TextInputType keyboardType = TextInputType.text, bool required = false, int maxLines = 1}) {
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
        validator: required
            ? (v) => (v == null || v.trim().isEmpty) ? '$label is required' : null
            : null,
      ),
    );
  }
}

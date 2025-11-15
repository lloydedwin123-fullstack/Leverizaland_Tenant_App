import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../widgets/file_section_widget.dart';
import 'edit_contact_page.dart';

class EditTenantDetailsPage extends StatefulWidget {
  final String tenantId;

  const EditTenantDetailsPage({super.key, required this.tenantId});

  @override
  State<EditTenantDetailsPage> createState() => _EditTenantDetailsPageState();
}

class _EditTenantDetailsPageState extends State<EditTenantDetailsPage> {
  final supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();
  bool isLoading = true;
  bool isSaving = false;

  Map<String, dynamic>? tenant;
  List<Map<String, dynamic>> contactPersons = [];

  // Text Controllers
  late TextEditingController _nameCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _contactPersonCtrl;
  late TextEditingController _emergencyContactNameCtrl;
  late TextEditingController _emergencyContactNumberCtrl;
  late TextEditingController _emergencyContactRelationshipCtrl;

  @override
  void initState() {
    super.initState();
    fetchTenantDetails();
  }

  Future<void> fetchTenantDetails() async {
    try {
      final response = await supabase
          .from('tenants')
          .select('''
            id, name, phone, email, contact_person,
            emergency_contact_name, emergency_contact_number, emergency_contact_relationship
          ''')
          .eq('id', widget.tenantId)
          .single();

      final contactsRes = await supabase
          .from('contact_persons')
          .select()
          .eq('tenant_id', widget.tenantId);

      if (mounted) {
        setState(() {
          tenant = response;
          contactPersons = List<Map<String, dynamic>>.from(contactsRes);

          // Initialize controllers
          _nameCtrl = TextEditingController(text: tenant!['name']);
          _phoneCtrl = TextEditingController(text: tenant!['phone']);
          _emailCtrl = TextEditingController(text: tenant!['email']);
          _contactPersonCtrl = TextEditingController(text: tenant!['contact_person']);
          _emergencyContactNameCtrl = TextEditingController(text: tenant!['emergency_contact_name']);
          _emergencyContactNumberCtrl = TextEditingController(text: tenant!['emergency_contact_number']);
          _emergencyContactRelationshipCtrl = TextEditingController(text: tenant!['emergency_contact_relationship']);

          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching tenant details: $e')),
        );
        setState(() => isLoading = false);
      }
    }
  }

  Future<void> _saveChanges() async {
    if (mounted && !_formKey.currentState!.validate()) return;

    setState(() => isSaving = true);

    try {
      await supabase.from('tenants').update({
        'name': _nameCtrl.text,
        'phone': _phoneCtrl.text,
        'email': _emailCtrl.text,
        'contact_person': _contactPersonCtrl.text,
        'emergency_contact_name': _emergencyContactNameCtrl.text,
        'emergency_contact_number': _emergencyContactNumberCtrl.text,
        'emergency_contact_relationship': _emergencyContactRelationshipCtrl.text,
      }).eq('id', widget.tenantId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tenant details saved successfully!')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving tenant details: $e')),
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
        title: const Text('Edit Tenant Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: isSaving ? null : _saveChanges,
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Tenant Details Fields
              Text('Tenant Information', style: Theme.of(context).textTheme.headlineSmall),
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: 'Tenant Name'),
                validator: (value) => value!.isEmpty ? 'Please enter a name' : null,
              ),
              TextFormField(
                controller: _phoneCtrl,
                decoration: const InputDecoration(labelText: 'Phone'),
              ),
              TextFormField(
                controller: _emailCtrl,
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              TextFormField(
                controller: _contactPersonCtrl,
                decoration: const InputDecoration(labelText: 'Primary Contact Person'),
              ),
              const SizedBox(height: 20),
              Text('Emergency Contact', style: Theme.of(context).textTheme.headlineSmall),
              TextFormField(
                controller: _emergencyContactNameCtrl,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              TextFormField(
                controller: _emergencyContactNumberCtrl,
                decoration: const InputDecoration(labelText: 'Number'),
              ),
              TextFormField(
                controller: _emergencyContactRelationshipCtrl,
                decoration: const InputDecoration(labelText: 'Relationship'),
              ),

              const SizedBox(height: 20),

              // Contact Persons Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Contact Persons', style: Theme.of(context).textTheme.headlineSmall),
                  IconButton(
                    icon: const Icon(Icons.add, color: Colors.green),
                    onPressed: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => EditContactPage(tenantId: widget.tenantId),
                        ),
                      );
                      if (result == true) {
                        fetchTenantDetails();
                      }
                    },
                  ),
                ],
              ),
              if (contactPersons.isEmpty)
                const Text('No contact persons added.')
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: contactPersons.length,
                  itemBuilder: (context, index) {
                    final contact = contactPersons[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      child: ListTile(
                        title: Row(
                          children: [
                            if (contact['is_primary'] == true)
                              const Padding(
                                padding: EdgeInsets.only(right: 6.0),
                                child: Icon(Icons.star, size: 18, color: Colors.amber),
                              ),
                            Expanded(child: Text(contact['name'] ?? 'N/A')),
                          ],
                        ),
                        subtitle: _buildContactSubtitle(contact),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blue),
                              onPressed: () async {
                                final result = await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => EditContactPage(
                                      tenantId: widget.tenantId,
                                      contact: contact,
                                    ),
                                  ),
                                );
                                if (result == true) {
                                  fetchTenantDetails();
                                }
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () async {
                                await supabase
                                    .from('contact_persons')
                                    .delete()
                                    .eq('id', contact['id']);
                                fetchTenantDetails();
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),

              const SizedBox(height: 20),

              // Tenant Documents Section
              Text('Tenant Documents', style: Theme.of(context).textTheme.headlineSmall),
              FileSectionWidget(
                category: 'tenant_documents',
                referenceId: widget.tenantId,
                isPublic: false,
                title: 'Tenant Documents',
              ),

              const SizedBox(height: 20),

              ElevatedButton(
                onPressed: isSaving ? null : _saveChanges,
                child: const Text('Save Changes'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget? _buildContactSubtitle(Map<String, dynamic> contact) {
    final position = (contact['position'] ?? '').toString().trim();
    final phone = (contact['phone_number'] ?? '').toString().trim();
    final email = (contact['email'] ?? '').toString().trim();
    final notes = (contact['notes'] ?? '').toString().trim();

    final List<String> lines = [];

    if (position.isNotEmpty) lines.add('Position: $position');
    if (phone.isNotEmpty) lines.add('Phone: $phone');
    if (email.isNotEmpty) lines.add('Email: $email');
    if (notes.isNotEmpty) lines.add('Notes: $notes');

    if (lines.isEmpty) return null;
    return Text(lines.join('\n'));
  }
}

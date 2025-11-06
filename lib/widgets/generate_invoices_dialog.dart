
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class GenerateInvoicesDialog extends StatefulWidget {
  final List<Map<String, dynamic>> leasesToInvoice;

  const GenerateInvoicesDialog({super.key, required this.leasesToInvoice});

  @override
  State<GenerateInvoicesDialog> createState() => _GenerateInvoicesDialogState();
}

class _GenerateInvoicesDialogState extends State<GenerateInvoicesDialog> {
  final supabase = Supabase.instance.client;
  late Set<String> _selectedLeaseIds;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    // By default, all proposed invoices are selected
    _selectedLeaseIds = widget.leasesToInvoice
        .where((lease) => !(lease['has_invoice'] as bool))
        .map((lease) => lease['id'] as String)
        .toSet();
  }

  Future<void> _confirmAndGenerate() async {
    setState(() => _isSaving = true);

    try {
      final selectedLeases = widget.leasesToInvoice
          .where((lease) => _selectedLeaseIds.contains(lease['id']))
          .toList();

      if (selectedLeases.isEmpty) {
        Navigator.pop(context, 0); // Return 0 invoices created
        return;
      }
      
      final now = DateTime.now();
      final firstDayOfMonth = DateTime(now.year, now.month, 1);

      final newInvoices = selectedLeases.map((lease) => {
        'tenant_id': lease['tenant_id'],
        'lease_id': lease['id'],
        'amount_due': lease['rent_amount'],
        'due_date': firstDayOfMonth.toIso8601String(),
        'notes': 'Monthly Rent for \${now.month}/\${now.year}',
      }).toList();

      await supabase.from('invoices').insert(newInvoices);

      if (mounted) {
        Navigator.pop(context, newInvoices.length); // Return the number of invoices created
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error generating invoices: \$e")),
        );
        Navigator.pop(context, 0);
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Generate Monthly Invoices'),
      content: _isSaving
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: widget.leasesToInvoice.map((lease) {
                  final leaseId = lease['id'] as String;
                  final tenantName = lease['tenants']?['name'] ?? 'Unknown Tenant';
                  final rentAmount = lease['rent_amount'] ?? 0;
                  final hasInvoice = lease['has_invoice'] as bool;

                  return CheckboxListTile(
                    title: Text(tenantName),
                    subtitle: Text('Rent: ₱\$rentAmount'),
                    value: _selectedLeaseIds.contains(leaseId),
                    onChanged: hasInvoice
                        ? null // Disable the checkbox if an invoice already exists
                        : (bool? selected) {
                            setState(() {
                              if (selected == true) {
                                _selectedLeaseIds.add(leaseId);
                              } else {
                                _selectedLeaseIds.remove(leaseId);
                              }
                            });
                          },
                  );
                }).toList(),
              ),
            ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, 0),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isSaving ? null : _confirmAndGenerate,
          child: _isSaving ? const Text('Saving...') : const Text('Confirm'),
        ),
      ],
    );
  }
}

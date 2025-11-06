import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class GenerateInvoicesDialog extends StatefulWidget {
  final List<Map<String, dynamic>> leasesToInvoice;

  const GenerateInvoicesDialog({super.key, required this.leasesToInvoice});

  @override
  State<GenerateInvoicesDialog> createState() => _GenerateInvoicesDialogState();
}

class _GenerateInvoicesDialogState extends State<GenerateInvoicesDialog> {
  final supabase = Supabase.instance.client;
  late Set<dynamic> _selectedLeaseIds;
  bool _isGenerating = false;

  @override
  void initState() {
    super.initState();
    _selectedLeaseIds = widget.leasesToInvoice
        .where((lease) => !(lease['has_invoice'] as bool))
        .map((lease) => lease['id'])
        .toSet();
  }

  Future<void> _confirmAndGenerate() async {
    setState(() => _isGenerating = true);

    try {
      final selectedLeases = widget.leasesToInvoice
          .where((lease) => _selectedLeaseIds.contains(lease['id']))
          .toList();

      if (selectedLeases.isEmpty) {
        if (mounted) Navigator.pop(context, 0);
        return;
      }

      final now = DateTime.now();
      final firstDayOfMonth = DateTime(now.year, now.month, 1);

      final newInvoices = selectedLeases.map((lease) => {
        'lease_id': lease['id'],
        'amount_due': lease['rent_amount'],
        'due_date': firstDayOfMonth.toIso8601String(),
        'remarks': 'Monthly Rent for ${DateFormat('MMMM yyyy').format(now)}', // Corrected from 'notes'
        'category': 'Rent',
      }).toList();

      await supabase.from('invoices').insert(newInvoices);

      if (mounted) {
        Navigator.pop(context, newInvoices.length);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error generating invoices: $e")),
        );
        Navigator.pop(context, 0);
      }
    } finally {
      if (mounted) {
        setState(() => _isGenerating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormatter = NumberFormat.currency(locale: 'en_PH', symbol: '₱');

    return AlertDialog(
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('Generate Monthly Invoices'),
          Text(
            '(${_selectedLeaseIds.length})',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.normal,
              color: Colors.blueGrey,
            ),
          ),
        ],
      ),
      content: _isGenerating
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: widget.leasesToInvoice.map((lease) {
                  final leaseId = lease['id'];
                  final tenantName = lease['tenants']?['name'] ?? 'Unknown Tenant';
                  final rentAmount = lease['rent_amount'] ?? 0;
                  final hasInvoice = lease['has_invoice'] as bool;

                  return CheckboxListTile(
                    title: Text(tenantName),
                    subtitle: Text('Rent: ${currencyFormatter.format(rentAmount)}'),
                    value: _selectedLeaseIds.contains(leaseId),
                    onChanged: hasInvoice
                        ? null // Disable checkbox if invoice already exists
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
          onPressed: _isGenerating ? null : _confirmAndGenerate,
          child: _isGenerating ? const Text('Generating...') : const Text('Confirm'),
        ),
      ],
    );
  }
}

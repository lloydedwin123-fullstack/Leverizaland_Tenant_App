import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'arrear_details_page.dart';

class PropertyArrearsPage extends StatefulWidget {
  final String propertyName;
  final List<Map<String, dynamic>> invoices;

  const PropertyArrearsPage({
    super.key,
    required this.propertyName,
    required this.invoices,
  });

  @override
  State<PropertyArrearsPage> createState() => _PropertyArrearsPageState();
}

class _PropertyArrearsPageState extends State<PropertyArrearsPage> {
  late List<Map<String, dynamic>> _invoices;

  @override
  void initState() {
    super.initState();
    _invoices = widget.invoices;
  }

  Future<void> _deleteInvoice(String invoiceId, int index) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Invoice?'),
        content: const Text('Are you sure you want to delete this invoice? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );

    if (confirm == true && mounted) {
      try {
        await Supabase.instance.client.from('invoices').delete().eq('id', invoiceId);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invoice deleted successfully')),
        );
        setState(() {
          _invoices.removeAt(index);
        });
        // If all invoices are deleted, pop the page and signal a refresh.
        if (_invoices.isEmpty) {
          Navigator.pop(context, true);
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting invoice: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormatter = NumberFormat.currency(locale: 'en_PH', symbol: '₱');

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.propertyName),
      ),
      body: ListView.builder(
        itemCount: _invoices.length,
        itemBuilder: (context, index) {
          final invoice = _invoices[index];
          final dueDate = invoice['due_date'] != null
              ? DateFormat('MMMM d, yyyy').format(DateTime.parse(invoice['due_date']))
              : '-';

          return Card(
            margin: const EdgeInsets.all(8),
            child: ListTile(
              title: Text("Due: $dueDate", style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Amount Due: ${currencyFormatter.format(invoice['amount_due'] ?? 0)}"),
                  Text("Balance: ${currencyFormatter.format(invoice['balance'] ?? 0)}", style: const TextStyle(color: Color(0xFFAF2626), fontWeight: FontWeight.bold)),
                  if (invoice['category'] != null) Text("Category: ${invoice['category']}"),
                  if (invoice['remarks'] != null) Text("Remarks: ${invoice['remarks']}"),
                ],
              ),
              trailing: IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                tooltip: 'Delete Invoice',
                onPressed: () => _deleteInvoice(invoice['invoice_id'], index),
              ),
              onTap: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ArrearDetailsPage(arrear: invoice),
                  ),
                );

                if (result == true && mounted) {
                  setState(() {
                    _invoices.removeAt(index);
                    if (_invoices.isEmpty) {
                      Navigator.pop(context, true);
                    }
                  });
                }
              },
            ),
          );
        },
      ),
    );
  }
}

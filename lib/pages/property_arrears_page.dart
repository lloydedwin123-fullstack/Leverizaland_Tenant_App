import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'arrear_details_page.dart';

class PropertyArrearsPage extends StatelessWidget {
  final String propertyName;
  final List<Map<String, dynamic>> invoices;

  const PropertyArrearsPage({
    super.key,
    required this.propertyName,
    required this.invoices,
  });

  @override
  Widget build(BuildContext context) {
    final currencyFormatter = NumberFormat.currency(locale: 'en_PH', symbol: '₱');

    return Scaffold(
      appBar: AppBar(
        title: Text(propertyName),
      ),
      body: ListView.builder(
        itemCount: invoices.length,
        itemBuilder: (context, index) {
          final invoice = invoices[index];
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
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ArrearDetailsPage(arrear: invoice),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

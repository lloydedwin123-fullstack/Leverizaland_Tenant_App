import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

import '../widgets/file_section_widget.dart';
import 'edit_tenant_details_page.dart'; // Import the new edit page
import 'unit_details_page.dart'; // Import the unit details page
import 'add_invoice_page.dart'; // Import the add invoice page
import 'arrear_details_page.dart'; // Import the arrear details page
import 'add_payment_page.dart'; // Import the add payment page
import 'payment_details_page.dart'; // Import the payment details page
import '../models/arrear_summary.dart'; // Import the new model
import 'property_arrears_page.dart'; // Import the drill-down page

class TenantDetailsPage extends StatefulWidget {
  final String tenantId;
  final String tenantName;

  const TenantDetailsPage({
    super.key,
    required this.tenantId,
    required this.tenantName,
  });

  @override
  State<TenantDetailsPage> createState() => _TenantDetailsPageState();
}

class _TenantDetailsPageState extends State<TenantDetailsPage> {
  final supabase = Supabase.instance.client;
  String _filter = "details";

  Map<String, dynamic>? tenant;
  List<Map<String, dynamic>> units = [];
  List<Map<String, dynamic>> contactPersons = [];
  bool isLoading = true;

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    fetchTenantDetails();
  }

  Future<void> fetchTenantDetails() async {
    final response = await supabase
        .from('tenants')
        .select('''
          id, name, phone, email, contact_person,
          emergency_contact_name, emergency_contact_number, emergency_contact_relationship,
          units (id, building, unit_number, current_rent_amount)
        ''')
        .eq('id', widget.tenantId)
        .maybeSingle();

    final contactsRes = await supabase
        .from('contact_persons')
        .select()
        .eq('tenant_id', widget.tenantId);

    if (mounted) {
      setState(() {
        tenant = response;
        units = List<Map<String, dynamic>>.from(response?['units'] ?? []);
        contactPersons = List<Map<String, dynamic>>.from(contactsRes);
        isLoading = false;
      });
    }
  }

  Future<void> _deletePayment(String paymentId) async {
    try {
      await supabase.from('payments').delete().eq('id', paymentId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payment deleted successfully!')),
        );
        setState(() {}); // Refresh the list
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting payment: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormatter = NumberFormat.currency(locale: 'en_PH', symbol: '₱');

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.tenantName),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.amber))
          : Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ChoiceChip(
                  label: const Text("Tenant Details"),
                  selected: _filter == "details",
                  onSelected: (_) => setState(() => _filter = "details"),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text("Arrears"),
                  selected: _filter == "arrears",
                  onSelected: (_) => setState(() => _filter = "arrears"),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text("Payment History"),
                  selected: _filter == "payments",
                  onSelected: (_) => setState(() => _filter = "payments"),
                ),
              ],
            ),
          ),
          Expanded(
            child: _filter == "details"
                ? _buildTenantDetails(currencyFormatter)
                : _filter == "arrears"
                ? _buildArrears(currencyFormatter)
                : _buildPayments(currencyFormatter),
          ),
        ],
      ),
      floatingActionButton: _filter == 'arrears'
          ? FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AddInvoicePage(tenantId: widget.tenantId, tenantName: widget.tenantName),
            ),
          );
          if (result == true && mounted) {
            setState(() {}); // Refresh the arrears list
          }
        },
        child: const Icon(Icons.add),
      )
          : _filter == 'payments' ?
      FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AddPaymentPage(tenantId: widget.tenantId),
            ),
          );
          if (result == true && mounted) {
            setState(() {
              _filter = 'payments';
            });
          }
        },
        child: const Icon(Icons.add),
      )
          : null,
    );
  }

  Widget _buildTenantDetails(NumberFormat currencyFormatter) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => EditTenantDetailsPage(tenantId: widget.tenantId),
                ),
              );
              if (result == true && mounted) {
                fetchTenantDetails();
              }
            },
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Contact Person: ${tenant?['contact_person'] ?? '-'}"),
                    Text("Phone: ${tenant?['phone'] ?? '-'}"),
                    Text("Email: ${tenant?['email'] ?? '-'}"),
                    const SizedBox(height: 8),
                    Text("Emergency Contact Person: ${tenant?['emergency_contact_name'] ?? '-'}"),
                    Text("Emergency Contact Number: ${tenant?['emergency_contact_number'] ?? '-'}"),
                    Text("Relationship: ${tenant?['emergency_contact_relationship'] ?? '-'}"),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            "Contact Persons:",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          if (contactPersons.isEmpty)
            const Text("No contact persons found."),
          ...contactPersons.map((c) {
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 4),
              child: ListTile(
                title: Text(c['name'] ?? 'N/A'),
                subtitle: Text(c['position'] ?? 'N/A'),
              ),
            );
          }),

          const SizedBox(height: 16),
          const Text(
            "Occupied Units:",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          if (units.isEmpty) const Text("No assigned units."),
          ...units.map((u) {
            final unitName =
                "${u['building'] ?? ''}${(u['unit_number'] ?? '').toString().trim().isNotEmpty ? ' ${u['unit_number']}' : ''}";
            final rent = u['current_rent_amount'] ?? 0;
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 4),
              child: ListTile(
                title: Text(unitName),
                subtitle: Text("Current Rent: ${currencyFormatter.format(rent)}"),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => UnitDetailsPage(
                        unitId: u['id'],
                        building: u['building'],
                        unitNumber: u['unit_number'],
                      ),
                    ),
                  );
                },
              ),
            );
          }),
          const SizedBox(height: 16),
          FileSectionWidget(
            category: 'tenant_documents',
            referenceId: widget.tenantId,
            isPublic: false,
            title: 'Tenant Documents',
          ),
        ],
      ),
    );
  }

  Widget _buildArrears(NumberFormat currencyFormatter) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: supabase
          .from('invoice_payment_status')
          .select(
          'invoice_id, tenant_id, tenant_name, building, unit_name, due_date, amount_due, total_paid, balance, category, remarks')
          .eq('tenant_id', widget.tenantId)
          .gt('balance', 0)
          .order('due_date', ascending: true),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Colors.amber));
        }
        if (snapshot.hasError) {
          return Center(
              child: Text("Error: ${snapshot.error}", style: const TextStyle(color: Colors.red)));
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text("No unpaid invoices"));
        }

        final arrears = snapshot.data!;
        final groupedArrears = _groupArrears(arrears);

        return ListView.builder(
          itemCount: groupedArrears.length,
          itemBuilder: (context, index) {
            final summary = groupedArrears[index];
            return Card(
              margin: const EdgeInsets.all(8),
              child: ListTile(
                title: Text(summary.propertyName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Total Balance: ${currencyFormatter.format(summary.totalBalance)}", style: const TextStyle(color: Color(0xFFAF2626), fontWeight: FontWeight.bold)),
                    Text("Coverage: ${summary.dateRange}"),
                    Text("${summary.invoiceCount} Unpaid Invoices"),
                  ],
                ),
                onTap: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => PropertyArrearsPage(
                        propertyName: summary.propertyName,
                        invoices: summary.invoices,
                      ),
                    ),
                  );
                  if (result == true && mounted) {
                    setState(() {});
                  }
                },
              ),
            );
          },
        );
      },
    );
  }

  List<ArrearSummary> _groupArrears(List<Map<String, dynamic>> arrears) {
    final Map<String, List<Map<String, dynamic>>> grouped = {};
    for (final arrear in arrears) {
      final propertyName = "${arrear['building'] ?? ''}${arrear['unit_name'] != null ? ' ${arrear['unit_name']}' : ''}";
      (grouped[propertyName] ??= []).add(arrear);
    }

    return grouped.entries.map((entry) {
      final propertyName = entry.key;
      final invoices = entry.value;
      final totalBalance = invoices.fold<double>(0, (sum, item) => sum + (item['balance'] ?? 0));
      final invoiceCount = invoices.length;

      invoices.sort((a, b) => (a['due_date'] as String).compareTo(b['due_date']));
      final startDate = DateFormat('MMMM yyyy').format(DateTime.parse(invoices.first['due_date']));
      final endDate = DateFormat('MMMM yyyy').format(DateTime.parse(invoices.last['due_date']));
      final dateRange = startDate == endDate ? startDate : '$startDate to $endDate';

      return ArrearSummary(
        propertyName: propertyName,
        totalBalance: totalBalance,
        invoiceCount: invoiceCount,
        dateRange: dateRange,
        invoices: invoices,
      );
    }).toList();
  }

  Widget _buildPayments(NumberFormat currencyFormatter) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: "Search payments (method, reference, remarks, date)...",
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onChanged: (_) => setState(() {}),
          ),
        ),
        Expanded(
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: supabase
                .from('payments')
                .select('*, invoice_id(*)')
                .eq('tenant_id', widget.tenantId)
                .order('payment_date', ascending: false),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: Colors.amber));
              }
              if (snapshot.hasError) {
                return Center(
                    child: Text("Error: ${snapshot.error}",
                        style: const TextStyle(color: Colors.red)));
              }
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Center(child: Text("No payment history."));
              }

              final searchQuery = _searchController.text.toLowerCase();

              final payments = snapshot.data!.where((p) {
                final method = (p['method'] ?? '').toString().toLowerCase();
                final ref = (p['reference_no'] ?? '').toString().toLowerCase();
                final remarks = (p['remarks'] ?? '').toString().toLowerCase();

                final formattedDate = p['payment_date'] != null
                    ? DateFormat('MMMM d, yyyy')
                    .format(DateTime.parse(p['payment_date']))
                    .toLowerCase()
                    : '';

                return method.contains(searchQuery) ||
                    ref.contains(searchQuery) ||
                    remarks.contains(searchQuery) ||
                    formattedDate.contains(searchQuery);
              }).toList();

              if (payments.isEmpty) {
                return const Center(child: Text("No results found."));
              }

              return ListView.builder(
                itemCount: payments.length,
                itemBuilder: (context, index) {
                  final p = payments[index];
                  final formattedDate = p['payment_date'] != null
                      ? DateFormat('MMMM d, yyyy').format(DateTime.parse(p['payment_date']))
                      : '-';

                  return Slidable(
                    key: ValueKey(p['id']),
                    endActionPane: ActionPane(
                      motion: const ScrollMotion(),
                      children: [
                        SlidableAction(
                          onPressed: (context) async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (context) {
                                return AlertDialog(
                                  title: const Text('Delete Payment'),
                                  content: const Text('Are you sure you want to delete this payment?'),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context, false),
                                      child: const Text('Cancel'),
                                    ),
                                    TextButton(
                                      onPressed: () => Navigator.pop(context, true),
                                      child: const Text('Delete'),
                                    ),
                                  ],
                                );
                              },
                            );

                            if (confirm == true) {
                              _deletePayment(p['id']);
                            }
                          },
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          icon: Icons.delete,
                          label: 'Delete',
                        ),
                      ],
                    ),
                    child: Card(
                      margin: const EdgeInsets.all(8),
                      child: ListTile(
                        title: Text(
                          "Amount Paid: ${currencyFormatter.format(p['amount_paid'] ?? 0)}",
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Method: ${p['method'] ?? '-'}"),
                            Text("Reference Code: ${p['reference_no'] ?? '-'}"),
                            Text("Remarks: ${p['remarks'] ?? '-'}"),
                            Text("Payment Date: $formattedDate"),
                          ],
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => PaymentDetailsPage(payment: p),
                            ),
                          );
                        },
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

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
  bool isLoading = true;

  // 🔍 Search controller for payments
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
          units (building, unit_number, current_rent_amount)
        ''')
        .eq('id', widget.tenantId)
        .maybeSingle();

    setState(() {
      tenant = response;
      units = List<Map<String, dynamic>>.from(response?['units'] ?? []);
      isLoading = false;
    });
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
          // 🔘 Tabs
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
    );
  }

  // 🧾 Tenant Details Section
  Widget _buildTenantDetails(NumberFormat currencyFormatter) {
    return SingleChildScrollView(
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
          const SizedBox(height: 16),
          const Text(
            "Units:",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          if (units.isEmpty)
            const Text("No assigned units."),
          ...units.map((u) {
            final unitName =
                "${u['building'] ?? ''}${(u['unit_number'] ?? '').toString().trim().isNotEmpty ? ' ${u['unit_number']}' : ''}";
            final rent = u['current_rent_amount'] ?? 0;
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 4),
              child: ListTile(
                title: Text(unitName),
                subtitle: Text("Current Rent: ${currencyFormatter.format(rent)}"),
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  // 📋 Arrears Section (Unpaid Invoices)
  Widget _buildArrears(NumberFormat currencyFormatter) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: supabase
          .from('invoice_payment_status')
          .select(
          'invoice_id, tenant_name, building, unit_name, due_date, amount_due, total_paid, balance')
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
        return ListView.builder(
          itemCount: arrears.length,
          itemBuilder: (context, index) {
            final a = arrears[index];
            final dueDate = a['due_date'] != null
                ? DateFormat('MMMM d, yyyy').format(DateTime.parse(a['due_date']))
                : '-';
            final propertyName =
                "${a['building'] ?? ''}${(a['unit_name'] ?? '').toString().trim().isNotEmpty ? ' ${a['unit_name']}' : ''}";

            return Card(
              margin: const EdgeInsets.all(8),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (propertyName.isNotEmpty && propertyName != '-')
                      Text(
                        propertyName,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    Text("Due Date: $dueDate", style: const TextStyle(fontSize: 14)),
                    Text("Amount Due: ${currencyFormatter.format(a['amount_due'] ?? 0)}"),
                    Text("Total Paid: ${currencyFormatter.format(a['total_paid'] ?? 0)}"),
                    Text(
                      "Balance: ${currencyFormatter.format(a['balance'] ?? 0)}",
                      style: const TextStyle(
                        color: Color(0xFFAF2626),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // 💰 Payment History Section (with search)
  Widget _buildPayments(NumberFormat currencyFormatter) {
    return Column(
      children: [
        // 🔍 Search bar
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

        // 📋 Payments list
        Expanded(
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: supabase
                .from('payments')
                .select('amount_paid, method, reference_no, remarks, payment_date')
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

                // ✅ Search also in formatted date
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

                  return Card(
                    margin: const EdgeInsets.all(8),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Amount Paid: ${currencyFormatter.format(p['amount_paid'] ?? 0)}",
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text("Method: ${p['method'] ?? '-'}"),
                          Text("Reference Code: ${p['reference_no'] ?? '-'}"),
                          Text("Remarks: ${p['remarks'] ?? '-'}"),
                          Text("Payment Date: $formattedDate"),
                        ],
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

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'tenant_details_page.dart'; // ✅ Tenant details page
import '../widgets/generate_invoices_dialog.dart'; // Import the dialog

class TenantsPage extends StatefulWidget {
  const TenantsPage({super.key});

  @override
  State<TenantsPage> createState() => _TenantsPageState();
}

class _TenantsPageState extends State<TenantsPage> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> tenants = [];
  List<Map<String, dynamic>> filteredTenants = [];
  bool isLoading = true;
  String searchQuery = '';

  @override
  void initState() {
    super.initState();
    fetchTenants();
  }

  Future<void> fetchTenants() async {
    try {
      final response = await supabase
          .from('tenants')
          .select(
        '''
            id,
            name,
            phone,
            email,
            active,
            units (building, unit_number, current_rent_amount)
            ''',
      )
          .eq('active', true) // ✅ Only include active tenants
          .order('name', ascending: true);

      if (mounted) {
        setState(() {
          tenants = List<Map<String, dynamic>>.from(response);
          filteredTenants = tenants;
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error loading tenants: $e")),
        );
      }
    }
  }

  void filterTenants(String query) {
    final q = query.toLowerCase();
    setState(() {
      searchQuery = query;
      filteredTenants = tenants.where((tenant) {
        final name = (tenant['name'] ?? '').toString().toLowerCase();
        final phone = (tenant['phone'] ?? '').toString().toLowerCase();
        final email = (tenant['email'] ?? '').toString().toLowerCase();
        return name.contains(q) || phone.contains(q) || email.contains(q);
      }).toList();
    });
  }

  Future<void> _generateInvoices() async {
    final now = DateTime.now();
    final firstDayOfMonth = DateTime(now.year, now.month, 1);
    final lastDayOfMonth = DateTime(now.year, now.month + 1, 0);

    try {
      // 1. Get all active leases with tenant names
      final leasesResponse = await supabase
          .from('leases')
          .select('id, tenant_id, rent_amount, tenants (name)')
          .eq('status', 'Active');
      
      final leases = List<Map<String, dynamic>>.from(leasesResponse);

      if (leases.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No active leases found.')),
          );
        }
        return;
      }

      // 2. Get all invoices for the current month to check for existence
      final invoicesResponse = await supabase
          .from('invoices')
          .select('lease_id')
          .gte('due_date', firstDayOfMonth.toIso8601String())
          .lte('due_date', lastDayOfMonth.toIso8601String());

      final existingInvoices = List<Map<String, dynamic>>.from(invoicesResponse)
          .map((invoice) => invoice['lease_id'])
          .toSet();

      // 3. Add a flag to each lease indicating if an invoice already exists
      final allLeasesWithStatus = leases.map((lease) {
        return {
          ...lease,
          'has_invoice': existingInvoices.contains(lease['id']),
        };
      }).toList();

      // 4. Show the confirmation dialog
      final invoicesCreated = await showDialog<int>(
        context: context,
        builder: (context) => GenerateInvoicesDialog(leasesToInvoice: allLeasesWithStatus),
      );

      if (mounted && invoicesCreated != null && invoicesCreated > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Successfully generated $invoicesCreated invoices.')),
        );
      }

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error generating invoices: $e")),
        );
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Tenants List"),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_card),
            onPressed: _generateInvoices,
            tooltip: 'Generate Monthly Invoices',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: fetchTenants,
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : tenants.isEmpty
          ? const Center(child: Text("No active tenants found"))
          : RefreshIndicator(
        onRefresh: fetchTenants,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 8),
              child: TextField(
                onChanged: filterTenants,
                decoration: InputDecoration(
                  hintText:
                  "Search tenant name, phone, or email...",
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                      vertical: 0, horizontal: 16),
                ),
              ),
            ),
            Expanded(
              child: filteredTenants.isEmpty
                  ? const Center(
                child: Text("No active tenants found"),
              )
                  : ListView.builder(
                itemCount: filteredTenants.length,
                itemBuilder: (context, index) {
                  final tenant = filteredTenants[index];

                  final tenantName = (tenant['name'] ?? '')
                      .toString()
                      .trim()
                      .isEmpty
                      ? "Unnamed Tenant"
                      : tenant['name'];
                  final tenantPhone =
                  (tenant['phone'] ?? '').toString().trim();
                  final tenantEmail =
                  (tenant['email'] ?? '').toString().trim();

                  final units =
                      tenant['units'] as List<dynamic>? ?? [];

                  final unitNumbers = units.map((u) {
                    final building = u['building'] ?? "";
                    final unitNumber =
                    (u['unit_number'] ?? "").toString().trim();
                    return unitNumber.isNotEmpty
                        ? "$building $unitNumber"
                        : building;
                  }).join(", ");

                  final rents = units
                      .map((u) {
                    final rent = u['current_rent_amount'];
                    return rent != null ? "₱$rent" : "";
                  })
                      .where((r) => r.isNotEmpty)
                      .join(" | ");

                  return Card(
                    margin: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    child: ListTile(
                      contentPadding:
                      const EdgeInsets.all(12),
                      title: Text(
                        tenantName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (tenantPhone.isNotEmpty ||
                              tenantEmail.isNotEmpty)
                            Text(
                              "$tenantPhone ${tenantPhone.isNotEmpty && tenantEmail.isNotEmpty ? "|" : ""} $tenantEmail",
                              style:
                              const TextStyle(fontSize: 14),
                            ),
                          if (unitNumbers.isNotEmpty)
                            Text("Units: $unitNumbers",
                                style: const TextStyle(
                                    fontSize: 13)),
                          if (rents.isNotEmpty)
                            Text("Rent: $rents",
                                style: const TextStyle(
                                    fontSize: 13)),
                        ],
                      ),

                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                TenantDetailsPage(
                                  tenantId: tenant['id'],
                                  tenantName: tenantName,
                                ),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

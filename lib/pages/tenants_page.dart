import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'tenant_details_page.dart'; // ✅ Tenant details page

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

  // 🧩 Fetch tenants (only active)
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

      setState(() {
        tenants = List<Map<String, dynamic>>.from(response);
        filteredTenants = tenants;
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error loading tenants: $e")),
      );
    }
  }

  // 🔍 Filter tenants by search
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Tenants List"),
        centerTitle: true,
        actions: [
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
            // 🔍 Search Bar
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

            // 📋 Tenants List
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

                  // 🏢 Unit info
                  final unitNumbers = units.map((u) {
                    final building = u['building'] ?? "";
                    final unitNumber =
                    (u['unit_number'] ?? "").toString().trim();
                    return unitNumber.isNotEmpty
                        ? "$building $unitNumber"
                        : building;
                  }).join(", ");

                  // 💰 Rent info
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
                        crossAxisAlignment:
                        CrossAxisAlignment.start,
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

                      // 👇 On tap → go to Tenant Details Page
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

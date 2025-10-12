import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'unit_details_page.dart'; // ✅ Import our details page

class UnitsPage extends StatefulWidget {
  const UnitsPage({super.key});

  @override
  State<UnitsPage> createState() => _UnitsPageState();
}

class _UnitsPageState extends State<UnitsPage> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> units = [];
  List<Map<String, dynamic>> filteredUnits = [];
  bool isLoading = true;
  String searchQuery = '';

  @override
  void initState() {
    super.initState();
    fetchUnits();
  }

  Future<void> fetchUnits() async {
    try {
      final response = await supabase
          .from('units')
          .select(
          'id, building, unit_number, current_rent_amount, tenants(name)')
          .order('building', ascending: true);

      setState(() {
        units = List<Map<String, dynamic>>.from(response);
        filteredUnits = units;
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error loading units: $e")),
      );
    }
  }

  // 🔍 Filter logic
  void filterUnits(String query) {
    final q = query.toLowerCase();
    setState(() {
      searchQuery = query;
      filteredUnits = units.where((unit) {
        final building = (unit['building'] ?? '').toString().toLowerCase();
        final unitNumber = (unit['unit_number'] ?? '').toString().toLowerCase();
        final rent =
        (unit['current_rent_amount'] ?? '').toString().toLowerCase();
        final tenantName =
        (unit['tenants']?['name'] ?? 'Vacant').toString().toLowerCase();
        return building.contains(q) ||
            unitNumber.contains(q) ||
            rent.contains(q) ||
            tenantName.contains(q);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Units List"),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: fetchUnits,
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : units.isEmpty
          ? const Center(child: Text("No units found"))
          : RefreshIndicator(
        onRefresh: fetchUnits,
        child: Column(
          children: [
            // 🔍 Search Bar
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 8),
              child: TextField(
                onChanged: filterUnits,
                decoration: InputDecoration(
                  hintText:
                  "Search by building, unit, rent, or tenant...",
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                      vertical: 0, horizontal: 16),
                ),
              ),
            ),

            // 🏢 Units List
            Expanded(
              child: filteredUnits.isEmpty
                  ? const Center(child: Text("No units found"))
                  : ListView.builder(
                itemCount: filteredUnits.length,
                itemBuilder: (context, index) {
                  final unit = filteredUnits[index];

                  final building =
                      unit['building'] ?? "Unknown Building";
                  final unitNumber = (unit['unit_number']
                      ?.toString()
                      .trim()
                      .isEmpty ??
                      true)
                      ? "-"
                      : unit['unit_number'];
                  final rent =
                      unit['current_rent_amount'] ?? 0;
                  final tenantName =
                      unit['tenants']?['name'] ?? "Vacant";

                  // 🖱️ Clickable Unit Card
                  return InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => UnitDetailsPage(
                            unitId: unit['id'],
                            building: building,
                            unitNumber:
                            unitNumber.toString(),
                          ),
                        ),
                      );
                    },
                    child: Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment:
                          CrossAxisAlignment.start,
                          children: [
                            Text(
                              "$building - Unit $unitNumber",
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              "Rent: ₱$rent / month",
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "Tenant: $tenantName",
                              style: TextStyle(
                                fontSize: 14,
                                color: tenantName == "Vacant"
                                    ? Colors.red[700]
                                    : Colors.black87,
                                fontWeight:
                                tenantName == "Vacant"
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ),
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

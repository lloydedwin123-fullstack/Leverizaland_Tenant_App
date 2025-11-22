import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'unit_details_page.dart';

class VacantUnitsPage extends StatefulWidget {
  const VacantUnitsPage({super.key});

  @override
  State<VacantUnitsPage> createState() => _VacantUnitsPageState();
}

class _VacantUnitsPageState extends State<VacantUnitsPage> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> units = [];
  List<Map<String, dynamic>> filteredUnits = [];
  bool isLoading = true;
  String searchQuery = '';

  final currency = NumberFormat.currency(locale: 'en_PH', symbol: '₱', decimalDigits: 2);

  @override
  void initState() {
    super.initState();
    fetchVacantUnits();
  }

  Future<void> fetchVacantUnits() async {
    try {
      // 1. Get all active leases to identify occupied units
      final activeLeases = await supabase
          .from('leases')
          .select('unit_id')
          .eq('status', 'Active');
      
      final occupiedUnitIds = List<Map<String, dynamic>>.from(activeLeases)
          .map((l) => l['unit_id'])
          .toSet();

      // 2. Get all units
      final response = await supabase
          .from('units')
          .select('id, building, unit_number, current_rent_amount')
          .order('building', ascending: true)
          .order('unit_number', ascending: true);

      final allUnits = List<Map<String, dynamic>>.from(response);

      // 3. Filter locally: Keep only units NOT in occupied set
      final vacantList = allUnits.where((u) => !occupiedUnitIds.contains(u['id'])).toList();

      if (mounted) {
        setState(() {
          units = vacantList;
          filteredUnits = units;
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error loading vacant units: $e")),
        );
      }
    }
  }

  void filterUnits(String query) {
    final q = query.toLowerCase();
    setState(() {
      searchQuery = query;
      filteredUnits = units.where((unit) {
        final building = (unit['building'] ?? '').toString().toLowerCase();
        final unitNumber = (unit['unit_number'] ?? '').toString().toLowerCase();
        final rent = (unit['current_rent_amount'] ?? '').toString().toLowerCase();
        return building.contains(q) || unitNumber.contains(q) || rent.contains(q);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Vacant Units"),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: fetchVacantUnits,
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : units.isEmpty
              ? const Center(child: Text("No vacant units found! Good job! 🎉"))
              : RefreshIndicator(
                  onRefresh: fetchVacantUnits,
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        child: TextField(
                          onChanged: filterUnits,
                          decoration: InputDecoration(
                            hintText: "Search by building, unit, or rent...",
                            prefixIcon: const Icon(Icons.search),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                          ),
                        ),
                      ),
                      Expanded(
                        child: filteredUnits.isEmpty
                            ? const Center(child: Text("No matching units found"))
                            : ListView.builder(
                                itemCount: filteredUnits.length,
                                itemBuilder: (context, index) {
                                  final unit = filteredUnits[index];
                                  final building = (unit['building'] ?? '').toString().trim();
                                  final unitNumber = (unit['unit_number']?.toString().trim() ?? '');
                                  final rent = unit['current_rent_amount'] ?? 0;
                                  
                                  final displayTitle = unitNumber.isEmpty ? building : "$building $unitNumber";

                                  return Card(
                                    margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    elevation: 2,
                                    child: ListTile(
                                      leading: const CircleAvatar(
                                        backgroundColor: Colors.green,
                                        child: Icon(Icons.meeting_room_outlined, color: Colors.white),
                                      ),
                                      title: Text(
                                        displayTitle,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                      ),
                                      subtitle: Text("Target Rent: ${currency.format(rent)} / month"),
                                      trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => UnitDetailsPage(
                                              unitId: unit['id'],
                                              building: building,
                                              unitNumber: unitNumber,
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

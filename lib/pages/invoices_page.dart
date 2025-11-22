import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class InvoicesPage extends StatefulWidget {
  const InvoicesPage({super.key});

  @override
  State<InvoicesPage> createState() => _InvoicesPageState();
}

class _InvoicesPageState extends State<InvoicesPage> with SingleTickerProviderStateMixin {
  final supabase = Supabase.instance.client;
  late TabController _tabController;

  List<Map<String, dynamic>> allInvoices = [];
  List<Map<String, dynamic>> filteredInvoices = [];
  bool isLoading = true;
  String searchQuery = '';

  final currency = NumberFormat.currency(locale: 'en_PH', symbol: '₱', decimalDigits: 2);
  final dateFmt = DateFormat('MMM d, yyyy');

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this); // All, Pending, Paid, Overdue
    _tabController.addListener(_filterInvoices);
    fetchInvoices();
  }

  Future<void> fetchInvoices() async {
    try {
      // We use the view 'invoice_payment_status' if available for easy balance checking,
      // or raw 'invoices' table. Let's use 'invoice_payment_status' as used in ReportsPage 
      // because it has calculated balances.
      final response = await supabase
          .from('invoice_payment_status')
          .select('*')
          .order('due_date', ascending: false);

      if (mounted) {
        setState(() {
          allInvoices = List<Map<String, dynamic>>.from(response);
          _filterInvoices();
          isLoading = false;
        });
      }
    } catch (e) {
      // Fallback to raw invoices table if view fails
      try {
        final rawResponse = await supabase
            .from('invoices')
            .select('*, tenants(name)')
            .order('due_date', ascending: false);
        
        if (mounted) {
          setState(() {
            allInvoices = List<Map<String, dynamic>>.from(rawResponse);
            _filterInvoices();
            isLoading = false;
          });
        }
      } catch (e2) {
        if (mounted) {
          setState(() => isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error loading invoices: $e2')),
          );
        }
      }
    }
  }

  void _filterInvoices() {
    if (!mounted) return;
    
    final index = _tabController.index;
    List<Map<String, dynamic>> temp = List.from(allInvoices);

    // Filter by Tab
    if (index == 1) { // Pending (Balance > 0)
      temp = temp.where((i) => (i['balance'] ?? 0) > 0).toList();
    } else if (index == 2) { // Paid (Balance == 0)
      temp = temp.where((i) => (i['balance'] ?? 0) <= 0).toList();
    } else if (index == 3) { // Overdue (Balance > 0 && Due Date < Today)
      final now = DateTime.now();
      temp = temp.where((i) {
        final bal = (i['balance'] ?? 0);
        if (bal <= 0) return false;
        final due = i['due_date'] != null ? DateTime.parse(i['due_date']) : now;
        return due.isBefore(now);
      }).toList();
    }

    // Filter by Search
    if (searchQuery.isNotEmpty) {
      final q = searchQuery.toLowerCase();
      temp = temp.where((i) {
        final tenant = (i['tenant_name'] ?? i['tenants']?['name'] ?? '').toString().toLowerCase();
        final invId = (i['invoice_id'] ?? i['id'] ?? '').toString().toLowerCase();
        return tenant.contains(q) || invId.contains(q);
      }).toList();
    }

    setState(() {
      filteredInvoices = temp;
    });
  }

  void _onSearch(String val) {
    searchQuery = val;
    _filterInvoices();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Invoices"),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(text: 'All'),
            Tab(text: 'Unpaid'),
            Tab(text: 'Paid'),
            Tab(text: 'Overdue'),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: fetchInvoices),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(10.0),
                  child: TextField(
                    onChanged: _onSearch,
                    decoration: InputDecoration(
                      hintText: 'Search Invoice # or Tenant...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                  ),
                ),
                Expanded(
                  child: filteredInvoices.isEmpty
                      ? const Center(child: Text("No invoices found."))
                      : ListView.builder(
                          itemCount: filteredInvoices.length,
                          itemBuilder: (context, index) {
                            final inv = filteredInvoices[index];
                            return _buildInvoiceCard(inv);
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildInvoiceCard(Map<String, dynamic> inv) {
    final tenantName = inv['tenant_name'] ?? inv['tenants']?['name'] ?? 'Unknown';
    final dateStr = inv['due_date'] != null 
        ? dateFmt.format(DateTime.parse(inv['due_date'])) 
        : '-';
    
    final amount = (inv['amount_due'] ?? inv['total_amount'] ?? 0).toDouble();
    final balance = (inv['balance'] ?? 0).toDouble();
    final isPaid = balance <= 0;
    
    // Status Logic
    String status = isPaid ? 'PAID' : 'UNPAID';
    Color statusColor = isPaid ? Colors.green : Colors.orange;
    
    if (!isPaid && inv['due_date'] != null) {
      if (DateTime.parse(inv['due_date']).isBefore(DateTime.now())) {
        status = 'OVERDUE';
        statusColor = Colors.red;
      }
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: statusColor.withOpacity(0.1),
          child: Icon(
            isPaid ? Icons.check : Icons.priority_high,
            color: statusColor,
            size: 20,
          ),
        ),
        title: Text(tenantName, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text("Due: $dateStr\nInv #: ${inv['invoice_id'] ?? inv['id'] ?? '-'}"),
        trailing: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(currency.format(amount), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            if (!isPaid)
              Text("Bal: ${currency.format(balance)}", style: const TextStyle(fontSize: 12, color: Colors.red)),
            if (isPaid)
              const Text("Cleared", style: TextStyle(fontSize: 12, color: Colors.green)),
          ],
        ),
        onTap: () {
          // Future: Navigate to invoice details or print view
        },
      ),
    );
  }
}

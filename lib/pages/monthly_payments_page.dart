import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'payment_details_page.dart';

enum PaymentSortOption {
  dateDesc,
  dateAsc,
  amountDesc,
  amountAsc,
  tenantAsc,
}

class MonthlyPaymentsPage extends StatefulWidget {
  final DateTime initialMonth;

  const MonthlyPaymentsPage({super.key, required this.initialMonth});

  @override
  State<MonthlyPaymentsPage> createState() => _MonthlyPaymentsPageState();
}

class _MonthlyPaymentsPageState extends State<MonthlyPaymentsPage> {
  final supabase = Supabase.instance.client;
  late DateTime currentMonth;
  bool isLoading = true;
  List<Map<String, dynamic>> allPayments = []; // Store all payments for the month
  List<Map<String, dynamic>> filteredPayments = []; // Store filtered/sorted payments
  double totalCollected = 0.0;
  
  String _searchQuery = '';
  PaymentSortOption _sortOption = PaymentSortOption.dateDesc;

  final currency = NumberFormat.currency(locale: 'en_PH', symbol: '₱', decimalDigits: 2);
  final dateFmt = DateFormat('MMM d, yyyy');
  final monthTitleFmt = DateFormat('MMMM yyyy');

  @override
  void initState() {
    super.initState();
    currentMonth = widget.initialMonth;
    fetchPayments();
  }

  Future<void> fetchPayments() async {
    setState(() => isLoading = true);
    try {
      final startOfMonth = DateTime(currentMonth.year, currentMonth.month, 1);
      final startOfNextMonth = DateTime(currentMonth.year, currentMonth.month + 1, 1);
      
      final startStr = DateFormat('yyyy-MM-dd').format(startOfMonth);
      final endStr = DateFormat('yyyy-MM-dd').format(startOfNextMonth);

      final response = await supabase
          .from('payments')
          .select('*, tenants(name)')
          .gte('payment_date', startStr)
          .lt('payment_date', endStr)
          .order('payment_date', ascending: false);

      double sum = 0.0;
      for (var p in response) {
        sum += (p['amount_paid'] ?? 0.0) as num;
      }

      if (mounted) {
        setState(() {
          allPayments = List<Map<String, dynamic>>.from(response);
          totalCollected = sum;
          isLoading = false;
        });
        _applyFiltersAndSort();
      }
    } catch (e) {
      if (mounted) {
        setState(() => isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading payments: $e')),
        );
      }
    }
  }

  void _applyFiltersAndSort() {
    List<Map<String, dynamic>> temp = List.from(allPayments);

    // Filter
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      temp = temp.where((p) {
        final tenantName = (p['tenants']?['name'] ?? '').toLowerCase();
        final method = (p['method'] ?? '').toLowerCase();
        final ref = (p['reference_no'] ?? '').toLowerCase();
        final amount = (p['amount_paid'] ?? '').toString();
        return tenantName.contains(q) || method.contains(q) || ref.contains(q) || amount.contains(q);
      }).toList();
    }

    // Sort
    temp.sort((a, b) {
      switch (_sortOption) {
        case PaymentSortOption.dateAsc:
          return (a['payment_date'] ?? '').compareTo(b['payment_date'] ?? '');
        case PaymentSortOption.dateDesc:
          return (b['payment_date'] ?? '').compareTo(a['payment_date'] ?? '');
        case PaymentSortOption.amountAsc:
          return (a['amount_paid'] ?? 0.0).compareTo(b['amount_paid'] ?? 0.0);
        case PaymentSortOption.amountDesc:
          return (b['amount_paid'] ?? 0.0).compareTo(a['amount_paid'] ?? 0.0);
        case PaymentSortOption.tenantAsc:
          return (a['tenants']?['name'] ?? '').compareTo(b['tenants']?['name'] ?? '');
      }
    });
    
    setState(() {
      filteredPayments = temp;
    });
  }

  void _changeMonth(int monthsToAdd) {
    setState(() {
      currentMonth = DateTime(currentMonth.year, currentMonth.month + monthsToAdd, 1);
    });
    fetchPayments();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Payments: ${monthTitleFmt.format(currentMonth)}"),
        centerTitle: true,
        actions: [
          PopupMenuButton<PaymentSortOption>(
            icon: const Icon(Icons.sort),
            onSelected: (option) {
              setState(() => _sortOption = option);
              _applyFiltersAndSort();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: PaymentSortOption.dateDesc, child: Text('Date (Newest First)')),
              const PopupMenuItem(value: PaymentSortOption.dateAsc, child: Text('Date (Oldest First)')),
              const PopupMenuItem(value: PaymentSortOption.amountDesc, child: Text('Amount (High-Low)')),
              const PopupMenuItem(value: PaymentSortOption.amountAsc, child: Text('Amount (Low-High)')),
              const PopupMenuItem(value: PaymentSortOption.tenantAsc, child: Text('Tenant (A-Z)')),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: currentMonth,
                firstDate: DateTime(2020),
                lastDate: DateTime.now().add(const Duration(days: 365)),
              );
              if (picked != null) {
                setState(() => currentMonth = picked);
                fetchPayments();
              }
            },
          )
        ],
      ),
      body: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: Icon(Icons.chevron_left, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)),
                      onPressed: () => _changeMonth(-1),
                    ),
                    Column(
                      children: [
                         Text(
                          currency.format(totalCollected),
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Total Collected this Month",
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6), 
                            fontSize: 12, 
                            fontWeight: FontWeight.bold
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: Icon(Icons.chevron_right, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)),
                      onPressed: () => _changeMonth(1),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              onChanged: (value) {
                setState(() => _searchQuery = value);
                _applyFiltersAndSort();
              },
              decoration: InputDecoration(
                hintText: 'Search by tenant, amount, method...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
              ),
            ),
          ),

          // List of Payments
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : filteredPayments.isEmpty
                    ? Center(child: Text("No payments found.", style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6))))
                    : ListView.builder(
                        itemCount: filteredPayments.length,
                        itemBuilder: (context, index) {
                          final p = filteredPayments[index];
                          final amount = currency.format(p['amount_paid']);
                          final dateStr = p['payment_date'] != null
                              ? dateFmt.format(DateTime.parse(p['payment_date']))
                              : '-';
                          
                          String tenantName = p['tenants']?['name'] ?? 'Unknown Tenant';
                          final method = p['method'] ?? 'Cash';

                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            elevation: 1,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                                child: Icon(Icons.receipt_long, color: Theme.of(context).colorScheme.primary, size: 20),
                              ),
                              title: Text(tenantName, style: const TextStyle(fontWeight: FontWeight.w600)),
                              subtitle: Text("$dateStr • $method"),
                              trailing: Text(
                                amount,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => PaymentDetailsPage(payment: p),
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
    );
  }
}

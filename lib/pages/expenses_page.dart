import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'add_expense_page.dart';
import 'expense_details_page.dart'; 

class ExpensesPage extends StatefulWidget {
  const ExpensesPage({super.key});

  @override
  State<ExpensesPage> createState() => _ExpensesPageState();
}

class _ExpensesPageState extends State<ExpensesPage> {
  final supabase = Supabase.instance.client;
  late DateTime currentMonth;
  bool isLoading = true;
  List<Map<String, dynamic>> expenses = [];
  double totalExpensesMonth = 0.0;
  double totalExpensesOverall = 0.0; // ✅ Renamed for clarity

  final currency = NumberFormat.currency(locale: 'en_PH', symbol: '₱', decimalDigits: 2);
  final dateFmt = DateFormat('MMM d, yyyy');
  final monthTitleFmt = DateFormat('MMMM yyyy');

  @override
  void initState() {
    super.initState();
    currentMonth = DateTime.now();
    fetchExpenses();
  }

  Future<void> fetchExpenses() async {
    setState(() => isLoading = true);
    try {
      final startOfMonth = DateTime(currentMonth.year, currentMonth.month, 1);
      final startOfNextMonth = DateTime(currentMonth.year, currentMonth.month + 1, 1);
      
      final startStr = DateFormat('yyyy-MM-dd').format(startOfMonth);
      final endStr = DateFormat('yyyy-MM-dd').format(startOfNextMonth);

      // 1. Fetch expenses for this month
      final responseMonth = await supabase
          .from('expenses')
          .select('*, units(building, unit_number)') 
          .gte('date', startStr)
          .lt('date', endStr)
          .order('date', ascending: false);

      double sumMonth = 0.0;
      for (var e in responseMonth) {
        sumMonth += (e['amount'] ?? 0.0) as num;
      }

      // 2. Fetch Overall Total
      final responseOverall = await supabase
          .from('expenses')
          .select('amount');

      double sumOverall = 0.0;
      for (var e in responseOverall) {
        sumOverall += (e['amount'] ?? 0.0) as num;
      }

      if (mounted) {
        setState(() {
          expenses = List<Map<String, dynamic>>.from(responseMonth);
          totalExpensesMonth = sumMonth;
          totalExpensesOverall = sumOverall;
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => isLoading = false);
         debugPrint("Error loading expenses: $e");
      }
    }
  }

  void _changeMonth(int monthsToAdd) {
    setState(() {
      currentMonth = DateTime(currentMonth.year, currentMonth.month + monthsToAdd, 1);
    });
    fetchExpenses();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Expenses"),
        centerTitle: true,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context, 
            MaterialPageRoute(builder: (_) => const AddExpensePage())
          );
          if (result == true) fetchExpenses();
        },
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          // Summary Header
          Container(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
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
                          monthTitleFmt.format(currentMonth),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          currency.format(totalExpensesMonth),
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.error, 
                          ),
                        ),
                        const SizedBox(height: 4),
                         Text(
                          "Total Expenses",
                          style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: Icon(Icons.chevron_right, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)),
                      onPressed: () => _changeMonth(1),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                // ✅ Overall Indicator
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.error.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: Theme.of(context).colorScheme.error.withOpacity(0.2)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.trending_up, size: 14, color: Theme.of(context).colorScheme.error),
                      const SizedBox(width: 8),
                      Text(
                        "Total Expenses: ${currency.format(totalExpensesOverall)}", // ✅ Updated Label
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // List
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : expenses.isEmpty
                    ? Center(child: Text("No expenses logged for this month.", style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6))))
                    : ListView.builder(
                        itemCount: expenses.length,
                        itemBuilder: (context, index) {
                          final e = expenses[index];
                          final amount = currency.format(e['amount']);
                          final dateStr = e['date'] != null
                              ? dateFmt.format(DateTime.parse(e['date']))
                              : '-';
                          final category = e['category'] ?? 'Uncategorized';

                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(color: Theme.of(context).dividerColor),
                            ),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Colors.orange.withOpacity(0.1),
                                child: const Icon(Icons.receipt, color: Colors.orange, size: 20),
                              ),
                              title: Text(e['title'] ?? 'Expense', style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text("$dateStr • $category"),
                              trailing: Text(
                                amount,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: Theme.of(context).colorScheme.error,
                                ),
                              ),
                              onTap: () async {
                                final result = await Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => ExpenseDetailsPage(expense: e)),
                                );
                                if (result == true) fetchExpenses();
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

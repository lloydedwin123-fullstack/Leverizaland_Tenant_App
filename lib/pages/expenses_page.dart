import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'add_expense_page.dart';
import 'expense_details_page.dart'; // ✅ Import Details Page

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
  double totalExpenses = 0.0;

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

      // Fetch expenses for this month
      final response = await supabase
          .from('expenses')
          .select('*, units(building, unit_number)') // ✅ Join units for display if needed
          .gte('date', startStr)
          .lt('date', endStr)
          .order('date', ascending: false);

      double sum = 0.0;
      for (var e in response) {
        sum += (e['amount'] ?? 0.0) as num;
      }

      if (mounted) {
        setState(() {
          expenses = List<Map<String, dynamic>>.from(response);
          totalExpenses = sum;
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
                          monthTitleFmt.format(currentMonth),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          currency.format(totalExpenses),
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.error, // Red for expenses
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
                                // ✅ Navigate to Details Page
                                final result = await Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => ExpenseDetailsPage(expense: e)),
                                );
                                // Refresh if deleted
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

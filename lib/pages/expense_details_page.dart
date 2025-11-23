import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/file_section_widget.dart';
import 'add_expense_page.dart'; // We can reuse this for editing or make a separate Edit page

class ExpenseDetailsPage extends StatefulWidget {
  final Map<String, dynamic> expense;

  const ExpenseDetailsPage({super.key, required this.expense});

  @override
  State<ExpenseDetailsPage> createState() => _ExpenseDetailsPageState();
}

class _ExpenseDetailsPageState extends State<ExpenseDetailsPage> {
  final supabase = Supabase.instance.client;
  late Map<String, dynamic> _expenseData;
  bool _isLoading = false;

  final currency = NumberFormat.currency(locale: 'en_PH', symbol: '₱', decimalDigits: 2);
  final dateFmt = DateFormat('MMMM d, yyyy');

  @override
  void initState() {
    super.initState();
    _expenseData = widget.expense;
  }

  Future<void> _refreshDetails() async {
    setState(() => _isLoading = true);
    try {
      final res = await supabase
          .from('expenses')
          .select('*, units(building, unit_number)') // Fetch unit details if linked
          .eq('id', _expenseData['id'])
          .single();

      if (mounted) {
        setState(() {
          _expenseData = res;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error refreshing details: $e')),
        );
      }
    }
  }

  Future<void> _deleteExpense() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Expense?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await supabase.from('expenses').delete().eq('id', _expenseData['id']);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Expense deleted.')),
        );
        Navigator.pop(context, true); // Return true to refresh parent list
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final amount = (_expenseData['amount'] ?? 0.0) as num;
    final dateStr = _expenseData['date'] != null
        ? dateFmt.format(DateTime.parse(_expenseData['date']))
        : '-';
    final category = _expenseData['category'] ?? 'Uncategorized';
    final notes = _expenseData['notes'] ?? 'No notes.';
    
    // Extract Unit Name if joined, or just ID if not
    String unitDisplay = 'General Property';
    if (_expenseData['units'] != null) {
      final u = _expenseData['units'];
      unitDisplay = "${u['building']} ${u['unit_number'] ?? ''}";
    } else if (_expenseData['unit_id'] != null) {
      unitDisplay = "Unit ID: ${_expenseData['unit_id']}"; // Fallback if join missing
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Expense Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              // TODO: Navigate to Edit Expense Page (reusing AddExpensePage or similar)
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Edit feature coming soon")));
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: _deleteExpense,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title & Amount Card
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Theme.of(context).dividerColor),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _expenseData['title'] ?? 'Expense',
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            currency.format(amount),
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.error, // Red for expense
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Divider(),
                          const SizedBox(height: 16),
                          _buildDetailRow(context, Icons.calendar_today, 'Date', dateStr),
                          _buildDetailRow(context, Icons.category, 'Category', category),
                          _buildDetailRow(context, Icons.apartment, 'Linked Unit', unitDisplay),
                          const SizedBox(height: 16),
                          const Text("Notes:", style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text(notes, style: Theme.of(context).textTheme.bodyMedium),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Receipt Section
                  FileSectionWidget(
                    category: 'expense_receipts',
                    referenceId: _expenseData['id'].toString(),
                    isPublic: false,
                    title: 'Receipt / Proof',
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildDetailRow(BuildContext context, IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6))),
              Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
        ],
      ),
    );
  }
}

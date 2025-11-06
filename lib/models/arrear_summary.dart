class ArrearSummary {
  final String propertyName;
  final double totalBalance;
  final int invoiceCount;
  final String dateRange;
  final List<Map<String, dynamic>> invoices;

  ArrearSummary({
    required this.propertyName,
    required this.totalBalance,
    required this.invoiceCount,
    required this.dateRange,
    required this.invoices,
  });
}

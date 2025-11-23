import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class PdfService {
  final currency = NumberFormat.currency(locale: 'en_PH', symbol: 'P', decimalDigits: 2);
  final dateFmt = DateFormat('MMMM d, yyyy');

  Future<Uint8List> generateStatementOfAccount({
    required String tenantName,
    required String unitName,
    required List<Map<String, dynamic>> unpaidInvoices,
    required double totalDue,
    String companyName = "LEVERIZALAND INC.",
    String companyAddress = "Property Management Department\nEmail: leverizalandinc@gmail.com",
    String bankDetails = "",
    bool showBankDetails = true,
  }) async {
    final pdf = pw.Document();
    final now = DateTime.now();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            _buildHeader(companyName, companyAddress),
            pw.SizedBox(height: 20),
            _buildTenantInfo(tenantName, unitName, now),
            pw.SizedBox(height: 30),
            _buildInvoiceTable(unpaidInvoices),
            pw.SizedBox(height: 20),
            _buildTotal(totalDue),
            pw.Spacer(),
            _buildFooter(companyName, bankDetails, showBankDetails),
          ];
        },
      ),
    );

    return pdf.save();
  }

  pw.Widget _buildHeader(String name, String address) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // ✅ Use FittedBox to ensure single line scaling
        pw.SizedBox(
          width: double.infinity,
          height: 30, 
          child: pw.FittedBox(
            alignment: pw.Alignment.centerLeft,
            child: pw.Text(
              name,
              style: pw.TextStyle(
                fontWeight: pw.FontWeight.bold, 
                color: PdfColors.blue900
              ),
            ),
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Text(address, style: const pw.TextStyle(fontSize: 10)),
        pw.Divider(thickness: 1),
        pw.Center(
          child: pw.Text(
            "STATEMENT OF ACCOUNT",
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
          ),
        ),
        pw.SizedBox(height: 10),
      ],
    );
  }

  pw.Widget _buildTenantInfo(String tenantName, String unitName, DateTime date) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text("Bill To:", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.Text(tenantName, style: const pw.TextStyle(fontSize: 14)),
            pw.Text("Unit: $unitName"),
          ],
        ),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text("Date: ${dateFmt.format(date)}"),
            pw.Text("Terms: Due Immediately"),
          ],
        ),
      ],
    );
  }

  pw.Widget _buildInvoiceTable(List<Map<String, dynamic>> invoices) {
    final headers = ['Due Date', 'Description', 'Amount Due'];
    
    final data = invoices.map((inv) {
      final date = inv['due_date'] != null 
          ? dateFmt.format(DateTime.parse(inv['due_date'])) 
          : '-';
      final desc = inv['category'] ?? 'Rent';
      final amount = currency.format(inv['balance'] ?? 0);
      return [date, desc, amount];
    }).toList();

    return pw.TableHelper.fromTextArray(
      headers: headers,
      data: data,
      border: null,
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.blue700),
      cellHeight: 30,
      cellAlignments: {
        0: pw.Alignment.centerLeft,
        1: pw.Alignment.centerLeft,
        2: pw.Alignment.centerRight,
      },
    );
  }

  pw.Widget _buildTotal(double total) {
    return pw.Container(
      alignment: pw.Alignment.centerRight,
      child: pw.Row(
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          pw.Text("TOTAL OUTSTANDING:  ", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.Text(
            currency.format(total),
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.red),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildFooter(String companyName, String bankDetails, bool showBankDetails) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Divider(thickness: 1),
        pw.Text("Please make checks payable to $companyName", style: const pw.TextStyle(fontSize: 10)),
        
        if (showBankDetails) ...[
          pw.SizedBox(height: 4),
          pw.Text(bankDetails, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700), textAlign: pw.TextAlign.center),
        ],

        pw.SizedBox(height: 4),
        pw.Text("Thank you for your business!", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontStyle: pw.FontStyle.italic)),
      ],
    );
  }

  Future<void> printOrSharePdf(Uint8List pdfData, String fileName) async {
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfData,
      name: fileName,
    );
  }
}

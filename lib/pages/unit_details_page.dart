import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

import '../widgets/file_section_widget.dart';
import 'edit_unit_page.dart';
import 'edit_lease_page.dart';
import 'edit_contact_page.dart';
import 'edit_tenant_details_page.dart';
import 'payment_details_page.dart';
import '../models/arrear_summary.dart';
import 'property_arrears_page.dart';
import '../services/pdf_service.dart'; 

class UnitDetailsPage extends StatefulWidget {
  final String unitId;
  final String building;
  final String unitNumber;
  final bool showFinanceChips;
  final String? initialChip;

  const UnitDetailsPage({
    super.key,
    required this.unitId,
    required this.building,
    required this.unitNumber,
    this.showFinanceChips = false,
    this.initialChip,
  });

  @override
  State<UnitDetailsPage> createState() => _UnitDetailsPageState();
}

class _UnitDetailsPageState extends State<UnitDetailsPage> {
  final supabase = Supabase.instance.client;
  final pdfService = PdfService(); 

  bool isLoading = true;
  bool isGeneratingPdf = false; 

  Map<String, dynamic>? unit;
  Map<String, dynamic>? activeLease;
  Map<String, dynamic>? tenant;
  List<Map<String, dynamic>> pastLeases = [];
  List<Map<String, dynamic>> contactPersons = [];

  String _chip = 'unit';

  final currency = NumberFormat.currency(locale: 'en_PH', symbol: '₱', decimalDigits: 2);
  final dateFmt = DateFormat('MMMM d, yyyy');

  final TextEditingController _paymentsSearchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _chip = widget.initialChip ?? 'unit';
    fetchUnitDetails();
  }

  double toDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0.0;
  }

  Future<void> fetchUnitDetails() async {
    try {
      final unitRes = await supabase
          .from('units')
          .select('''
            id, building, unit_number, current_rent_amount,
            water_meter_no, electric_meter_no, water_account_no, electric_account_no
          ''')
          .eq('id', widget.unitId)
          .single();

      final activeLeaseRes = await supabase
          .from('leases')
          .select('''
            id, tenant_id, tenant_name, start_date, end_date, status,
            rent_amount, security_deposit, advance_rent, advance_effectivity,
            escalation_rate, escalation_period_years
          ''')
          .eq('unit_id', widget.unitId)
          .eq('status', 'Active')
          .maybeSingle();

      final pastRes = await supabase
          .from('leases')
          .select('id, tenant_name, start_date, end_date, rent_amount')
          .eq('unit_id', widget.unitId)
          .eq('status', 'Ended')
          .order('end_date', ascending: false);

      Map<String, dynamic>? tenantRes;
      List<Map<String, dynamic>> contactsRes = [];

      if (activeLeaseRes != null && activeLeaseRes['tenant_id'] != null) {
        final t = await supabase
            .from('tenants')
            .select('''
              id, name, phone, email, contact_person,
              emergency_contact_name, emergency_contact_number, emergency_contact_relationship
            ''')
            .eq('id', activeLeaseRes['tenant_id'])
            .maybeSingle();

        if (t != null) {
          tenantRes = Map<String, dynamic>.from(t);
        }

        final c = await supabase
            .from('contact_persons')
            .select('id, name, position, email, phone_number, notes, is_primary')
            .eq('tenant_id', activeLeaseRes['tenant_id']);

        contactsRes = List<Map<String, dynamic>>.from(c as List);
      }

      if (!mounted) return;
      setState(() {
        unit = Map<String, dynamic>.from(unitRes);
        activeLease = activeLeaseRes == null ? null : Map<String, dynamic>.from(activeLeaseRes);
        pastLeases = List<Map<String, dynamic>>.from(pastRes as List);
        tenant = tenantRes;
        contactPersons = contactsRes;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading details: $e')));
    }
  }

  // ✅ Select Corporation Profile
  Future<Map<String, dynamic>?> _selectCorporation() async {
    bool showBankDetails = true;

    return await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder( 
          builder: (context, setState) {
            return SimpleDialog(
              title: const Text('Select Biller / Entity'),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
                  child: Row(
                    children: [
                      Checkbox(
                        value: showBankDetails,
                        onChanged: (val) => setState(() => showBankDetails = val ?? true),
                      ),
                      const Text("Show Bank Details?"),
                    ],
                  ),
                ),
                const Divider(),
                SimpleDialogOption(
                  onPressed: () => Navigator.pop(ctx, {
                    'name': 'LEVERIZALAND INC.',
                    'address': 'Property Management Department\nEmail: leverizalandinc@gmail.com',
                    'bank': 'Bank: Eastwest Bank | Account No: 200003483362 | Account Name: Leverizaland Incorporated',
                    'showBank': showBankDetails,
                  }),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12.0),
                    child: Text('Leverizaland Inc.'),
                  ),
                ),
                SimpleDialogOption(
                  onPressed: () => Navigator.pop(ctx, {
                    'name': 'SOUTHLAND PRIME PROPERTIES & DEVT CORP.',
                    'address': 'Property Management Department\nEmail: southlandcorp@gmail.com',
                    'bank': 'Bank: Metrobank | Account No: 447-7-44751012-6 | Account Name: SOUTHLAND PRIME PROPERTIES & DEVT CORP.',
                    'showBank': showBankDetails,
                  }),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12.0),
                    child: Text('Southland Prime Properties'),
                  ),
                ),
              ],
            );
          }
        );
      },
    );
  }

  // ✅ Generate SOA Function
  Future<void> _generateSOA() async {
    if (tenant == null || activeLease == null) return;

    final corpInfo = await _selectCorporation();
    if (corpInfo == null) return; 

    setState(() => isGeneratingPdf = true);
    try {
      final tenantId = activeLease!['tenant_id'];
      final tenantName = tenant!['name'] ?? 'Tenant';
      final unitName = "${widget.building} ${widget.unitNumber}";

      final response = await supabase
          .from('invoice_payment_status')
          .select('*')
          .eq('tenant_id', tenantId)
          .gt('balance', 0)
          .order('due_date', ascending: true);

      final invoices = List<Map<String, dynamic>>.from(response);

      double totalDue = 0.0;
      for (var inv in invoices) {
        totalDue += (inv['balance'] ?? 0.0) as num;
      }

      final pdfData = await pdfService.generateStatementOfAccount(
        tenantName: tenantName,
        unitName: unitName,
        unpaidInvoices: invoices,
        totalDue: totalDue,
        companyName: corpInfo['name'],
        companyAddress: corpInfo['address'],
        bankDetails: corpInfo['bank'],
        showBankDetails: corpInfo['showBank'], 
      );

      await pdfService.printOrSharePdf(pdfData, 'SOA_${tenantName}_${DateTime.now().millisecondsSinceEpoch}.pdf');

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error generating PDF: $e')));
    } finally {
      if (mounted) setState(() => isGeneratingPdf = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final titleUnit = (widget.unitNumber.trim().isEmpty)
        ? widget.building
        : '${widget.building} ${widget.unitNumber}';

    return Scaffold(
      appBar: AppBar(
        title: Text(titleUnit),
        centerTitle: true,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : unit == null
              ? const Center(child: Text('Unit not found'))
              : Column(
                  children: [
                    const SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ChoiceChip(
                            label: const Text('Tenant Details'),
                            selected: _chip == 'tenant',
                            onSelected: (_) => setState(() => _chip = 'tenant'),
                          ),
                          const SizedBox(width: 8),
                          ChoiceChip(
                            label: const Text('Unit Details'),
                            selected: _chip == 'unit',
                            onSelected: (_) => setState(() => _chip = 'unit'),
                          ),
                          const SizedBox(width: 8),
                          ChoiceChip(
                            label: const Text('Arrears'),
                            selected: _chip == 'arrears',
                            onSelected: (_) => setState(() => _chip = 'arrears'),
                          ),
                          const SizedBox(width: 8),
                          ChoiceChip(
                            label: const Text('Payment History'),
                            selected: _chip == 'payments',
                            onSelected: (_) => setState(() => _chip = 'payments'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: _buildActiveTab(),
                    ),
                  ],
                ),
    );
  }

  Widget _buildActiveTab() {
    switch (_chip) {
      case 'tenant':
        return _buildTenantDetailsTab();
      case 'unit':
        return _buildUnitDetailsTab();
      case 'arrears':
        return _buildArrearsTab();
      case 'payments':
        return _buildPaymentsTab();
      default:
        return _buildUnitDetailsTab();
    }
  }

  Widget _buildTenantDetailsTab() {
    if (tenant == null) {
      return const Center(
        child: Text('No active tenant for this unit.'),
      );
    }

    Map<String, dynamic>? primaryContact;
    if (contactPersons.isNotEmpty) {
      try {
        primaryContact = contactPersons.firstWhere(
          (c) => c['is_primary'] == true,
          orElse: () => contactPersons.first,
        );
      } catch (_) {
        primaryContact = contactPersons.first;
      }
    }

    final primaryName = primaryContact?['name'] ?? tenant?['contact_person'] ?? '-';
    final primaryPhone = primaryContact?['phone_number'] ?? tenant?['phone'] ?? '-';
    final primaryEmail = primaryContact?['email'] ?? tenant?['email'] ?? '-';
    final primaryPosition = primaryContact?['position'];

    final tenantId = tenant?['id'] ?? activeLease?['tenant_id'];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Generate SOA Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: isGeneratingPdf ? null : _generateSOA,
              icon: isGeneratingPdf 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.picture_as_pdf),
              label: const Text("Generate Statement of Account"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          const SizedBox(height: 16),

          InkWell(
            onTap: () async {
              if (tenantId == null) return;
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => EditTenantDetailsPage(tenantId: tenantId.toString()),
                ),
              );
              if (result == true && mounted) {
                fetchUnitDetails();
              }
            },
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Contact Person: $primaryName"),
                    if (primaryPosition != null && primaryPosition.toString().trim().isNotEmpty)
                      Text("Position: $primaryPosition"),
                    Text("Phone: $primaryPhone"),
                    Text("Email: $primaryEmail"),
                    const SizedBox(height: 8),
                    Text("Emergency Contact Person: ${tenant?['emergency_contact_name'] ?? '-'}"),
                    Text("Emergency Contact Number: ${tenant?['emergency_contact_number'] ?? '-'}"),
                    Text("Relationship: ${tenant?['emergency_contact_relationship'] ?? '-'}"),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            "Contact Persons:",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          if (contactPersons.isEmpty)
            const Text("No contact persons found.")
          else
            ...contactPersons.map((c) {
              final position = (c['position'] ?? '').toString().trim();
              final phone = (c['phone_number'] ?? '').toString().trim();
              final email = (c['email'] ?? '').toString().trim();
              final notes = (c['notes'] ?? '').toString().trim();
              final isPrimary = c['is_primary'] == true;

              final List<String> lines = [];
              if (position.isNotEmpty) lines.add('Position: $position');
              if (phone.isNotEmpty) lines.add('Phone: $phone');
              if (email.isNotEmpty) lines.add('Email: $email');
              if (notes.isNotEmpty) lines.add('Notes: $notes');

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 4),
                child: ListTile(
                  title: Row(
                    children: [
                      if (isPrimary)
                        const Padding(
                          padding: EdgeInsets.only(right: 6.0),
                          child: Icon(Icons.star, size: 18, color: Colors.amber),
                        ),
                      Expanded(child: Text(c['name'] ?? 'N/A')),
                    ],
                  ),
                  subtitle: lines.isEmpty ? null : Text(lines.join('\n')),
                ),
              );
            }).toList(),
          const SizedBox(height: 16),
          if (tenantId != null)
            FileSectionWidget(
              category: 'tenant_documents',
              referenceId: tenantId.toString(),
              isPublic: false,
              title: 'Tenant Documents',
            ),
        ],
      ),
    );
  }

  Widget _buildUnitDetailsTab() {
    final occupied = activeLease != null;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          OverviewCard(
            unit: unit!,
            currency: currency,
            occupied: occupied,
            dateFmt: dateFmt,
          ),
          const SizedBox(height: 12),
          FileSectionWidget(
            category: 'unit_documents',
            referenceId: widget.unitId,
            isPublic: false,
            title: 'Unit Documents',
          ),
          const SizedBox(height: 12),
          ActiveLeaseCard(
            lease: activeLease,
            contacts: contactPersons,
            currency: currency,
            dateFmt: dateFmt,
            unitCurrentRent: toDouble(unit?['current_rent_amount']),
          ),
          const SizedBox(height: 12),
          if (activeLease != null)
            FileSectionWidget(
              category: 'lease_documents',
              referenceId: activeLease!['id'].toString(),
              isPublic: false,
              title: 'Lease Documents',
            ),
          const SizedBox(height: 12),
          PastLeasesSection(
            pastLeases: pastLeases,
            currency: currency,
            dateFmt: dateFmt,
            toDouble: toDouble,
          ),
        ],
      ),
    );
  }

  Widget _buildArrearsTab() {
    if (activeLease == null || activeLease!['tenant_id'] == null) {
      return const Center(
        child: Text('No active lease; no unpaid invoices.'),
      );
    }

    final tenantId = activeLease!['tenant_id'];

    return Column( // ✅ Changed to Column to hold button + list
      children: [
        // ✅ Added Generate SOA Button at the top of Arrears Tab
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: isGeneratingPdf ? null : _generateSOA,
              icon: isGeneratingPdf 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.picture_as_pdf),
              label: const Text("Generate Statement of Account"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ),
        
        Expanded(
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: supabase
                .from('invoice_payment_status')
                .select('invoice_id, tenant_id, tenant_name, building, unit_name, due_date, amount_due, total_paid, balance, category, remarks')
                .eq('tenant_id', tenantId)
                .gt('balance', 0)
                .order('due_date', ascending: true),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: Colors.amber));
              }
              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    "Error: ${snapshot.error}",
                    style: const TextStyle(color: Colors.red),
                  ),
                );
              }
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Center(child: Text("No unpaid invoices"));
              }

              final arrears = snapshot.data!;
              final groupedArrears = _groupArrears(arrears);

              return ListView.builder(
                itemCount: groupedArrears.length,
                itemBuilder: (context, index) {
                  final summary = groupedArrears[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), // Reduced margin
                    child: ListTile(
                      title: Text(
                        summary.propertyName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Total Balance: ${currency.format(summary.totalBalance)}",
                            style: const TextStyle(
                              color: Color(0xFFAF2626),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text("Coverage: ${summary.dateRange}"),
                          Text("${summary.invoiceCount} Unpaid Invoices"),
                        ],
                      ),
                      onTap: () async {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => PropertyArrearsPage(
                              propertyName: summary.propertyName,
                              invoices: summary.invoices,
                            ),
                          ),
                        );
                        if (result == true && mounted) {
                          setState(() {
                            _chip = 'payments';
                          });
                        }
                      },
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  List<ArrearSummary> _groupArrears(List<Map<String, dynamic>> arrears) {
    final Map<String, List<Map<String, dynamic>>> grouped = {};
    for (final arrear in arrears) {
      final propertyName =
          "${arrear['building'] ?? ''}${arrear['unit_name'] != null ? ' ${arrear['unit_name']}' : ''}";
      (grouped[propertyName] ??= []).add(arrear);
    }

    return grouped.entries.map((entry) {
      final propertyName = entry.key;
      final invoices = entry.value;
      final totalBalance =
          invoices.fold<double>(0, (sum, item) => sum + (item['balance'] ?? 0));
      final invoiceCount = invoices.length;

      invoices.sort((a, b) =>
          (a['due_date'] as String).compareTo(b['due_date'] as String));
      final startDate =
          DateFormat('MMMM yyyy').format(DateTime.parse(invoices.first['due_date']));
      final endDate =
          DateFormat('MMMM yyyy').format(DateTime.parse(invoices.last['due_date']));
      final dateRange = startDate == endDate ? startDate : '$startDate to $endDate';

      return ArrearSummary(
        propertyName: propertyName,
        totalBalance: totalBalance,
        invoiceCount: invoiceCount,
        dateRange: dateRange,
        invoices: invoices,
      );
    }).toList();
  }

  Future<void> _deletePayment(String paymentId) async {
    try {
      await supabase.from('payments').delete().eq('id', paymentId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payment deleted successfully!')),
        );
        setState(() {}); 
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting payment: $e')),
        );
      }
    }
  }

  Widget _buildPaymentsTab() {
    if (activeLease == null || activeLease!['tenant_id'] == null) {
      return const Center(
        child: Text('No active lease; no payment history for this unit.'),
      );
    }

    final tenantId = activeLease!['tenant_id'];

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: TextField(
            controller: _paymentsSearchController,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText:
                  "Search payments (method, reference, remarks, date)...",
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onChanged: (_) => setState(() {}),
          ),
        ),
        Expanded(
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: supabase
                .from('payments')
                .select('*, invoice_id(*)')
                .eq('tenant_id', tenantId)
                .order('payment_date', ascending: false),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                    child: CircularProgressIndicator(color: Colors.amber));
              }
              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    "Error: ${snapshot.error}",
                    style: const TextStyle(color: Colors.red),
                  ),
                );
              }
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Center(child: Text("No payment history."));
              }

              final searchQuery =
                  _paymentsSearchController.text.toLowerCase();

              final payments = snapshot.data!.where((p) {
                final method =
                    (p['method'] ?? '').toString().toLowerCase();
                final ref =
                    (p['reference_no'] ?? '').toString().toLowerCase();
                final remarks =
                    (p['remarks'] ?? '').toString().toLowerCase();

                final formattedDate = p['payment_date'] != null
                    ? DateFormat('MMMM d, yyyy')
                        .format(DateTime.parse(p['payment_date']))
                        .toLowerCase()
                    : '';

                return method.contains(searchQuery) ||
                    ref.contains(searchQuery) ||
                    remarks.contains(searchQuery) ||
                    formattedDate.contains(searchQuery);
              }).toList();

              if (payments.isEmpty) {
                return const Center(child: Text("No results found."));
              }

              return ListView.builder(
                itemCount: payments.length,
                itemBuilder: (context, index) {
                  final p = payments[index];
                  final formattedDate = p['payment_date'] != null
                      ? DateFormat('MMMM d, yyyy')
                          .format(DateTime.parse(p['payment_date']))
                      : '-';

                  return Slidable(
                    key: ValueKey(p['id']),
                    endActionPane: ActionPane(
                      motion: const ScrollMotion(),
                      children: [
                        SlidableAction(
                          onPressed: (context) async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (context) {
                                return AlertDialog(
                                  title: const Text('Delete Payment'),
                                  content: const Text(
                                      'Are you sure you want to delete this payment?'),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, false),
                                      child: const Text('Cancel'),
                                    ),
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, true),
                                      child: const Text('Delete'),
                                    ),
                                  ],
                                );
                              },
                            );

                            if (confirm == true) {
                              _deletePayment(p['id']);
                            }
                          },
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          icon: Icons.delete,
                          label: 'Delete',
                        ),
                      ],
                    ),
                    child: Card(
                      margin: const EdgeInsets.all(8),
                      child: ListTile(
                        title: Text(
                          "Amount Paid: ${currency.format(p['amount_paid'] ?? 0)}",
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Method: ${p['method'] ?? '-'}"),
                            Text("Reference Code: ${p['reference_no'] ?? '-'}"),
                            Text("Remarks: ${p['remarks'] ?? '-'}"),
                            Text("Payment Date: $formattedDate"),
                          ],
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  PaymentDetailsPage(payment: p),
                            ),
                          );
                        },
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

// ====== Overview Card ======
class OverviewCard extends StatelessWidget {
  final Map<String, dynamic> unit;
  final NumberFormat currency;
  final DateFormat dateFmt;
  final bool occupied;

  const OverviewCard({
    super.key,
    required this.unit,
    required this.currency,
    required this.occupied,
    required this.dateFmt,
  });

  @override
  Widget build(BuildContext context) {
    final waterAccount = unit['water_account_no'] ?? 'no data';
    final waterMeter = unit['water_meter_no'] ?? 'no data';
    final electricAccount = unit['electric_account_no'] ?? 'no data';
    final electricMeter = unit['electric_meter_no'] ?? 'no data';

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Unit Overview',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.blue),
                  tooltip: 'Edit Unit Details',
                  onPressed: () async {
                    final updated = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => EditUnitPage(unit: unit),
                      ),
                    );
                    if (updated == true) {
                      final parentState =
                      context.findAncestorStateOfType<_UnitDetailsPageState>();
                      parentState?.fetchUnitDetails();
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('Rent: ${currency.format(unit['current_rent_amount'] ?? 0)} / month'),
            Text('Status: ${occupied ? 'Occupied' : 'Vacant'}'),
            const SizedBox(height: 4),
            Text('Water Account #: $waterAccount'),
            Text('Water Meter #: $waterMeter'),
            const SizedBox(height: 4),
            Text('Electric Account #: $electricAccount'),
            Text('Electric Meter #: $electricMeter'),
          ],
        ),
      ),
    );
  }
}

// ====== Past Leases Section ======
class PastLeasesSection extends StatelessWidget {
  final List<Map<String, dynamic>> pastLeases;
  final NumberFormat currency;
  final DateFormat dateFmt;
  final double Function(dynamic) toDouble;

  const PastLeasesSection({
    super.key,
    required this.pastLeases,
    required this.currency,
    required this.dateFmt,
    required this.toDouble,
  });

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      title: const Text('Past Leases',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      initiallyExpanded: false,
      children: pastLeases.isEmpty
          ? [const Padding(padding: EdgeInsets.all(8), child: Text('No past leases found.'))]
          : pastLeases.map((l) {
        final startStr = l['start_date'] != null
            ? dateFmt.format(DateTime.parse(l['start_date']))
            : '-';
        final endStr = l['end_date'] != null
            ? dateFmt.format(DateTime.parse(l['end_date']))
            : '-';
        final rent = toDouble(l['rent_amount']);
        return ListTile(
          title: Text('Tenant: ${l['tenant_name'] ?? 'Unknown'}'),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Start: $startStr'),
              Text('End: $endStr'),
              Text('Rent: ${currency.format(rent)}'),
            ],
          ),
        );
      }).toList(),
    );
  }
}

// ====== Active Lease ======
class ActiveLeaseCard extends StatelessWidget {
  final Map<String, dynamic>? lease;
  final List<Map<String, dynamic>> contacts;
  final NumberFormat currency;
  final DateFormat dateFmt;
  final double unitCurrentRent;

  const ActiveLeaseCard({
    super.key,
    required this.lease,
    required this.contacts,
    required this.currency,
    required this.dateFmt,
    required this.unitCurrentRent,
  });

  double _d(dynamic v) {
    if (v == null) return 0.0;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0.0;
  }

  @override
  Widget build(BuildContext context) {
    if (lease == null) {
      return Card(
        color: Colors.red[50],
        child: const Padding(
          padding: EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
               Text(
                'No active lease for this unit.',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
               SizedBox(height: 10),
               // 🆕 Add Lease Button Logic will go here if you decide to put it inside the card,
               // but for now, the "Add Lease" Quick Action handles creation.
               Text("Use the 'Add Lease' Quick Action on the Dashboard to create a new lease.", style: TextStyle(fontSize: 12)),
            ],
          ),
        ),
      );
    }

    final tenantName = (lease!['tenant_name'] ?? 'Unknown Tenant').toString();
    final startStr = lease!['start_date'] != null
        ? dateFmt.format(DateTime.parse(lease!['start_date']))
        : '-';
    final endStr = lease!['end_date'] != null
        ? dateFmt.format(DateTime.parse(lease!['end_date']))
        : '-';

    final baseRent = (_d(lease!['rent_amount']) != 0.0)
        ? _d(lease!['rent_amount'])
        : unitCurrentRent;
    final securityDeposit = _d(lease!['security_deposit']);
    final advanceRent = _d(lease!['advance_rent']);
    final advanceEffectivity = lease!['advance_effectivity'] ?? '-';
    final escalationRate = lease!['escalation_rate'];
    final escalationPeriod = lease!['escalation_period_years'];

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Active Lease',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.blue),
                  tooltip: 'Edit Lease Details',
                  onPressed: () async {
                    final updated = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => EditLeasePage(lease: lease!),
                      ),
                    );

                    if (updated == true) {
                      final parentState =
                      context.findAncestorStateOfType<_UnitDetailsPageState>();
                      parentState?.fetchUnitDetails();
                    }
                  },
                ),
              ],
            ),

            const SizedBox(height: 8),
            Text('Tenant: $tenantName',
                style: const TextStyle(fontWeight: FontWeight.w700)),
            Text('Start Date: $startStr'),
            Text('End Date: $endStr'),
            const Divider(),

            Text('Base Rent: ${currency.format(baseRent)}'),
            Text('Security Deposit: ${currency.format(securityDeposit)}'),
            Text('Advance Rent: ${currency.format(advanceRent)}'),
            Text('Advance Effectivity: $advanceEffectivity'),
            Text('Escalation Rate: ${escalationRate != null ? '$escalationRate%' : 'Not Set'}'),
            Text(
              'Escalation Period: ${escalationPeriod != null ? 'Every $escalationPeriod year${(escalationPeriod is num && escalationPeriod > 1) ? 's' : ''}' : 'Not Set'}',
            ),
            const SizedBox(height: 10),
            const Divider(),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Contact Persons',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline, color: Colors.green),
                  tooltip: 'Add Contact',
                  onPressed: () async {
                    final updated = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            EditContactPage(tenantId: lease!['tenant_id']),
                      ),
                    );

                    if (updated == true) {
                      final parentState =
                      context.findAncestorStateOfType<_UnitDetailsPageState>();
                      parentState?.fetchUnitDetails();
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 6),

            contacts.isEmpty
                ? const Text('No contacts found.')
                : Column(
              children: contacts.map((c) {
                final name = c['name'] ?? '';
                final pos = (c['position'] ?? '').toString().trim();
                final phone = c['phone_number'] ?? '—';
                final email = c['email'] ?? '—';

                return Card(
                  margin: const EdgeInsets.only(bottom: 6),
                  child: ListTile(
                    leading: const Icon(Icons.person, size: 24),
                    title: Text(pos.isNotEmpty ? '$name ($pos)' : name),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('📞 $phone'),
                        Text('📧 $email'),
                        if (c['is_primary'] == true)
                          const Text(
                            'Primary Contact',
                            style: TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.w500),
                          ),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.blue),
                          tooltip: 'Edit Contact',
                          onPressed: () async {
                            final updated = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => EditContactPage(
                                  contact: c,
                                  tenantId: lease!['tenant_id'],
                                ),
                              ),
                            );
                            if (updated == true) {
                              final parentState = context
                                  .findAncestorStateOfType<_UnitDetailsPageState>();
                              parentState?.fetchUnitDetails();
                            }
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          tooltip: 'Delete Contact',
                          onPressed: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('Delete Contact?'),
                                content:
                                Text('Remove $name from contact persons?'),
                                actions: [
                                  TextButton(
                                      onPressed: () =>
                                          Navigator.pop(ctx, false),
                                      child: const Text('Cancel')),
                                  TextButton(
                                      onPressed: () =>
                                          Navigator.pop(ctx, true),
                                      child: const Text('Delete')),
                                ],
                              ),
                            );

                            if (confirm == true) {
                              final contactId = c['id'];
                              if (contactId == null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text(
                                          'Cannot delete: contact has no ID.')),
                                );
                                return;
                              }

                              await Supabase.instance.client
                                  .from('contact_persons')
                                  .delete()
                                  .eq('id', contactId);

                              final parentState = context
                                  .findAncestorStateOfType<_UnitDetailsPageState>();
                              parentState?.fetchUnitDetails();
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

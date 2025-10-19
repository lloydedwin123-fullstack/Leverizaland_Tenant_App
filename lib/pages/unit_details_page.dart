import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

import '../widgets/file_section_widget.dart'; // 🧩 Reusable file section
import 'edit_unit_page.dart';
import 'edit_lease_page.dart';
import 'edit_contact_page.dart';
import 'payment_details_page.dart';

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

  bool isLoading = true;
  Map<String, dynamic>? unit;
  Map<String, dynamic>? activeLease;
  List<Map<String, dynamic>> pastLeases = [];
  List<Map<String, dynamic>> contactPersons = [];

  String _chip = 'arrears';
  final currency =
  NumberFormat.currency(locale: 'en_PH', symbol: '₱', decimalDigits: 2);
  final dateFmt = DateFormat('MMMM d, yyyy');

  @override
  void initState() {
    super.initState();
    _chip = widget.initialChip ?? 'arrears';
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

      List<Map<String, dynamic>> contactsRes = [];
      if (activeLeaseRes != null && activeLeaseRes['tenant_id'] != null) {
        final c = await supabase
            .from('contact_persons')
            .select(
            'id, name, position, email, phone_number, notes, is_primary')
            .eq('tenant_id', activeLeaseRes['tenant_id']);
        contactsRes = List<Map<String, dynamic>>.from(c as List);
      }

      if (!mounted) return;
      setState(() {
        unit = Map<String, dynamic>.from(unitRes);
        activeLease =
        activeLeaseRes == null ? null : Map<String, dynamic>.from(activeLeaseRes);
        pastLeases = List<Map<String, dynamic>>.from(pastRes as List);
        contactPersons = contactsRes;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error loading details: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final occupied = activeLease != null;
    final titleUnit = (widget.unitNumber.trim().isEmpty)
        ? widget.building
        : '${widget.building} ${widget.unitNumber}';

    return Scaffold(
      appBar: AppBar(title: Text(titleUnit), centerTitle: true),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : unit == null
          ? const Center(child: Text('Unit not found'))
          : RefreshIndicator(
        onRefresh: fetchUnitDetails,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ====== Overview ======
                OverviewCard(
                  unit: unit!,
                  currency: currency,
                  occupied: occupied,
                  dateFmt: dateFmt,
                ),

                const SizedBox(height: 12),

                // ====== Unit Documents ======
                FileSectionWidget(
                  category: 'unit_documents',
                  referenceId: widget.unitId,
                  isPublic: false,
                  title: 'Unit Documents',
                ),

                const SizedBox(height: 12),

                // ====== Active Lease ======
                ActiveLeaseCard(
                  lease: activeLease,
                  contacts: contactPersons,
                  currency: currency,
                  dateFmt: dateFmt,
                  unitCurrentRent:
                  toDouble(unit?['current_rent_amount']),
                ),

                const SizedBox(height: 12),

                // ====== Lease Documents ======
                if (activeLease != null)
                  FileSectionWidget(
                    category: 'lease_documents',
                    referenceId: activeLease!['id'].toString(),
                    isPublic: false,
                    title: 'Lease Documents',
                  ),

                const SizedBox(height: 12),

                // ====== Finance Tabs / Past Leases ======
                if (widget.showFinanceChips) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ChoiceChip(
                        label: const Text('Arrears'),
                        selected: _chip == 'arrears',
                        onSelected: (_) =>
                            setState(() => _chip = 'arrears'),
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('Payment History'),
                        selected: _chip == 'payments',
                        onSelected: (_) =>
                            setState(() => _chip = 'payments'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_chip == 'arrears') _buildUnitArrearsByUnitId(),
                  if (_chip == 'payments')
                    _buildUnitPaymentsByTenant(),
                ] else
                  PastLeasesSection(
                    pastLeases: pastLeases,
                    currency: currency,
                    dateFmt: dateFmt,
                    toDouble: toDouble,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ====== Arrears ======
  Widget _buildUnitArrearsByUnitId() {
    if (activeLease == null || activeLease!['tenant_id'] == null) {
      return const Text('No active lease; no unpaid invoices for this unit.');
    }

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: supabase
          .from('invoice_payment_status')
          .select(
          'invoice_id, unit_id, due_date, amount_due, total_paid, balance, lease_status')
          .eq('unit_id', widget.unitId)
          .eq('lease_status', 'Active')
          .gt('balance', 0)
          .order('due_date', ascending: true),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Text('Error: ${snap.error}');
        }
        final items = snap.data ?? [];
        if (items.isEmpty) {
          return const Text('No unpaid invoices for this unit.');
        }

        double total = 0;
        for (final r in items) {
          total += toDouble(r['balance']);
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ...items.map((a) {
              final dueStr = a['due_date'] != null
                  ? dateFmt.format(DateTime.parse(a['due_date']))
                  : '-';
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Due Date: $dueStr'),
                      Text(
                          'Amount Due: ${currency.format(toDouble(a['amount_due']))}'),
                      Text(
                          'Total Paid: ${currency.format(toDouble(a['total_paid']))}'),
                      Text(
                        'Balance: ${currency.format(toDouble(a['balance']))}',
                        style: const TextStyle(
                            color: Color(0xFFAF2626),
                            fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              );
            }),
            if (items.length > 1)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Total Arrears: ${currency.format(total)}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
          ],
        );
      },
    );
  }

  // ====== Payments ======
  Widget _buildUnitPaymentsByTenant() {
    if (activeLease == null || activeLease!['tenant_id'] == null) {
      return const Text('No active lease; no payment history for this unit.');
    }

    final tenantId = activeLease!['tenant_id'];

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: supabase
          .from('payments')
          .select('*')
          .eq('tenant_id', tenantId)
          .order('payment_date', ascending: false),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Text('Error: ${snap.error}');
        }

        final pays = snap.data ?? [];
        if (pays.isEmpty) return const Text('No payment history.');

        return Column(
          children: pays.map((p) {
            final dateStr = p['payment_date'] != null
                ? dateFmt.format(DateTime.parse(p['payment_date']))
                : '-';

            return ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 120),
              child: InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => PaymentDetailsPage(payment: p),
                    ),
                  );
                },
                child: Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Amount Paid: ${currency.format(toDouble(p['amount_paid']))}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text('Method: ${p['method'] ?? '-'}'),
                        Text('Reference Code: ${p['reference_no'] ?? '-'}'),
                        Text('Remarks: ${p['remarks'] ?? '-'}'),
                        Text('Payment Date: $dateStr'),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        );
      },
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
          child: Text(
            'No active lease for this unit.',
            style: TextStyle(fontSize: 16),
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
            // Title + Edit Lease button
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

            // ✅ CONTACT PERSONS SECTION RESTORED
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


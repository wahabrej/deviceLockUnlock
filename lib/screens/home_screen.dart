import 'package:devicelocunlock/core/routes/Routes_name.dart';
import 'package:devicelocunlock/models/device_status_profile.dart';
import 'package:devicelocunlock/services/device_control_service.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    DeviceControlService.instance.addListener(_onServiceChange);
    _refresh();
  }

  @override
  void dispose() {
    DeviceControlService.instance.removeListener(_onServiceChange);
    super.dispose();
  }

  void _onServiceChange() {
    if (!mounted) return;
    if (DeviceControlService.instance.isLocked) {
      Navigator.pushNamedAndRemoveUntil(
        context,
        RouteName.lockScreen,
        (route) => false,
      );
      return;
    }
    setState(() {});
  }

  Future<void> _refresh() async {
    if (_isRefreshing) return;
    if (mounted) setState(() => _isRefreshing = true);
    await Future.wait([
      DeviceControlService.instance.refreshLocalDeviceInfo(),
      DeviceControlService.instance.checkDeviceOwnerStatus(),
      DeviceControlService.instance.syncWithServer(),
    ]);
    if (mounted) setState(() => _isRefreshing = false);
  }

  @override
  Widget build(BuildContext context) {
    final service = DeviceControlService.instance;
    final profile = service.profile;

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: const Color(0xFFF3F6FA),
        appBar: AppBar(
          title: const Text('SmartPay Device'),
          backgroundColor: const Color(0xFF075E9C),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        body: RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              _managementStatus(service),
              const SizedBox(height: 16),
              _sectionCard(
                title: 'Device information',
                icon: Icons.smartphone,
                children: _deviceRows(profile),
              ),
              const SizedBox(height: 16),
              _sectionCard(
                title: 'Customer information',
                icon: Icons.person_outline,
                children: _customerRows(profile.customer),
              ),
              const SizedBox(height: 16),
              _sectionCard(
                title: 'Loan information',
                icon: Icons.account_balance_wallet_outlined,
                children: _loanRows(profile.loan),
              ),
              const SizedBox(height: 16),
              _sectionCard(
                title: 'Payment status',
                icon: Icons.payments_outlined,
                children: _paymentRows(profile),
              ),
              if (service.syncError != null) ...[
                const SizedBox(height: 14),
                Text(
                  service.syncError!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.orange.shade900, fontSize: 12),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _managementStatus(DeviceControlService service) {
    final commandPending = service.profile.isLocked && !service.isLocked;
    final protected = service.isDeviceOwner;
    final color = commandPending
        ? Colors.red
        : protected
            ? Colors.green
            : Colors.orange;
    final title = commandPending
        ? 'Lock command pending'
        : protected
            ? 'Managed protection active'
            : 'Device Owner provisioning required';
    final description = commandPending
        ? 'Connect this managed device to the internet so SmartPay can apply the lock.'
        : protected
            ? 'This device is enrolled and protected by SmartPay.'
            : 'A normal APK installation cannot prevent removal or control the whole device.';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            commandPending
                ? Icons.lock_clock_outlined
                : protected
                    ? Icons.verified_user_outlined
                    : Icons.warning_amber_rounded,
            color: color,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(fontWeight: FontWeight.w700, color: color),
                ),
                const SizedBox(height: 3),
                Text(description, style: const TextStyle(fontSize: 12)),
              ],
            ),
          ),
          if (_isRefreshing)
            const Padding(
              padding: EdgeInsets.only(left: 8),
              child: SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _deviceRows(DeviceStatusProfile profile) {
    final device = profile.device;
    return [
      _infoRow('Model', _first([device.model, device.brand])),
      _infoRow('IMEI', _first([profile.canonicalImei])),
      if (_hasText(device.imei2) && device.imei2 != profile.canonicalImei)
        _infoRow('IMEI 2', device.imei2!),
      _infoRow('Android', _first([device.osVersion])),
      _infoRow(
        'Battery',
        device.batteryLevel == null
            ? 'Not available'
            : '${device.batteryLevel}%',
      ),
    ];
  }

  List<Widget> _customerRows(CustomerDetails? customer) => [
        _infoRow('Customer name', _first([customer?.name])),
        _infoRow('Phone number', _first([customer?.phone])),
        if (_hasText(customer?.id)) _infoRow('Customer ID', customer!.id!),
      ];

  List<Widget> _loanRows(LoanDetails? loan) => [
        _infoRow('Loan ID', _first([loan?.reference])),
        _infoRow('Loan status', _first([loan?.status])),
        if (loan?.totalAmount != null)
          _infoRow('Loan amount', _money(loan!.totalAmount)),
        if (loan?.installmentAmount != null)
          _infoRow('Installment', _money(loan!.installmentAmount)),
        if (loan?.installmentCount != null || loan?.paidInstallments != null)
          _infoRow(
            'Installments paid',
            '${loan?.paidInstallments ?? 0} / ${loan?.installmentCount ?? '-'}',
          ),
        if (loan?.outstandingAmount != null)
          _infoRow('Outstanding', _money(loan!.outstandingAmount)),
        _infoRow('Next due date', _date(loan?.nextDueDate)),
      ];

  List<Widget> _paymentRows(DeviceStatusProfile profile) {
    final payment = profile.payment;
    final outstanding =
        payment?.outstandingAmount ?? profile.loan?.outstandingAmount;
    final overdueAmount = payment?.overdueAmount ?? profile.loan?.overdueAmount;
    return [
      _infoRow('Status', _first([payment?.status])),
      if (payment?.paidAmount != null)
        _infoRow('Amount paid', _money(payment!.paidAmount)),
      if (outstanding != null)
        _infoRow('Outstanding', _money(outstanding)),
      if (overdueAmount != null)
        _infoRow('Overdue amount', _money(overdueAmount), warning: overdueAmount > 0),
      if (payment?.overdueInstallments != null)
        _infoRow(
          'Overdue installments',
          payment!.overdueInstallments.toString(),
          warning: payment.overdueInstallments! > 0,
        ),
      if (payment?.daysOverdue != null)
        _infoRow(
          'Days overdue',
          payment!.daysOverdue.toString(),
          warning: payment.daysOverdue! > 0,
        ),
      _infoRow(
        'Next due date',
        _date(payment?.nextDueDate ?? profile.loan?.nextDueDate),
      ),
      if (_hasText(payment?.lastPayment))
        _infoRow('Last payment', payment!.lastPayment!),
    ];
  }

  Widget _sectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Card(
      margin: EdgeInsets.zero,
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 21, color: const Color(0xFF075E9C)),
                const SizedBox(width: 9),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value, {bool warning = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(label, style: const TextStyle(color: Color(0xFF627084))),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: warning ? Colors.red.shade700 : const Color(0xFF172033),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _first(List<String?> values) {
    for (final value in values) {
      if (_hasText(value)) return value!.trim();
    }
    return 'Not available';
  }

  bool _hasText(String? value) => value != null && value.trim().isNotEmpty;

  String _money(num? value) =>
      value == null ? 'Not available' : '৳${NumberFormat('#,##0.##').format(value)}';

  String _date(String? value) {
    if (!_hasText(value)) return 'Not available';
    final parsed = DateTime.tryParse(value!);
    return parsed == null ? value : DateFormat('d MMM yyyy').format(parsed.toLocal());
  }
}

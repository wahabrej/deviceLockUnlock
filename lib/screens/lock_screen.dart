import 'package:devicelocunlock/models/device_status_profile.dart';
import 'package:devicelocunlock/services/device_control_service.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class LockScreen extends StatelessWidget {
  const LockScreen({super.key});

  static const String lockedMessage =
      'This device has been locked due to an outstanding loan payment. '
      'Please complete your payment to unlock the device.';

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<DeviceControlService>().profile;

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: const Color(0xFF090D14),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 38, 24, 30),
            child: Column(
              children: [
                Container(
                  width: 104,
                  height: 104,
                  decoration: BoxDecoration(
                    color: const Color(0xFFB42318).withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFFE5484D).withValues(alpha: 0.65),
                      width: 2,
                    ),
                  ),
                  child: const Icon(
                    Icons.lock_rounded,
                    size: 52,
                    color: Color(0xFFFF5A5F),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'DEVICE LOCKED',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.4,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  lockedMessage,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFFE6EAF0),
                    fontSize: 17,
                    height: 1.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (_hasText(profile.lockReason)) ...[
                  const SizedBox(height: 12),
                  Text(
                    profile.lockReason!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFFFFB4AB),
                      fontSize: 13,
                    ),
                  ),
                ],
                const SizedBox(height: 28),
                _detailsCard(profile),
                const SizedBox(height: 22),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.sync_rounded,
                      color: Color(0xFF9AA6B7),
                      size: 17,
                    ),
                    SizedBox(width: 7),
                    Flexible(
                      child: Text(
                        'The device will be restored automatically after SmartPay confirms the unlock.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFF9AA6B7),
                          fontSize: 12,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _detailsCard(DeviceStatusProfile profile) {
    final payment = profile.payment;
    final loan = profile.loan;
    final outstanding = payment?.outstandingAmount ?? loan?.outstandingAmount;
    final overdue = payment?.overdueAmount ?? loan?.overdueAmount;
    final dueDate = payment?.nextDueDate ?? loan?.nextDueDate;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF151B25),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2A3443)),
      ),
      child: Column(
        children: [
          _detailRow('Customer', _value(profile.customer?.name)),
          _detailRow('Phone', _value(profile.customer?.phone)),
          _detailRow('Loan ID', _value(loan?.reference)),
          _detailRow('Payment status', _value(payment?.status ?? loan?.status)),
          if (outstanding != null)
            _detailRow('Outstanding', _money(outstanding), highlight: true),
          if (overdue != null)
            _detailRow('Overdue amount', _money(overdue), highlight: overdue > 0),
          _detailRow('Next due date', _date(dueDate)),
          _detailRow('IMEI', _value(profile.canonicalImei), last: true),
        ],
      ),
    );
  }

  Widget _detailRow(
    String label,
    String value, {
    bool highlight = false,
    bool last = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: last
            ? null
            : const Border(
                bottom: BorderSide(color: Color(0xFF2A3443)),
              ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 116,
            child: Text(
              label,
              style: const TextStyle(color: Color(0xFF9AA6B7), fontSize: 13),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                color: highlight ? const Color(0xFFFF827C) : Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static bool _hasText(String? value) =>
      value != null && value.trim().isNotEmpty;

  static String _value(String? value) =>
      _hasText(value) ? value!.trim() : 'Not available';

  static String _money(num value) =>
      '৳${NumberFormat('#,##0.##').format(value)}';

  static String _date(String? value) {
    if (!_hasText(value)) return 'Not available';
    final parsed = DateTime.tryParse(value!);
    return parsed == null
        ? value
        : DateFormat('d MMM yyyy').format(parsed.toLocal());
  }
}

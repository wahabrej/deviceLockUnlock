import 'dart:convert';

/// Typed view of the device lock-status payload returned by SmartPay.
///
/// The parser accepts both the current nested contract and the older flat
/// response keys so deployed APKs can be upgraded without re-enrolling a
/// device.
class DeviceStatusProfile {
  const DeviceStatusProfile({
    required this.isLocked,
    this.lockRevision = 0,
    this.lockReason,
    this.lockMessage,
    this.imei,
    this.device = const DeviceDetails(),
    this.customer,
    this.loan,
    this.payment,
    this.updatedAt,
  });

  final bool isLocked;
  final int lockRevision;
  final String? lockReason;
  final String? lockMessage;
  final String? imei;
  final DeviceDetails device;
  final CustomerDetails? customer;
  final LoanDetails? loan;
  final PaymentDetails? payment;
  final String? updatedAt;

  String get canonicalImei =>
      _firstNonBlank([imei, device.imei, device.imei1]) ?? '';

  factory DeviceStatusProfile.fromApiResponse(Map<String, dynamic> response) {
    final data = _asMap(response['data']);
    return DeviceStatusProfile.fromJson(data.isEmpty ? response : data);
  }

  factory DeviceStatusProfile.fromJson(Map<String, dynamic> json) {
    final deviceJson = _asMap(json['device']);
    final customerJson = _asMap(json['customer']);
    final loanJson = _asMap(json['loan']);
    final paymentJson = _asMap(json['payment']);

    final rawLock = _pick(json, const [
      'isLocked',
      'is_locked',
      'locked',
    ]);
    final lockStatus = _text(
      _pick(json, const ['lockStatus', 'lock_status', 'deviceLockStatus']),
    );

    return DeviceStatusProfile(
      isLocked: rawLock == null
          ? const {'locked', 'lock', 'blocked'}.contains(
              lockStatus?.trim().toLowerCase(),
            )
          : _boolean(rawLock),
      lockRevision:
          _integer(_pick(json, const ['lockRevision', 'lock_revision'])) ?? 0,
      lockReason: _text(
        _pick(json, const ['lockReason', 'lock_reason', 'reason']),
      ),
      lockMessage: _text(
        _pick(json, const ['lockMessage', 'lock_message']),
      ),
      imei: _text(
        _pick(json, const ['canonicalImei', 'canonical_imei', 'imei', 'imei1']),
      ),
      device: DeviceDetails.fromJson(deviceJson, fallback: json),
      customer: CustomerDetails.fromJsonOrNull(
        customerJson,
        fallback: json,
      ),
      loan: LoanDetails.fromJsonOrNull(loanJson, fallback: json),
      payment: PaymentDetails.fromJsonOrNull(paymentJson, fallback: json),
      updatedAt: _text(
        _pick(json, const ['updatedAt', 'updated_at', 'lastUpdatedAt']),
      ),
    );
  }

  factory DeviceStatusProfile.fromStorage(String? value) {
    if (value == null || value.trim().isEmpty) {
      return const DeviceStatusProfile(isLocked: false);
    }
    try {
      final decoded = jsonDecode(value);
      if (decoded is Map) {
        return DeviceStatusProfile.fromJson(
          decoded.map((key, value) => MapEntry(key.toString(), value)),
        );
      }
    } catch (_) {
      // A corrupt cache should never prevent the management app from opening.
    }
    return const DeviceStatusProfile(isLocked: false);
  }

  DeviceStatusProfile copyWith({
    bool? isLocked,
    int? lockRevision,
    String? lockReason,
    String? lockMessage,
    String? imei,
    DeviceDetails? device,
    CustomerDetails? customer,
    LoanDetails? loan,
    PaymentDetails? payment,
    String? updatedAt,
  }) {
    return DeviceStatusProfile(
      isLocked: isLocked ?? this.isLocked,
      lockRevision: lockRevision ?? this.lockRevision,
      lockReason: lockReason ?? this.lockReason,
      lockMessage: lockMessage ?? this.lockMessage,
      imei: imei ?? this.imei,
      device: device ?? this.device,
      customer: customer ?? this.customer,
      loan: loan ?? this.loan,
      payment: payment ?? this.payment,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'isLocked': isLocked,
        'lockRevision': lockRevision,
        if (lockReason != null) 'lockReason': lockReason,
        if (lockMessage != null) 'lockMessage': lockMessage,
        if (imei != null) 'imei': imei,
        'device': device.toJson(),
        if (customer != null) 'customer': customer!.toJson(),
        if (loan != null) 'loan': loan!.toJson(),
        if (payment != null) 'payment': payment!.toJson(),
        if (updatedAt != null) 'updatedAt': updatedAt,
      };

  String toStorage() => jsonEncode(toJson());
}

class DeviceDetails {
  const DeviceDetails({
    this.imei,
    this.imei1,
    this.imei2,
    this.model,
    this.brand,
    this.serialNumber,
    this.osVersion,
    this.appVersion,
    this.batteryLevel,
    this.deviceId,
  });

  final String? imei;
  final String? imei1;
  final String? imei2;
  final String? model;
  final String? brand;
  final String? serialNumber;
  final String? osVersion;
  final String? appVersion;
  final num? batteryLevel;
  final String? deviceId;

  factory DeviceDetails.fromJson(
    Map<String, dynamic> json, {
    Map<String, dynamic> fallback = const {},
  }) {
    dynamic value(List<String> keys) => _pick(json, keys) ?? _pick(fallback, keys);

    return DeviceDetails(
      imei: _text(value(const ['canonicalImei', 'canonical_imei', 'imei'])),
      imei1: _text(value(const ['imei1', 'imei_1'])),
      imei2: _text(value(const ['imei2', 'imei_2'])),
      model: _text(value(const ['model', 'deviceModel', 'device_model'])),
      brand: _text(value(const ['brand', 'manufacturer'])),
      serialNumber: _text(
        value(const ['serialNumber', 'serial_number', 'serial']),
      ),
      osVersion: _text(
        value(const ['osVersion', 'os_version', 'androidVersion']),
      ),
      appVersion: _text(value(const ['appVersion', 'app_version'])),
      batteryLevel: _number(value(const ['batteryLevel', 'battery_level'])),
      deviceId: _text(value(const ['deviceId', 'device_id', 'androidId'])),
    );
  }

  DeviceDetails merge(DeviceDetails fallback) => DeviceDetails(
        imei: _firstNonBlank([imei, fallback.imei]),
        imei1: _firstNonBlank([imei1, fallback.imei1]),
        imei2: _firstNonBlank([imei2, fallback.imei2]),
        model: _firstNonBlank([model, fallback.model]),
        brand: _firstNonBlank([brand, fallback.brand]),
        serialNumber: _firstNonBlank([serialNumber, fallback.serialNumber]),
        osVersion: _firstNonBlank([osVersion, fallback.osVersion]),
        appVersion: _firstNonBlank([appVersion, fallback.appVersion]),
        batteryLevel: batteryLevel ?? fallback.batteryLevel,
        deviceId: _firstNonBlank([deviceId, fallback.deviceId]),
      );

  Map<String, dynamic> toJson() => {
        if (imei != null) 'imei': imei,
        if (imei1 != null) 'imei1': imei1,
        if (imei2 != null) 'imei2': imei2,
        if (model != null) 'model': model,
        if (brand != null) 'brand': brand,
        if (serialNumber != null) 'serialNumber': serialNumber,
        if (osVersion != null) 'osVersion': osVersion,
        if (appVersion != null) 'appVersion': appVersion,
        if (batteryLevel != null) 'batteryLevel': batteryLevel,
        if (deviceId != null) 'deviceId': deviceId,
      };
}

class CustomerDetails {
  const CustomerDetails({this.id, this.name, this.phone});

  final String? id;
  final String? name;
  final String? phone;

  static CustomerDetails? fromJsonOrNull(
    Map<String, dynamic> json, {
    Map<String, dynamic> fallback = const {},
  }) {
    dynamic value(List<String> keys) => _pick(json, keys) ?? _pick(fallback, keys);
    final result = CustomerDetails(
      id: _text(value(const ['customerId', 'customer_id', 'id'])),
      name: _text(
        value(const ['name', 'fullName', 'full_name', 'customerName']),
      ),
      phone: _text(
        value(const ['phone', 'phoneNumber', 'phone_number', 'customerPhone']),
      ),
    );
    return result.id == null && result.name == null && result.phone == null
        ? null
        : result;
  }

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        if (name != null) 'name': name,
        if (phone != null) 'phone': phone,
      };
}

class LoanDetails {
  const LoanDetails({
    this.id,
    this.displayId,
    this.status,
    this.totalAmount,
    this.installmentAmount,
    this.installmentCount,
    this.paidInstallments,
    this.outstandingAmount,
    this.overdueAmount,
    this.nextDueDate,
  });

  final String? id;
  final String? displayId;
  final String? status;
  final num? totalAmount;
  final num? installmentAmount;
  final int? installmentCount;
  final int? paidInstallments;
  final num? outstandingAmount;
  final num? overdueAmount;
  final String? nextDueDate;

  String get reference => _firstNonBlank([displayId, id]) ?? '';

  static LoanDetails? fromJsonOrNull(
    Map<String, dynamic> json, {
    Map<String, dynamic> fallback = const {},
  }) {
    dynamic value(List<String> keys) => _pick(json, keys) ?? _pick(fallback, keys);
    final result = LoanDetails(
      id: _text(value(const ['loanId', 'loan_id', 'id'])),
      displayId: _text(
        value(const ['displayId', 'display_id', 'loanNumber', 'loan_number']),
      ),
      status: _text(value(const ['loanStatus', 'loan_status', 'status'])),
      totalAmount: _number(
        value(const [
          'totalAmount',
          'total_amount',
          'loanAmount',
          'loan_amount',
          'principalAmount',
        ]),
      ),
      installmentAmount: _number(
        value(const [
          'installmentAmount',
          'installment_amount',
          'monthlyInstallment',
          'monthly_installment',
          'emiAmount',
        ]),
      ),
      installmentCount: _integer(
        value(const [
          'installmentCount',
          'installment_count',
          'totalInstallments',
        ]),
      ),
      paidInstallments: _integer(
        value(const ['paidInstallments', 'paid_installments']),
      ),
      outstandingAmount: _number(
        value(const ['outstandingAmount', 'outstanding_amount', 'dueAmount']),
      ),
      overdueAmount: _number(
        value(const ['overdueAmount', 'overdue_amount']),
      ),
      nextDueDate: _text(
        value(const ['nextDueDate', 'next_due_date', 'dueDate']),
      ),
    );
    return result.toJson().isEmpty ? null : result;
  }

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        if (displayId != null) 'displayId': displayId,
        if (status != null) 'status': status,
        if (totalAmount != null) 'totalAmount': totalAmount,
        if (installmentAmount != null) 'installmentAmount': installmentAmount,
        if (installmentCount != null) 'installmentCount': installmentCount,
        if (paidInstallments != null) 'paidInstallments': paidInstallments,
        if (outstandingAmount != null)
          'outstandingAmount': outstandingAmount,
        if (overdueAmount != null) 'overdueAmount': overdueAmount,
        if (nextDueDate != null) 'nextDueDate': nextDueDate,
      };
}

class PaymentDetails {
  const PaymentDetails({
    this.status,
    this.paidAmount,
    this.outstandingAmount,
    this.overdueAmount,
    this.overdueInstallments,
    this.daysOverdue,
    this.nextDueDate,
    this.lastPayment,
  });

  final String? status;
  final num? paidAmount;
  final num? outstandingAmount;
  final num? overdueAmount;
  final int? overdueInstallments;
  final int? daysOverdue;
  final String? nextDueDate;
  final String? lastPayment;

  bool get isOverdue =>
      (overdueAmount ?? 0) > 0 ||
      (overdueInstallments ?? 0) > 0 ||
      (daysOverdue ?? 0) > 0 ||
      (status?.toLowerCase().contains('overdue') ?? false);

  static PaymentDetails? fromJsonOrNull(
    Map<String, dynamic> json, {
    Map<String, dynamic> fallback = const {},
  }) {
    dynamic value(List<String> keys) => _pick(json, keys) ?? _pick(fallback, keys);
    final result = PaymentDetails(
      status: _text(
        value(const ['paymentStatus', 'payment_status', 'status']),
      ),
      paidAmount: _number(value(const ['paidAmount', 'paid_amount'])),
      outstandingAmount: _number(
        value(const ['outstandingAmount', 'outstanding_amount', 'dueAmount']),
      ),
      overdueAmount: _number(
        value(const ['overdueAmount', 'overdue_amount']),
      ),
      overdueInstallments: _integer(
        value(const ['overdueInstallments', 'overdue_installments']),
      ),
      daysOverdue: _integer(value(const ['daysOverdue', 'days_overdue'])),
      nextDueDate: _text(
        value(const ['nextDueDate', 'next_due_date', 'dueDate']),
      ),
      lastPayment: _lastPaymentSummary(
        value(const ['lastPayment', 'last_payment']),
      ),
    );
    return result.toJson().isEmpty ? null : result;
  }

  Map<String, dynamic> toJson() => {
        if (status != null) 'status': status,
        if (paidAmount != null) 'paidAmount': paidAmount,
        if (outstandingAmount != null)
          'outstandingAmount': outstandingAmount,
        if (overdueAmount != null) 'overdueAmount': overdueAmount,
        if (overdueInstallments != null)
          'overdueInstallments': overdueInstallments,
        if (daysOverdue != null) 'daysOverdue': daysOverdue,
        if (nextDueDate != null) 'nextDueDate': nextDueDate,
        if (lastPayment != null) 'lastPayment': lastPayment,
      };
}

Map<String, dynamic> _asMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((key, value) => MapEntry(key.toString(), value));
  }
  return const {};
}

dynamic _pick(Map<String, dynamic> source, List<String> keys) {
  for (final key in keys) {
    if (source.containsKey(key) && source[key] != null) return source[key];
  }
  return null;
}

String? _text(dynamic value) {
  if (value == null) return null;
  final text = value.toString().trim();
  return text.isEmpty || text.toLowerCase() == 'null' ? null : text;
}

String? _firstNonBlank(Iterable<String?> values) {
  for (final value in values) {
    final text = _text(value);
    if (text != null) return text;
  }
  return null;
}

bool _boolean(dynamic value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  final normalized = value?.toString().trim().toLowerCase();
  return normalized == 'true' ||
      normalized == '1' ||
      normalized == 'locked' ||
      normalized == 'yes';
}

num? _number(dynamic value) {
  if (value is num) return value;
  if (value == null) return null;
  return num.tryParse(value.toString().replaceAll(RegExp(r'[^0-9.\-]'), ''));
}

int? _integer(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '');
}

String? _lastPaymentSummary(dynamic value) {
  final text = _text(value);
  if (value is! Map) return text;
  final payment = _asMap(value);
  final date = _text(
    _pick(payment, const ['paidAt', 'paid_at', 'date', 'paymentDate']),
  );
  final amount = _number(
    _pick(payment, const ['amount', 'paidAmount', 'paid_amount']),
  );
  if (date == null && amount == null) return null;
  if (date == null) return amount.toString();
  if (amount == null) return date;
  return '$amount on $date';
}

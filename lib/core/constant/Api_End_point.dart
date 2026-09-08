class ApiEndPoint {
  ApiEndPoint._();

  // ── Base URLs ───────────────────────────────────────────────
  static const String localBaseUrl = 'http://localhost:3001';
  static const String productionBaseUrl = 'https://api.smartpay.click';

  // Active base URL
  static const String baseUrl = productionBaseUrl;

  // ── API Version / Prefix ──────────────────────────────────
  static const String apiPrefix = '/apk'; // <-- Add this line

  // Helper method to add prefix
  static String _withPrefix(String endpoint) => '$apiPrefix$endpoint';

  // ── Auth ──────────────────────────────────────────────────
  static String get login => '$baseUrl${_withPrefix('/auth/login')}';
  static String get currentUser => '$baseUrl${_withPrefix('/auth/me')}';

  /// 1. Sales Person / Staff Dashboard
  static String salesDashboardSummary(String userId) =>
      '$baseUrl${_withPrefix('/dashboard/summary/$userId')}';

  /// 2. Customer Dashboard
  static String customerDashboardSummary(String userId) =>
      '$baseUrl${_withPrefix('/dashboard/customer-summary/$userId')}';

  // ── Lookup / Dropdown APIs ──────────────────────────────
  static String get shops => '$baseUrl${_withPrefix('/shops')}';
  static String get agents => '$baseUrl${_withPrefix('/agents')}';
  static String get managers => '$baseUrl${_withPrefix('/managers')}';
  static String get salesPersons => '$baseUrl${_withPrefix('/sales-persons')}';
  static String get products => '$baseUrl${_withPrefix('/products')}';
  static String get emiPlans => '$baseUrl${_withPrefix('/emi-plans')}';

  static String emiPlansByProduct(String productId) =>
      '$baseUrl${_withPrefix('/emi-plans/product/$productId')}';

  // ── EMI Quotation ────────────────────────────────────────
  static String emiQuotation(String emiPlanId) =>
      '$baseUrl${_withPrefix('/emi-plans/$emiPlanId/quotation')}';

  // ── Customer CRUD ────────────────────────────────────────
  static String get customers => '$baseUrl${_withPrefix('/customers')}';
  static String get myCustomerDetails =>
      '$baseUrl${_withPrefix('/customers/me/details')}';

  static String customerById(String id) =>
      '$baseUrl${_withPrefix('/customers/$id')}';

  static String customerDetails(String id) =>
      '$baseUrl${_withPrefix('/customers/$id/details')}';

  // ── Customer File Uploads ───────────────────────────────
  static String uploadCustomerPhoto(String customerId) =>
      '$baseUrl${_withPrefix('/customers/$customerId/photo')}';

  static String uploadCustomerDocument(String customerId) =>
      '$baseUrl${_withPrefix('/customers/$customerId/documents')}';

  static String deleteCustomerDocument(String customerId, String docId) =>
      '$baseUrl${_withPrefix('/customers/$customerId/documents/$docId')}';

  // ── Guarantor Document Upload ──────────────────────────
  static String uploadGuarantorDocument(
    String customerId,
    String guarantorId,
  ) =>
      '$baseUrl${_withPrefix('/customers/$customerId/guarantors/$guarantorId/document')}';

  // ── Loan Applications ──────────────────────────────────
  static String get loanApplications =>
      '$baseUrl${_withPrefix('/loan-applications')}';

  static String loanApplicationById(String id) =>
      '$baseUrl${_withPrefix('/loan-applications/$id')}';

  static String approveLoanApplication(String id) =>
      '$baseUrl${_withPrefix('/loan-applications/$id/approve')}';

  static String rejectLoanApplication(String id) =>
      '$baseUrl${_withPrefix('/loan-applications/$id/reject')}';

  // ── Asset URL Helper ──────────────────────────────────
  // ── Asset URL Helper ──────────────────────────────────
  static String assetUrl(String relativeUrl) {
    if (relativeUrl.isEmpty) return '';

    // যদি ইতিমধ্যে Full URL থাকে
    if (relativeUrl.startsWith('http://') ||
        relativeUrl.startsWith('https://')) {
      return relativeUrl;
    }

    // যদি URL /assets/ দিয়ে শুরু হয়
    if (relativeUrl.startsWith('/assets/')) {
      return '$baseUrl$relativeUrl';
    }

    // যদি URL assets/ দিয়ে শুরু হয়
    if (relativeUrl.startsWith('assets/')) {
      return '$baseUrl/$relativeUrl';
    }

    // যদি URL / দিয়ে শুরু হয়
    if (relativeUrl.startsWith('/')) {
      return '$baseUrl$relativeUrl';
    }

    // অন্যথায় baseUrl এর সাথে যোগ করুন
    return '$baseUrl/$relativeUrl';
  }

  // ── Customer Panel Specific Endpoints ────────────────
  static String get customerProfile =>
      '$baseUrl${_withPrefix('/customer/profile')}';
  static String get customerDashboard =>
      '$baseUrl${_withPrefix('/customer/dashboard')}';
  static String get customerLoans =>
      '$baseUrl${_withPrefix('/customer/loans')}';

  static String customerLoanById(String loanId) =>
      '$baseUrl${_withPrefix('/customer/loans/$loanId')}';

  static String get customerPayments =>
      '$baseUrl${_withPrefix('/customer/payments')}';
  static String get initiateCustomerPayment =>
      '$baseUrl${_withPrefix('/customer/payments/initiate')}';
  static String get submitBankPayment =>
      '$baseUrl${_withPrefix('/customer/payments/bank')}';
  static String get customerLoanApplications =>
      '$baseUrl${_withPrefix('/customer/loan-applications')}';

  static String customerLoanApplicationById(String id) =>
      '$baseUrl${_withPrefix('/customer/loan-applications/$id')}';

  static String get customerNotifications =>
      '$baseUrl${_withPrefix('/customer/notifications')}';
  static String get sellerNotifications =>
      '$baseUrl${_withPrefix('/notifications')}';

  /// Order Summary
  static String get loansSummary => '$baseUrl${_withPrefix('/loans/summary')}';

  /// Payment History
  static String get paymentsHistory => '$baseUrl${_withPrefix('/payments')}';
  static String get payInstallment =>
      '$baseUrl${_withPrefix('/customer/installment/pay')}';

  // New api

  // ── New APIs from PDF ─────────────────────────────────────────

  // ── NEW APIs from PDF ─────────────────────────────────────────

  // 1. Check Customer Eligibility (Fraud / Defaulter Check)
  static String checkCustomerEligibility({
    required String phone,
    required String idPassportNumber,
  }) =>
      '$baseUrl${_withPrefix('/customers/check-eligibility?phone=$phone&idPassportNumber=$idPassportNumber')}';

  // 2. Get Pending Applications List
  static String get pendingLoanApplications =>
      '$baseUrl${_withPrefix('/loan-applications?status=PENDING')}';

  // 3. Get Pending Applications Count
  static String get pendingCount =>
      '$baseUrl${_withPrefix('/loan-applications/pending-count')}';

  // 4. Get Approved Loan Details
  static String getLoanById(String id) =>
      '$baseUrl${_withPrefix('/loans/$id')}';
  // ─── Active Loan Details ───

  // ─── Payments (Staff/Collection) ───
  static String get collectPayment =>
      '$baseUrl${_withPrefix('/payments/collect')}';
  static String get assignedProducts => '$baseUrl${_withPrefix('/assigned-products')}';

  static String editCustomer(String id) => '$baseUrl${_withPrefix('/customers/$id')}';
  static String updatePaymentDate(String id) => '$baseUrl${_withPrefix('/customers/$id')}';

}

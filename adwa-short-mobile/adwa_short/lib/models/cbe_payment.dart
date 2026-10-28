class CbePaymentInitiateResult {
  const CbePaymentInitiateResult({
    required this.orderId,
    required this.itemType,
    this.itemId,
    required this.amountBirr,
    required this.currency,
    required this.status,
    required this.billReference,
    required this.checkoutUrl,
    required this.ussdCode,
    this.createdAt,
  });

  final String orderId;
  final String itemType;
  final int? itemId;
  final num amountBirr;
  final String currency;
  final String status;
  final String billReference;
  final String checkoutUrl;
  final String ussdCode;
  final DateTime? createdAt;

  factory CbePaymentInitiateResult.fromJson(Map<String, dynamic> json) {
    return CbePaymentInitiateResult(
      orderId: (json['order_id'] ?? '').toString(),
      itemType: (json['item_type'] ?? '').toString(),
      itemId: json['item_id'] is int
          ? json['item_id'] as int
          : int.tryParse(json['item_id']?.toString() ?? ''),
      amountBirr: (json['amount_birr'] as num?) ?? 0,
      currency: (json['currency'] ?? 'ETB').toString(),
      status: (json['status'] ?? 'pending').toString(),
      billReference: (json['bill_reference'] ?? '').toString(),
      checkoutUrl: (json['checkout_url'] ?? '').toString(),
      ussdCode: (json['ussd_code'] ?? '').toString(),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
    );
  }
}

class CbeOrderStatus {
  const CbeOrderStatus({
    required this.orderId,
    required this.itemType,
    this.itemId,
    required this.amountBirr,
    required this.currency,
    required this.status,
    this.cbeTransactionId,
    this.billReference,
    this.checkoutUrl,
    this.ussdCode,
    this.createdAt,
    this.processedAt,
  });

  final String orderId;
  final String itemType;
  final int? itemId;
  final num amountBirr;
  final String currency;
  final String status;
  final String? cbeTransactionId;
  final String? billReference;
  final String? checkoutUrl;
  final String? ussdCode;
  final DateTime? createdAt;
  final DateTime? processedAt;

  bool get isCompleted => status.toLowerCase() == 'completed';
  bool get isFailed => status.toLowerCase() == 'failed' || status.toLowerCase() == 'canceled';
  bool get isPending => status.toLowerCase() == 'pending';

  factory CbeOrderStatus.fromJson(Map<String, dynamic> json) {
    return CbeOrderStatus(
      orderId: (json['order_id'] ?? '').toString(),
      itemType: (json['item_type'] ?? '').toString(),
      itemId: json['item_id'] is int
          ? json['item_id'] as int
          : int.tryParse(json['item_id']?.toString() ?? ''),
      amountBirr: (json['amount_birr'] as num?) ?? 0,
      currency: (json['currency'] ?? 'ETB').toString(),
      status: (json['status'] ?? 'pending').toString(),
      cbeTransactionId: json['cbe_transaction_id']?.toString(),
      billReference: json['bill_reference']?.toString(),
      checkoutUrl: json['checkout_url']?.toString(),
      ussdCode: json['ussd_code']?.toString(),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
      processedAt: json['processed_at'] != null
          ? DateTime.tryParse(json['processed_at'].toString())
          : null,
    );
  }
}

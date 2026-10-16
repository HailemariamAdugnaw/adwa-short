class ApiException implements Exception {
  ApiException({
    required this.statusCode,
    required this.message,
    this.code,
    this.details,
    this.body,
    this.stackTrace,
  });

  final int statusCode;
  final String message;
  final String? code;
  final String? details;
  final dynamic body;
  final StackTrace? stackTrace;

  factory ApiException.fromResponse(int statusCode, Map<String, dynamic> json) {
    return ApiException(
      statusCode: statusCode,
      message: (json['message'] ?? json['detail'] ?? json['error'])?.toString() ??
          'Request failed with status $statusCode',
      code: (json['code'] ?? json['error_code'])?.toString(),
      details: json['details']?.toString(),
      body: json,
    );
  }

  factory ApiException.network(String message, {StackTrace? stackTrace}) {
    return ApiException(
      statusCode: -1,
      message: message,
      code: 'NETWORK_ERROR',
      stackTrace: stackTrace,
    );
  }

  factory ApiException.parse(String message) {
    return ApiException(
      statusCode: -2,
      message: message,
      code: 'PARSE_ERROR',
    );
  }

  bool get isUnauthorized => statusCode == 401;
  bool get isForbidden => statusCode == 403;
  bool get isNotFound => statusCode == 404;
  bool get isTooManyRequests => statusCode == 429;
  bool get isServer => statusCode >= 500;
  bool get isNetworkError => statusCode == -1;

  bool get isMaxDeviceLimit =>
      isForbidden && code == 'MAX_DEVICE_LIMIT_REACHED';

  @override
  String toString() {
    return 'ApiException($statusCode${code != null ? ', code=$code' : ''}): $message';
  }
}

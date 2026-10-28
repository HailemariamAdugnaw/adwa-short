class ActivePassStatus {
  const ActivePassStatus({
    required this.hasActivePass,
    this.purchaseId,
    this.passId,
    this.name,
    this.durationHours,
    this.priceBirr,
    this.startsAt,
    this.expiresAt,
    this.isActive = false,
    this.serverTime,
    this.remainingSeconds = 0,
  });

  final bool hasActivePass;
  final int? purchaseId;
  final int? passId;
  final String? name;
  final int? durationHours;
  final num? priceBirr;
  final DateTime? startsAt;
  final DateTime? expiresAt;
  final bool isActive;
  final DateTime? serverTime;
  final int remainingSeconds;

  factory ActivePassStatus.empty() {
    return const ActivePassStatus(hasActivePass: false);
  }

  factory ActivePassStatus.fromJson(Map<String, dynamic> json) {
    return ActivePassStatus(
      hasActivePass: json['has_active_pass'] == true,
      purchaseId: _asInt(json['purchase_id']),
      passId: _asInt(json['pass_id']),
      name: json['name']?.toString(),
      durationHours: _asInt(json['duration_hours']),
      priceBirr: _asNum(json['price_birr']),
      startsAt: _asDateTime(json['starts_at']),
      expiresAt: _asDateTime(json['expires_at']),
      isActive: json['is_active'] == true,
      serverTime: _asDateTime(json['server_time']),
      remainingSeconds: _asInt(json['remaining_seconds']) ?? 0,
    );
  }

  ActivePassStatus copyWith({
    bool? hasActivePass,
    int? purchaseId,
    int? passId,
    String? name,
    int? durationHours,
    num? priceBirr,
    DateTime? startsAt,
    DateTime? expiresAt,
    bool? isActive,
    DateTime? serverTime,
    int? remainingSeconds,
  }) {
    return ActivePassStatus(
      hasActivePass: hasActivePass ?? this.hasActivePass,
      purchaseId: purchaseId ?? this.purchaseId,
      passId: passId ?? this.passId,
      name: name ?? this.name,
      durationHours: durationHours ?? this.durationHours,
      priceBirr: priceBirr ?? this.priceBirr,
      startsAt: startsAt ?? this.startsAt,
      expiresAt: expiresAt ?? this.expiresAt,
      isActive: isActive ?? this.isActive,
      serverTime: serverTime ?? this.serverTime,
      remainingSeconds: remainingSeconds ?? this.remainingSeconds,
    );
  }

  String get formattedRemaining {
    if (remainingSeconds <= 0) return 'Expired';
    final d = remainingSeconds ~/ 86400;
    final h = (remainingSeconds % 86400) ~/ 3600;
    final m = (remainingSeconds % 3600) ~/ 60;
    final s = remainingSeconds % 60;
    if (d > 0) return '${d}d ${h}h ${m}m ${s}s';
    if (h > 0) return '${h}h ${m}m ${s}s';
    return '${m}m ${s}s';
  }

  String get formattedExpiresAt {
    if (expiresAt == null) return '';
    final local = expiresAt!.toLocal();
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final mStr = months[(local.month - 1).clamp(0, 11)];
    final h = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final ampm = local.hour >= 12 ? 'PM' : 'AM';
    final min = local.minute.toString().padLeft(2, '0');
    return '$mStr ${local.day}, ${local.year} $h:$min $ampm';
  }
}

class ActiveSubscriptionStatus {
  const ActiveSubscriptionStatus({
    required this.hasActiveSubscription,
    this.subscriptionId,
    this.planId,
    this.planName,
    this.billingCycle,
    this.priceBirr,
    this.status,
    this.startedAt,
    this.nextBillingAt,
    this.serverTime,
    this.remainingSeconds = 0,
  });

  final bool hasActiveSubscription;
  final int? subscriptionId;
  final int? planId;
  final String? planName;
  final String? billingCycle;
  final num? priceBirr;
  final String? status;
  final DateTime? startedAt;
  final DateTime? nextBillingAt;
  final DateTime? serverTime;
  final int remainingSeconds;

  factory ActiveSubscriptionStatus.empty() {
    return const ActiveSubscriptionStatus(hasActiveSubscription: false);
  }

  factory ActiveSubscriptionStatus.fromJson(Map<String, dynamic> json) {
    return ActiveSubscriptionStatus(
      hasActiveSubscription: json['has_active_subscription'] == true,
      subscriptionId: _asInt(json['subscription_id']),
      planId: _asInt(json['plan_id']),
      planName: json['plan_name']?.toString(),
      billingCycle: json['billing_cycle']?.toString(),
      priceBirr: _asNum(json['price_birr']),
      status: json['status']?.toString(),
      startedAt: _asDateTime(json['started_at']),
      nextBillingAt: _asDateTime(json['next_billing_at']),
      serverTime: _asDateTime(json['server_time']),
      remainingSeconds: _asInt(json['remaining_seconds']) ?? 0,
    );
  }

  ActiveSubscriptionStatus copyWith({
    bool? hasActiveSubscription,
    int? subscriptionId,
    int? planId,
    String? planName,
    String? billingCycle,
    num? priceBirr,
    String? status,
    DateTime? startedAt,
    DateTime? nextBillingAt,
    DateTime? serverTime,
    int? remainingSeconds,
  }) {
    return ActiveSubscriptionStatus(
      hasActiveSubscription: hasActiveSubscription ?? this.hasActiveSubscription,
      subscriptionId: subscriptionId ?? this.subscriptionId,
      planId: planId ?? this.planId,
      planName: planName ?? this.planName,
      billingCycle: billingCycle ?? this.billingCycle,
      priceBirr: priceBirr ?? this.priceBirr,
      status: status ?? this.status,
      startedAt: startedAt ?? this.startedAt,
      nextBillingAt: nextBillingAt ?? this.nextBillingAt,
      serverTime: serverTime ?? this.serverTime,
      remainingSeconds: remainingSeconds ?? this.remainingSeconds,
    );
  }

  String get formattedRemaining {
    if (remainingSeconds <= 0) return 'Expired';
    final d = remainingSeconds ~/ 86400;
    final h = (remainingSeconds % 86400) ~/ 3600;
    final m = (remainingSeconds % 3600) ~/ 60;
    final s = remainingSeconds % 60;
    if (d > 0) return '${d}d ${h}h ${m}m ${s}s';
    if (h > 0) return '${h}h ${m}m ${s}s';
    return '${m}m ${s}s';
  }

  String get formattedExpiresAt {
    if (nextBillingAt == null) return '';
    final local = nextBillingAt!.toLocal();
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final mStr = months[(local.month - 1).clamp(0, 11)];
    final h = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final ampm = local.hour >= 12 ? 'PM' : 'AM';
    final min = local.minute.toString().padLeft(2, '0');
    return '$mStr ${local.day}, ${local.year} $h:$min $ampm';
  }
}

class UserAccessDashboard {
  const UserAccessDashboard({
    required this.serverTime,
    required this.activePass,
    required this.activeSubscription,
  });

  final DateTime serverTime;
  final ActivePassStatus activePass;
  final ActiveSubscriptionStatus activeSubscription;

  factory UserAccessDashboard.fromJson(Map<String, dynamic> json) {
    final sTime = _asDateTime(json['server_time']) ?? DateTime.now().toUtc();
    return UserAccessDashboard(
      serverTime: sTime,
      activePass: json['active_pass'] is Map<String, dynamic>
          ? ActivePassStatus.fromJson(json['active_pass'] as Map<String, dynamic>)
          : ActivePassStatus.empty(),
      activeSubscription: json['active_subscription'] is Map<String, dynamic>
          ? ActiveSubscriptionStatus.fromJson(json['active_subscription'] as Map<String, dynamic>)
          : ActiveSubscriptionStatus.empty(),
    );
  }
}

int? _asInt(dynamic v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v);
  return null;
}

num? _asNum(dynamic v) {
  if (v is num) return v;
  if (v is String) return num.tryParse(v);
  return null;
}

DateTime? _asDateTime(dynamic v) {
  if (v == null) return null;
  if (v is DateTime) return v;
  if (v is String && v.isNotEmpty) return DateTime.tryParse(v);
  return null;
}

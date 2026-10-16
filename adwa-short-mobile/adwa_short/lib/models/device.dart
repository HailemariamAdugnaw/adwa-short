class Device {
  Device({
    required this.id,
    required this.name,
    required this.platform,
    required this.lastActiveAt,
    required this.isCurrent,
    this.location,
  });

  final String id;
  final String name;
  final String platform;
  final DateTime lastActiveAt;
  final bool isCurrent;
  final String? location;

  factory Device.fromJson(Map<String, dynamic> json) {
    return Device(
      id: json['id']?.toString() ?? '',
      name: (json['name'] ?? json['device_name'])?.toString() ??
          'Unknown device',
      platform: (json['platform'] ?? json['device_type'])?.toString() ??
          'unknown',
      lastActiveAt: (json['last_active_at'] ?? json['last_seen']) != null
          ? DateTime.tryParse(
                  (json['last_active_at'] ?? json['last_seen']).toString()) ??
              DateTime.now()
          : DateTime.now(),
      isCurrent: json['is_current'] == true || json['is_active'] == true,
      location: json['location']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'platform': platform,
        'last_active_at': lastActiveAt.toIso8601String(),
        'is_current': isCurrent,
        'location': location,
      };
}

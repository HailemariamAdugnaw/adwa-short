import 'wallet.dart';

class User {
  User({
    required this.id,
    required this.phone,
    this.email,
    required this.displayName,
    this.avatarUrl,
    this.wallet,
  });

  final String id;
  final String phone;
  final String? email;
  final String displayName;
  final String? avatarUrl;
  final Wallet? wallet;

  factory User.fromJson(Map<String, dynamic> json) {
    final rawWallet = json['wallet'];
    return User(
      id: (json['id'] ?? json['user_id'])?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      email: json['email']?.toString(),
      displayName: json['display_name']?.toString() ?? 'User',
      avatarUrl: json['avatar_url']?.toString(),
      wallet: rawWallet is Map<String, dynamic>
          ? Wallet.fromJson(rawWallet)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'phone': phone,
        'email': email,
        'display_name': displayName,
        'avatar_url': avatarUrl,
        'wallet': wallet?.toJson(),
      };

  User copyWith({
    String? id,
    String? phone,
    String? email,
    String? displayName,
    String? avatarUrl,
    Wallet? wallet,
  }) =>
      User(
        id: id ?? this.id,
        phone: phone ?? this.phone,
        email: email ?? this.email,
        displayName: displayName ?? this.displayName,
        avatarUrl: avatarUrl ?? this.avatarUrl,
        wallet: wallet ?? this.wallet,
      );
}

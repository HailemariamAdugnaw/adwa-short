class Wallet {
  Wallet({
    required this.balanceBirr,
    required this.balanceCoins,
    this.recentTransactions = const [],
  });

  final num balanceBirr;
  final num balanceCoins;
  final List<Transaction> recentTransactions;

  factory Wallet.fromJson(Map<String, dynamic> json) {
    final rawTx = json['recent_transactions'];
    List<Transaction> txList;
    if (rawTx is List) {
      txList = rawTx
          .whereType<Map<String, dynamic>>()
          .map((e) => Transaction.fromJson(e))
          .toList();
    } else {
      txList = const [];
    }
    return Wallet(
      balanceBirr: (json['balance_birr'] is num
          ? json['balance_birr'] as num
          : (num.tryParse(json['balance_birr']?.toString() ?? '') ?? 0)),
      balanceCoins: (json['balance_coins'] is num
          ? json['balance_coins'] as num
          : (num.tryParse(json['balance_coins']?.toString() ?? '') ?? 0)),
      recentTransactions: txList,
    );
  }

  Map<String, dynamic> toJson() => {
        'balance_birr': balanceBirr,
        'balance_coins': balanceCoins,
        'recent_transactions':
            recentTransactions.map((e) => e.toJson()).toList(),
      };

  Wallet copyWith({
    num? balanceBirr,
    num? balanceCoins,
    List<Transaction>? recentTransactions,
  }) =>
      Wallet(
        balanceBirr: balanceBirr ?? this.balanceBirr,
        balanceCoins: balanceCoins ?? this.balanceCoins,
        recentTransactions: recentTransactions ?? this.recentTransactions,
      );
}

class Transaction {
  Transaction({
    required this.id,
    required this.type,
    required this.amount,
    required this.currency,
    required this.description,
    required this.createdAt,
  });

  final String id;
  final String type;
  final num amount;
  final String currency;
  final String description;
  final DateTime createdAt;

  factory Transaction.fromJson(Map<String, dynamic> json) {
    final num amountBirr =
        (json['amount_birr'] is num ? json['amount_birr'] as num : 0);
    final num amountCoins =
        (json['amount_coins'] is num ? json['amount_coins'] as num : 0);
    final num amount = (json['amount'] is num ? json['amount'] as num : 0);
    final String currency =
        json['currency']?.toString() ?? (amountCoins != 0 ? 'coins' : 'birr');
    final num effectiveAmount = amount != 0 ? amount : amountBirr;
    return Transaction(
      id: json['id']?.toString() ?? '',
      type: json['type']?.toString() ?? 'unknown',
      amount: effectiveAmount != 0 ? effectiveAmount : amountCoins,
      currency: currency,
      description: json['description']?.toString() ??
          json['reference']?.toString() ??
          '',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ??
              DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'amount': amount,
        'currency': currency,
        'description': description,
        'created_at': createdAt.toIso8601String(),
      };

  bool get isCredit => amount > 0;
}

import 'dart:math';

/// A single ledger entry in the customer's CleanCredit balance.
class WalletTransaction {
  final String id;
  final String title;
  final String description;
  final int amount; // positive = credit, negative = debit
  final DateTime date;
  final String? referenceId;

  const WalletTransaction({
    required this.id,
    required this.title,
    required this.description,
    required this.amount,
    required this.date,
    this.referenceId,
  });

  bool get isCredit => amount > 0;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'amount': amount,
        'date': date.toIso8601String(),
        'referenceId': referenceId,
      };

  factory WalletTransaction.fromJson(Map<String, dynamic> json) =>
      WalletTransaction(
        id: json['id'] as String,
        title: json['title'] as String,
        description: json['description'] as String,
        amount: json['amount'] as int,
        date: DateTime.parse(json['date'] as String),
        referenceId: json['referenceId'] as String?,
      );
}

/// The customer's CleanCredit wallet balance and transaction ledger.
class WalletState {
  final int balance;
  final List<WalletTransaction> transactions;

  const WalletState({
    this.balance = 0,
    this.transactions = const [],
  });

  /// 40% margin protection cap: at most 40% of the service total can be covered
  /// by CleanCredit, ensuring CleanCruisers operates at positive unit margin on every wash.
  int maxDiscountForTotal(int total) => (total * 0.40).floor();

  /// Usable credit for a given booking total based on available balance and the 40% cap.
  int usableCredit(int total) {
    if (balance <= 0 || total <= 0) return 0;
    return min(balance, maxDiscountForTotal(total));
  }

  WalletState copyWith({
    int? balance,
    List<WalletTransaction>? transactions,
  }) =>
      WalletState(
        balance: balance ?? this.balance,
        transactions: transactions ?? this.transactions,
      );
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

class PaymentModel extends Equatable {
  final String id;
  final String uid;
  final int amount;
  final String currency;
  final String method; // 'mbank', 'card', 'google_play'
  final String status; // 'pending', 'confirmed', 'failed'
  final String? providerTxnId;
  final String? productId; // test_id or subscription_id
  final String productType; // 'mock_test', 'subscription'
  final DateTime createdAt;
  final DateTime? confirmedAt;

  const PaymentModel({
    required this.id,
    required this.uid,
    required this.amount,
    this.currency = 'KGS',
    required this.method,
    required this.status,
    this.providerTxnId,
    this.productId,
    required this.productType,
    required this.createdAt,
    this.confirmedAt,
  });

  factory PaymentModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return PaymentModel(
      id: doc.id,
      uid: data['uid'] ?? '',
      amount: data['amount'] ?? 0,
      currency: data['currency'] ?? 'KGS',
      method: data['method'] ?? '',
      status: data['status'] ?? 'pending',
      providerTxnId: data['provider_txn_id'],
      productId: data['product_id'],
      productType: data['product_type'] ?? 'mock_test',
      createdAt: (data['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      confirmedAt: (data['confirmed_at'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'uid': uid,
      'amount': amount,
      'currency': currency,
      'method': method,
      'status': status,
      'provider_txn_id': providerTxnId,
      'product_id': productId,
      'product_type': productType,
      'created_at': Timestamp.fromDate(createdAt),
      'confirmed_at': confirmedAt != null ? Timestamp.fromDate(confirmedAt!) : null,
    };
  }

  bool get isConfirmed => status == 'confirmed';
  bool get isPending => status == 'pending';
  bool get isFailed => status == 'failed';

  @override
  List<Object?> get props => [
        id,
        uid,
        amount,
        currency,
        method,
        status,
        providerTxnId,
        productId,
        productType,
        createdAt,
        confirmedAt,
      ];
}

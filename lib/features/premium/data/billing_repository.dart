import 'package:dio/dio.dart';
import 'package:talk_it_out/core/api/api_guard.dart';
import 'package:talk_it_out/core/api/endpoints.dart';
import 'package:talk_it_out/core/errors/repository_exception.dart';
import 'package:talk_it_out/core/mock/mock_controls.dart';
import 'package:talk_it_out/core/mock/run_mock.dart';
import 'package:talk_it_out/features/premium/data/premium_models.dart';

/// Premium state and Premium-only data (`API.md` 71).
abstract class BillingRepository {
  Future<Entitlements> entitlements();

  /// After a store purchase: asks the server to re-check the store now.
  Future<Entitlements> sync();

  /// Group Insights for a group the caller leads. Throws
  /// `RepositoryException(code: 'premium_required')` without Premium.
  Future<GroupInsights> insights(String groupId);

  /// Web payments (`API.md` 75): whether Razorpay is set up on the server.
  Future<bool> razorpayEnabled();

  /// Starts a ₹99 monthly Razorpay subscription for Checkout.
  Future<RazorpayCheckout> startRazorpay();

  /// Sends Checkout's signed result; the server checks it with Razorpay.
  Future<Entitlements> verifyRazorpay(RazorpayPaid paid);

  /// Stops a web subscription renewing (access lasts the paid month).
  Future<Entitlements> cancelWebSubscription();
}

/// What Razorpay Checkout needs to open.
class RazorpayCheckout {
  const RazorpayCheckout({
    required this.keyId,
    required this.subscriptionId,
    required this.name,
    required this.email,
  });

  final String keyId;
  final String subscriptionId;
  final String name;
  final String email;
}

/// Checkout's success result, signed by Razorpay.
class RazorpayPaid {
  const RazorpayPaid({
    required this.paymentId,
    required this.subscriptionId,
    required this.signature,
  });

  final String paymentId;
  final String subscriptionId;
  final String signature;
}

class ApiBillingRepository implements BillingRepository {
  ApiBillingRepository(this._dio);

  final Dio _dio;

  @override
  Future<Entitlements> entitlements() => guardApi(() async {
    final res = await _dio.get(Endpoints.billingEntitlements);
    return Entitlements.fromJson(res.data as Map<String, dynamic>);
  });

  @override
  Future<Entitlements> sync() => guardApi(() async {
    final res = await _dio.post(Endpoints.billingSync);
    return Entitlements.fromJson(res.data as Map<String, dynamic>);
  });

  @override
  Future<GroupInsights> insights(String groupId) => guardApi(() async {
    final res = await _dio.get(
      Endpoints.groupInsights(groupId),
      queryParameters: {
        'tz_offset_minutes': DateTime.now().timeZoneOffset.inMinutes,
      },
    );
    return GroupInsights.fromJson(res.data as Map<String, dynamic>);
  });

  @override
  Future<bool> razorpayEnabled() => guardApi(() async {
    final res = await _dio.get(Endpoints.billingRazorpay);
    return (res.data as Map<String, dynamic>)['enabled'] == true;
  });

  @override
  Future<RazorpayCheckout> startRazorpay() => guardApi(() async {
    final res = await _dio.post(Endpoints.billingRazorpaySubscription);
    final data = res.data as Map<String, dynamic>;
    return RazorpayCheckout(
      keyId: '${data['key_id'] ?? ''}',
      subscriptionId: '${data['subscription_id'] ?? ''}',
      name: '${data['name'] ?? ''}',
      email: '${data['email'] ?? ''}',
    );
  });

  @override
  Future<Entitlements> verifyRazorpay(RazorpayPaid paid) => guardApi(() async {
    final res = await _dio.post(
      Endpoints.billingRazorpayVerify,
      data: {
        'razorpay_payment_id': paid.paymentId,
        'razorpay_subscription_id': paid.subscriptionId,
        'razorpay_signature': paid.signature,
      },
    );
    return Entitlements.fromJson(res.data as Map<String, dynamic>);
  });

  @override
  Future<Entitlements> cancelWebSubscription() => guardApi(() async {
    final res = await _dio.post(Endpoints.billingRazorpayCancel);
    return Entitlements.fromJson(res.data as Map<String, dynamic>);
  });
}

/// The demo: everyone starts on Free; "subscribing" succeeds at once.
class MockBillingRepository implements BillingRepository {
  MockBillingRepository(this._controls);

  final MockControls _controls;
  var _premium = false;

  /// Used by the demo store when someone subscribes.
  void grant() => _premium = true;

  @override
  Future<Entitlements> entitlements() => runMock(
    _controls,
    () => _premium
        ? Entitlements(
            premium: true,
            status: 'active',
            provider: 'manual',
            expiresAt: DateTime.now().add(const Duration(days: 30)),
            willRenew: true,
          )
        : Entitlements.free,
  );

  @override
  Future<Entitlements> sync() => entitlements();

  // The demo has no web payments (its store subscribes at once).
  @override
  Future<bool> razorpayEnabled() async => false;

  @override
  Future<RazorpayCheckout> startRazorpay() => runMock(
    _controls,
    () => throw const RepositoryException(
      code: 'billing_unconfigured',
      message: 'Web payments are not set up in the demo.',
    ),
  );

  @override
  Future<Entitlements> verifyRazorpay(RazorpayPaid paid) => entitlements();

  @override
  Future<Entitlements> cancelWebSubscription() => runMock(_controls, () {
    _premium = false;
    return Entitlements.free;
  });

  @override
  Future<GroupInsights> insights(String groupId) => runMock(_controls, () {
    // Like the server: Premium first (402 premium_required).
    if (!_premium) {
      throw const RepositoryException(
        code: 'premium_required',
        message: 'Group Insights are part of Premium.',
      );
    }
    final today = DateTime.now();
    const counts = [2, 5, 3, 0, 4, 7, 6, 3, 1, 5, 8, 4, 6, 9];
    return GroupInsights(
      windowDays: 14,
      memberCount: 6,
      breakdownsAvailable: true,
      messages: counts.fold(0, (a, b) => a + b),
      daily: [
        for (var i = 0; i < 14; i++)
          DayCount(
            DateTime(today.year, today.month, today.day - 13 + i),
            counts[i],
          ),
      ],
      pending: 2,
      accepted: 31,
      rejected: 3,
      reviewMedianMinutes: 18,
      participants: 4,
      anonymousMessages: 11,
      busiestHours: const [(10, 14), (16, 11), (21, 7)],
      topWords: const [
        ('deadline', 9),
        ('dashboard', 7),
        ('testing', 6),
        ('handover', 4),
        ('meetings', 3),
      ],
    );
  });
}

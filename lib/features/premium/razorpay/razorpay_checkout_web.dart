import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:talk_it_out/features/premium/data/billing_repository.dart';
import 'package:web/web.dart' as web;

/// The web build opens Razorpay Checkout (API.md 75).
const razorpayCheckoutSupported = true;

const _scriptUrl = 'https://checkout.razorpay.com/v1/checkout.js';

@JS('Razorpay')
extension type _Razorpay._(JSObject _) implements JSObject {
  external factory _Razorpay(JSObject options);
  external void open();
}

Future<void>? _loading;

/// Loads Razorpay's script once, when someone first pays.
Future<void> _loadScript() => _loading ??= () {
  final done = Completer<void>();
  final script = web.HTMLScriptElement()
    ..src = _scriptUrl
    ..async = true;
  script.onload = ((web.Event _) => done.complete()).toJS;
  script.onerror = ((web.Event _) {
    _loading = null;
    if (!done.isCompleted) {
      done.completeError(StateError('Razorpay Checkout did not load.'));
    }
  }).toJS;
  web.document.head!.append(script);
  return done.future;
}();

JSObject _object(Map<String, JSAny?> fields) {
  final o = JSObject();
  fields.forEach((key, value) => o[key] = value);
  return o;
}

/// Opens Checkout for [checkout]; completes with the signed result, or null
/// when the person closes it. Card and UPI details stay with Razorpay.
Future<RazorpayPaid?> openRazorpayCheckout(RazorpayCheckout checkout) async {
  await _loadScript();
  final result = Completer<RazorpayPaid?>();
  String field(JSObject r, String name) => (r[name] as JSString?)?.toDart ?? '';

  final options = _object({
    'key': checkout.keyId.toJS,
    'subscription_id': checkout.subscriptionId.toJS,
    'name': 'Talk It Out'.toJS,
    'description': 'Premium · ₹99 a month'.toJS,
    'prefill': _object({
      'name': checkout.name.toJS,
      'email': checkout.email.toJS,
    }),
    'theme': _object({'color': '#0A0A0A'.toJS}),
    'handler': ((JSObject response) {
      if (result.isCompleted) return;
      result.complete(
        RazorpayPaid(
          paymentId: field(response, 'razorpay_payment_id'),
          subscriptionId: field(response, 'razorpay_subscription_id'),
          signature: field(response, 'razorpay_signature'),
        ),
      );
    }).toJS,
    'modal': _object({
      'ondismiss': (() {
        if (!result.isCompleted) result.complete(null);
      }).toJS,
    }),
  });
  _Razorpay(options).open();
  return result.future;
}

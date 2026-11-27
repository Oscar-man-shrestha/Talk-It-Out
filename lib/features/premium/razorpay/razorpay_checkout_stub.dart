import 'package:talk_it_out/features/premium/data/billing_repository.dart';

/// Only the web build opens Razorpay Checkout.
const razorpayCheckoutSupported = false;

/// Opens Checkout; null when the person closes it without paying.
Future<RazorpayPaid?> openRazorpayCheckout(RazorpayCheckout checkout) =>
    throw UnsupportedError('Razorpay Checkout runs on the web only.');

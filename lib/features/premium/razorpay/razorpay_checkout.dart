// Razorpay Checkout on the web; unsupported elsewhere (phones use the
// App Store / Google Play).
export 'razorpay_checkout_stub.dart'
    if (dart.library.js_interop) 'razorpay_checkout_web.dart';

import 'package:flutter/widgets.dart';
import 'package:google_sign_in_web/web_only.dart' as web;

/// Google requires its own rendered button on the web (Google Identity
/// Services). Sign-ins from it arrive on GoogleSignIn.authenticationEvents.
Widget? renderGoogleButton() => web.renderButton(
  configuration: web.GSIButtonConfiguration(
    type: web.GSIButtonType.standard,
    theme: web.GSIButtonTheme.outline,
    size: web.GSIButtonSize.large,
    text: web.GSIButtonText.continueWith,
    shape: web.GSIButtonShape.rectangular,
    minimumWidth: 380,
  ),
);

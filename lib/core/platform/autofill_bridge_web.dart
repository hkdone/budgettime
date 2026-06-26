import 'dart:js_interop';
import 'dart:js_interop_unsafe';

@JS('btAutofillCredentials')
external JSObject? get _btAutofillCredentials;

@JS('btAutofillCredentials')
external set btAutofillCredentials(JSObject? value);

/// Lit les identifiants remplis par un gestionnaire de mots de passe
/// dans le formulaire HTML de secours (`web/index.html`).
class AutofillBridge {
  static ({String username, String password})? peek() {
    final creds = _btAutofillCredentials;
    if (creds == null) return null;

    final username = (creds['username'] as JSString?)?.toDart ?? '';
    final password = (creds['password'] as JSString?)?.toDart ?? '';
    if (username.isEmpty && password.isEmpty) return null;

    return (username: username, password: password);
  }

  static void clear() {
    btAutofillCredentials = null;
  }
}

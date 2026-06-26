// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

/// Champs HTML natifs pour Proton Pass / Bitwarden (Flutter Web ne reçoit pas
/// l'injection des extensions sur ses inputs internes).
class WebLoginInputs {
  WebLoginInputs._();

  static bool _registered = false;
  static html.InputElement? email;
  static html.InputElement? password;
  static void Function()? onSubmit;

  static String get emailValue => email?.value ?? '';
  static String get passwordValue => password?.value ?? '';

  static void focusEmail() => email?.focus();

  static void register() {
    if (_registered) return;
    _registered = true;

    ui_web.platformViewRegistry.registerViewFactory(
      'bt-login-form',
      (int viewId) {
        final form = html.FormElement()
          ..id = 'bt-login-form'
          ..autocomplete = 'on'
          ..method = 'post'
          ..action = '/login'
          ..className = 'bt-login-form';

        email = html.InputElement()
          ..id = 'username'
          ..name = 'username'
          ..type = 'email'
          ..autocomplete = 'username'
          ..placeholder = 'Email'
          ..className = 'bt-login-input';

        password = html.InputElement()
          ..id = 'password'
          ..name = 'password'
          ..type = 'password'
          ..autocomplete = 'current-password'
          ..placeholder = 'Mot de passe'
          ..className = 'bt-login-input';

        email!.addEventListener('keydown', (event) {
          final keyEvent = event as html.KeyboardEvent;
          if (keyEvent.key == 'Enter') {
            event.preventDefault();
            password?.focus();
          }
        });

        password!.addEventListener('keydown', (event) {
          final keyEvent = event as html.KeyboardEvent;
          if (keyEvent.key == 'Enter') {
            event.preventDefault();
            onSubmit?.call();
          }
        });

        form
          ..append(email!)
          ..append(password!)
          ..onSubmit.listen((event) {
            event.preventDefault();
            onSubmit?.call();
          });

        return form;
      },
    );
  }
}

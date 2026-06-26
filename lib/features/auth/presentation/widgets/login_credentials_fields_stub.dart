import 'package:flutter/material.dart';

class LoginCredentialsFields extends StatelessWidget {
  const LoginCredentialsFields({
    super.key,
    required this.emailController,
    required this.passwordController,
    required this.emailFocusNode,
    required this.passwordFocusNode,
    required this.onEmailSubmitted,
    required this.onPasswordSubmitted,
    required this.emailValidator,
    required this.passwordValidator,
    required this.onSubmit,
  });

  final TextEditingController emailController;
  final TextEditingController passwordController;
  final FocusNode emailFocusNode;
  final FocusNode passwordFocusNode;
  final VoidCallback onEmailSubmitted;
  final VoidCallback onPasswordSubmitted;
  final FormFieldValidator<String> emailValidator;
  final FormFieldValidator<String> passwordValidator;
  final Future<void> Function() onSubmit;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          controller: emailController,
          focusNode: emailFocusNode,
          decoration: const InputDecoration(
            labelText: 'Email',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.email),
          ),
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          autofillHints: const [
            AutofillHints.username,
            AutofillHints.email,
          ],
          onFieldSubmitted: (_) => onEmailSubmitted(),
          validator: emailValidator,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: passwordController,
          focusNode: passwordFocusNode,
          decoration: const InputDecoration(
            labelText: 'Mot de passe',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.lock),
          ),
          obscureText: true,
          enableSuggestions: false,
          autocorrect: false,
          textInputAction: TextInputAction.done,
          autofillHints: const [AutofillHints.password],
          onFieldSubmitted: (_) => onPasswordSubmitted(),
          validator: passwordValidator,
        ),
      ],
    );
  }
}

String readLoginEmail(TextEditingController controller) => controller.text;

String readLoginPassword(TextEditingController controller) => controller.text;

void focusLoginEmail(FocusNode focusNode) => focusNode.requestFocus();

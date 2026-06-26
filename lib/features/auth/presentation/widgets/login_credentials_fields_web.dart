import 'package:flutter/material.dart';
import '../../../../core/platform/web_login_inputs_web.dart';

class LoginCredentialsFields extends StatefulWidget {
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
  State<LoginCredentialsFields> createState() => _LoginCredentialsFieldsState();
}

class _LoginCredentialsFieldsState extends State<LoginCredentialsFields> {
  @override
  void initState() {
    super.initState();
    WebLoginInputs.onSubmit = () {
      widget.onSubmit();
    };
  }

  @override
  void didUpdateWidget(covariant LoginCredentialsFields oldWidget) {
    super.didUpdateWidget(oldWidget);
    WebLoginInputs.onSubmit = () {
      widget.onSubmit();
    };
  }

  @override
  void dispose() {
    WebLoginInputs.onSubmit = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 128,
      child: HtmlElementView(viewType: 'bt-login-form'),
    );
  }
}

String readLoginEmail(TextEditingController controller) =>
    WebLoginInputs.emailValue;

String readLoginPassword(TextEditingController controller) =>
    WebLoginInputs.passwordValue;

void focusLoginEmail(FocusNode focusNode) => WebLoginInputs.focusEmail();

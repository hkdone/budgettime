import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/services/database_service.dart';
import '../../../core/utils/responsive_breakpoints.dart';
import 'auth_controller.dart';
import 'widgets/login_credentials_fields.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _emailFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      focusLoginEmail(_emailFocusNode);
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Veuillez entrer votre email';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Veuillez entrer votre mot de passe';
    }
    return null;
  }

  Future<void> _submit() async {
    if (!kIsWeb) {
      if (!_formKey.currentState!.validate()) return;
    } else {
      final emailError = _validateEmail(readLoginEmail(_emailController));
      final passwordError = _validatePassword(
        readLoginPassword(_passwordController),
      );
      if (emailError != null || passwordError != null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(emailError ?? passwordError!),
          ),
        );
        return;
      }
    }

    await ref.read(authControllerProvider.notifier).signIn(
          readLoginEmail(_emailController),
          readLoginPassword(_passwordController),
        );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authControllerProvider, (previous, next) {
      if (next.hasError) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: ${next.error}')));
      } else if (previous?.isLoading == true &&
          !next.isLoading &&
          !next.hasError) {
        context.go('/');
      }
    });

    final authState = ref.watch(authControllerProvider);
    final isLoading = authState.isLoading;

    final credentialsFields = LoginCredentialsFields(
      emailController: _emailController,
      passwordController: _passwordController,
      emailFocusNode: _emailFocusNode,
      passwordFocusNode: _passwordFocusNode,
      onEmailSubmitted: () =>
          FocusScope.of(context).requestFocus(_passwordFocusNode),
      onPasswordSubmitted: _submit,
      emailValidator: _validateEmail,
      passwordValidator: _validatePassword,
      onSubmit: _submit,
    );

    return Scaffold(
      body: SafeArea(
        child: context.isExpanded
            ? Row(
                children: [
                  Expanded(
                    child: Container(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      padding: const EdgeInsets.all(48),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Image.asset('assets/logo.png', height: 120),
                          const SizedBox(height: 24),
                          Text(
                            'BudgetTime',
                            style: Theme.of(context)
                                .textTheme
                                .headlineLarge
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Gérez votre budget familial simplement.',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(48),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                            maxWidth: Breakpoints.authMaxWidth,
                          ),
                          child: _buildLoginForm(
                            context,
                            credentialsFields,
                            isLoading,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              )
            : Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24.0),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: Breakpoints.authMaxWidth,
                    ),
                    child: _buildLoginForm(
                      context,
                      credentialsFields,
                      isLoading,
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildLoginForm(
    BuildContext context,
    Widget credentialsFields,
    bool isLoading,
  ) {
    return kIsWeb
        ? Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!context.isExpanded) _buildHeader(context),
              credentialsFields,
              const SizedBox(height: 24),
              _buildActions(context, isLoading),
            ],
          )
        : Form(
            key: _formKey,
            child: AutofillGroup(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (!context.isExpanded) _buildHeader(context),
                  credentialsFields,
                  const SizedBox(height: 24),
                  _buildActions(context, isLoading),
                ],
              ),
            ),
          );
  }

  Widget _buildHeader(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Image.asset('assets/logo.png', height: 100),
        const SizedBox(height: 16),
        Text(
          'BudgetTime',
          style: Theme.of(context).textTheme.headlineMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildActions(BuildContext context, bool isLoading) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton(
          onPressed: isLoading ? null : _submit,
          child: isLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Se connecter'),
        ),
        const SizedBox(height: 16),
        TextButton(
          onPressed: () async {
            final dbService = ref.read(databaseServiceProvider);
            final baseUrl = dbService.pb.baseURL;
            final adminUrl = baseUrl.endsWith('/')
                ? '${baseUrl}_/'
                : '$baseUrl/_/';

            try {
              // ignore: deprecated_member_use
              await launchUrl(Uri.parse(adminUrl));
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Impossible d\'ouvrir le lien: $e'),
                  ),
                );
              }
            }
          },
          child: const Text('Interface Admin (PocketBase)'),
        ),
        const SizedBox(height: 24),
        const Text(
          'v2.4.18-test1',
          style: TextStyle(color: Colors.grey, fontSize: 12),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'app_state.dart';
import 'app_theme.dart';
import 'common_widgets.dart';
import 'firestore_service.dart';
import 'main_shell.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _mobile = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;
  bool _loading = false;

  @override
  void dispose() {
    _name.dispose();
    _mobile.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await FirestoreService.registerAccount(
        fullName: _name.text.trim(),
        mobile: _mobile.text.trim(),
        email: _email.text.trim(),
        password: _password.text,
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      final message = switch (e.code) {
        'email-already-in-use' =>
          'This email is already registered. Please log in.',
        'mobile-already-in-use' => 'This mobile number is already registered.',
        'invalid-registration-data' =>
          e.message ?? 'Check your registration details.',
        'operation-not-allowed' =>
          'Email/Password sign-in is disabled for Firebase project aqualink-fd9f8. Enable it in Authentication > Sign-in providers.',
        'weak-password' => 'Choose a stronger password.',
        'invalid-email' => 'Enter a valid email address.',
        _ => e.message ?? 'Registration failed.',
      };
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
      setState(() => _loading = false);
      return;
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Registration failed: $e')));
      setState(() => _loading = false);
      return;
    }

    if (!mounted) return;
    AppScope.of(context).register(
      fullName: _name.text.trim(),
      mobile: _mobile.text.trim(),
      email: _email.text.trim().toLowerCase(),
    );
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Account created.')));
    Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const MainShell()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.water_drop, color: AppColors.brand600, size: 34),
              const SizedBox(height: 6),
              const Text(
                'AquaLink',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.brand600,
                ),
              ),
              const Text(
                'Create your account',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.slate500),
              ),
              const SizedBox(height: 24),
              _field('Full Name', _name, (value) {
                final error = FirestoreService.validateRegistration(
                  fullName: value ?? '',
                  mobile: '09123456789',
                  password: 'Aa123456',
                );
                return error?.startsWith('Enter your complete') == true
                    ? error
                    : null;
              }),
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: TextFormField(
                  controller: _mobile,
                  keyboardType: TextInputType.phone,
                  maxLength: 11,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'Mobile Number',
                    hintText: '09XXXXXXXXX',
                    counterText: '',
                  ),
                  validator: (value) =>
                      RegExp(r'^09\d{9}$').hasMatch(value?.trim() ?? '')
                      ? null
                      : 'Enter exactly 11 digits starting with 09',
                ),
              ),
              _field(
                'Email',
                _email,
                (value) => value == null || !value.contains('@')
                    ? 'Enter a valid email'
                    : null,
              ),
              TextFormField(
                controller: _password,
                obscureText: _obscure,
                decoration: InputDecoration(
                  labelText: 'Password',
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscure
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
                validator: (value) =>
                    RegExp(
                      r'^(?=.*[A-Z])(?=.*[a-z])(?=.*\d).{8,}$',
                    ).hasMatch(value ?? '')
                    ? null
                    : 'Use 8+ characters with uppercase, lowercase, and a number',
              ),
              PrimaryButton(
                label: 'Register',
                onPressed: _register,
                loading: _loading,
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _field(
    String label,
    TextEditingController controller,
    String? Function(String?) validator,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: TextFormField(
      controller: controller,
      decoration: InputDecoration(labelText: label),
      validator: validator,
    ),
  );
}

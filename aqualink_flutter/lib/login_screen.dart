import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'app_state.dart';
import 'app_theme.dart';
import 'common_widgets.dart';
import 'firestore_service.dart';
import 'main_shell.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  static const routeName = '/login';

  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _submitting = false;

  Future<void> _forgotPassword() async {
    final email = TextEditingController(
      text: _usernameController.text.trim().toLowerCase(),
    );
    final formKey = GlobalKey<FormState>();
    final submitted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Reset password'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Registered email address',
                ),
                validator: (value) => value != null &&
                        RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value.trim())
                    ? null
                    : 'Enter a valid email address',
              ),
            ],  
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(dialogContext, true);
              }
            },
            child: const Text('Send reset link'),
          ),
        ],
      ),
    );
    final emailValue = email.text.trim().toLowerCase();
    Future<void>.delayed(const Duration(milliseconds: 300), email.dispose);
    if (submitted != true || !mounted) return;

    try {
      await FirestoreService.sendPasswordReset(
        email: emailValue,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password reset link sent to your email.')),
      );
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      final message = switch (error.code) {
        'user-not-found' => 'No account was found for that email address.',
        'operation-not-allowed' =>
          'Email/password sign-in is disabled in Firebase Authentication.',
        'invalid-email' => 'Enter a valid email address.',
        _ => 'We could not send the reset email. Please try again.',
      };
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('We could not send the reset email.')),
      );
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final loginId = _usernameController.text.trim();
    final password = _passwordController.text;

    if (loginId.isEmpty || password.isEmpty) {
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter your email or mobile number and password.'),
        ),
      );
      return;
    }

    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    await Future<void>.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;

    final normalizedLoginId = loginId.toLowerCase();
    if (normalizedLoginId == AccountCredentials.retiredAdminEmail) {
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This account is no longer available.')),
      );
      return;
    }
    final ownerStation = AccountCredentials.stationForOwnerEmail(
      normalizedLoginId,
    );
    final isOwner = ownerStation != null;
    final role = isOwner
        ? AccountRole.stationOwner
        : AccountRole.customer;

    if (isOwner &&
      Firebase.apps.isEmpty &&
      password != AccountCredentials.passwordForOwnerEmail(normalizedLoginId)) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid credentials.')),
      );
      return;
    }

    String? profileName;
    String? profileMobile;
    try {
      if (isOwner && Firebase.apps.isNotEmpty) {
        final credential = await FirestoreService.loginWithEmail(
          email: normalizedLoginId,
          password: password,
        );
        final uid = credential.user?.uid;
        final ownerProfile = uid == null
            ? null
            : await FirestoreService.loadOwnerProfile(uid);
        if (ownerProfile == null || ownerProfile['stationName'] != ownerStation) {
          throw StateError('This owner account has no assigned station.');
        }
        profileName = ownerProfile['fullName'] as String?;
        profileMobile = ownerProfile['mobile'] as String?;
      } else if (isOwner) {
        profileName = AccountCredentials.nameForOwnerEmail(normalizedLoginId);
        profileMobile = normalizedLoginId == AccountCredentials.ownerEmail
            ? '09170000001'
            : '09170000003';
      } else {
        final credential = await FirestoreService.loginWithMobileOrEmail(
          mobileOrEmail: normalizedLoginId,
          password: password,
        );
        final uid = credential.user?.uid;
        if (uid != null) {
          await FirestoreService.updateUserLogin(
            uid: uid,
            role: role.name,
            mobileOrEmail: normalizedLoginId,
          );
          final profile = await FirestoreService.loadUserProfile(uid);
          profileName =
              profile?['fullName'] as String? ?? credential.user?.displayName;
          profileMobile = profile?['mobile'] as String?;
        }
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      final message = switch (e.code) {
        'user-not-found' || 'wrong-password' || 'invalid-credential' =>
          'Invalid credentials.',
        'invalid-email' => 'Enter a valid email address.',
        _ => e.message ?? 'Login failed.',
      };
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      return;
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Login failed: $e')),
      );
      return;
    }

    if (!mounted) return;
    AppScope.of(context).login(
      mobileOrEmail: _usernameController.text,
      role: role,
      stationName: ownerStation,
      fullName: profileName,
      mobile: profileMobile,
    );

    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const MainShell()),
        (_) => false,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.slate100,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: const BoxDecoration(
                          color: AppColors.brand50,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.water_drop,
                          color: AppColors.brand600,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'AquaLink',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: AppColors.brand700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Welcome back!',
                    style: TextStyle(color: AppColors.slate500, fontSize: 14),
                  ),
                  const SizedBox(height: 32),
                  TextFormField(
                    controller: _usernameController,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      hintText: 'name@example.com',
                    ),
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      final loginId = value?.trim() ?? '';
                      if (loginId.isEmpty) return 'Required';
                      if (loginId.contains('@')) {
                        final emailPattern = RegExp(
                          r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                        );
                        if (!emailPattern.hasMatch(loginId)) {
                          return 'Enter a valid email address';
                        }
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          color: AppColors.slate400,
                        ),
                        onPressed: () => setState(
                          () => _obscurePassword = !_obscurePassword,
                        ),
                      ),
                    ),
                    validator: (value) =>
                        value == null || value.isEmpty ? 'Required' : null,
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _forgotPassword,
                      child: const Text(
                        'Forgot password?',
                        style: TextStyle(
                          color: AppColors.brand600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  PrimaryButton(
                    label: 'Login',
                    onPressed: _handleLogin,
                    loading: _submitting,
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        "Don't have an account? ",
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.slate600,
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const RegisterScreen(),
                          ),
                        ),
                        child: const Text(
                          'Create account',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.brand700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

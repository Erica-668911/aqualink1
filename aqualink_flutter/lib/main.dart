import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'app_state.dart';
import 'app_theme.dart';
import 'firestore_service.dart';
import 'login_screen.dart';
import 'main_shell.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await FirebaseAuth.instance.authStateChanges().first;

  if (FirebaseAuth.instance.currentUser == null) {
    try {
      await FirestoreService.initializeBuiltInAccountsAndData();
    } catch (e) {
      debugPrint('Firestore startup data initialization failed: $e');
    }
  }

  runApp(const AquaLinkApp());
}

class AquaLinkApp extends StatefulWidget {
  const AquaLinkApp({super.key});

  @override
  State<AquaLinkApp> createState() => _AquaLinkAppState();
}

class _AquaLinkAppState extends State<AquaLinkApp> {
  final AppState _state = AppState();
  bool _restoringSession = Firebase.apps.isNotEmpty;

  @override
  void dispose() {
    _state.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadStationDetails();
    _restoreSession();
  }

  Future<void> _restoreSession() async {
    if (Firebase.apps.isEmpty) return;
    try {
      await FirebaseAuth.instance.authStateChanges().first;
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final email = user.email ?? '';
        if (email.toLowerCase() == AccountCredentials.retiredAdminEmail) {
          await FirebaseAuth.instance.signOut();
          return;
        }
        final station = AccountCredentials.stationForOwnerEmail(email);
        final isOwner = station != null;
        final role = isOwner ? AccountRole.stationOwner : AccountRole.customer;
        _state.login(
          mobileOrEmail: email,
          role: role,
          stationName: station,
          fullName: isOwner
              ? AccountCredentials.nameForOwnerEmail(email)
              : user.displayName,
        );

        try {
          final profile =
              (isOwner
                      ? FirestoreService.loadOwnerProfile(user.uid)
                      : FirestoreService.loadUserProfile(user.uid))
                  .timeout(const Duration(seconds: 8));
          final data = await profile;
          if (data != null && mounted) {
            _state.login(
              mobileOrEmail: email,
              role: role,
              stationName: station,
              fullName: data['fullName'] as String? ?? user.displayName,
              mobile: data['mobile'] as String?,
            );
          }
        } on TimeoutException {
          debugPrint('Saved user profile restore timed out.');
        }
      }
    } catch (error) {
      debugPrint('Saved login session restore failed: $error');
    } finally {
      if (mounted) setState(() => _restoringSession = false);
    }
  }

  Future<void> _loadStationDetails() async {
    if (Firebase.apps.isEmpty) return;
    try {
      final savedDetails = await FirestoreService.loadSavedStationDetails();
      for (final entry in savedDetails.entries) {
        _state.updateStationDetails(
          stationName: entry.key,
          details: entry.value,
        );
      }
    } catch (error) {
      debugPrint('Saved station profile loading failed: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AquaLink',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: _restoringSession
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : _state.isLoggedIn
          ? const MainShell()
          : const LoginScreen(),
      builder: (context, child) =>
          AppScope(state: _state, child: child ?? const SizedBox.shrink()),
    );
  }
}

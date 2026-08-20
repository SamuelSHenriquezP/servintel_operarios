import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../shared/widgets/common_widgets.dart';
import 'login_screen.dart';
import 'role_router.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  User? _cachedUser;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && _cachedUser == null) {
          return const LoadingScreen();
        }

        if (snapshot.hasData && snapshot.data != null) {
          _cachedUser = snapshot.data;
          return RoleRouter(uid: snapshot.data!.uid);
        }

        _cachedUser = null;
        return const LoginScreen();
      },
    );
  }
}

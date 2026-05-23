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
        // Guardar usuario válido en caché
        if (snapshot.hasData && snapshot.data != null) {
          _cachedUser = snapshot.data;
        }

        // Si hay usuario en caché, siempre mostrar la app (ignorar errores transitorios)
        if (_cachedUser != null) {
          // Si se deslogueó explícitamente (data = null, sin error), limpiar caché
          if (!snapshot.hasError && snapshot.connectionState == ConnectionState.active && snapshot.data == null) {
            _cachedUser = null;
            return const LoginScreen();
          }
          return RoleRouter(uid: _cachedUser!.uid);
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LoadingScreen();
        }
        if (snapshot.hasData) {
          return RoleRouter(uid: snapshot.data!.uid);
        }
        return const LoginScreen();
      },
    );
  }
}

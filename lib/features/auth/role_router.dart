import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/constants.dart';
import '../../shared/widgets/common_widgets.dart';
import '../cliente/cliente_screen.dart';
import '../operario/operario_screen.dart';

class RoleRouter extends StatelessWidget {
  final String uid;
  const RoleRouter({super.key, required this.uid});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('usuarios')
          .doc(uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LoadingScreen();
        }

        if (!snapshot.hasData || !snapshot.data!.exists) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            FirebaseAuth.instance.signOut();
          });
          return const MessageScreen(
            message: 'Usuario no encontrado en el sistema.',
          );
        }

        final userData = snapshot.data!.data() as Map<String, dynamic>;
        final String rol = (userData['rol'] ?? '')
            .toString()
            .toLowerCase()
            .trim();
        final bool activo = userData['activo'] == true;

        if (!activo) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            FirebaseAuth.instance.signOut();
          });
          return const MessageScreen(
            message: 'Cuenta desactivada. Contacte a soporte.',
          );
        }

        if (rol == 'cliente') {
          return ClienteScreen(userData: userData);
        }
        if (rol == 'operario') {
          return OperarioScreen(userData: userData);
        }

        return const _AdminBlockScreen();
      },
    );
  }
}

class _AdminBlockScreen extends StatelessWidget {
  const _AdminBlockScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.admin_panel_settings, size: 60, color: cAzul),
              const SizedBox(height: 20),
              const Text(
                'Los Administradores deben usar el Panel Web.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: cTextoOscuro,
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: cFucsia),
                onPressed: () => FirebaseAuth.instance.signOut(),
                child: const Text('Cerrar Sesión'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

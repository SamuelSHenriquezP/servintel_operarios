import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/constants.dart';
import '../../shared/widgets/common_widgets.dart';
import '../cliente/cliente_screen.dart';
import '../operario/operario_screen.dart';

class RoleRouter extends StatefulWidget {
  final String uid;
  const RoleRouter({super.key, required this.uid});

  @override
  State<RoleRouter> createState() => _RoleRouterState();
}

class _RoleRouterState extends State<RoleRouter> {
  Map<String, dynamic>? _cachedUserData;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('usuarios')
          .doc(widget.uid)
          .snapshots(),
      builder: (context, snapshot) {
        // Si llegaron datos válidos, guardar en caché
        if (snapshot.hasData && snapshot.data!.exists) {
          _cachedUserData = snapshot.data!.data() as Map<String, dynamic>;
        }

        // Si ya tenemos datos en caché, usarlos siempre (incluso si hay error)
        if (_cachedUserData != null) {
          return _buildScreen(_cachedUserData!);
        }

        // Sin caché: esperar
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LoadingScreen();
        }

        // Sin caché + error de conexión
        if (snapshot.hasError) {
          final msg = snapshot.error.toString().contains('PERMISSION_DENIED')
              ? 'Sin permisos de acceso. Contacte al administrador.'
              : 'Verifica tu conexión a internet e intenta de nuevo.';
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.cloud_off_rounded, size: 64, color: Color(0xFF14AEE1)),
                    const SizedBox(height: 16),
                    const Text('Sin conexión', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text(msg, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey, fontSize: 14)),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () => FirebaseAuth.instance.signOut(),
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Reintentar'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        // Sin caché + documento no existe
        if (!snapshot.hasData || !snapshot.data!.exists) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            FirebaseAuth.instance.signOut();
          });
          return const MessageScreen(message: 'Usuario no encontrado en el sistema.');
        }

        return const LoadingScreen();
      },
    );
  }

  Widget _buildScreen(Map<String, dynamic> userData) {
    final String rol = (userData['rol'] ?? '').toString().toLowerCase().trim();
    final bool activo = userData['activo'] == true;

    if (!activo) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        FirebaseAuth.instance.signOut();
      });
      return const MessageScreen(message: 'Cuenta desactivada. Contacte a soporte.');
    }

    if (rol == 'cliente') {
      return ClienteScreen(userData: userData);
    }
    if (rol == 'operario') {
      return OperarioScreen(userData: userData);
    }

    return const _AdminBlockScreen();
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

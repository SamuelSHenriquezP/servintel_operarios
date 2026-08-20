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
        if (snapshot.hasData && snapshot.data != null && snapshot.data!.exists) {
          _cachedUserData = snapshot.data!.data() as Map<String, dynamic>?;
        }

        // Si ya tenemos datos en caché, usarlos
        if (_cachedUserData != null) {
          return _buildScreen(_cachedUserData!);
        }

        // Sin caché: estado de espera
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LoadingScreen();
        }

        // Sin caché + error de conexión / permisos
        if (snapshot.hasError) {
          final errorStr = snapshot.error.toString();
          final isPermDenied = errorStr.contains('PERMISSION_DENIED') || errorStr.contains('permission-denied');
          return Scaffold(
            backgroundColor: Colors.white,
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      isPermDenied ? Icons.lock_outline_rounded : Icons.cloud_off_rounded,
                      size: 64,
                      color: isPermDenied ? cFucsia : cAzul,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      isPermDenied ? 'Permiso Denegado' : 'Sin Conexión',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: cTextoOscuro),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      isPermDenied
                          ? 'No tienes permisos para acceder a esta cuenta. Contacte al administrador.'
                          : 'Verifica tu conexión a internet e intenta de nuevo.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.grey, fontSize: 14, height: 1.4),
                    ),
                    const SizedBox(height: 28),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: cAzul,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          ),
                          onPressed: () => setState(() {}),
                          icon: const Icon(Icons.refresh_rounded, size: 18),
                          label: const Text('Reintentar'),
                        ),
                        const SizedBox(width: 12),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: cTextoOscuro,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                          onPressed: () => FirebaseAuth.instance.signOut(),
                          icon: const Icon(Icons.logout_rounded, size: 18),
                          label: const Text('Salir'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        // Sin caché + documento no existe
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return Scaffold(
            backgroundColor: Colors.white,
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.person_off_rounded, size: 64, color: Colors.orange),
                    const SizedBox(height: 20),
                    const Text(
                      'Usuario no registrado',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: cTextoOscuro),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Esta cuenta existe en autenticación pero no tiene un perfil registrado en la base de datos de ServiIntel.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey, fontSize: 14, height: 1.4),
                    ),
                    const SizedBox(height: 28),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: cAzul,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                      ),
                      onPressed: () => FirebaseAuth.instance.signOut(),
                      icon: const Icon(Icons.arrow_back_rounded, size: 18),
                      label: const Text('VOLVER AL INICIO'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return const LoadingScreen();
      },
    );
  }

  bool _isUserActive(dynamic rawActivo) {
    if (rawActivo == null) return true; // Activo por defecto si el campo no existe
    if (rawActivo is bool) return rawActivo;
    if (rawActivo is num) return rawActivo != 0;
    if (rawActivo is String) {
      final s = rawActivo.trim().toLowerCase();
      if (s == 'false' || s == '0' || s == 'inactivo' || s == 'pendiente' || s == 'bloqueado' || s == 'suspendido') {
        return false;
      }
      return true;
    }
    return true;
  }

  Widget _buildScreen(Map<String, dynamic> userData) {
    final String rol = (userData['rol'] ?? userData['Rol'] ?? userData['role'] ?? userData['Role'] ?? userData['tipo'] ?? '').toString().toLowerCase().trim();

    // 1. Si es Administrador, dirigir a la pantalla informativa de Admin (panel web)
    if (rol == 'admin' || rol == 'administrador' || rol == 'administrator') {
      return const _AdminBlockScreen();
    }

    // 2. Para clientes y técnicos/operarios, verificar si la cuenta está activa
    final dynamic rawActivo = userData['activo'] ?? userData['Activo'];
    final bool activo = _isUserActive(rawActivo);

    if (!activo) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.lock_clock_rounded, size: 64, color: cFucsia),
                const SizedBox(height: 20),
                const Text(
                  'Cuenta Pendiente de Activación',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: cTextoOscuro),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Tu cuenta está registrada pero se encuentra inactiva o en revisión por el administrador de ServiIntel.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey, fontSize: 14, height: 1.4),
                ),
                const SizedBox(height: 28),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: cAzul,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  ),
                  onPressed: () => FirebaseAuth.instance.signOut(),
                  icon: const Icon(Icons.logout_rounded, size: 18),
                  label: const Text('VOLVER AL LOGIN'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // 3. Clientes
    if (rol == 'cliente' || rol == 'clientes' || rol == 'client') {
      return ClienteScreen(userData: userData);
    }

    // 4. Operarios / Técnicos
    if (rol == 'operario' || rol == 'operarios' || rol == 'tecnico' || rol == 'técnico' || rol == 'tecnicos' || rol == 'técnicos' || rol == 'operador') {
      return OperarioScreen(userData: userData);
    }

    // 5. Usuario sin rol asignado o desconocido
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.help_outline_rounded, size: 64, color: Colors.amber),
              const SizedBox(height: 20),
              const Text(
                'Rol no Asignado',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: cTextoOscuro),
              ),
              const SizedBox(height: 12),
              Text(
                'Tu cuenta no tiene un rol válido asignado ("${rol.isEmpty ? 'sin rol' : rol}"). Contacta al administrador de ServiIntel.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey, fontSize: 14, height: 1.4),
              ),
              const SizedBox(height: 28),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: cAzul,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                ),
                onPressed: () => FirebaseAuth.instance.signOut(),
                icon: const Icon(Icons.logout_rounded, size: 18),
                label: const Text('VOLVER AL LOGIN'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdminBlockScreen extends StatelessWidget {
  const _AdminBlockScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.admin_panel_settings_rounded, size: 64, color: cAzul),
              const SizedBox(height: 20),
              const Text(
                'Panel Web Requerido',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: cTextoOscuro,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              const Text(
                'Las funciones de Administrador se gestionan exclusivamente desde la plataforma web:\nhttps://gestion-servi-intel-sas.web.app',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 14, height: 1.4),
              ),
              const SizedBox(height: 28),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: cFucsia,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                ),
                onPressed: () => FirebaseAuth.instance.signOut(),
                icon: const Icon(Icons.logout_rounded, size: 18),
                label: const Text('CERRAR SESIÓN'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

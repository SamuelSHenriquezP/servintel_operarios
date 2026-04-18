import 'package:flutter/material.dart';
import '../../core/constants.dart';

/// Pantalla de carga genérica
class LoadingScreen extends StatelessWidget {
  const LoadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator(color: cAzul)),
    );
  }
}

/// Pantalla de mensaje de error/información
class MessageScreen extends StatelessWidget {
  final String message;
  const MessageScreen({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, color: cTextoOscuro),
          ),
        ),
      ),
    );
  }
}

/// Header de sección para separar activos/completados
class SectionHeader extends StatelessWidget {
  final String title;
  final int count;
  final Color color;
  const SectionHeader({
    super.key,
    required this.title,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 5),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 18,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// CHIP DE ESTADO PERSONALIZADO
class EstadoChip extends StatelessWidget {
  final String estado;
  final bool darkText;
  const EstadoChip({super.key, required this.estado, this.darkText = true});

  @override
  Widget build(BuildContext context) {
    final color = getColorEstado(estado);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: darkText ? 0.12 : 1.0),
        borderRadius: BorderRadius.circular(8),
        border: darkText ? Border.all(color: color.withValues(alpha: 0.3)) : null,
      ),
      child: Text(
        estado.replaceAll('_', ' ').toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w900,
          color: darkText ? color : Colors.white,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

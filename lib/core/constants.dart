import 'package:flutter/material.dart';

// ======================================================================
// CONSTANTES GLOBALES
// ======================================================================
// Identidad de color según pedido: blanco principal, azul marca,
// fucsia y amarillo para CTAs/alertas.
const Color cAzul = Color(0xFF14AEE1);
const Color cFucsia = Color(0xFFE71E65);
const Color cAmarillo = Color(0xFFF3E72E);
// Fondo principal: blanco puro (#ffffff)
const Color cFondo = Color(0xFFFFFFFF);
const Color cTextoOscuro = Color(0xFF1E293B);

// CTA alternantes (primario/alterno)
const Color cCTAPrimary = cFucsia;
const Color cCTASecondary = cAmarillo;

const List<String> kCategorias = [
  'Mantenimiento',
  'Soporte Técnico',
  'Impresora / Fotocopiadora',
  'Reparaciones Generales',
];

// Helper global para color de estado
Color getColorEstado(String estado) {
  switch (estado) {
    case 'solicitado':
      return cFucsia;
    case 'asignado':
      return Colors.orange;
    case 'en_camino':
      return cAzul;
    case 'retrasado':
      return Colors.red;
    case 'en_sitio':
      return Colors.teal;
    case 'revision_cliente':
      return Colors.deepPurple;
    case 'trabajo_aprobado':
      return Colors.indigo;
    case 'en_progreso':
      return Colors.blue.shade700;
    case 'esperando_cierre':
      return Colors.teal;
    case 'completado': // Esto es cierre admin
      return Colors.green;
    case 'evaluado_cliente':
      return Colors.blueGrey;
    case 'cerrado':
      return Colors.grey;
    default:
      return Colors.grey;
  }
}

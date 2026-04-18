import 'package:cloud_firestore/cloud_firestore.dart';

class Trabajo {
  final String id;
  final String categoria;
  final String clienteNombre;
  final String descripcion;
  final String? estado;
  final String? operarioId;
  final String? operarioNombre;
  final DateTime? creadoEn;
  final DateTime? tiempoEnCamino;
  final DateTime? tiempoEnSitio;
  final DateTime? tiempoCompletado;
  final Map<String, dynamic>? evaluacionCliente;

  const Trabajo({
    required this.id,
    required this.categoria,
    required this.clienteNombre,
    required this.descripcion,
    this.estado,
    this.operarioId,
    this.operarioNombre,
    this.creadoEn,
    this.tiempoEnCamino,
    this.tiempoEnSitio,
    this.tiempoCompletado,
    this.evaluacionCliente,
  });

  factory Trabajo.fromDoc(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Trabajo(
      id: doc.id,
      categoria: data['categoria'] ?? '',
      clienteNombre: data['clienteNombre'] ?? '',
      descripcion: data['descripcion'] ?? '',
      estado: data['estado'] as String?,
      operarioId: data['operarioId'] as String?,
      operarioNombre: data['operarioNombre'] as String?,
      creadoEn: (data['creadoEn'] as Timestamp?)?.toDate(),
      tiempoEnCamino: (data['tiempoEnCamino'] as Timestamp?)?.toDate(),
      tiempoEnSitio: (data['tiempoEnSitio'] as Timestamp?)?.toDate(),
      tiempoCompletado: (data['tiempoCompletado'] as Timestamp?)?.toDate(),
      evaluacionCliente: data['evaluacionCliente'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toMap() => {
        'categoria': categoria,
        'clienteNombre': clienteNombre,
        'descripcion': descripcion,
        'estado': estado,
        'operarioId': operarioId,
        'operarioNombre': operarioNombre,
        'creadoEn': creadoEn,
        'tiempoEnCamino': tiempoEnCamino,
        'tiempoEnSitio': tiempoEnSitio,
        'tiempoCompletado': tiempoCompletado,
        'evaluacionCliente': evaluacionCliente,
      };
}

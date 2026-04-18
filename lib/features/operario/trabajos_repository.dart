import 'package:cloud_firestore/cloud_firestore.dart';

class TrabajosRepository {
  static final CollectionReference _col = FirebaseFirestore.instance.collection('trabajos');

  static Stream<QuerySnapshot> streamActiveForOperario(String uid) {
    return _col
        .where('operarioId', isEqualTo: uid)
        .where('estado', whereIn: ['asignado', 'en_camino', 'en_sitio', 'retrasado'])
        .snapshots();
  }

  static Stream<QuerySnapshot> streamCompletedRecentForOperario(String uid) {
    return _col
        .where('operarioId', isEqualTo: uid)
        .where('estado', whereIn: ['revision_cliente', 'reporte_aprobado', 'completado', 'evaluado_cliente', 'cerrado'])
        .orderBy('creadoEn', descending: true)
        .limit(5)
        .snapshots();
  }

  static Future<List<QueryDocumentSnapshot>> searchByClienteName(String uid, String query) async {
    final snapshot = await _col
        .where('operarioId', isEqualTo: uid)
        .where('clienteNombre', isGreaterThanOrEqualTo: query)
        .where('clienteNombre', isLessThanOrEqualTo: '$query\uf8ff')
        .get();
    return snapshot.docs;
  }

  static Future<void> updateEstado(String jobId, Map<String, dynamic> updateData) {
    return _col.doc(jobId).update(updateData);
  }
}

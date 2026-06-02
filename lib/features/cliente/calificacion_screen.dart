import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/constants.dart';
import '../../shared/widgets/premium_widgets.dart';

class CalificacionScreen extends StatefulWidget {
  final Map<String, dynamic> data;
  final String jobId;

  const CalificacionScreen({super.key, required this.data, required this.jobId});

  @override
  State<CalificacionScreen> createState() => _CalificacionScreenState();
}

class _CalificacionScreenState extends State<CalificacionScreen> {
  bool _isApproving = false;
  int _rating = 5;
  final _commentCtrl = TextEditingController();

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _enviarCalificacion() async {
    setState(() => _isApproving = true);
    try {
      final docRef = FirebaseFirestore.instance.collection('trabajos').doc(widget.jobId);
      final docSnap = await docRef.get();
      final currentEstado = docSnap.data()?['estado'];

      final updateData = <String, dynamic>{
        'evaluacionCliente': {
          'estrellas': _rating,
          'comentario': _commentCtrl.text.trim(),
          'fechaEvaluacion': FieldValue.serverTimestamp(),
        },
      };

      if (currentEstado != 'cerrado') {
        updateData['estado'] = 'evaluado_cliente';
      }

      await docRef.update(updateData);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('¡Gracias por su calificación!'), backgroundColor: Colors.green));
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isApproving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const BrandedAppBar(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader(
              title: 'Calificación Final',
              subtitle: 'El trabajo ha finalizado. Por favor evalúe el servicio',
            ),
            PremiumCard(
              accentColor: cAmarillo,
              child: Column(
                children: [
                  const Text('¿Qué tal le pareció el servicio?', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) => IconButton(
                      icon: Icon(
                        index < _rating ? Icons.star_rounded : Icons.star_outline_rounded,
                        color: cAmarillo,
                        size: 40,
                      ),
                      onPressed: () => setState(() => _rating = index + 1),
                    )),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _commentCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(hintText: 'Déjanos un comentario adicional...'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                icon: _isApproving ? const SizedBox() : const Icon(Icons.check_circle_outline, color: Colors.white),
                label: _isApproving
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('ENVIAR CALIFICACIÓN', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                onPressed: _isApproving ? null : _enviarCalificacion,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

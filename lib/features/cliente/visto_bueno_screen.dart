import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/constants.dart';
import '../../shared/widgets/premium_widgets.dart';

class VistoBuenoScreen extends StatefulWidget {
  final Map<String, dynamic> data;
  final String jobId;

  const VistoBuenoScreen({super.key, required this.data, required this.jobId});

  @override
  State<VistoBuenoScreen> createState() => _VistoBuenoScreenState();
}

class _VistoBuenoScreenState extends State<VistoBuenoScreen> {
  bool _isApproving = false;
  int _rating = 5;
  final _commentCtrl = TextEditingController();

  Future<void> _aprobarReporte() async {
    setState(() => _isApproving = true);
    try {
      await FirebaseFirestore.instance.collection('trabajos').doc(widget.jobId).update({
        'estado': 'evaluado_cliente',
        'reporteAprobado': true,
        'evaluacionCliente': {
          'estrellas': _rating,
          'comentario': _commentCtrl.text.trim(),
          'fechaEvaluacion': FieldValue.serverTimestamp(),
        },
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('¡Gracias por su aprobación y evaluación!'), backgroundColor: Colors.green));
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
    final reporte = widget.data['reporteTecnico'] ?? {};
    
    return Scaffold(
      appBar: const BrandedAppBar(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader(
              title: 'Resumen de Servicio',
              subtitle: 'Verifique los detalles del trabajo realizado',
            ),
            PremiumCard(
              accentColor: cAzul,
              child: Row(
                children: [
                   const Icon(Icons.description_outlined, color: cAzul, size: 32),
                   const SizedBox(width: 16),
                   Expanded(
                     child: Column(
                       crossAxisAlignment: CrossAxisAlignment.start,
                       children: [
                         const Text('RESUMEN TÉCNICO', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: cAzul, letterSpacing: 1)),
                         Text('Ticket #${widget.jobId.substring(widget.jobId.length - 6).toUpperCase()}', style: const TextStyle(color: cTextoOscuro, fontSize: 16, fontWeight: FontWeight.bold)),
                       ],
                     ),
                   ),
                ],
              ),
            ),
            _buildSection(
              'DATOS DEL PERSONAL',
              [
                _buildRow('Encargado', reporte['encargadoNombre'] ?? 'No especificado'),
                _buildRow('Identificación', reporte['encargadoCedula'] ?? 'No especificada'),
                _buildRow('Tipo Servicio', reporte['tipoServicio'] ?? 'General'),
              ],
            ),
            if ((reporte['equipos'] as List?)?.isNotEmpty == true)
              _buildSection(
                'EQUIPOS INTERVENIDOS',
                (reporte['equipos'] as List).map((e) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.03),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        _buildRow('Equipo', e['equipoMarca'] ?? ''),
                        _buildRow('Modelo', e['modelo'] ?? ''),
                        _buildRow('Contador', e['contador'] ?? ''),
                      ],
                    ),
                  );
                }).toList(),
              ),
            if ((reporte['detallesTecnicos'] as List?)?.isNotEmpty == true)
              _buildSection(
                'DETALLES DE LA INTERVENCIÓN',
                (reporte['detallesTecnicos'] as List).map((d) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('DIAGNÓSTICO:', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                        Text(d['diagnostico'] ?? '', style: const TextStyle(color: cTextoOscuro, fontWeight: FontWeight.w500)),
                        const SizedBox(height: 6),
                        const Text('SOLUCIÓN APLICADA:', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                        Text(d['solucion'] ?? '', style: const TextStyle(color: cTextoOscuro, fontWeight: FontWeight.w500)),
                      ],
                    ),
                  );
                }).toList(),
              ),
            if (reporte['costoServicio']?.toString().isNotEmpty == true || reporte['costoTecnico']?.toString().isNotEmpty == true)
              _buildSection(
                'LIQUIDACIÓN DE SERVICIOS',
                [
                  if (reporte['costoServicio']?.toString().isNotEmpty == true)
                    _buildRow('Servicio Empresa', '\$${reporte['costoServicio']}', isBold: true),
                  if (reporte['costoTecnico']?.toString().isNotEmpty == true)
                    _buildRow('Servicio Técnico', '\$${reporte['costoTecnico']}', isBold: true),
                ],
              ),
            const SectionHeader(title: 'Calificación del Servicio'),
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
                    : const Text('ACEPTAR Y FINALIZAR', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                onPressed: _isApproving ? null : _aprobarReporte,
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 24, bottom: 12),
          child: Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 1.2)),
        ),
        PremiumCard(
          padding: const EdgeInsets.all(20),
          accentColor: cAzul.withValues(alpha: 0.1),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildRow(String label, String value, {bool isBold = false}) {
    return Padding(
       padding: const EdgeInsets.symmetric(vertical: 4),
       child: Row(
         mainAxisAlignment: MainAxisAlignment.spaceBetween,
         children: [
           Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.w500)),
           Text(
             value, 
             style: TextStyle(
               color: cTextoOscuro, 
               fontSize: 14, 
               fontWeight: isBold ? FontWeight.w900 : FontWeight.bold
             )
           ),
         ],
       ),
    );
  }
}

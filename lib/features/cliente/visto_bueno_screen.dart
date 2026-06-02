import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/constants.dart';
import '../../shared/widgets/premium_widgets.dart';

class VistoBuenoScreen extends StatefulWidget {
  final Map<String, dynamic> data;
  final String jobId;
  final bool isReadOnly;

  const VistoBuenoScreen({super.key, required this.data, required this.jobId, this.isReadOnly = false});

  @override
  State<VistoBuenoScreen> createState() => _VistoBuenoScreenState();
}

class _VistoBuenoScreenState extends State<VistoBuenoScreen> {
  bool _isApproving = false;
  bool _isRejecting = false;

  final _commentCtrl = TextEditingController();

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _aprobarReporte() async {
    setState(() => _isApproving = true);
    try {
      await FirebaseFirestore.instance.collection('trabajos').doc(widget.jobId).update({
        'estado': 'trabajo_aprobado',
        'reporteAprobado': true,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('¡Diagnóstico aprobado! El técnico procederá con el trabajo.'), backgroundColor: Colors.green));
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isApproving = false);
    }
  }

  Future<void> _rechazarReporte() async {
    setState(() => _isRejecting = true);
    try {
      await FirebaseFirestore.instance.collection('trabajos').doc(widget.jobId).update({
        'estado': 'en_sitio', // Vuelve al operario para rehacer reporte
        'reporteRechazado': true,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reporte rechazado. El técnico debe generarlo nuevamente.'), backgroundColor: Colors.orange));
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isRejecting = false);
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
              ],
            ),
            if ((reporte['trabajosReportados'] as List?)?.isNotEmpty == true)
              ...((reporte['trabajosReportados'] as List).asMap().entries.map((entry) {
                final int idx = entry.key;
                final t = entry.value as Map<String, dynamic>;
                return _buildSection(
                  'TRABAJO ${idx + 1}: ${t['tipo']?.toString().toUpperCase() ?? ''}',
                  [
                    if (t['tipo'] == 'Venta') ...[
                      _buildRow('Valor de Venta', '\$${t['ventaValor'] ?? 0}'),
                      _buildRow('Condiciones', t['ventaCondiciones']?.toString() ?? 'N/A'),
                      const Divider(),
                    ],
                    if (t['tipo'] == 'Alquiler') ...[
                      _buildRow('Duración', '${t['alquilerMeses'] ?? 0} Meses'),
                      _buildRow('Valor Mensual', '\$${t['alquilerValorMensual'] ?? 0}'),
                      const Divider(),
                    ],
                    if ((t['equipos'] as List?)?.isNotEmpty == true) ...[
                      const Text('EQUIPOS:', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                      const SizedBox(height: 8),
                      ...(t['equipos'] as List).map((e) => Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(8),
                        color: Colors.grey.withValues(alpha: 0.05),
                        child: Column(
                          children: [
                            _buildRow('Marca', e['equipoMarca'] ?? ''),
                            _buildRow('Modelo', e['modelo'] ?? ''),
                            _buildRow('Contador', e['contador'] ?? ''),
                          ],
                        ),
                      )),
                      const SizedBox(height: 8),
                    ],
                    if ((t['detallesTecnicos'] as List?)?.isNotEmpty == true) ...[
                      const Text('INTERVENCIÓN:', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                      const SizedBox(height: 8),
                      ...(t['detallesTecnicos'] as List).map((d) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Diag: ${d['diagnostico'] ?? ''}', style: const TextStyle(color: cTextoOscuro, fontSize: 13)),
                            Text('Sol: ${d['solucion'] ?? ''}', style: const TextStyle(color: cTextoOscuro, fontSize: 13)),
                          ],
                        ),
                      )),
                    ],
                  ],
                );
              }))
            else ...[
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
            ],
            if (reporte['costoEmpresa'] != null || reporte['costoTecnico'] != null)
              _buildSection(
                'LIQUIDACIÓN DE SERVICIOS',
                [
                  if (reporte['costoEmpresa'] != null)
                    _buildRow('Servicio Empresa', '\$${reporte['costoEmpresa']}', isBold: true),
                  if (reporte['costoTecnico'] != null)
                    _buildRow('Servicio Técnico', '\$${reporte['costoTecnico']}', isBold: true),
                ],
              ),
            if (!widget.isReadOnly) ...[
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 56,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        icon: _isRejecting ? const SizedBox() : const Icon(Icons.cancel_outlined, color: Colors.white),
                        label: _isRejecting
                            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Text('RECHAZAR', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                        onPressed: (_isApproving || _isRejecting) ? null : _rechazarReporte,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: SizedBox(
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
                            : const Text('APROBAR', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                        onPressed: (_isApproving || _isRejecting) ? null : _aprobarReporte,
                      ),
                    ),
                  ),
                ],
              ),
            ] else if (widget.data['evaluacionCliente'] != null) ...[
              const SectionHeader(title: 'Su Calificación'),
              PremiumCard(
                accentColor: cAmarillo,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: List.generate(5, (index) => Icon(
                        index < (widget.data['evaluacionCliente']['estrellas'] ?? 0) ? Icons.star_rounded : Icons.star_outline_rounded,
                        color: cAmarillo,
                        size: 32,
                      )),
                    ),
                    const SizedBox(height: 12),
                    Text(widget.data['evaluacionCliente']['comentario'] ?? 'Sin comentario', style: const TextStyle(fontSize: 14, color: cTextoOscuro)),
                  ],
                ),
              ),
            ],
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

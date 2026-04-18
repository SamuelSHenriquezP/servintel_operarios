import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/constants.dart';

class VistoBuenoScreen extends StatefulWidget {
  final Map<String, dynamic> data;
  final String jobId;

  const VistoBuenoScreen({super.key, required this.data, required this.jobId});

  @override
  State<VistoBuenoScreen> createState() => _VistoBuenoScreenState();
}

class _VistoBuenoScreenState extends State<VistoBuenoScreen> {
  bool _isApproving = false;

  Future<void> _aprobarReporte() async {
    setState(() => _isApproving = true);
    try {
      await FirebaseFirestore.instance.collection('trabajos').doc(widget.jobId).update({
        'estado': 'reporte_aprobado',
        'fechaVistoBueno': FieldValue.serverTimestamp(),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Comprobante Aprobado Exitosamente'), backgroundColor: Colors.green));
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
    final reporte = widget.data['reporteTecnico'] as Map<String, dynamic>? ?? {};

    return Scaffold(
      appBar: AppBar(title: const Text('Constancia de Servicio')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSection(
              'Datos del Servicio',
              [
                _buildRow('Encargado', reporte['encargadoNombre'] ?? ''),
                _buildRow('Cédula', reporte['encargadoCedula'] ?? ''),
                _buildRow('Tipo Mantenimiento', reporte['tipoServicio'] ?? ''),
              ],
            ),
            if ((reporte['equipos'] as List?)?.isNotEmpty == true)
              _buildSection(
                'Información del Equipo',
                (reporte['equipos'] as List).map((e) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildRow('Equipo', e['equipoMarca'] ?? ''),
                      _buildRow('Modelo', e['modelo'] ?? ''),
                      _buildRow('Contador', e['contador'] ?? ''),
                      const SizedBox(height: 10),
                    ],
                  );
                }).toList(),
              ),
            if ((reporte['detallesTecnicos'] as List?)?.isNotEmpty == true)
              _buildSection(
                'Detalles Técnicos',
                (reporte['detallesTecnicos'] as List).map((d) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildRow('Diagnóstico', d['diagnostico'] ?? ''),
                      _buildRow('Solución', d['solucion'] ?? ''),
                      const SizedBox(height: 10),
                    ],
                  );
                }).toList(),
              ),
            if ((reporte['insumos'] as List?)?.isNotEmpty == true)
              _buildSection(
                'Desglose de Insumos',
                (reporte['insumos'] as List).map((i) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildRow('Insumo', i['descripcion'] ?? ''),
                      _buildRow('Cantidad', i['cantidad'] ?? ''),
                      const SizedBox(height: 10),
                    ],
                  );
                }).toList(),
              ),
            if (reporte['costoServicio']?.toString().isNotEmpty == true || reporte['costoTecnico']?.toString().isNotEmpty == true)
              _buildSection(
                'Costos Acordados',
                [
                  if (reporte['costoServicio']?.toString().isNotEmpty == true)
                    _buildRow('Srv. Prestado', '\$${reporte['costoServicio']}'),
                  if (reporte['costoTecnico']?.toString().isNotEmpty == true)
                    _buildRow('Srv. Técnico', '\$${reporte['costoTecnico']}'),
                ],
              ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                padding: const EdgeInsets.symmetric(vertical: 16),
                minimumSize: const Size(double.infinity, 50),
              ),
              icon: _isApproving ? const SizedBox() : const Icon(Icons.thumb_up, color: Colors.white),
              label: _isApproving
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('ACEPTADO / CONFORME', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              onPressed: _isApproving ? null : _aprobarReporte,
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: cAzul)),
            const Divider(),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 2, child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey))),
          Expanded(flex: 3, child: Text(value, style: const TextStyle(color: cTextoOscuro))),
        ],
      ),
    );
  }
}

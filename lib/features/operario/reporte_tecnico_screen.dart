import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/constants.dart';

class ReporteTecnicoScreen extends StatefulWidget {
  final Map<String, dynamic> userData;
  final String jobId;

  const ReporteTecnicoScreen({super.key, required this.userData, required this.jobId});

  @override
  State<ReporteTecnicoScreen> createState() => _ReporteTecnicoScreenState();
}

class _ReporteTecnicoScreenState extends State<ReporteTecnicoScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isSending = false;

  // Encargado
  final _cedulaEncargadoCtrl = TextEditingController();

  // Tipo Servicio
  String? _tipoServicio;
  final _tipos = ['Preventivo', 'Correctivo', 'Instalación', 'Arriendo', 'A finalización'];

  // Dinámicos
  final List<Map<String, TextEditingController>> _equipos = [];
  final List<Map<String, TextEditingController>> _detalles = [];
  final List<Map<String, TextEditingController>> _insumos = [];

  // Costos
  final _costoServicioCtrl = TextEditingController();
  final _costoTecnicoCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _addEquipo();
    _addDetalle();
    _addInsumo();
  }

  void _addEquipo() {
    setState(() => _equipos.add({
      'equipoMarca': TextEditingController(),
      'modelo': TextEditingController(),
      'contador': TextEditingController(),
    }));
  }

  void _addDetalle() {
    setState(() => _detalles.add({
      'diagnostico': TextEditingController(),
      'solucion': TextEditingController(),
    }));
  }

  void _addInsumo() {
    setState(() => _insumos.add({
      'descripcion': TextEditingController(),
      'cantidad': TextEditingController(),
    }));
  }

  Future<void> _enviarReporte() async {
    if (!_formKey.currentState!.validate()) return;
    if (_tipoServicio == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Seleccione el tipo de servicio')));
      return;
    }

    setState(() => _isSending = true);

    try {
      final reporte = {
        'encargadoNombre': widget.userData['nombre'],
        'encargadoCedula': _cedulaEncargadoCtrl.text.trim(),
        'tipoServicio': _tipoServicio,
        'equipos': _equipos.map((e) => {
          'equipoMarca': e['equipoMarca']!.text.trim(),
          'modelo': e['modelo']!.text.trim(),
          'contador': e['contador']!.text.trim(),
        }).toList(),
        'detallesTecnicos': _detalles.map((d) => {
          'diagnostico': d['diagnostico']!.text.trim(),
          'solucion': d['solucion']!.text.trim(),
        }).toList(),
        'insumos': _insumos.map((i) => {
          'descripcion': i['descripcion']!.text.trim(),
          'cantidad': i['cantidad']!.text.trim(),
        }).toList(),
        'costoServicio': _costoServicioCtrl.text.trim(),
        'costoTecnico': _costoTecnicoCtrl.text.trim(),
        'fechaEmision': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance.collection('trabajos').doc(widget.jobId).update({
        'estado': 'revision_cliente',
        'reporteTecnico': reporte,
        'tiempoCompletado': FieldValue.serverTimestamp(), 
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reporte enviado a revisión al cliente'), backgroundColor: Colors.green));
      Navigator.pop(context); // Regresa a pantalla anterior
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Constancia de Servicio')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildInfoCard(
              title: 'Datos del Encargado',
              children: [
                TextFormField(
                  initialValue: widget.userData['nombre'],
                  decoration: const InputDecoration(labelText: 'Nombre Técnico'),
                  readOnly: true,
                ),
                TextFormField(
                  controller: _cedulaEncargadoCtrl,
                  decoration: const InputDecoration(labelText: 'Cédula'),
                  keyboardType: TextInputType.number,
                  validator: (v) => v!.isEmpty ? 'Requerido' : null,
                ),
              ],
            ),
            _buildInfoCard(
              title: 'Datos del Servicio',
              children: [
                DropdownButtonFormField<String>(
                  value: _tipoServicio,
                  decoration: const InputDecoration(labelText: 'Tipo de Mantenimiento / Servicio'),
                  items: _tipos.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                  onChanged: (v) => setState(() => _tipoServicio = v),
                ),
              ],
            ),
            _buildDynamicSection('Información del Equipo', _equipos, _addEquipo, (i) {
              return [
                TextFormField(controller: _equipos[i]['equipoMarca'], decoration: const InputDecoration(labelText: 'Equipo y Marca')),
                TextFormField(controller: _equipos[i]['modelo'], decoration: const InputDecoration(labelText: 'Modelo')),
                TextFormField(controller: _equipos[i]['contador'], decoration: const InputDecoration(labelText: 'Contador')),
              ];
            }),
            _buildDynamicSection('Detalles Técnicos', _detalles, _addDetalle, (i) {
              return [
                TextFormField(controller: _detalles[i]['diagnostico'], decoration: const InputDecoration(labelText: 'Diagnóstico del Equipo')),
                TextFormField(controller: _detalles[i]['solucion'], decoration: const InputDecoration(labelText: 'Solución aplicable')),
              ];
            }),
            _buildDynamicSection('Insumos / Repuestos Utilizados', _insumos, _addInsumo, (i) {
              return [
                TextFormField(controller: _insumos[i]['descripcion'], decoration: const InputDecoration(labelText: 'Descripción Insumo/Servicio')),
                TextFormField(controller: _insumos[i]['cantidad'], decoration: const InputDecoration(labelText: 'Cantidad'), keyboardType: TextInputType.number),
              ];
            }),
            _buildInfoCard(
              title: 'Costos (Opcional)',
              children: [
                TextFormField(controller: _costoServicioCtrl, decoration: const InputDecoration(labelText: 'Valor del servicio prestado (\$)', prefixText: '\$'), keyboardType: TextInputType.number),
                TextFormField(controller: _costoTecnicoCtrl, decoration: const InputDecoration(labelText: 'Remuneración Servicio Técnico (\$)', prefixText: '\$'), keyboardType: TextInputType.number),
              ],
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: cFucsia, padding: const EdgeInsets.symmetric(vertical: 16)),
              onPressed: _isSending ? null : _enviarReporte,
              child: _isSending ? const CircularProgressIndicator(color: Colors.white) : const Text('FINALIZAR Y ENVIAR AL CLIENTE', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard({required String title, required List<Widget> children}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
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

  Widget _buildDynamicSection(String title, List items, VoidCallback onAdd, List<Widget> Function(int) builder) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: cAzul))),
                IconButton(icon: const Icon(Icons.add_circle, color: cFucsia), onPressed: onAdd),
              ],
            ),
            const Divider(),
            for (int i = 0; i < items.length; i++) ...[
              if (i > 0) const Divider(color: Colors.grey, thickness: 1),
              ...builder(i),
            ],
          ],
        ),
      ),
    );
  }
}

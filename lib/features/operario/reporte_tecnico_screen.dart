import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/constants.dart';
import '../../shared/widgets/premium_widgets.dart';

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

  final _cedulaEncargadoCtrl = TextEditingController();
  String? _tipoServicio;
  final _tipos = kCategorias;

  final List<Map<String, TextEditingController>> _equipos = [];
  final List<Map<String, TextEditingController>> _detalles = [];
  final List<Map<String, TextEditingController>> _insumos = [];

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
    setState(() => _equipos.add({'equipoMarca': TextEditingController(), 'modelo': TextEditingController(), 'contador': TextEditingController()}));
  }

  void _removeEquipo(int index) {
    if (_equipos.length > 1) {
      for (final c in _equipos[index].values) { c.dispose(); }
      setState(() => _equipos.removeAt(index));
    }
  }

  void _addDetalle() {
    setState(() => _detalles.add({'diagnostico': TextEditingController(), 'solucion': TextEditingController()}));
  }

  void _removeDetalle(int index) {
    if (_detalles.length > 1) {
      for (final c in _detalles[index].values) { c.dispose(); }
      setState(() => _detalles.removeAt(index));
    }
  }

  void _addInsumo() {
    setState(() => _insumos.add({'descripcion': TextEditingController(), 'cantidad': TextEditingController()}));
  }

  void _removeInsumo(int index) {
    if (_insumos.length > 1) {
      for (final c in _insumos[index].values) { c.dispose(); }
      setState(() => _insumos.removeAt(index));
    }
  }

  @override
  void dispose() {
    _cedulaEncargadoCtrl.dispose();
    _costoServicioCtrl.dispose();
    _costoTecnicoCtrl.dispose();
    for (final m in [..._equipos, ..._detalles, ..._insumos]) {
      for (final c in m.values) { c.dispose(); }
    }
    super.dispose();
  }

  Future<void> _enviarReporte() async {
    if (!_formKey.currentState!.validate() || _tipoServicio == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Complete los campos obligatorios')));
      return;
    }

    setState(() => _isSending = true);
    try {
      final reporte = {
        'encargadoNombre': widget.userData['nombre'],
        'encargadoCedula': _cedulaEncargadoCtrl.text.trim(),
        'tipoServicio': _tipoServicio,
        'equipos': _equipos.map((e) => {'equipoMarca': e['equipoMarca']!.text.trim(), 'modelo': e['modelo']!.text.trim(), 'contador': e['contador']!.text.trim()}).toList(),
        'detallesTecnicos': _detalles.map((d) => {'diagnostico': d['diagnostico']!.text.trim(), 'solucion': d['solucion']!.text.trim()}).toList(),
        'insumos': _insumos.map((i) => {'descripcion': i['descripcion']!.text.trim(), 'cantidad': i['cantidad']!.text.trim()}).toList(),
        'costoServicio': double.tryParse(_costoServicioCtrl.text.trim()) ?? 0.0,
        'costoTecnico': double.tryParse(_costoTecnicoCtrl.text.trim()) ?? 0.0,
        'fechaEmision': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance.collection('trabajos').doc(widget.jobId).update({
        'estado': 'revision_cliente',
        'reporteTecnico': reporte,
        'tiempoCompletado': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reporte enviado al cliente'), backgroundColor: Colors.green));
      Navigator.pop(context);
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
      appBar: const BrandedAppBar(),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionHeader(title: 'Generar Reporte Técnico', subtitle: 'Llene la constancia de servicio para el cliente'),
              
              PremiumCard(
                accentColor: cAzul,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('INFO DEL TÉCNICO', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                    const SizedBox(height: 12),
                    TextFormField(initialValue: widget.userData['nombre'], decoration: const InputDecoration(labelText: 'Nombre Completo'), readOnly: true),
                    const SizedBox(height: 16),
                    TextFormField(controller: _cedulaEncargadoCtrl, decoration: const InputDecoration(labelText: 'Cédula N°', hintText: 'Ingrese su identificación'), keyboardType: TextInputType.number, validator: (v) => v!.isEmpty ? 'Requerido' : null),
                  ],
                ),
              ),

              PremiumCard(
                accentColor: cFucsia,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('TIPO DE INTERVENCIÓN', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _tipoServicio,
                      decoration: const InputDecoration(hintText: 'Seleccione el servicio ejecutado'),
                      items: _tipos.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                      onChanged: (v) => setState(() => _tipoServicio = v),
                      validator: (v) => v == null ? 'Seleccione una opción' : null,
                    ),
                  ],
                ),
              ),

              _buildDynamicSection('Detalles del Equipo', _equipos, _addEquipo, _removeEquipo, (i) => [
                TextFormField(controller: _equipos[i]['equipoMarca'], decoration: const InputDecoration(labelText: 'Equipo / Marca'), validator: (v) => v!.trim().isEmpty ? 'Requerido' : null),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: TextFormField(controller: _equipos[i]['modelo'], decoration: const InputDecoration(labelText: 'Modelo'))),
                  const SizedBox(width: 12),
                  Expanded(child: TextFormField(controller: _equipos[i]['contador'], decoration: const InputDecoration(labelText: 'Contador'))),
                ]),
              ]),

              _buildDynamicSection('Trabajo Realizado', _detalles, _addDetalle, _removeDetalle, (i) => [
                TextFormField(controller: _detalles[i]['diagnostico'], decoration: const InputDecoration(labelText: 'Diagnóstico'), validator: (v) => v!.trim().isEmpty ? 'Requerido' : null),
                const SizedBox(height: 12),
                TextFormField(controller: _detalles[i]['solucion'], decoration: const InputDecoration(labelText: 'Solución Técnica')),
              ]),

              _buildDynamicSection('Insumos Utilizados', _insumos, _addInsumo, _removeInsumo, (i) => [
                TextFormField(controller: _insumos[i]['descripcion'], decoration: const InputDecoration(labelText: 'Descripción del Insumo (Opcional)')),
                const SizedBox(height: 12),
                TextFormField(controller: _insumos[i]['cantidad'], decoration: const InputDecoration(labelText: 'Cantidad'), keyboardType: TextInputType.number),
              ]),

              PremiumCard(
                accentColor: cAmarillo,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('LIQUIDACIÓN DE SERVICIOS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _costoServicioCtrl,
                            decoration: const InputDecoration(labelText: 'Costo Empresa (\$)', hintText: '0'),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _costoTecnicoCtrl,
                            decoration: const InputDecoration(labelText: 'Costo Técnico (\$)', hintText: '0'),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: cFucsia),
                  onPressed: _isSending ? null : _enviarReporte,
                  icon: _isSending ? const SizedBox() : const Icon(Icons.send_rounded, color: Colors.white),
                  label: _isSending 
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('ENVIAR REPORTE AL CLIENTE', style: TextStyle(fontWeight: FontWeight.w900, color: Colors.white, fontSize: 14)),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDynamicSection(String title, List items, VoidCallback onAdd, void Function(int) onRemove, List<Widget> Function(int) builder) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            SectionHeader(title: title),
            IconButton(icon: const Icon(Icons.add_circle_rounded, color: cAzul), onPressed: onAdd),
          ],
        ),
        for (int i = 0; i < items.length; i++) ...[
          PremiumCard(
            accentColor: cAzul.withValues(alpha: 0.5),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (items.length > 1)
                  Align(
                    alignment: Alignment.topRight,
                    child: InkWell(
                      onTap: () => onRemove(i),
                      child: const Padding(
                        padding: EdgeInsets.only(bottom: 12.0),
                        child: Icon(Icons.remove_circle_outline, color: Colors.redAccent, size: 22),
                      ),
                    ),
                  ),
                ...builder(i),
              ],
            ),
          ),
        ],
      ],
    );
  }
}


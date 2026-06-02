import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/constants.dart';
import '../../shared/widgets/premium_widgets.dart';

class SubTrabajoState {
  String tipo;
  TextEditingController ventaValorCtrl = TextEditingController();
  TextEditingController ventaCondicionesCtrl = TextEditingController();
  TextEditingController alquilerMesesCtrl = TextEditingController();
  TextEditingController alquilerValorMensualCtrl = TextEditingController();
  
  List<Map<String, TextEditingController>> equipos = [];
  List<Map<String, TextEditingController>> detalles = [];
  List<Map<String, TextEditingController>> insumos = [];

  SubTrabajoState({this.tipo = 'Mantenimiento'}) {
    addEquipo();
    addDetalle();
    addInsumo();
  }

  void addEquipo() {
    equipos.add({'equipoMarca': TextEditingController(), 'modelo': TextEditingController(), 'contador': TextEditingController()});
  }
  void removeEquipo(int index) {
    if (equipos.length > 1) {
      for (final c in equipos[index].values) { c.dispose(); }
      equipos.removeAt(index);
    }
  }

  void addDetalle() {
    detalles.add({'diagnostico': TextEditingController(), 'solucion': TextEditingController()});
  }
  void removeDetalle(int index) {
    if (detalles.length > 1) {
      for (final c in detalles[index].values) { c.dispose(); }
      detalles.removeAt(index);
    }
  }

  void addInsumo() {
    insumos.add({'descripcion': TextEditingController(), 'cantidad': TextEditingController()});
  }
  void removeInsumo(int index) {
    if (insumos.length > 1) {
      for (final c in insumos[index].values) { c.dispose(); }
      insumos.removeAt(index);
    }
  }

  void dispose() {
    ventaValorCtrl.dispose();
    ventaCondicionesCtrl.dispose();
    alquilerMesesCtrl.dispose();
    alquilerValorMensualCtrl.dispose();
    for (final m in [...equipos, ...detalles, ...insumos]) {
      for (final c in m.values) { c.dispose(); }
    }
  }
}

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
  
  final List<SubTrabajoState> _trabajos = [];

  final _costoServicioCtrl = TextEditingController();
  final _costoTecnicoCtrl = TextEditingController();

  final List<String> _tiposTrabajo = ['Mantenimiento', 'Venta', 'Alquiler'];

  @override
  void initState() {
    super.initState();
    _trabajos.add(SubTrabajoState());
  }

  void _agregarSubTrabajo() {
    setState(() {
      _trabajos.add(SubTrabajoState());
    });
  }

  void _eliminarSubTrabajo(int index) {
    if (_trabajos.length > 1) {
      _trabajos[index].dispose();
      setState(() {
        _trabajos.removeAt(index);
      });
    }
  }

  @override
  void dispose() {
    _cedulaEncargadoCtrl.dispose();
    _costoServicioCtrl.dispose();
    _costoTecnicoCtrl.dispose();
    for (var t in _trabajos) {
      t.dispose();
    }
    super.dispose();
  }

  Future<void> _enviarReporte() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Complete los campos obligatorios')));
      return;
    }

    setState(() => _isSending = true);
    try {
      List<Map<String, dynamic>> trabajosReportados = [];

      for (var t in _trabajos) {
        final Map<String, dynamic> trabajoData = {
          'tipo': t.tipo,
          'equipos': t.equipos
            .where((e) => e['equipoMarca']!.text.trim().isNotEmpty)
            .map((e) => {
              'equipoMarca': e['equipoMarca']!.text.trim(), 
              'modelo': e['modelo']!.text.trim(), 
              'contador': e['contador']!.text.trim()
            }).toList(),
          'detallesTecnicos': t.detalles
            .where((d) => d['diagnostico']!.text.trim().isNotEmpty || d['solucion']!.text.trim().isNotEmpty)
            .map((d) => {
              'diagnostico': d['diagnostico']!.text.trim(), 
              'solucion': d['solucion']!.text.trim()
            }).toList(),
          'insumos': t.insumos
            .where((i) => i['descripcion']!.text.trim().isNotEmpty)
            .map((i) => {
              'descripcion': i['descripcion']!.text.trim(), 
              'cantidad': i['cantidad']!.text.trim()
            }).toList(),
        };

        if (t.tipo == 'Venta') {
          trabajoData['ventaValor'] = double.tryParse(t.ventaValorCtrl.text.trim()) ?? 0.0;
          trabajoData['ventaCondiciones'] = t.ventaCondicionesCtrl.text.trim();
        } else if (t.tipo == 'Alquiler') {
          trabajoData['alquilerMeses'] = int.tryParse(t.alquilerMesesCtrl.text.trim()) ?? 0;
          trabajoData['alquilerValorMensual'] = double.tryParse(t.alquilerValorMensualCtrl.text.trim()) ?? 0.0;
        }

        trabajosReportados.add(trabajoData);
      }

      final reporte = {
        'encargadoNombre': widget.userData['nombre'],
        'encargadoCedula': _cedulaEncargadoCtrl.text.trim(),
        'trabajosReportados': trabajosReportados,
        'costoEmpresa': double.tryParse(_costoServicioCtrl.text.trim()) ?? 0.0,
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

              ...List.generate(_trabajos.length, (index) {
                final t = _trabajos[index];
                return Padding(
                  padding: const EdgeInsets.only(top: 16.0),
                  child: PremiumCard(
                    accentColor: cFucsia,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('TRABAJO #${index + 1}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: cTextoOscuro)),
                            if (_trabajos.length > 1)
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.red),
                                onPressed: () => _eliminarSubTrabajo(index),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          value: t.tipo,
                          decoration: const InputDecoration(labelText: 'Tipo de Intervención'),
                          items: _tiposTrabajo.map((tp) => DropdownMenuItem(value: tp, child: Text(tp))).toList(),
                          onChanged: (v) => setState(() => t.tipo = v!),
                        ),
                        const SizedBox(height: 16),

                        if (t.tipo == 'Venta') ...[
                          const Text('DATOS DE VENTA', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: t.ventaValorCtrl,
                            decoration: const InputDecoration(labelText: 'Valor de Venta (\$)'),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: t.ventaCondicionesCtrl,
                            decoration: const InputDecoration(labelText: 'Condiciones o Garantía'),
                          ),
                          const SizedBox(height: 16),
                        ],

                        if (t.tipo == 'Alquiler') ...[
                          const Text('DATOS DE ALQUILER', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: t.alquilerMesesCtrl,
                            decoration: const InputDecoration(labelText: 'Duración (Meses)'),
                            keyboardType: TextInputType.number,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: t.alquilerValorMensualCtrl,
                            decoration: const InputDecoration(labelText: 'Valor Mensual (\$)'),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          ),
                          const SizedBox(height: 16),
                        ],

                        _buildDynamicSection('Detalles del Equipo', t.equipos, () => setState(() => t.addEquipo()), () => setState(() => t.removeEquipo(t.equipos.length - 1)), (i) => [
                          TextFormField(controller: t.equipos[i]['equipoMarca'], decoration: const InputDecoration(labelText: 'Equipo / Marca'), validator: (v) => v!.trim().isEmpty ? 'Requerido' : null),
                          const SizedBox(height: 12),
                          Row(children: [
                            Expanded(child: TextFormField(controller: t.equipos[i]['modelo'], decoration: const InputDecoration(labelText: 'Modelo'))),
                            const SizedBox(width: 12),
                            Expanded(child: TextFormField(controller: t.equipos[i]['contador'], decoration: const InputDecoration(labelText: 'Contador'))),
                          ]),
                        ]),

                        _buildDynamicSection('Trabajo Realizado', t.detalles, () => setState(() => t.addDetalle()), () => setState(() => t.removeDetalle(t.detalles.length - 1)), (i) => [
                          TextFormField(controller: t.detalles[i]['diagnostico'], decoration: const InputDecoration(labelText: 'Diagnóstico'), validator: (v) => v!.trim().isEmpty ? 'Requerido' : null),
                          const SizedBox(height: 12),
                          TextFormField(controller: t.detalles[i]['solucion'], decoration: const InputDecoration(labelText: 'Solución Técnica')),
                        ]),

                        _buildDynamicSection('Insumos Utilizados', t.insumos, () => setState(() => t.addInsumo()), () => setState(() => t.removeInsumo(t.insumos.length - 1)), (i) => [
                          TextFormField(controller: t.insumos[i]['descripcion'], decoration: const InputDecoration(labelText: 'Descripción del Insumo (Opcional)')),
                          const SizedBox(height: 12),
                          TextFormField(controller: t.insumos[i]['cantidad'], decoration: const InputDecoration(labelText: 'Cantidad'), keyboardType: TextInputType.number),
                        ]),
                      ],
                    ),
                  ),
                );
              }),

              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _agregarSubTrabajo,
                  icon: const Icon(Icons.add_circle_outline),
                  label: const Text('Añadir Otro Trabajo'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: cAzul,
                    side: const BorderSide(color: cAzul, width: 2),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              PremiumCard(
                accentColor: cAmarillo,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('LIQUIDACIÓN TOTAL', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _costoServicioCtrl,
                            decoration: const InputDecoration(labelText: 'Costo Empresa (\$)', hintText: '0'), // guardado como costoEmpresa
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

  Widget _buildDynamicSection(String title, List items, VoidCallback onAdd, VoidCallback onRemove, List<Widget> Function(int) builder) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Text(title, style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.grey, fontSize: 11)),
            ),
            Row(
              children: [
                if (items.length > 1)
                  IconButton(icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent, size: 20), onPressed: onRemove, padding: EdgeInsets.zero, constraints: const BoxConstraints()),
                const SizedBox(width: 8),
                IconButton(icon: const Icon(Icons.add_circle_rounded, color: cAzul, size: 20), onPressed: onAdd, padding: EdgeInsets.zero, constraints: const BoxConstraints()),
              ],
            )
          ],
        ),
        for (int i = 0; i < items.length; i++) ...[
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: cAzul.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: cAzul.withValues(alpha: 0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ...builder(i),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

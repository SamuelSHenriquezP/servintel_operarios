import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/constants.dart';
import '../../shared/widgets/premium_widgets.dart';

class SubTrabajoState {
  String tipo;

  // Equipo
  TextEditingController idPropioCtrl = TextEditingController();
  TextEditingController marcaCtrl = TextEditingController();
  TextEditingController modeloCtrl = TextEditingController();
  TextEditingController serialCtrl = TextEditingController();
  TextEditingController contadorCtrl = TextEditingController();

  // Mantenimiento
  TextEditingController diagnosticoCtrl = TextEditingController();
  TextEditingController solucionCtrl = TextEditingController();
  TextEditingController insumosCtrl = TextEditingController();

  // Venta
  TextEditingController ventaDescripcionCtrl = TextEditingController();
  TextEditingController ventaValorCtrl = TextEditingController();
  TextEditingController ventaGarantiaCtrl = TextEditingController();

  // Alquiler
  TextEditingController alquilerCondicionesCtrl = TextEditingController();
  TextEditingController alquilerDuracionCtrl = TextEditingController();
  TextEditingController alquilerValorMensualCtrl = TextEditingController();

  SubTrabajoState({this.tipo = 'Mantenimiento'});

  void dispose() {
    idPropioCtrl.dispose();
    marcaCtrl.dispose();
    modeloCtrl.dispose();
    serialCtrl.dispose();
    contadorCtrl.dispose();

    diagnosticoCtrl.dispose();
    solucionCtrl.dispose();
    insumosCtrl.dispose();

    ventaDescripcionCtrl.dispose();
    ventaValorCtrl.dispose();
    ventaGarantiaCtrl.dispose();

    alquilerCondicionesCtrl.dispose();
    alquilerDuracionCtrl.dispose();
    alquilerValorMensualCtrl.dispose();
  }
}

class ReporteTecnicoScreen extends StatefulWidget {
  final Map<String, dynamic> userData;
  final String jobId;
  final Map<String, dynamic>? jobData;

  const ReporteTecnicoScreen({
    super.key,
    required this.userData,
    required this.jobId,
    this.jobData,
  });

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
    final firstTrabajo = SubTrabajoState();
    if (widget.jobData != null) {
      firstTrabajo.idPropioCtrl.text = widget.jobData!['maquinaIdPropio']?.toString() ?? '';
      firstTrabajo.modeloCtrl.text = widget.jobData!['maquinaModelo']?.toString() ?? '';
      firstTrabajo.serialCtrl.text = widget.jobData!['maquinaSerial']?.toString() ?? '';
    }
    _trabajos.add(firstTrabajo);
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Complete los campos obligatorios')),
      );
      return;
    }

    setState(() => _isSending = true);
    try {
      List<Map<String, dynamic>> trabajosReportados = [];

      for (var t in _trabajos) {
        final Map<String, dynamic> trabajoData = {
          'tipo': t.tipo,
        };

        final brand = t.marcaCtrl.text.trim();
        final model = t.modeloCtrl.text.trim();
        final ownId = t.idPropioCtrl.text.trim();
        final serialNum = t.serialCtrl.text.trim();
        final counter = t.contadorCtrl.text.trim();

        if (brand.isNotEmpty) trabajoData['marca'] = brand;
        if (model.isNotEmpty) trabajoData['modelo'] = model;
        if (ownId.isNotEmpty) trabajoData['idPropio'] = ownId;
        if (serialNum.isNotEmpty) trabajoData['serial'] = serialNum;
        if (counter.isNotEmpty) trabajoData['contador'] = counter;

        bool hasValidData = false;

        if (t.tipo == 'Mantenimiento') {
          final diag = t.diagnosticoCtrl.text.trim();
          final sol = t.solucionCtrl.text.trim();
          final ins = t.insumosCtrl.text.trim();

          if (diag.isNotEmpty) trabajoData['diagnostico'] = diag;
          if (sol.isNotEmpty) trabajoData['solucion'] = sol;
          if (ins.isNotEmpty) trabajoData['insumos'] = ins;

          if (brand.isNotEmpty || model.isNotEmpty || diag.isNotEmpty || sol.isNotEmpty) {
            hasValidData = true;
          }
        } else if (t.tipo == 'Venta') {
          final desc = t.ventaDescripcionCtrl.text.trim();
          final valorStr = t.ventaValorCtrl.text.trim();
          final gar = t.ventaGarantiaCtrl.text.trim();

          if (desc.isNotEmpty) trabajoData['descripcion'] = desc;
          if (valorStr.isNotEmpty) {
            trabajoData['valor'] = num.tryParse(valorStr) ?? 0;
          }
          if (gar.isNotEmpty) trabajoData['garantia'] = gar;

          if (brand.isNotEmpty || model.isNotEmpty || desc.isNotEmpty || valorStr.isNotEmpty) {
            hasValidData = true;
          }
        } else if (t.tipo == 'Alquiler') {
          final cond = t.alquilerCondicionesCtrl.text.trim();
          final duracionStr = t.alquilerDuracionCtrl.text.trim();
          final valorMensualStr = t.alquilerValorMensualCtrl.text.trim();

          if (cond.isNotEmpty) trabajoData['condiciones'] = cond;
          if (duracionStr.isNotEmpty) {
            trabajoData['duracion'] = num.tryParse(duracionStr) ?? 0;
          }
          if (valorMensualStr.isNotEmpty) {
            trabajoData['valorMensual'] = num.tryParse(valorMensualStr) ?? 0;
          }

          if (brand.isNotEmpty || model.isNotEmpty || cond.isNotEmpty || valorMensualStr.isNotEmpty) {
            hasValidData = true;
          }
        }

        if (hasValidData) {
          trabajosReportados.add(trabajoData);
        }
      }

      if (trabajosReportados.isEmpty) {
        setState(() => _isSending = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Debe agregar al menos un trabajo válido en el reporte'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final reporte = {
        'encargadoNombre': widget.userData['nombre'],
        'encargadoCedula': _cedulaEncargadoCtrl.text.trim(),
        'trabajosReportados': trabajosReportados,
        'costoEmpresa': double.tryParse(_costoServicioCtrl.text.trim()) ?? 0.0,
        'costoTecnico': double.tryParse(_costoTecnicoCtrl.text.trim()) ?? 0.0,
        'fechaEmision': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance
          .collection('trabajos')
          .doc(widget.jobId)
          .update({
            'estado': 'revision_cliente',
            'reporteTecnico': reporte,
            'tiempoCompletado': FieldValue.serverTimestamp(),
          });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Reporte enviado al cliente'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
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
              const SectionHeader(
                title: 'Generar Reporte Técnico',
                subtitle: 'Llene la constancia de servicio para el cliente',
              ),

              PremiumCard(
                accentColor: cAzul,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'INFO DEL TÉCNICO',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      initialValue: widget.userData['nombre'],
                      decoration: const InputDecoration(
                        labelText: 'Nombre Completo',
                      ),
                      readOnly: true,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _cedulaEncargadoCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Cédula N°',
                        hintText: 'Ingrese su identificación',
                      ),
                      keyboardType: TextInputType.number,
                      validator: (v) => v!.isEmpty ? 'Requerido' : null,
                    ),
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
                            Text(
                              'TRABAJO #${index + 1}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: cTextoOscuro,
                              ),
                            ),
                            if (_trabajos.length > 1)
                              IconButton(
                                icon: const Icon(
                                  Icons.delete_outline,
                                  color: Colors.red,
                                ),
                                onPressed: () => _eliminarSubTrabajo(index),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: t.tipo,
                          decoration: const InputDecoration(
                            labelText: 'Tipo de Intervención',
                          ),
                          items: _tiposTrabajo
                              .map(
                                (tp) => DropdownMenuItem(
                                  value: tp,
                                  child: Text(tp),
                                ),
                              )
                              .toList(),
                          onChanged: (v) => setState(() => t.tipo = v!),
                        ),
                        const SizedBox(height: 16),

                        if (t.tipo == 'Venta') ...[
                          const Text(
                            'DATOS DE VENTA',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: t.ventaDescripcionCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Detalle Venta',
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: t.ventaValorCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Valor de Venta (\$)',
                            ),
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: t.ventaGarantiaCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Garantía',
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        if (t.tipo == 'Alquiler') ...[
                          const Text(
                            'DATOS DE ALQUILER',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: t.alquilerCondicionesCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Condiciones',
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: t.alquilerDuracionCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Duración (Meses)',
                            ),
                            keyboardType: TextInputType.number,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: t.alquilerValorMensualCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Valor Mensual (\$)',
                            ),
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        const Text('EQUIPO', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(child: TextFormField(controller: t.idPropioCtrl, decoration: const InputDecoration(labelText: 'ID Propio (Opcional)'))),
                            const SizedBox(width: 8),
                            Expanded(child: TextFormField(controller: t.serialCtrl, decoration: const InputDecoration(labelText: 'Serial (Opcional)'))),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(child: TextFormField(controller: t.marcaCtrl, decoration: const InputDecoration(labelText: 'Marca'))),
                            const SizedBox(width: 8),
                            Expanded(child: TextFormField(controller: t.modeloCtrl, decoration: const InputDecoration(labelText: 'Modelo'))),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextFormField(controller: t.contadorCtrl, decoration: const InputDecoration(labelText: 'Contador (Opcional)')),
                        const SizedBox(height: 16),

                        if (t.tipo == 'Mantenimiento') ...[
                          const Text('INTERVENCIÓN', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: t.diagnosticoCtrl,
                            decoration: const InputDecoration(labelText: 'Diagnóstico'),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: t.solucionCtrl,
                            decoration: const InputDecoration(labelText: 'Solución'),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: t.insumosCtrl,
                            decoration: const InputDecoration(labelText: 'Insumos / Repuestos'),
                          ),
                        ]
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
                    const Text(
                      'LIQUIDACIÓN TOTAL',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _costoServicioCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Costo Empresa (\$)',
                              hintText: '0',
                            ), // guardado como costoEmpresa
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _costoTecnicoCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Costo Técnico (\$)',
                              hintText: '0',
                            ),
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
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
                  icon: _isSending
                      ? const SizedBox()
                      : const Icon(Icons.send_rounded, color: Colors.white),
                  label: _isSending
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'ENVIAR REPORTE AL CLIENTE',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            fontSize: 14,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}

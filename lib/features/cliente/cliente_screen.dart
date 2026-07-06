import 'dart:math';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/constants.dart';
import '../../shared/widgets/premium_widgets.dart';
import 'visto_bueno_screen.dart';
import 'mapa_cliente_screen.dart';
import 'calificacion_screen.dart';

class ClienteScreen extends StatefulWidget {
  final Map<String, dynamic> userData;
  const ClienteScreen({super.key, required this.userData});

  @override
  State<ClienteScreen> createState() => _ClienteScreenState();
}

class _ClienteScreenState extends State<ClienteScreen> {
  final _descCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String? _categoriaSel;
  late Stream<QuerySnapshot> _historialStream;

  // --- ESTADO DE SELECCIÓN DE MÁQUINAS ---
  // Map de índice → TextEditingController de descripción por máquina
  final Map<int, TextEditingController> _maqDescControllers = {};
  final Set<int> _maqsSeleccionadas = {};
  bool _enviandoLote = false;

  @override
  void initState() {
    super.initState();
    _historialStream = FirebaseFirestore.instance
        .collection('trabajos')
        .where('clienteId', isEqualTo: FirebaseAuth.instance.currentUser!.uid)
        .orderBy('creadoEn', descending: true)
        .limit(10)
        .snapshots();
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    for (final c in _maqDescControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  List<Map<String, dynamic>> get _maquinas {
    final raw = widget.userData['maquinas'];
    if (raw == null || raw is! List) return [];
    return List<Map<String, dynamic>>.from(raw.map((m) => Map<String, dynamic>.from(m)));
  }

  void _toggleMaquina(int index, bool selected) {
    setState(() {
      if (selected) {
        _maqsSeleccionadas.add(index);
        _maqDescControllers.putIfAbsent(index, () => TextEditingController());
      } else {
        _maqsSeleccionadas.remove(index);
        _maqDescControllers[index]?.dispose();
        _maqDescControllers.remove(index);
      }
    });
  }

  Future<void> _enviarSolicitudConMaquinas() async {
    if (_categoriaSel == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Seleccione el área técnica'), backgroundColor: Colors.red),
      );
      return;
    }

    // Validar que todas las máquinas seleccionadas tienen descripción
    for (final idx in _maqsSeleccionadas) {
      final desc = _maqDescControllers[idx]?.text.trim() ?? '';
      if (desc.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Describa el problema para cada máquina seleccionada.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    setState(() => _enviandoLote = true);

    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final clienteNombre = widget.userData['nombre'] ?? 'Cliente';
      final maquinas = _maquinas;
      final List<Future> futures = [];

      for (final idx in _maqsSeleccionadas) {
        final m = maquinas[idx];
        final descMaq = _maqDescControllers[idx]!.text.trim();
        final pinCode = (Random.secure().nextInt(9000) + 1000).toString();
        final descripcionTicket =
            '${m['idPropio'] != null ? "[${m['idPropio']}] " : ""}${m['modelo'] ?? ""}:\n$descMaq';
        final direccionBase = [
          m['ubicacionLocal'],
          m['direccion'],
          m['barrio'],
          m['ciudad'],
        ].where((v) => v != null && v.toString().isNotEmpty).join(', ');

        futures.add(
          FirebaseFirestore.instance.collection('trabajos').add({
            'clienteId': uid,
            'clienteNombre': clienteNombre,
            'categoria': _categoriaSel!,
            'servicio': _categoriaSel!,
            'descripcion': descripcionTicket,
            'direccionText': direccionBase.isNotEmpty ? direccionBase : (widget.userData['direccion'] ?? ''),
            'lat': m['lat'],
            'lng': m['lng'],
            'maquinaIdPropio': m['idPropio'],
            'maquinaModelo': m['modelo'],
            'maquinaSerial': m['serial'],
            'pinCode': pinCode,
            'estado': 'solicitado',
            'creadoEn': FieldValue.serverTimestamp(),
            'operarioId': null,
            'operarioNombre': null,
          }),
        );
      }

      await Future.wait(futures);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('🚀 ¡Se enviaron ${_maqsSeleccionadas.length} requerimiento(s) al despacho!'),
          backgroundColor: Colors.green,
        ),
      );

      // Limpiar selección
      setState(() {
        _maqsSeleccionadas.clear();
        for (final c in _maqDescControllers.values) {
          c.dispose();
        }
        _maqDescControllers.clear();
        _categoriaSel = null;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _enviandoLote = false);
    }
  }

  Future<void> _enviarSolicitudGeneral() async {
    if (!_formKey.currentState!.validate()) return;

    final categoria = _categoriaSel!;
    final desc = _descCtrl.text.trim();

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MapaClienteScreen(
          userData: widget.userData,
          categoria: categoria,
          descripcion: desc,
        ),
      ),
    );

    if (result == true) {
      _descCtrl.clear();
      setState(() => _categoriaSel = null);
    }
  }

  Future<void> _onPresionarContinuar() async {
    if (_maqsSeleccionadas.isNotEmpty) {
      await _enviarSolicitudConMaquinas();
    } else {
      await _enviarSolicitudGeneral();
    }
  }

  @override
  Widget build(BuildContext context) {
    final maquinas = _maquinas;
    final tieneMaquinas = maquinas.isNotEmpty;

    return Scaffold(
      appBar: BrandedAppBar(
        actions: [
          IconButton(
            icon: const Icon(Icons.power_settings_new_rounded, color: Colors.grey),
            onPressed: () => FirebaseAuth.instance.signOut(),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // WELCOME HEADER
            const Text(
              'PLATAFORMA DE SERVICIO',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: cAzul, letterSpacing: 1.5),
            ),
            const SizedBox(height: 8),
            Text(
              'Hola, ${widget.userData['nombre'] ?? 'Cliente'}',
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: cTextoOscuro, letterSpacing: -1),
            ),
            const SizedBox(height: 32),

            // REQUEST CARD
            PremiumCard(
              accentColor: cFucsia,
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.headset_mic_rounded, color: cFucsia, size: 20),
                        SizedBox(width: 10),
                        Text('SOLICITAR INTERVENCIÓN', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: cTextoOscuro)),
                      ],
                    ),
                    const SizedBox(height: 24),
                    const Text('ÁREA TÉCNICA', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: _categoriaSel,
                      decoration: const InputDecoration(hintText: 'Seleccione el servicio...'),
                      items: kCategorias.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                      onChanged: (v) => setState(() => _categoriaSel = v),
                      validator: (v) => v == null ? 'Seleccione una categoría' : null,
                    ),
                    const SizedBox(height: 20),

                    // ──── SECCIÓN MÁQUINAS DEL CLIENTE ────
                    if (tieneMaquinas) ...[
                      Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: cAzul.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: cAzul.withValues(alpha: 0.25)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.print_rounded, color: cAzul, size: 16),
                                SizedBox(width: 6),
                                Text(
                                  'MÁQUINA(S) CON FALLA',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: cAzul, letterSpacing: 0.8),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Seleccione las máquinas afectadas. Si no selecciona ninguna, puede describirlo abajo.',
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                            ),
                            const SizedBox(height: 10),
                            ...maquinas.asMap().entries.map((entry) {
                              final idx = entry.key;
                              final m = entry.value;
                              final isSelected = _maqsSeleccionadas.contains(idx);
                              return AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                margin: const EdgeInsets.only(bottom: 8),
                                decoration: BoxDecoration(
                                  color: isSelected ? cAzul.withValues(alpha: 0.08) : Colors.white,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: isSelected ? cAzul : const Color(0xFFE2E8F0),
                                    width: isSelected ? 1.5 : 1,
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    CheckboxListTile(
                                      dense: true,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                      value: isSelected,
                                      activeColor: cAzul,
                                      onChanged: (v) => _toggleMaquina(idx, v ?? false),
                                      title: Text(
                                        '${m['idPropio'] != null ? "[${m['idPropio']}] " : ""}${m['modelo'] ?? 'Sin modelo'}',
                                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: cTextoOscuro),
                                      ),
                                      subtitle: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          if (m['serial'] != null)
                                            Text('Serie: ${m['serial']}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                          if (m['ubicacionLocal'] != null)
                                            Text('📍 ${m['ubicacionLocal']}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                        ],
                                      ),
                                      secondary: m['lat'] != null
                                          ? Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                              decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(6)),
                                              child: const Text('GPS', style: TextStyle(fontSize: 10, color: Colors.green, fontWeight: FontWeight.bold)),
                                            )
                                          : null,
                                    ),
                                    // Campo de descripción por máquina (solo cuando está seleccionada)
                                    if (isSelected) ...[
                                      Padding(
                                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                                        child: TextFormField(
                                          controller: _maqDescControllers[idx],
                                          maxLines: 2,
                                          decoration: InputDecoration(
                                            hintText: 'Describa el problema de esta máquina...',
                                            fillColor: Colors.white,
                                            filled: true,
                                            border: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(8),
                                              borderSide: BorderSide(color: cAzul.withValues(alpha: 0.3)),
                                            ),
                                            contentPadding: const EdgeInsets.all(10),
                                          ),
                                          style: const TextStyle(fontSize: 13),
                                          validator: isSelected
                                              ? (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null
                                              : null,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                    ],

                    // ──── DESCRIPCIÓN GENERAL (cuando no hay máquinas seleccionadas) ────
                    if (!tieneMaquinas || _maqsSeleccionadas.isEmpty) ...[
                      const Text('DIAGNÓSTICO INICIAL', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _descCtrl,
                        maxLines: 4,
                        decoration: const InputDecoration(hintText: 'Describa el problema lo más detallado posible...'),
                        validator: _maqsSeleccionadas.isEmpty
                            ? (v) => (v == null || v.trim().length < 10) ? 'Detalle más el problema' : null
                            : null,
                      ),
                    ],

                    const SizedBox(height: 24),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: cFucsia,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: _enviandoLote ? null : _onPresionarContinuar,
                        icon: _enviandoLote
                            ? const SizedBox(
                                width: 18, height: 18,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : Icon(_maqsSeleccionadas.isNotEmpty ? Icons.send_rounded : Icons.location_searching_rounded),
                        label: Text(
                          _enviandoLote
                              ? 'ENVIANDO...'
                              : _maqsSeleccionadas.isNotEmpty
                                  ? 'ENVIAR ${_maqsSeleccionadas.length} REQUERIMIENTO(S)'
                                  : 'CONTINUAR A UBICACIÓN',
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SectionHeader(
              title: 'Historial de Requerimientos',
              subtitle: 'Sus últimas 10 solicitudes de servicio',
            ),

            // LIST OF REQUESTS
            StreamBuilder<QuerySnapshot>(
              stream: _historialStream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red)));
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Text('No hay solicitudes registradas.', style: TextStyle(color: Colors.grey)),
                    ),
                  );
                }

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    final job = snapshot.data!.docs[index];
                    final data = job.data() as Map<String, dynamic>;
                    final String estado = data['estado'] ?? 'solicitado';
                    final bool isFinished =
                        estado == 'evaluado_cliente' || estado == 'cerrado' || estado == 'completado';
                    final bool pinVisible = data['pinCode'] != null &&
                        !isFinished &&
                        estado != 'revision_cliente';

                    return PremiumCard(
                      accentColor: getColorEstado(estado),
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: getColorEstado(estado).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  estado.toUpperCase().replaceAll('_', ' '),
                                  style: TextStyle(color: getColorEstado(estado), fontSize: 9, fontWeight: FontWeight.w900),
                                ),
                              ),
                              Text(
                                '#${job.id.substring(job.id.length - 6).toUpperCase()}',
                                style: TextStyle(color: Colors.grey.withValues(alpha: 0.4), fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            data['categoria'] ?? data['servicio'] ?? 'General',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: cTextoOscuro),
                          ),
                          // Máquina asociada si viene de ese flujo
                          if (data['maquinaModelo'] != null) ...[
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(Icons.print_rounded, size: 13, color: cAzul),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    '${data['maquinaIdPropio'] != null ? "[${data['maquinaIdPropio']}] " : ""}${data['maquinaModelo']}',
                                    style: const TextStyle(fontSize: 12, color: cAzul, fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ],
                            ),
                          ],
                          if (data['direccionText'] != null && data['direccionText'].toString().isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                const Icon(Icons.location_on_rounded, size: 14, color: cFucsia),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    data['direccionText'],
                                    style: const TextStyle(fontSize: 13, color: cTextoOscuro, fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 6),
                          Text(
                            data['descripcion'] ?? '',
                            style: const TextStyle(fontSize: 13, color: Colors.grey, height: 1.4),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const Divider(height: 32),
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 14,
                                backgroundColor: (data['operarioNombre'] != null ? cAzul : Colors.grey).withValues(alpha: 0.1),
                                child: Icon(
                                  Icons.engineering_rounded,
                                  size: 14,
                                  color: data['operarioNombre'] != null ? cAzul : Colors.grey,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('ESPECIALISTA', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: Colors.grey)),
                                    Text(
                                      data['operarioNombre'] ?? 'Asignando...',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: data['operarioNombre'] != null ? cTextoOscuro : Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          // ──── BOTÓN: REVISAR Y APROBAR ────
                          if (estado == 'revision_cliente') ...[
                            const SizedBox(height: 20),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(backgroundColor: cAzul),
                                onPressed: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => VistoBuenoScreen(data: data, jobId: job.id)),
                                ),
                                child: const Text(
                                  'REVISAR Y APROBAR',
                                  style: TextStyle(fontWeight: FontWeight.w900, color: Colors.white),
                                ),
                              ),
                            ),
                          ],

                          // ──── BOTÓN: VER DIAGNÓSTICO APROBADO ────
                          if (isFinished && data['reporteTecnico'] != null) ...[
                            const SizedBox(height: 20),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: cAzul,
                                  side: const BorderSide(color: cAzul),
                                ),
                                onPressed: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => VistoBuenoScreen(data: data, jobId: job.id, isReadOnly: true),
                                  ),
                                ),
                                icon: const Icon(Icons.description_outlined),
                                label: const Text('VER REPORTE TÉCNICO', style: TextStyle(fontWeight: FontWeight.w900)),
                              ),
                            ),
                          ],

                          // ──── BOTÓN: CALIFICAR ────
                          if ((estado == 'completado' || estado == 'cerrado') && data['evaluacionCliente'] == null) ...[
                            const SizedBox(height: 20),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(backgroundColor: cAmarillo, foregroundColor: Colors.white),
                                onPressed: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => CalificacionScreen(data: data, jobId: job.id)),
                                ),
                                icon: const Icon(Icons.star_rate_rounded),
                                label: const Text('CALIFICAR SERVICIO', style: TextStyle(fontWeight: FontWeight.w900)),
                              ),
                            ),
                          ],

                          // ──── PIN DE SEGURIDAD ────
                          if (pinVisible) ...[
                            const SizedBox(height: 20),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEFCE8),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFFEF08A)),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'CÓDIGO PIN SEGURO',
                                        style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Color(0xFF854D0E)),
                                      ),
                                      Text(
                                        data['pinCode'].toString(),
                                        style: const TextStyle(
                                          fontSize: 22, fontWeight: FontWeight.w900, color: cTextoOscuro, letterSpacing: 4,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const Icon(Icons.security_rounded, color: Color(0xFFCA8A04)),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

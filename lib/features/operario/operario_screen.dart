import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/constants.dart';
import '../../shared/widgets/premium_widgets.dart';
import 'trabajos_repository.dart';
import 'reporte_tecnico_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class OperarioScreen extends StatefulWidget {
  final Map<String, dynamic> userData;
  const OperarioScreen({super.key, required this.userData});

  @override
  State<OperarioScreen> createState() => _OperarioScreenState();
}

class _OperarioScreenState extends State<OperarioScreen> {
  final _searchCtrl = TextEditingController();
  List<QueryDocumentSnapshot>? _searchResults;
  bool _isSearching = false;
  late Stream<QuerySnapshot> _activeStream;
  late Stream<QuerySnapshot> _completedStream;

  @override
  void initState() {
    super.initState();
    final uid = FirebaseAuth.instance.currentUser!.uid;
    _activeStream = TrabajosRepository.streamActiveForOperario(uid);
    _completedStream = TrabajosRepository.streamCompletedRecentForOperario(uid);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _buscarTrabajo() async {
    final query = _searchCtrl.text.trim();
    final uid = FirebaseAuth.instance.currentUser!.uid;
    if (query.isEmpty) {
      setState(() => _searchResults = null);
      return;
    }

    setState(() => _isSearching = true);
    try {
      final results = await TrabajosRepository.searchByClienteName(uid, query);
      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
      setState(() => _isSearching = false);
    }
  }

  Future<void> _actualizarEstado(String jobId, String nuevoEstado) async {
    final Map<String, dynamic> updateData = {'estado': nuevoEstado};
    if (nuevoEstado == 'en_camino') updateData['tiempoEnCamino'] = FieldValue.serverTimestamp();
    if (nuevoEstado == 'en_sitio') updateData['tiempoEnSitio'] = FieldValue.serverTimestamp();
    if (nuevoEstado == 'en_progreso') updateData['tiempoInicioTrabajo'] = FieldValue.serverTimestamp();
    if (nuevoEstado == 'esperando_cierre') updateData['tiempoFinTrabajo'] = FieldValue.serverTimestamp();

    try {
      await TrabajosRepository.updateEstado(jobId, updateData);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Estado actualizado'), backgroundColor: Colors.green));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {

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
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            color: Colors.white,
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Buscar cliente...',
                prefixIcon: const Icon(Icons.search_rounded, color: cAzul),
                suffixIcon: ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _searchCtrl,
                  builder: (_, value, __) => value.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () { _searchCtrl.clear(); _buscarTrabajo(); },
                      )
                    : const SizedBox.shrink(),
                ),
              ),
              onSubmitted: (_) => _buscarTrabajo(),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_searchResults != null) ...[
                    const SectionHeader(title: 'Resultados de Búsqueda'),
                    if (_isSearching) const Center(child: CircularProgressIndicator())
                    else if (_searchResults!.isEmpty) const Text('No se encontraron resultados.')
                    else ..._searchResults!.map((job) => _TarjetaOperario(job: job, onActualizar: _actualizarEstado, userData: widget.userData)),
                  ] else ...[
                    // ACTIVE TASKS
                    StreamBuilder<QuerySnapshot>(
                      stream: _activeStream,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()));
                        }
                        if (snapshot.hasError) {
                          // Si hay datos previos en caché, mostrarlos igual
                          if (snapshot.data != null && snapshot.data!.docs.isNotEmpty) {
                            final docs = snapshot.data!.docs;
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SectionHeader(title: 'Tareas Pendientes'),
                                ...docs.map((job) => _TarjetaOperario(job: job, onActualizar: _actualizarEstado, userData: widget.userData)),
                              ],
                            );
                          }
                          return const SizedBox();
                        }
                        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const SizedBox();
                        final docs = List.of(snapshot.data!.docs)
                          ..sort((a, b) {
                            final aTs = (a.data() as Map)['creadoEn'];
                            final bTs = (b.data() as Map)['creadoEn'];
                            if (aTs == null || bTs == null) return 0;
                            return (bTs as Timestamp).compareTo(aTs as Timestamp);
                          });
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SectionHeader(title: 'Tareas Pendientes'),
                            ...docs.map((job) => _TarjetaOperario(job: job, onActualizar: _actualizarEstado, userData: widget.userData)),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 10),
                    // COMPLETED TASKS
                    StreamBuilder<QuerySnapshot>(
                      stream: _completedStream,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const SizedBox();
                        }
                        if (snapshot.hasError) {
                          if (snapshot.data != null && snapshot.data!.docs.isNotEmpty) {
                            final docs = snapshot.data!.docs;
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SectionHeader(title: 'Recién Completadas'),
                                ...docs.map((job) => _TarjetaOperario(job: job, onActualizar: (_, __) {}, userData: widget.userData)),
                              ],
                            );
                          }
                          return const SizedBox();
                        }
                        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const SizedBox();
                        final docs = List.of(snapshot.data!.docs)
                          ..sort((a, b) {
                            final aTs = (a.data() as Map)['creadoEn'];
                            final bTs = (b.data() as Map)['creadoEn'];
                            if (aTs == null || bTs == null) return 0;
                            return (bTs as Timestamp).compareTo(aTs as Timestamp);
                          });
                        final docsLimited = docs.take(5).toList();
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SectionHeader(title: 'Recién Completadas'),
                            ...docsLimited.map((job) => _TarjetaOperario(job: job, onActualizar: (_, __) {}, userData: widget.userData)),
                          ],
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TarjetaOperario extends StatelessWidget {
  final QueryDocumentSnapshot job;
  final Function(String, String) onActualizar;
  final Map<String, dynamic> userData;

  const _TarjetaOperario({required this.job, required this.onActualizar, required this.userData});

  @override
  Widget build(BuildContext context) {
    final data = job.data() as Map<String, dynamic>;
    final String estado = data['estado'] ?? '';

    return PremiumCard(
      accentColor: getColorEstado(estado),
      padding: const EdgeInsets.all(20),
      onTap: () => _mostrarDetalles(context, data, job.id),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  (data['categoria'] ?? 'SERVICIO').toUpperCase(),
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: cAzul, letterSpacing: 1.2),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: getColorEstado(estado).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                child: Text(estado.toUpperCase(), style: TextStyle(color: getColorEstado(estado), fontSize: 9, fontWeight: FontWeight.w900)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Icon(Icons.person_pin_rounded, color: cTextoOscuro, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  data['clienteNombre'] ?? 'Cliente',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: cTextoOscuro),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (data['direccionText'] != null && data['direccionText'].toString().isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(color: cFucsia.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
              child: Row(
                children: [
                  const Icon(Icons.location_city_rounded, color: cFucsia, size: 20),
                  const SizedBox(width: 8),
                  Expanded(child: Text(data['direccionText'], style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: cFucsia))),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE2E8F0))),
            child: Text(data['descripcion'] ?? '', style: const TextStyle(fontSize: 13, color: Colors.grey, height: 1.5)),
          ),
          if (data['lat'] != null) ...[
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () async {
                final lat = (data['lat'] as num).toDouble();
                final lng = (data['lng'] as num).toDouble();
                final url = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng');
                try {
                  await launchUrl(url, mode: LaunchMode.externalApplication);
                } catch (_) {
                  await launchUrl(url, mode: LaunchMode.inAppBrowserView);
                }
              },
              child: Stack(
                alignment: Alignment.bottomCenter,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      height: 120,
                      child: FlutterMap(
                        options: MapOptions(
                          initialCenter: LatLng((data['lat'] as num).toDouble(), (data['lng'] as num).toDouble()),
                          initialZoom: 15.0,
                          interactionOptions: const InteractionOptions(flags: InteractiveFlag.none),
                        ),
                        children: [
                          TileLayer(
                            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'com.servintel.operarios',
                          ),
                          MarkerLayer(
                            markers: [
                              Marker(
                                point: LatLng((data['lat'] as num).toDouble(), (data['lng'] as num).toDouble()),
                                width: 40,
                                height: 40,
                                child: const Icon(Icons.location_on, color: Colors.red, size: 30),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.45),
                      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.open_in_new_rounded, color: Colors.white, size: 14),
                        SizedBox(width: 6),
                        Text('Abrir en Google Maps', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
          _BotonAccionOperario(data: data, jobId: job.id, onActualizar: onActualizar, userData: userData),
        ],
      ),
    );
  }

  void _mostrarDetalles(BuildContext context, Map<String, dynamic> data, String jobId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.65,
        maxChildSize: 0.95,
        minChildSize: 0.4,
        builder: (_, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          children: [
            Center(child: Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 20), decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text((data['categoria'] ?? 'SERVICIO').toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: cAzul, letterSpacing: 1.2)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(color: getColorEstado(data['estado'] ?? '').withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
                  child: Text((data['estado'] ?? '').toUpperCase(), style: TextStyle(color: getColorEstado(data['estado'] ?? ''), fontSize: 11, fontWeight: FontWeight.w900)),
                ),
              ],
            ),
            const Divider(height: 24),
            _detalleItem(Icons.person_pin_rounded, 'Cliente', data['clienteNombre']),
            if (data['clienteTelefono'] != null && data['clienteTelefono'].toString().isNotEmpty)
              _detalleItem(Icons.phone_rounded, 'Teléfono', data['clienteTelefono']),
            if (data['clienteEmail'] != null && data['clienteEmail'].toString().isNotEmpty)
              _detalleItem(Icons.email_rounded, 'Email', data['clienteEmail']),
            if (data['direccionText'] != null && data['direccionText'].toString().isNotEmpty)
              _detalleItem(Icons.location_on_rounded, 'Dirección', data['direccionText']),
            if (data['descripcion'] != null && data['descripcion'].toString().isNotEmpty)
              _detalleItem(Icons.description_rounded, 'Descripción', data['descripcion']),
            if (data['notas'] != null && data['notas'].toString().isNotEmpty)
              _detalleItem(Icons.note_rounded, 'Notas', data['notas']),
            if (data['pinCode'] != null)
              _detalleItem(Icons.pin_rounded, 'PIN de verificación', data['pinCode'].toString()),
            if (data['creadoEn'] != null) ...[
              const SizedBox(height: 8),
              _detalleItem(Icons.calendar_today_rounded, 'Creado', _formatTimestamp(data['creadoEn'])),
            ],
            const SizedBox(height: 8),
            Text('ID: $jobId', style: TextStyle(fontSize: 11, color: Colors.grey.shade400, fontFamily: 'monospace')),
          ],
        ),
      ),
    );
  }

  Widget _detalleItem(IconData icon, String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: cAzul),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(value?.toString() ?? '—', style: const TextStyle(fontSize: 14, color: cTextoOscuro, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(dynamic ts) {
    if (ts == null) return '—';
    try {
      final dt = (ts as Timestamp).toDate();
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}  ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return ts.toString();
    }
  }
}

class _BotonAccionOperario extends StatefulWidget {
  final Map<String, dynamic> data;
  final String jobId;
  final Function(String, String) onActualizar;
  final Map<String, dynamic> userData;

  const _BotonAccionOperario({required this.data, required this.jobId, required this.onActualizar, required this.userData});

  @override
  State<_BotonAccionOperario> createState() => _BotonAccionOperarioState();
}

class _BotonAccionOperarioState extends State<_BotonAccionOperario> {
  bool _isLoading = false;

  Future<void> _iniciarRuta() async {
    final lat = widget.data['lat'];
    final lng = widget.data['lng'];
    try {
      if (lat != null && lng != null) {
        final url = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng');
        if (await canLaunchUrl(url)) await launchUrl(url, mode: LaunchMode.externalApplication);
      }
      widget.onActualizar(widget.jobId, 'en_camino');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al abrir mapa: $e'), backgroundColor: Colors.red));
    }
  }

  Future<void> _confirmarLlegada() async {
    setState(() => _isLoading = true);
    try {
      Position pos = await Geolocator.getCurrentPosition();
      final double destLat = (widget.data['lat'] as num).toDouble();
      final double destLng = (widget.data['lng'] as num).toDouble();
      double dist = Geolocator.distanceBetween(pos.latitude, pos.longitude, destLat, destLng);
      if (dist > 100) throw 'Debes estar a menos de 100m del destino.';
      if (!mounted) return;
      _solicitarPin();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _solicitarPin() {
    final pinCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Verificar PIN'),
        content: TextField(controller: pinCtrl, keyboardType: TextInputType.number, maxLength: 4, textAlign: TextAlign.center, style: const TextStyle(fontSize: 24, letterSpacing: 8)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () {
              if (pinCtrl.text.trim() == widget.data['pinCode'].toString().trim()) {
                Navigator.pop(ctx);
                widget.onActualizar(widget.jobId, 'en_sitio');
              } else {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('PIN Incorrecto')));
              }
            },
            child: const Text('VERIFICAR'),
          ),
        ],
      ),
    ).then((_) => pinCtrl.dispose());
  }

  @override
  Widget build(BuildContext context) {
    final estado = widget.data['estado'] ?? '';

    if (estado == 'asignado') {
      return _btn(Icons.route_rounded, 'INICIAR RUTA', cAzul, _iniciarRuta);
    }
    if (estado == 'en_camino') {
      return Row(children: [
        Expanded(child: _btn(Icons.location_on_rounded, _isLoading ? '...' : 'LLEGADA', cFucsia, _isLoading ? null : _confirmarLlegada)),
        const SizedBox(width: 10),
        Expanded(child: _btn(Icons.timer_rounded, 'RETRASO', cAmarillo, () => widget.onActualizar(widget.jobId, 'retrasado'), t: cTextoOscuro)),
      ]);
    }
    if (estado == 'en_sitio' || estado == 'retrasado') {
      return _btn(Icons.fact_check_rounded, 'GENERAR DIAGNÓSTICO', cAzul, () => Navigator.push(context, MaterialPageRoute(builder: (_) => ReporteTecnicoScreen(userData: widget.userData, jobId: widget.jobId))));
    }
    if (estado == 'revision_cliente') {
      return const Center(child: Text('⏳ ESPERANDO APROBACIÓN DEL CLIENTE', style: TextStyle(fontWeight: FontWeight.w900, color: Colors.orange)));
    }
    if (estado == 'trabajo_aprobado') {
      return _btn(Icons.build_circle_rounded, 'EMPEZAR TRABAJO', cFucsia, () => widget.onActualizar(widget.jobId, 'en_progreso'));
    }
    if (estado == 'en_progreso') {
      return _btn(Icons.check_circle_rounded, 'FINALIZAR TRABAJO', Colors.green, () => widget.onActualizar(widget.jobId, 'esperando_cierre'));
    }
    if (estado == 'esperando_cierre') {
      return const Center(child: Text('📋 TRABAJO ENVIADO · ESPERANDO CIERRE ADMIN', style: TextStyle(fontWeight: FontWeight.w900, color: Colors.teal, fontSize: 12)));
    }
    return const Center(child: Text('✅ FINALIZADO', style: TextStyle(fontWeight: FontWeight.w900, color: Colors.green)));
  }

  Widget _btn(IconData i, String l, Color b, VoidCallback? o, {Color t = Colors.white}) {
    return SizedBox(width: double.infinity, height: 50, child: ElevatedButton.icon(icon: Icon(i, color: t, size: 18), label: Text(l, style: TextStyle(color: t, fontWeight: FontWeight.w900, fontSize: 13)), style: ElevatedButton.styleFrom(backgroundColor: b), onPressed: o));
  }
}


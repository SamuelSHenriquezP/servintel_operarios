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
    if (nuevoEstado == 'completado') updateData['tiempoCompletado'] = FieldValue.serverTimestamp();

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
    final uid = FirebaseAuth.instance.currentUser!.uid;

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
                suffixIcon: _searchCtrl.text.isNotEmpty ? IconButton(icon: const Icon(Icons.close), onPressed: () { _searchCtrl.clear(); _buscarTrabajo(); }) : null,
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
                      stream: TrabajosRepository.streamActiveForOperario(uid),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) return const SizedBox();
                        final docs = snapshot.data!.docs;
                        if (docs.isEmpty) return const SizedBox();
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
                      stream: TrabajosRepository.streamCompletedRecentForOperario(uid),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) return const SizedBox();
                        final docs = snapshot.data!.docs;
                        if (docs.isEmpty) return const SizedBox();
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SectionHeader(title: 'Recién Completadas'),
                            ...docs.map((job) => _TarjetaOperario(job: job, onActualizar: (_, __) {}, userData: widget.userData)),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                (data['categoria'] ?? 'SERVICIO').toUpperCase(),
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: cAzul, letterSpacing: 1.2),
              ),
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
              Text(data['clienteNombre'] ?? 'Cliente', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: cTextoOscuro)),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE2E8F0))),
            child: Text(data['descripcion'] ?? '', style: const TextStyle(fontSize: 13, color: Colors.grey, height: 1.5)),
          ),
          if (data['lat'] != null) ...[
            const SizedBox(height: 16),
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
          ],
          const SizedBox(height: 24),
          _BotonAccionOperario(data: data, jobId: job.id, onActualizar: onActualizar, userData: userData),
        ],
      ),
    );
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

  void _iniciarRuta() async {
    final lat = widget.data['lat'];
    final lng = widget.data['lng'];
    if (lat != null && lng != null) {
      final url = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng');
      if (await canLaunchUrl(url)) await launchUrl(url, mode: LaunchMode.externalApplication);
    }
    widget.onActualizar(widget.jobId, 'en_camino');
  }

  Future<void> _confirmarLlegada() async {
    setState(() => _isLoading = true);
    try {
      Position pos = await Geolocator.getCurrentPosition();
      double dist = Geolocator.distanceBetween(pos.latitude, pos.longitude, widget.data['lat'], widget.data['lng']);
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
              if (pinCtrl.text == widget.data['pinCode']) { Navigator.pop(ctx); widget.onActualizar(widget.jobId, 'en_sitio'); }
              else { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('PIN Incorrecto'))); }
            },
            child: const Text('VERIFICAR'),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final estado = widget.data['estado'] ?? '';

    if (estado == 'asignado') {
      return _btn(Icons.route_rounded, 'INICIAR RUTA', cAzul, _iniciarRuta);
    }
    if (estado == 'en_camino') {
      return Row(children: [
        Expanded(child: _btn(Icons.location_on_rounded, _isLoading ? '...' : 'LLEGADA', cFucsia, _confirmarLlegada)),
        const SizedBox(width: 10),
        Expanded(child: _btn(Icons.timer_rounded, 'RETRASO', cAmarillo, () => widget.onActualizar(widget.jobId, 'retrasado'), t: cTextoOscuro)),
      ]);
    }
    if (estado == 'en_sitio' || estado == 'retrasado') {
      return _btn(Icons.fact_check_rounded, 'FINALIZAR REPORTE', cAzul, () => Navigator.push(context, MaterialPageRoute(builder: (_) => ReporteTecnicoScreen(userData: widget.userData, jobId: widget.jobId))));
    }
    return const Center(child: Text('✅ FINALIZADO', style: TextStyle(fontWeight: FontWeight.w900, color: Colors.green)));
  }

  Widget _btn(IconData i, String l, Color b, VoidCallback o, {Color t = Colors.white}) {
    return SizedBox(width: double.infinity, height: 50, child: ElevatedButton.icon(icon: Icon(i, color: t, size: 18), label: Text(l, style: TextStyle(color: t, fontWeight: FontWeight.w900, fontSize: 13)), style: ElevatedButton.styleFrom(backgroundColor: b), onPressed: o));
  }
}


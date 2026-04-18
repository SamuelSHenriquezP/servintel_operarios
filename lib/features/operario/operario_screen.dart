import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/constants.dart';
import '../../shared/widgets/common_widgets.dart';
import 'trabajos_repository.dart';
import 'reporte_tecnico_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';

// ======================================================================
// PANTALLA OPERARIO TÉCNICO (OPTIMIZADA)
// ======================================================================
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
        SnackBar(content: Text('Error en búsqueda: $e'), backgroundColor: Colors.red),
      );
      setState(() => _isSearching = false);
    }
  }

  Future<void> _actualizarEstado(
    BuildContext context,
    String jobId,
    String nuevoEstado,
  ) async {
    final Map<String, dynamic> updateData = {'estado': nuevoEstado};

    if (nuevoEstado == 'en_camino') {
      updateData['tiempoEnCamino'] = FieldValue.serverTimestamp();
    }
    if (nuevoEstado == 'en_sitio') {
      updateData['tiempoEnSitio'] = FieldValue.serverTimestamp();
    }
    if (nuevoEstado == 'completado') {
      updateData['tiempoCompletado'] = FieldValue.serverTimestamp();
    }

    try {
        await TrabajosRepository.updateEstado(jobId, updateData);

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Estado actualizado: $nuevoEstado'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final nombre = widget.userData['nombre'] ?? 'Técnico';
    final uid = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      appBar: AppBar(
        title: Text('Técnico: $nombre'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Cerrar sesión',
            onPressed: () {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                FirebaseAuth.instance.signOut();
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Buscar por nombre de cliente...',
                prefixIcon: const Icon(Icons.search, color: cAzul),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    _searchCtrl.clear();
                    _buscarTrabajo();
                  },
                ),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                filled: true,
                fillColor: cFondo,
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
              onSubmitted: (_) => _buscarTrabajo(),
            ),
          ),
          Expanded(
            child: _searchResults != null
                ? _buildSearchResults()
                : _buildEstandardList(uid),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults() {
    if (_isSearching) return const Center(child: CircularProgressIndicator());
    if (_searchResults!.isEmpty) {
      return const Center(child: Text('No se encontraron resultados.'));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(15),
      itemCount: _searchResults!.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return SectionHeader(title: 'Resultados de Búsqueda', count: _searchResults!.length, color: Colors.orange);
        }
        final job = _searchResults![index - 1];
        return _TarjetaOperario(
          job: job,
          onActualizarEstado: (nuevo) => _actualizarEstado(context, job.id, nuevo),
          onFinalizar: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ReporteTecnicoScreen(
                userData: widget.userData,
                jobId: job.id,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEstandardList(String uid) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 15),
      children: [
        StreamBuilder<QuerySnapshot>(
          stream: TrabajosRepository.streamActiveForOperario(uid),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const SizedBox();
            final docs = snapshot.data!.docs;
            if (docs.isEmpty) return const SizedBox();

            return Column(
              children: [
                SectionHeader(title: 'Tareas Activas', count: docs.length, color: cAzul),
                ...docs.map((job) => _TarjetaOperario(
                      job: job,
                      onActualizarEstado: (nuevo) => _actualizarEstado(context, job.id, nuevo),
                      onFinalizar: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ReporteTecnicoScreen(
                            userData: widget.userData,
                            jobId: job.id,
                          ),
                        ),
                      ),
                    )),
              ],
            );
          },
        ),
        const SizedBox(height: 10),
        StreamBuilder<QuerySnapshot>(
          stream: TrabajosRepository.streamCompletedRecentForOperario(uid),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const SizedBox();
            final docs = snapshot.data!.docs;
            if (docs.isEmpty) return const SizedBox();

            return Column(
              children: [
                SectionHeader(title: 'Completadas Recientes', count: docs.length, color: Colors.green),
                ...docs.map((job) => _TarjetaOperario(
                      job: job,
                      onActualizarEstado: (_) {},
                      onFinalizar: () {},
                    )),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _TarjetaOperario extends StatelessWidget {
  final QueryDocumentSnapshot job;
  final void Function(String nuevoEstado) onActualizarEstado;
  final VoidCallback onFinalizar;

  const _TarjetaOperario({required this.job, required this.onActualizarEstado, required this.onFinalizar});

  @override
  Widget build(BuildContext context) {
    final data = job.data() as Map<String, dynamic>;
    final String estado = data['estado'] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
            side: BorderSide(
            color: getColorEstado(estado).withValues(alpha: 0.2),
            width: 1,
          ),
        ),
                child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                cFondo,
                getColorEstado(estado).withValues(alpha: 0.02),
              ],
            ),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      data['categoria'] ?? '',
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                        color: cAzul,
                      ),
                    ),
                  ),
                  EstadoChip(estado: estado, darkText: false),
                ],
              ),
              const SizedBox(height: 5),
              Row(
                children: [
                  const Icon(Icons.person_pin, size: 16, color: cTextoOscuro),
                  const SizedBox(width: 4),
                  Text(
                    'Cliente: ${data['clienteNombre'] ?? ''}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: cTextoOscuro,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: cFondo,
                  borderRadius: BorderRadius.circular(8),
                ),
                width: double.infinity,
                child: Text(
                  data['descripcion'] ?? '',
                  style: const TextStyle(fontSize: 13, color: Colors.black87),
                ),
              ),
              const SizedBox(height: 15),
              _BotonesEstado(
                data: data,
                jobId: job.id,
                onActualizar: onActualizarEstado,
                onFinalizar: onFinalizar,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BotonesEstado extends StatefulWidget {
  final Map<String, dynamic> data;
  final String jobId;
  final void Function(String) onActualizar;
  final VoidCallback onFinalizar;

  const _BotonesEstado({
    required this.data,
    required this.jobId,
    required this.onActualizar,
    required this.onFinalizar,
  });

  @override
  State<_BotonesEstado> createState() => _BotonesEstadoState();
}

class _BotonesEstadoState extends State<_BotonesEstado> {
  bool _isLoading = false;

  void _iniciarRuta() async {
    final lat = widget.data['lat'];
    final lng = widget.data['lng'];
    if (lat != null && lng != null) {
      final url = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng');
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      }
    }
    widget.onActualizar('en_camino');
  }

  Future<void> _confirmarLlegada() async {
    setState(() => _isLoading = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) throw Exception('GPS desactivado');

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) throw Exception('Permiso GPS denegado');
      }

      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      
      final latDest = widget.data['lat'];
      final lngDest = widget.data['lng'];
      
      if (latDest != null && lngDest != null) {
        double distance = Geolocator.distanceBetween(
          position.latitude, position.longitude,
          latDest, lngDest,
        );
        
        if (distance > 50) {
          throw Exception('Estás a ${distance.toStringAsFixed(0)}m del destino. Debes estar a menos de 50 metros para confirmar la llegada.');
        }
      }

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
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar Llegada (Código PIN)', textAlign: TextAlign.center, style: TextStyle(fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Pídele al cliente el número PIN de 4 dígitos para confirmar tu llegada.', style: TextStyle(fontSize: 13, color: Colors.grey)),
            const SizedBox(height: 15),
            TextField(
              controller: pinCtrl,
              keyboardType: TextInputType.number,
              maxLength: 4,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 24, letterSpacing: 10, fontWeight: FontWeight.bold),
              decoration: const InputDecoration(border: OutlineInputBorder(), counterText: ''),
            )
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: cFucsia),
            onPressed: () {
              if (pinCtrl.text == widget.data['pinCode']) {
                Navigator.pop(ctx);
                widget.onActualizar('en_sitio');
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Llegada confirmada exitosamente.'), backgroundColor: Colors.green));
              } else {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('PIN incorrecto.'), backgroundColor: Colors.red));
              }
            },
            child: const Text('VERIFICAR PIN'),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final estado = widget.data['estado'] ?? '';

    if (estado == 'asignado') {
      return _boton(
        Icons.directions_car,
        'INICIAR RUTA',
        cAzul,
        _iniciarRuta,
      );
    }
    if (estado == 'en_camino') {
      return Row(
        children: [
          Expanded(
            child: _boton(
              Icons.location_on,
              _isLoading ? 'VERIFICANDO...' : 'CONFIRMAR LLEGADA',
              cCTAPrimary,
              _isLoading ? () {} : _confirmarLlegada,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _boton(
              Icons.warning,
              'RETRASO',
              cAmarillo,
              () => widget.onActualizar('retrasado'),
              textColor: cTextoOscuro,
            ),
          ),
        ],
      );
    }
    if (estado == 'en_sitio' || estado == 'retrasado') {
      return _boton(
        Icons.check_circle,
        'FINALIZAR Y LLENAR REPORTE',
        cFucsia,
        widget.onFinalizar,
      );
    }
    return const Center(
      child: Text(
        '✅ Trabajo concluido.',
        style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _boton(
    IconData icon,
    String label,
    Color bg,
    VoidCallback onTap, {
    Color textColor = Colors.white,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        icon: Icon(icon, color: textColor),
        label: Text(
          label,
          style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
        ),
        style: ElevatedButton.styleFrom(backgroundColor: bg),
        onPressed: onTap,
      ),
    );
  }
}

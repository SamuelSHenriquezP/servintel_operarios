import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/constants.dart';
import '../../shared/widgets/common_widgets.dart';
import 'trabajos_repository.dart';

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

  const _TarjetaOperario({required this.job, required this.onActualizarEstado});

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
              _BotonesEstado(estado: estado, onActualizar: onActualizarEstado),
            ],
          ),
        ),
      ),
    );
  }
}

class _BotonesEstado extends StatelessWidget {
  final String estado;
  final void Function(String) onActualizar;
  const _BotonesEstado({required this.estado, required this.onActualizar});

  @override
  Widget build(BuildContext context) {
    if (estado == 'asignado') {
      return _boton(
        Icons.directions_car,
        'VOY EN CAMINO',
        cAzul,
        () => onActualizar('en_camino'),
      );
    }
    if (estado == 'en_camino') {
      return Row(
        children: [
          Expanded(
            child: _boton(
              Icons.location_on,
              'LLEGUÉ',
              cCTAPrimary,
              () => onActualizar('en_sitio'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _boton(
              Icons.warning,
              'RETRASO',
              cAmarillo,
              () => onActualizar('retrasado'),
              textColor: cTextoOscuro,
            ),
          ),
        ],
      );
    }
    if (estado == 'en_sitio' || estado == 'retrasado') {
      return _boton(
        Icons.check_circle,
        'FINALIZAR TRABAJO',
        cFucsia,
        () => onActualizar('completado'),
      );
    }
    return const Center(
      child: Text(
        '✅ Completado. Esperando evaluación del cliente.',
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

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/constants.dart';
import '../../shared/widgets/common_widgets.dart';
import 'visto_bueno_screen.dart';
import 'mapa_cliente_screen.dart';

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
  final bool _isSending = false;

  @override
  void dispose() {
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _enviarSolicitud() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
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

  void _showSnackbar(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color),
    );
  }

  void _calificarServicio(String jobId) {
    int estrellas = 5;
    final comentarioCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text(
            'Calificar Servicio',
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '¿Qué tal le pareció el trabajo del técnico?',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 15),
              DropdownButtonFormField<int>(
                initialValue: estrellas,
                decoration: const InputDecoration(border: OutlineInputBorder()),
                items: [5, 4, 3, 2, 1]
                    .map(
                      (e) => DropdownMenuItem(
                        value: e,
                        child: Text('⭐' * e + ' ($e/5)'),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setDialogState(() => estrellas = v!),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: comentarioCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'Déjenos un comentario (opcional)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                comentarioCtrl.dispose();
                Navigator.pop(context);
              },
              child: const Text(
                'Cancelar',
                style: TextStyle(color: Colors.grey),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: cFucsia),
              onPressed: () async {
                final comentario = comentarioCtrl.text.trim();
                comentarioCtrl.dispose();
                Navigator.pop(context);
                await FirebaseFirestore.instance
                    .collection('trabajos')
                    .doc(jobId)
                    .update({
                  'estado': 'evaluado_cliente',
                  'evaluacionCliente': {
                    'estrellas': estrellas,
                    'comentario': comentario,
                    'fechaEvaluacion': FieldValue.serverTimestamp(),
                  },
                });
                if (!mounted) return;
                _showSnackbar('¡Gracias por su evaluación!', Colors.green);
              },
              child: const Text('ENVIAR'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final nombre = widget.userData['nombre'] ?? 'Cliente';

    return Scaffold(
      appBar: AppBar(
        title: Text('Hola, $nombre'),
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
          // ZONA DE SOLICITUD
          Container(
            padding: const EdgeInsets.all(20),
              color: cFondo,
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Solicitar Asistencia',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: cTextoOscuro,
                    ),
                  ),
                  const SizedBox(height: 15),

                  DropdownButtonFormField<String>(
                    initialValue: _categoriaSel,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 14,
                      ),
                      filled: true,
                      fillColor: cFondo,
                    ),
                    hint: const Text('Seleccione el tipo de problema'),
                    items: kCategorias
                        .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                        .toList(),
                    onChanged: (v) => setState(() => _categoriaSel = v),
                    validator: (v) =>
                        v == null ? 'Seleccione una categoría' : null,
                  ),
                  const SizedBox(height: 10),

                  TextFormField(
                    controller: _descCtrl,
                    maxLines: 2,
                    maxLength: 300,
                    decoration: const InputDecoration(
                      hintText: 'Describa el problema con detalle...',
                      border: OutlineInputBorder(),
                      filled: true,
                      fillColor: cFondo,
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Ingrese una descripción';
                      }
                      if (v.trim().length < 10) {
                        return 'La descripción es muy corta';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 10),

                  SizedBox(
                    width: double.infinity,
                    height: 45,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: cFucsia),
                      onPressed: _isSending ? null : _enviarSolicitud,
                      child: _isSending
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              'ENVIAR AL DESPACHO',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const Divider(height: 1, thickness: 1),

          // HISTORIAL
          const Padding(
            padding: EdgeInsets.fromLTRB(15, 12, 15, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Mis Requerimientos',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: cTextoOscuro,
                ),
              ),
            ),
          ),

          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('trabajos')
                  .where(
                    'clienteId',
                    isEqualTo: FirebaseAuth.instance.currentUser!.uid,
                  )
                  .orderBy('creadoEn', descending: true)
                  .limit(5)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: cAzul),
                  );
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.inbox_outlined,
                          size: 48,
                          color: Colors.grey,
                        ),
                        SizedBox(height: 10),
                        Text(
                          'No tiene requerimientos activos.',
                          style: TextStyle(color: Colors.grey, fontSize: 15),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(15),
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    final job = snapshot.data!.docs[index];
                    final data = job.data() as Map<String, dynamic>;
                    final String estado = data['estado'] ?? 'solicitado';
                    final bool yaEvaluado =
                        estado == 'evaluado_cliente' || estado == 'cerrado';

                    return Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: getColorEstado(estado).withValues(alpha: 0.4),
                          width: 1.5,
                        ),
                      ),
                      margin: const EdgeInsets.only(bottom: 15),
                      child: Padding(
                        padding: const EdgeInsets.all(15),
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
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: cTextoOscuro,
                                    ),
                                  ),
                                ),
                                EstadoChip(estado: estado),
                              ],
                            ),
                            const SizedBox(height: 5),
                            Text(
                              data['descripcion'] ?? '',
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 13,
                              ),
                            ),
                            const Divider(),
                            Row(
                              children: [
                                Icon(
                                  Icons.engineering,
                                  size: 16,
                                  color: data['operarioNombre'] != null
                                      ? cAzul
                                      : Colors.grey,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  'Técnico: ${data['operarioNombre'] ?? 'Buscando especialista...'}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: data['operarioNombre'] != null
                                        ? cAzul
                                        : Colors.grey,
                                  ),
                                ),
                              ],
                            ),

                            if (estado == 'completado' && !yaEvaluado) ...[
                              const SizedBox(height: 10),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  icon: const Icon(
                                    Icons.star,
                                    color: cTextoOscuro,
                                  ),
                                  label: const Text(
                                    'EVALUAR SERVICIO',
                                    style: TextStyle(
                                      color: cTextoOscuro,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: cAmarillo,
                                  ),
                                  onPressed: () => _calificarServicio(job.id),
                                ),
                              ),
                            ],

                            if (estado == 'revision_cliente') ...[
                              const SizedBox(height: 10),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  icon: const Icon(Icons.assignment, color: Colors.white),
                                  label: const Text(
                                    'VER REPORTE TÉCNICO',
                                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                  ),
                                  style: ElevatedButton.styleFrom(backgroundColor: cFucsia),
                                  onPressed: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => VistoBuenoScreen(data: data, jobId: job.id)),
                                  ),
                                ),
                              ),
                            ],

                            if (!yaEvaluado && data['pinCode'] != null && estado != 'revision_cliente' && estado != 'reporte_aprobado') ...[
                              const SizedBox(height: 10),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                                ),
                                child: Column(
                                  children: [
                                    const Text('CÓDIGO DE VERIFICACIÓN (PIN)', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blue)),
                                    const SizedBox(height: 4),
                                    Text(
                                      data['pinCode'],
                                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 4, color: Colors.blue),
                                    ),
                                    const Text('Entréguelo al técnico al llegar', style: TextStyle(fontSize: 11, color: Colors.blueGrey)),
                                  ],
                                ),
                              ),
                            ],

                            if (yaEvaluado &&
                                data['evaluacionCliente'] != null) ...[
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                      color: Colors.green.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.check_circle,
                                      size: 14,
                                      color: Colors.green,
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      'Evaluado: ${'⭐' * ((data['evaluacionCliente']['estrellas'] as int?) ?? 0)}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.green,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

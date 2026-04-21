import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/constants.dart';

class MapaClienteScreen extends StatefulWidget {
  final Map<String, dynamic> userData;
  final String categoria;
  final String descripcion;

  const MapaClienteScreen({
    super.key,
    required this.userData,
    required this.categoria,
    required this.descripcion,
  });

  @override
  State<MapaClienteScreen> createState() => _MapaClienteScreenState();
}

class _MapaClienteScreenState extends State<MapaClienteScreen> {
  final MapController _mapController = MapController();
  LatLng? _selectedLocation;
  bool _isLoading = true;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _initLocation();
  }

  Future<void> _initLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _setDefaultLocation();
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _setDefaultLocation();
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _setDefaultLocation();
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.best),
      );
      setState(() {
        _selectedLocation = LatLng(position.latitude, position.longitude);
        _isLoading = false;
      });
    } catch (e) {
      _setDefaultLocation();
    }
  }

  void _setDefaultLocation() {
    setState(() {
      // Default to center of Colombia or Cartagena (10.3910, -75.4794)
      _selectedLocation = const LatLng(10.3910, -75.4794);
      _isLoading = false;
    });
  }

  void _onMapTap(TapPosition tapPosition, LatLng point) {
    setState(() {
      _selectedLocation = point;
    });
  }

  Future<void> _confirmarYEnviar() async {
    if (_selectedLocation == null) return;
    setState(() => _isSending = true);

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) throw Exception('Sin autenticación');

      // Generate Random 4-digit PIN
      final pinCode = (Random().nextInt(9000) + 1000).toString();

      await FirebaseFirestore.instance.collection('trabajos').add({
        'clienteId': uid,
        'clienteNombre': widget.userData['nombre'] ?? 'Cliente',
        'categoria': widget.categoria,
        'descripcion': widget.descripcion,
        'lat': _selectedLocation!.latitude,
        'lng': _selectedLocation!.longitude,
        'pinCode': pinCode,
        'estado': 'solicitado',
        'creadoEn': FieldValue.serverTimestamp(),
        'operarioId': null,
        'operarioNombre': null,
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('🚀 ¡Solicitud enviada al despacho!'),
        backgroundColor: Colors.green,
      ));
      
      // Regresar 2 veces para volver a la pantalla limpia del cliente
      Navigator.pop(context, true);

    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Error: $e'),
        backgroundColor: Colors.red,
      ));
      setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: cFondo,
      appBar: AppBar(
        title: const Text('Confirmar Ubicación', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: cAzul))
          : Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _selectedLocation!,
                    initialZoom: 15.0,
                    onTap: _onMapTap,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.servintel.operarios',
                    ),
                    if (_selectedLocation != null)
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: _selectedLocation!,
                            width: 80,
                            height: 80,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: cFucsia.withValues(alpha: 0.2),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const Icon(
                                  Icons.location_on_rounded,
                                  color: cFucsia,
                                  size: 45,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
                Positioned(
                  bottom: 30,
                  left: 20,
                  right: 20,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: cAzul.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.info_outline_rounded, color: cAzul, size: 20),
                              ),
                              const SizedBox(width: 12),
                              const Expanded(
                                child: Text(
                                  'Mueve el mapa para marcar el sitio exacto del servicio.',
                                  style: TextStyle(fontSize: 13, color: cTextoOscuro, fontWeight: FontWeight.w500),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: cFucsia,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                              ),
                              onPressed: _isSending ? null : _confirmarYEnviar,
                              child: _isSending
                                  ? const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                    )
                                  : const Text(
                                      'CONFIRMAR Y SOLICITAR TÉCNICO',
                                      style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.5),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

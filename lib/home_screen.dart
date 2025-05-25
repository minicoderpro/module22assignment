import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import '../widgets/location_info_dialog.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final Completer<GoogleMapController> _controller = Completer();
  LatLng? _currentPosition;
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  final List<LatLng> _polylineCoordinates = [];
  late Timer _locationTimer;
  bool _isLocationServiceEnabled = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _initializeLocationService();
  }

  Future<void> _initializeLocationService() async {
    try {
      _isLocationServiceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!_isLocationServiceEnabled) {
        setState(() {
          _errorMessage = 'Location services are disabled.';
        });
        return;
      }

      final status = await Permission.location.request();
      if (status.isGranted) {
        await _getCurrentLocation();
        _locationTimer = Timer.periodic(
          const Duration(seconds: 10),
              (_) => _getCurrentLocation(),
        );
      } else {
        setState(() {
          _errorMessage = 'Location permission denied';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error initializing location: ${e.toString()}';
      });
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final newPosition = LatLng(position.latitude, position.longitude);

      if (mounted) {
        setState(() {
          _currentPosition = newPosition;
          _polylineCoordinates.add(newPosition);
          _errorMessage = '';
          _updateMarkers();
          _updatePolylines();
        });
      }

      final controller = await _controller.future;
      await controller.animateCamera(
        CameraUpdate.newLatLng(newPosition),
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error getting location: ${e.toString()}';
        });
      }
    }
  }

  void _updateMarkers() {
    _markers.clear();
    if (_currentPosition != null) {
      _markers.add(
        Marker(
          markerId: const MarkerId('currentLocation'),
          position: _currentPosition!,
          infoWindow: InfoWindow(
            title: 'My Current Location',
            snippet: '${_currentPosition!.latitude.toStringAsFixed(6)}, '
                '${_currentPosition!.longitude.toStringAsFixed(6)}',
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          onTap: () {
            showDialog(
              context: context,
              builder: (context) => LocationInfoDialog(
                position: _currentPosition!,
              ),
            );
          },
        ),
      );
    }
  }

  void _updatePolylines() {
    _polylines.clear();
    if (_polylineCoordinates.length > 1) {
      _polylines.add(
        Polyline(
          polylineId: const PolylineId('route'),
          points: _polylineCoordinates,
          color: Colors.blue,
          width: 5,
        ),
      );
    }
  }

  @override
  void dispose() {
    _locationTimer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Real-Time Location Tracker'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _getCurrentLocation,
          ),
        ],
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _currentPosition ?? const LatLng(23.8103, 90.4125),
              zoom: 15,
            ),
            markers: _markers,
            polylines: _polylines,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            onMapCreated: (GoogleMapController controller) {
              _controller.complete(controller);
            },
          ),
          if (_errorMessage.isNotEmpty)
            Positioned(
              top: 10,
              left: 10,
              right: 10,
              child: Material(
                color: Colors.redAccent,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    _errorMessage,
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _getCurrentLocation,
        child: const Icon(Icons.my_location),
      ),
    );
  }
}
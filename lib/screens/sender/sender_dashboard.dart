import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../services/location_service.dart';

class SenderDashboard extends StatefulWidget {
  const SenderDashboard({Key? key}) : super(key: key);

  @override
  State<SenderDashboard> createState() => _SenderDashboardState();
}

class _SenderDashboardState extends State<SenderDashboard> {
  GoogleMapController? _mapController;
  LatLng? _currentLocation;
  bool _isLoading = true;
  bool _isSharing = false;

  static const CameraPosition _initialCameraPosition = CameraPosition(
    target: LatLng(25.2742728, 85.2878293), // Bihar coordinates
    zoom: 15,
  );

  @override
  void initState() {
    super.initState();
    _checkAndRequestLocationPermission();
  }

  Future<void> _checkAndRequestLocationPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enable location services')),
        );
      }
      setState(() => _isLoading = false);
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.whileInUse || 
        permission == LocationPermission.always) {
      await _getCurrentLocation();
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location permission denied')),
        );
      }
      setState(() => _isLoading = false);
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      setState(() {
        _currentLocation = LatLng(position.latitude, position.longitude);
        _isLoading = false;
      });

      if (_mapController != null && _currentLocation != null) {
        _mapController!.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(target: _currentLocation!, zoom: 15),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error getting location: $e')),
        );
      }
      setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleLocationSharing() async {
    final locationService = Provider.of<LocationService>(context, listen: false);
    final authService = Provider.of<AuthService>(context, listen: false);

    if (_isSharing) {
      locationService.stopLocationTracking();
      setState(() => _isSharing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location sharing stopped')),
      );
    } else {
      bool started = await locationService.startLocationTracking(authService.user!.uid);
      if (started) {
        setState(() => _isSharing = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location sharing started')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to start location sharing')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sender Dashboard'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          Consumer<AuthService>(
            builder: (context, authService, _) => Row(
              children: [
                Text(
                  authService.userModel?.name ?? 'User',
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.logout),
                  onPressed: () => authService.signOut(),
                ),
              ],
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  color: _isSharing ? Colors.green[50] : Colors.red[50],
                  child: Row(
                    children: [
                      Icon(
                        _isSharing ? Icons.location_on : Icons.location_off,
                        color: _isSharing ? Colors.green : Colors.red,
                        size: 24,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _isSharing 
                              ? 'Location sharing is active (updates every 5 seconds)' 
                              : 'Location sharing is off',
                          style: TextStyle(
                            color: _isSharing ? Colors.green[700] : Colors.red[700],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      ElevatedButton(
                        onPressed: _toggleLocationSharing,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isSharing ? Colors.red : Colors.green,
                          foregroundColor: Colors.white,
                        ),
                        child: Text(_isSharing ? 'Stop' : 'Start'),
                      ),
                    ],
                  ),
                ),
                Consumer<LocationService>(
                  builder: (context, locationService, _) {
                    if (locationService.currentPosition != null) {
                      _currentLocation = LatLng(
                        locationService.currentPosition!.latitude,
                        locationService.currentPosition!.longitude,
                      );
                    }
                    return Expanded(
                      child: GoogleMap(
                        initialCameraPosition: CameraPosition(
                          target: _currentLocation ?? const LatLng(25.2742728, 85.2878293),
                          zoom: 15,
                        ),
                        mapType: MapType.normal,
                        onMapCreated: (GoogleMapController controller) {
                          _mapController = controller;
                          if (_currentLocation != null) {
                            controller.animateCamera(
                              CameraUpdate.newCameraPosition(
                                CameraPosition(target: _currentLocation!, zoom: 15),
                              ),
                            );
                          }
                        },
                        markers: {
                          if (_currentLocation != null)
                            Marker(
                              markerId: const MarkerId('current_location'),
                              position: _currentLocation!,
                              infoWindow: InfoWindow(
                                title: 'My Location',
                                snippet: 'Lat: ${_currentLocation!.latitude.toStringAsFixed(6)}, '
                                       'Lng: ${_currentLocation!.longitude.toStringAsFixed(6)}',
                              ),
                              icon: BitmapDescriptor.defaultMarkerWithHue(
                                  BitmapDescriptor.hueBlue),
                            ),
                        },
                        myLocationEnabled: true,
                        myLocationButtonEnabled: true,
                      ),
                    );
                  },
                ),
              ],
            ),
    );
  }

  @override
  void dispose() {
    final locationService = Provider.of<LocationService>(context, listen: false);
    locationService.stopLocationTracking();
    _mapController?.dispose();
    super.dispose();
  }
}
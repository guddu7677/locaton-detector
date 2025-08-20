import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import '../../models/user_model.dart';
import '../../models/location_model.dart';
import '../../services/location_service.dart';

class TrackUserScreen extends StatefulWidget {
  final UserModel sender;

  const TrackUserScreen({Key? key, required this.sender}) : super(key: key);

  @override
  State<TrackUserScreen> createState() => _TrackUserScreenState();
}

class _TrackUserScreenState extends State<TrackUserScreen>
    with TickerProviderStateMixin {
  final LocationService _locationService = LocationService();
  GoogleMapController? _mapController;
  LocationModel? _currentLocation;
  Position? _myLocation;
  double? _distance;
  StreamSubscription<Position>? _positionStreamSubscription;
  bool _isLoadingMyLocation = false;
  bool _followingUser = true;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  Timer? _locationUpdateTimer;
  
  // Add these new variables to track initial loading state
  bool _hasInitialData = false;
  bool _isInitialLoading = true;
  bool _isDataRefreshing = false;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _getMyLocation();
    _startLocationUpdates();
  }

  void _initializeAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
    _pulseController.repeat(reverse: true);
  }

  void _startLocationUpdates() {
    _locationUpdateTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (mounted) {
        _getMyLocation();
      }
    });
  }

  Future<void> _getMyLocation() async {
    if (_isLoadingMyLocation) return;
    
    setState(() {
      _isLoadingMyLocation = true;
    });

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showLocationServiceDialog();
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showPermissionDialog();
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _showPermissionPermanentlyDeniedDialog();
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      if (mounted) {
        setState(() {
          _myLocation = position;
          _isLoadingMyLocation = false;
          // Calculate distance here when we have both locations
          if (_currentLocation != null) {
            _distance = _calculateDistance(_currentLocation!);
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingMyLocation = false;
        });
        print('Error getting my location: $e');
      }
    }
  }

  double? _calculateDistance(LocationModel senderLocation) {
    if (_myLocation != null) {
      return Geolocator.distanceBetween(
        _myLocation!.latitude,
        _myLocation!.longitude,
        senderLocation.latitude,
        senderLocation.longitude,
      );
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Row(
          children: [
            Hero(
              tag: 'avatar_${widget.sender.uid}',
              child: CircleAvatar(
                radius: 16,
                backgroundColor: Colors.white,
                child: Text(
                  widget.sender.name.isNotEmpty
                      ? widget.sender.name[0].toUpperCase()
                      : 'S',
                  style: TextStyle(
                    color: Colors.green[600],
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Tracking ${widget.sender.name}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (context, child) {
                      return Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(
                                0.5 + (_pulseAnimation.value * 0.5),
                              ),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Text(
                            'LIVE TRACKING',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: Colors.green[600],
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(_followingUser ? Icons.gps_fixed : Icons.gps_not_fixed),
            onPressed: () {
              setState(() {
                _followingUser = !_followingUser;
              });
              if (_followingUser && _currentLocation != null) {
                _centerOnSender();
              }
            },
            tooltip: _followingUser ? 'Stop Following' : 'Follow User',
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _getMyLocation,
            tooltip: 'Refresh My Location',
          ),
        ],
      ),
      body: StreamBuilder<LocationModel?>(
        stream: _locationService.getUserLocationStream(widget.sender.uid),
        builder: (context, snapshot) {
          // Track data refreshing state
          if (snapshot.connectionState == ConnectionState.waiting) {
            if (_hasInitialData) {
              // Background refresh
              _isDataRefreshing = true;
            } else {
              // Initial loading
              return _buildLoadingState();
            }
          } else {
            _isDataRefreshing = false;
          }

          if (snapshot.hasError) {
            return _buildErrorState();
          }

          final location = snapshot.data;

          if (location == null) {
            // If we had data before but now it's null, don't show loading
            if (_hasInitialData) {
              return _buildNoLocationState();
            }
            // If this is the first time and we get null, show loading
            return _buildLoadingState();
          }

          // Mark that we have received initial data
          if (!_hasInitialData) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                setState(() {
                  _hasInitialData = true;
                  _isInitialLoading = false;
                });
              }
            });
          }

          // Update location and calculate distance without setState during build
          _currentLocation = location;
          final currentDistance = _calculateDistance(location);
          
          // Schedule setState to run after build is complete
          if (currentDistance != _distance) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                setState(() {
                  _distance = currentDistance;
                });
              }
            });
          }

          // Auto-follow user if enabled
          if (_followingUser && _mapController != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _centerOnSender();
            });
          }

          return _buildMapView(location, _isDataRefreshing);
        },
      ),
    );
  }

  Widget _buildLoadingState() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.green[600]!,
            Colors.green[50]!,
          ],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.green[600]!),
                    strokeWidth: 3,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Connecting to ${widget.sender.name}...',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(50),
              ),
              child: Icon(
                Icons.signal_wifi_off_rounded,
                size: 48,
                color: Colors.red[400],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Connection Error',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.red[700],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Unable to connect to location services.\nPlease check your internet connection.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.red[600],
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => setState(() {
                _hasInitialData = false;
                _isInitialLoading = true;
              }),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[600],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoLocationState() {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(50),
              ),
              child: Icon(
                Icons.location_off_rounded,
                size: 48,
                color: Colors.orange[400],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Location Not Available',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.orange[700],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '${widget.sender.name} is not currently sharing their location.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.orange[600],
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    color: Colors.blue[600],
                    size: 24,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Ask ${widget.sender.name} to:\n• Enable location sharing\n• Check their internet connection\n• Make sure the app is running',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.blue[700],
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMapView(LocationModel location, bool isRefreshing) {
    Set<Marker> markers = _createMarkers(location);
    Set<Polyline> polylines = _createPolylines(location);

    return Column(
      children: [
        _buildLocationHeader(location),
        Expanded(
          child: Stack(
            children: [
              GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: LatLng(location.latitude, location.longitude),
                  zoom: 16,
                ),
                onMapCreated: (GoogleMapController controller) {
                  _mapController = controller;
                  if (_myLocation != null) {
                    _fitMarkersInView();
                  }
                },
                markers: markers,
                polylines: polylines,
                myLocationEnabled: false,
                myLocationButtonEnabled: false,
                zoomControlsEnabled: false,
                mapType: MapType.normal,
                onCameraMove: (CameraPosition position) {
                  setState(() {
                    _followingUser = false;
                  });
                },
                onTap: (_) {
                  _centerOnSender();
                },
              ),
              _buildMapControls(),
              // Modified: Show loading indicator only for my location updates
              if (_isLoadingMyLocation)
                Positioned(
                  top: 16,
                  right: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.green[600]!),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Updating location...',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              // Add a subtle indicator for background data updates
              if (isRefreshing)
                Positioned(
                  top: 16,
                  left: 16,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.green[600]!.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(
                            strokeWidth: 1.5,
                            valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Syncing...',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

            ],
          ),
        ),
        _buildLocationDetails(location),
      ],
    );
  }

  Widget _buildLocationHeader(LocationModel location) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.green[600]!,
            Colors.green[500]!,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Center(
                child: Text(
                  widget.sender.name.isNotEmpty
                      ? widget.sender.name[0].toUpperCase()
                      : 'S',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.sender.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  Text(
                    'Updated ${_formatDateTime(location.timestamp)}',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 12,
                    ),
                  ),
                  if (_distance != null)
                    Text(
                      'Distance: ${_formatDistance(_distance!)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
            ),
            AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(
                      0.1 + (_pulseAnimation.value * 0.1),
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: _isLocationRecent(location.timestamp)
                              ? Colors.white
                              : Colors.orange,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _isLocationRecent(location.timestamp) ? 'LIVE' : 'DELAYED',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMapControls() {
    return Positioned(
      right: 16,
      bottom: 100,
      child: Column(
        children: [
          FloatingActionButton(
            heroTag: "fit_markers",
            backgroundColor: Colors.white,
            foregroundColor: Colors.green[600],
            mini: true,
            onPressed: _myLocation != null ? _fitMarkersInView : null,
            child: const Icon(Icons.fit_screen_rounded, size: 20),
            tooltip: 'Fit Both Locations',
          ),
          const SizedBox(height: 8),
          FloatingActionButton(
            heroTag: "my_location",
            backgroundColor: Colors.white,
            foregroundColor: Colors.blue[600],
            mini: true,
            onPressed: _myLocation != null ? _centerOnMyLocation : null,
            child: const Icon(Icons.my_location_rounded, size: 20),
            tooltip: 'My Location',
          ),
          const SizedBox(height: 8),
          FloatingActionButton(
            heroTag: "center_sender",
            backgroundColor: Colors.green[600],
            foregroundColor: Colors.white,
            onPressed: _centerOnSender,
            child: const Icon(Icons.person_pin_circle_rounded),
            tooltip: 'Center on ${widget.sender.name}',
          ),
        ],
      ),
    );
  }

  Widget _buildLocationDetails(LocationModel location) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.location_on_rounded,
                  color: Colors.green[600],
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Location Details',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildDetailsGrid(location),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailsGrid(LocationModel location) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildLocationDetail(
                'Latitude',
                location.latitude.toStringAsFixed(6),
                Icons.explore_rounded,
              ),
            ),
            Expanded(
              child: _buildLocationDetail(
                'Longitude',
                location.longitude.toStringAsFixed(6),
                Icons.explore_off_rounded,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            if (location.accuracy != null)
              Expanded(
                child: _buildLocationDetail(
                  'Accuracy',
                  '±${location.accuracy!.toStringAsFixed(1)}m',
                  Icons.gps_fixed_rounded,
                ),
              ),
            if (location.speed != null)
              Expanded(
                child: _buildLocationDetail(
                  'Speed',
                  '${(location.speed! * 3.6).toStringAsFixed(1)} km/h',
                  Icons.speed_rounded,
                ),
              ),
            if (_distance != null)
              Expanded(
                child: _buildLocationDetail(
                  'Distance',
                  _formatDistance(_distance!),
                  Icons.straighten_rounded,
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        _buildLocationDetail(
          'Last Updated',
          _formatDateTime(location.timestamp),
          Icons.update_rounded,
          fullWidth: true,
        ),
      ],
    );
  }

  Widget _buildLocationDetail(String label, String value, IconData icon, {bool fullWidth = false}) {
    return Container(
      width: fullWidth ? double.infinity : null,
      padding: const EdgeInsets.all(12),
      margin: EdgeInsets.only(right: fullWidth ? 0 : 4, left: fullWidth ? 0 : 4),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: fullWidth ? MainAxisAlignment.start : MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: Colors.green[600],
                size: 16,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: Colors.black87,
            ),
            textAlign: fullWidth ? TextAlign.left : TextAlign.center,
          ),
        ],
      ),
    );
  }

  Set<Marker> _createMarkers(LocationModel location) {
    Set<Marker> markers = {
      Marker(
        markerId: MarkerId(widget.sender.uid),
        position: LatLng(location.latitude, location.longitude),
        infoWindow: InfoWindow(
          title: widget.sender.name,
          snippet: 'Updated: ${_formatDateTime(location.timestamp)}',
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(
          BitmapDescriptor.hueGreen,
        ),
      ),
    };

    if (_myLocation != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('my_location'),
          position: LatLng(_myLocation!.latitude, _myLocation!.longitude),
          infoWindow: const InfoWindow(
            title: 'My Location',
            snippet: 'You are here',
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueBlue,
          ),
        ),
      );
    }

    return markers;
  }

  Set<Polyline> _createPolylines(LocationModel location) {
    if (_myLocation == null) return {};

    return {
      Polyline(
        polylineId: const PolylineId('distance_line'),
        points: [
          LatLng(_myLocation!.latitude, _myLocation!.longitude),
          LatLng(location.latitude, location.longitude),
        ],
        color: Colors.blue[600]!,
        width: 3,
        patterns: [PatternItem.dash(10), PatternItem.gap(8)],
        geodesic: true,
      ),
    };
  }

  void _centerOnSender() {
    if (_currentLocation != null && _mapController != null) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(_currentLocation!.latitude, _currentLocation!.longitude),
          16,
        ),
      );
      setState(() {
        _followingUser = true;
      });
    }
  }

  void _centerOnMyLocation() {
    if (_myLocation != null && _mapController != null) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(_myLocation!.latitude, _myLocation!.longitude),
          16,
        ),
      );
    }
  }

  void _fitMarkersInView() {
    if (_myLocation != null && _currentLocation != null && _mapController != null) {
      double minLat = [_myLocation!.latitude, _currentLocation!.latitude].reduce((a, b) => a < b ? a : b);
      double maxLat = [_myLocation!.latitude, _currentLocation!.latitude].reduce((a, b) => a > b ? a : b);
      double minLng = [_myLocation!.longitude, _currentLocation!.longitude].reduce((a, b) => a < b ? a : b);
      double maxLng = [_myLocation!.longitude, _currentLocation!.longitude].reduce((a, b) => a > b ? a : b);

      _mapController!.animateCamera(
        CameraUpdate.newLatLngBounds(
          LatLngBounds(
            southwest: LatLng(minLat, minLng),
            northeast: LatLng(maxLat, maxLng),
          ),
          120.0,
        ),
      );
    }
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inSeconds < 30) {
      return 'Just now';
    } else if (difference.inMinutes < 1) {
      return '${difference.inSeconds}s ago';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    }
  }

  String _formatDistance(double distanceInMeters) {
    if (distanceInMeters < 1000) {
      return '${distanceInMeters.toStringAsFixed(0)} m';
    } else {
      return '${(distanceInMeters / 1000).toStringAsFixed(2)} km';
    }
  }

  bool _isLocationRecent(DateTime timestamp) {
    final difference = DateTime.now().difference(timestamp);
    return difference.inSeconds < 60;
  }

  void _showLocationServiceDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Location Services Disabled'),
          content: const Text('Please enable location services to track your location.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await Geolocator.openLocationSettings();
              },
              child: const Text('Settings'),
            ),
          ],
        );
      },
    );
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Location Permission Required'),
          content: const Text('This app needs location permission to show your distance from the tracked user.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _getMyLocation();
              },
              child: const Text('Grant Permission'),
            ),
          ],
        );
      },
    );
  }

  void _showPermissionPermanentlyDeniedDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Location Permission Denied'),
          content: const Text('Location permissions are permanently denied. Please enable them in app settings.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await Geolocator.openAppSettings();
              },
              child: const Text('Open Settings'),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _positionStreamSubscription?.cancel();
    _locationUpdateTimer?.cancel();
    _mapController?.dispose();
    super.dispose();
  }
}

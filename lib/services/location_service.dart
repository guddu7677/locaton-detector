import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/location_model.dart';
import '../utils/permissions_helper.dart';

class LocationService with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  Timer? _locationTimer;
  StreamSubscription<QuerySnapshot>? _locationsSub;
  Position? _currentPosition;
  bool _isTracking = false;
  String? _trackingUserId;

  Position? get currentPosition => _currentPosition;
  bool get isTracking => _isTracking;

  Future<bool> startLocationTracking(String userId) async {
    bool hasPermission = await PermissionsHelper.requestLocationPermission();
    if (!hasPermission) return false;

    try {
      _trackingUserId = userId;
      _isTracking = true;
      
      // Update user status to active
      await _updateUserStatus(userId, true);
      
      // Start sending location using timer-based approach
      startSendingLocation(userId);
      
      notifyListeners();
      return true;
    } catch (e) {
      print('Error starting location tracking: $e');
      _isTracking = false;
      return false;
    }
  }

  void startSendingLocation(String uid) {
    _locationTimer?.cancel();
    _locationTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      try {
        Position pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.best
        );
        
        _currentPosition = pos;
        
        await _firestore.collection('locations').doc(uid).set({
          'userId': uid,
          'latitude': pos.latitude,
          'longitude': pos.longitude,
          'timestamp': FieldValue.serverTimestamp(),
          'accuracy': pos.accuracy,
          'speed': pos.speed,
        }, SetOptions(merge: true));
        
        notifyListeners();
      } catch (e) {
        print('Location update failed: $e');
      }
    });
  }

  void stopSendingLocation() {
    _locationTimer?.cancel();
    _locationTimer = null;
  }

  Future<void> _updateUserStatus(String userId, bool isActive) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .update({
        'isActive': isActive,
        'lastSeen': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error updating user status: $e');
    }
  }

  void stopLocationTracking() {
    stopSendingLocation();
    
    if (_trackingUserId != null) {
      _updateUserStatus(_trackingUserId!, false);
    }
    
    _isTracking = false;
    _trackingUserId = null;
    notifyListeners();
  }

  // Listen to all locations for receivers
  void listenToLocations(Function(List<LocationModel>) onLocationsUpdate) {
    _locationsSub?.cancel();
    _locationsSub = _firestore
        .collection('locations')
        .snapshots()
        .listen((snapshot) {
      List<LocationModel> locations = [];
      for (var doc in snapshot.docs) {
        try {
          locations.add(LocationModel.fromFirestore(doc));
        } catch (e) {
          print('Error parsing location document: $e');
        }
      }
      onLocationsUpdate(locations);
    });
  }

  void cancelListen() {
    _locationsSub?.cancel();
    _locationsSub = null;
  }

  Stream<LocationModel?> getUserLocationStream(String userId) {
    return _firestore
        .collection('locations')
        .doc(userId)
        .snapshots()
        .map((doc) {
      if (doc.exists && doc.data() != null) {
        return LocationModel.fromFirestore(doc);
      }
      return null;
    });
  }

  Future<double> calculateDistance(double lat1, double lon1, double lat2, double lon2) async {
    return Geolocator.distanceBetween(lat1, lon1, lat2, lon2);
  }

  @override
  void dispose() {
    stopLocationTracking();
    cancelListen();
    super.dispose();
  }
}
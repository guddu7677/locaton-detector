enum UserRole { sender, receiver }

class AppConstants {
  static const String appName = 'Location Tracker';
  static const Duration locationUpdateInterval = Duration(seconds: 5);
  static const double locationAccuracyThreshold = 100.0;
  
  // Colors
  static const int primaryBlue = 0xFF2196F3;
  static const int primaryGreen = 0xFF4CAF50;
  static const int warningOrange = 0xFFFF9800;
  static const int errorRed = 0xFFF44336;
}
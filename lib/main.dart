import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'services/auth_service.dart';
import 'services/database_service.dart';
import 'services/location_service.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/sender/sender_dashboard.dart';
import 'screens/receiver/receiver_dashboard.dart';
import 'screens/receiver/track_user_screen.dart';
import 'models/user_model.dart';
import 'utils/constants.dart';
import 'widgets/loading_widget.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Load environment variables
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    print("Could not load .env file: $e");
  }
  
  // Initialize Firebase
  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: "AIzaSyDUxO-ktSHtYlrQbsstY8c3yfeL8sCBNjo",
      appId: "1:564653882833:android:4fe99d9b0c4b5daa29f4f0",
      messagingSenderId: "564653882833",
      projectId: "location-7a51b",
    ),
  );

  runApp(const LocationTrackerApp());
}

class LocationTrackerApp extends StatelessWidget {
  const LocationTrackerApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => LocationService()),
        Provider(create: (_) => DatabaseService()),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: "Location Tracker",
        theme: ThemeData(
          primarySwatch: Colors.blue,
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        ),
        home: const AuthWrapper(),
        routes: {
          "/login": (_) => const LoginScreen(),
          "/register": (_) => const RegisterScreen(),
          "/senderDashboard": (_) => const SenderDashboard(),
          "/receiverDashboard": (_) => const ReceiverDashboard(),
          "/trackUser": (context) {
            final args = ModalRoute.of(context)!.settings.arguments as UserModel;
            return TrackUserScreen(sender: args);
          },
        },
      ),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthService>(
      builder: (context, authService, _) {
        // Show loading while checking auth state
        if (authService.isLoading) {
          return const Scaffold(
            body: LoadingWidget(message: "Loading..."),
          );
        }

        // User is not authenticated
        if (!authService.isAuthenticated) {
          return const LoginScreen();
        }

        // User is authenticated but userModel is not loaded yet
        if (authService.userModel == null) {
          return const Scaffold(
            body: LoadingWidget(message: "Setting up your account..."),
          );
        }

        // Route based on user role
        switch (authService.userRole) {
          case UserRole.sender:
            return const SenderDashboard();
          case UserRole.receiver:
            return const ReceiverDashboard();
          case null:
          default:
            return Scaffold(
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 64,
                      color: Colors.red[400],
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      "Unknown user role",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Please contact support or try logging out and back in.",
                      style: TextStyle(
                        color: Colors.grey[600],
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () async {
                        await authService.signOut();
                      },
                      child: const Text("Sign Out"),
                    ),
                  ],
                ),
              ),
            );
        }
      },
    );
  }
}
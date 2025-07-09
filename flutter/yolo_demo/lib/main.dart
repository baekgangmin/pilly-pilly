import 'package:flutter/material.dart';
import 'screens/splash_screen.dart';
import 'presentation/screens/camera_inference_screen.dart';

void main() {
  runApp(PillyApp());
}

class PillyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pillypilly',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.grey,
      ),
      home: SplashScreen(),
      routes: {
        '/camera_inference': (context) => CameraInferenceScreen(),
      }
    );
  }
}
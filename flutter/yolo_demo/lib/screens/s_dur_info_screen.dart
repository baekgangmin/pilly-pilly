// lib/screens/s_dur_info_screen.dart
import 'package:flutter/material.dart';

class SDurInfoScreen extends StatelessWidget {
  final Map<String, dynamic> durData;

  const SDurInfoScreen({
    Key? key,
    required this.durData,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('DUR 품목 정보')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Text('DUR 정보: ${durData.toString()}'),
      ),
    );
  }
}
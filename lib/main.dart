import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/lobby.dart';
import 'services/websocket.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => WebSocketService()..connect()),
      ],
      child: MaterialApp(
        title: 'Card Game',
        theme: ThemeData(primarySwatch: Colors.blue),
        home: const LobbyScreen(),
      ),
    );
  }
}
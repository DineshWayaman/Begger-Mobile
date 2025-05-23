import 'package:begger_card_game/screens/home_screen.dart';
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
        debugShowCheckedModeBanner: false,
        title: 'Beggar Online',
        theme: ThemeData(primaryColor: Colors.blue,textSelectionTheme: const TextSelectionThemeData(
          cursorColor: Colors.blue,
          selectionColor: Colors.lightBlueAccent,
          selectionHandleColor: Colors.blue,
        ),
        ),
        home: const HomeScreen(),
      ),
    );
  }
}
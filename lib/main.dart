import 'package:begger_card_game/screens/game_summary_screen.dart';
import 'package:begger_card_game/screens/home_screen.dart';
import 'package:begger_card_game/screens/splash_screen.dart';
import 'package:begger_card_game/services/ad_helper.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:unity_ads_plugin/unity_ads_plugin.dart';
import 'firebase_options.dart';
import 'screens/lobby.dart';
import 'services/websocket.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  FirebaseAnalytics analytics = FirebaseAnalytics.instance;

  if (!kIsWeb) {
    // Initialize Unity Ads for Android and iOS
    await UnityAds.init(
      gameId: AdHelper.gameId,
      testMode: true, // Set to false in production
      onComplete: () => print('Unity Ads Initialization Complete'),
      onFailed: (error, message) => print('Unity Ads Initialization Failed: $error $message'),
    );
  }
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp])
      .then((_) {
    runApp(const MyApp());
  });
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
        navigatorObservers: [
          FirebaseAnalyticsObserver(analytics: FirebaseAnalytics.instance),
        ],
        home: const SplashScreen(),
        // home: GameSummaryScreen(summaryMessage: "summaryMessage", gameId: "gameId", playerId: "playerId", onHomePressed: (){}, onReplayPressed: (){}, isSinglePlayer: true),
      ),
    );
  }
}
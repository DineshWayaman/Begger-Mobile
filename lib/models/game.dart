import 'player.dart';
import 'card.dart';

class Game {
  final String id;

  List<Player> players;
  List<List<Cards>> pile;
  int currentTurn;
  String? status;
  bool isTestMode;
  int passCount; // New field
  String? lastPlayedPlayerId; // New field
  String? currentPattern;


  Game({
    required this.id,
    this.players = const [],

    this.pile = const [],
    this.currentTurn = 0,
    this.status = 'waiting',
    this.isTestMode = false,
    this.passCount = 0,
    this.lastPlayedPlayerId,
    this.currentPattern,

  });



  factory Game.fromJson(Map<String, dynamic> json) => Game(
    id: json['id'],
    players: (json['players'] as List)
        .map((p) => Player.fromJson(p))
        .toList(),
    pile: (json['pile'] as List)
        .map((p) => (p as List)
        .map((c) => Cards.fromJson(c))
        .toList())
        .toList(),
    currentTurn: json['currentTurn'] ?? 0,
    status: json['status'],
    isTestMode: json['isTestMode'] ?? false,
    passCount: json['passCount'] ?? 0,
    lastPlayedPlayerId: json['lastPlayedPlayerId'],
    currentPattern: json['currentPattern'],

  );

}
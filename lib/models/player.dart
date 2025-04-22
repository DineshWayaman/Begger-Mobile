import 'card.dart';

class Player {
  final String id;
  final String name;
  List<Cards> hand;
  String? title;

  Player({
    required this.id,
    required this.name,
    this.hand = const [],
    this.title,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'hand': hand.map((card) => card.toJson()).toList(),
    'title': title,
  };

  factory Player.fromJson(Map<String, dynamic> json) => Player(
    id: json['id'] ?? '',
    name: json['name'] ?? 'Unknown',
    hand: (json['hand'] as List<dynamic>?)
        ?.map((card) => Cards.fromJson(card as Map<String, dynamic>))
        .toList() ??
        [],
    title: json['title'],
  );
}
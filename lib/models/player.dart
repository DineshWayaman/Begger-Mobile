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
    id: json['id'],
    name: json['name'],
    hand: (json['hand'] as List)
        .map((card) => Cards.fromJson(card))
        .toList(),
    title: json['title'],
  );
}
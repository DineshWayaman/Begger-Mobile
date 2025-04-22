class Cards {
  final String? suit;
  final String? rank;
  final bool isJoker;
  final bool isDetails;
  final String? assignedRank; // Store assigned rank for Jokers
  final String? assignedSuit; // Store assigned suit for Jokers

  Cards({
    this.suit,
    this.rank,
    this.isJoker = false,
    this.isDetails = false,
    this.assignedRank,
    this.assignedSuit,
  });

  Map<String, dynamic> toJson() => {
    'suit': suit,
    'rank': rank,
    'isJoker': isJoker,
    'isDetails': isDetails,
    'assignedRank': assignedRank,
    'assignedSuit': assignedSuit,
  };

  factory Cards.fromJson(Map<String, dynamic> json) => Cards(
    suit: json['suit'],
    rank: json['rank'],
    isJoker: json['isJoker'] ?? false,
    isDetails: json['isDetails'] ?? false,
    assignedRank: json['assignedRank'],
    assignedSuit: json['assignedSuit'],
  );

  String getAssetPath() {
    const defaultCardPath = 'assets/cards/default_card.png';
    const defaultJokerPath = 'assets/cards/card_joker_red.png';

    if (isDetails) return 'assets/cards/info_card.png';

    final rankMap = {
      '3': '03', '4': '04', '5': '05', '6': '06', '7': '07', '8': '08', '9': '09',
      '10': '10', 'J': '11', 'Q': '12', 'K': '13', 'A': 'A', '2': '02',
    };

    if (isJoker) {
      if (assignedRank != null && assignedSuit != null) {
        return 'assets/cards/card_${assignedSuit}_${rankMap[assignedRank] ?? '00'}.png';
      }
      return suit == 'joker1'
          ? 'assets/cards/card_joker_black.png'
          : 'assets/cards/card_joker_red.png';
    }

    if (suit != null && rank != null && rankMap.containsKey(rank)) {
      return 'assets/cards/card_${suit}_${rankMap[rank]}.png';
    }

    return defaultCardPath;
  }
}
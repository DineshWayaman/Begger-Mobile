class Cards {
  final String? suit;
  final String? rank;
  final bool isJoker;
  final bool isDetails;
  final String? assignedRank; // Joker Update: Store assigned rank for Jokers
  final String? assignedSuit; // Joker Update: Store assigned suit for Jokers

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
    'assignedRank': assignedRank, // Joker Update: Include in JSON
    'assignedSuit': assignedSuit, // Joker Update: Include in JSON
  };

  factory Cards.fromJson(Map<String, dynamic> json) => Cards(
    suit: json['suit'],
    rank: json['rank'],
    isJoker: json['isJoker'] ?? false,
    isDetails: json['isDetails'] ?? false,
    assignedRank: json['assignedRank'], // Joker Update: Parse from JSON
    assignedSuit: json['assignedSuit'], // Joker Update: Parse from JSON
  );

  // String getAssetPath() {
  //   if (isDetails) return 'assets/cards/card_details.svg';
  //   if (isJoker) return 'assets/cards/card_joker_${suit == 'joker1' ? '1' : '2'}.svg';
  //   return 'assets/cards/card_${suit!.toLowerCase()}_${rank!.toLowerCase()}.svg';
  // }
  // String getAssetPath() {
  //   if (isDetails) return 'assets/cards/info_card.png';
  //   if (isJoker) return 'assets/cards/card_joker_${suit == 'joker1' ? 'black' : 'red'}.png';
  //   final rankMap = {
  //     '3': '03', '4': '04', '5': '05', '6': '06', '7': '07', '8': '08', '9': '09',
  //     '10': '10', 'J': '11', 'Q': '12', 'K': '13', 'A': 'A', '2': '02',
  //   };
  //   return 'assets/cards/card_${suit!}_${rankMap[rank!]}.png';
  // }
  // String getAssetPath() {
  //   // Joker Update: Show assigned card's asset if assigned, else Joker asset
  //   if (isDetails) return  'assets/cards/info_card.png';
  //   if (isJoker) {
  //     if (assignedRank != null && assignedSuit != null) {
  //       final rankMap = {
  //         '3': '03', '4': '04', '5': '05', '6': '06', '7': '07', '8': '08', '9': '09',
  //         '10': '10', 'J': '11', 'Q': '12', 'K': '13', 'A': 'A', '2': '02',
  //       };
  //       return 'assets/cards/card_${suit!}_${rankMap[rank!]}.png';
  //     }
  //     return 'assets/cards/card_joker_${suit == 'joker1' ? 'black' : 'red'}.png';
  //   }
  //   final rankMap = {
  //     '3': '03', '4': '04', '5': '05', '6': '06', '7': '07', '8': '08', '9': '09',
  //     '10': '10', 'J': '11', 'Q': '12', 'K': '13', 'A': 'A', '2': '02',
  //   };
  //   return 'assets/cards/card_${suit!}_${rankMap[rank!]}.png';
  // }

  String getAssetPath() {
    const defaultCardPath = 'assets/cards/default_card.png'; // Default fallback path
    const defaultJokerPath = 'assets/cards/card_joker_red.png'; // Default Joker path

    if (isDetails) return 'assets/cards/info_card.png';

    print("isJoker: $isJoker");
    print("assignedRank: $assignedRank");
    print("assignedSuit: $assignedSuit");
    print("suit: $suit");

    if (isJoker) {
      if (assignedRank != null && assignedSuit != null) {
        final rankMap = {
          '3': '03', '4': '04', '5': '05', '6': '06', '7': '07', '8': '08', '9': '09',
          '10': '10', 'J': '11', 'Q': '12', 'K': '13', 'A': 'A', '2': '02',
        };
        return 'assets/cards/card_${assignedSuit}_${rankMap[assignedRank] ?? '00'}.png';
      }
      // Differentiate between red and black Jokers
      if (suit == 'joker2') {
        return 'assets/cards/card_joker_red.png';
      } else if (suit == 'joker1') {
        return 'assets/cards/card_joker_black.png';
      }
      return defaultJokerPath;
    }

    if (suit != null && rank != null) {
      final rankMap = {
        '3': '03', '4': '04', '5': '05', '6': '06', '7': '07', '8': '08', '9': '09',
        '10': '10', 'J': '11', 'Q': '12', 'K': '13', 'A': 'A', '2': '02',
      };
      return 'assets/cards/card_${suit}_${rankMap[rank] ?? '00'}.png';
    }

    return defaultCardPath; // Fallback for invalid or null suit/rank
  }
}


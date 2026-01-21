import 'solitaire_engine.dart';

String rankToAsset(int r) {
  switch (r) {
    case 1:
      return 'A';
    case 11:
      return 'J';
    case 12:
      return 'Q';
    case 13:
      return 'K';
    default:
      return '$r'; // 2..10 (10은 "10")
  }
}

String suitToAsset(Suit s) {
  switch (s) {
    case Suit.clubs:
      return 'C';
    case Suit.diamonds:
      return 'D';
    case Suit.hearts:
      return 'H';
    case Suit.spades:
      return 'S';
  }
}

String cardFrontAssetPath(CardModel c) =>
    'assets/cards/${rankToAsset(c.rank)}${suitToAsset(c.suit)}.png';

const String cardBackAssetPath = 'assets/cards/Card-back.png';

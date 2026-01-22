import 'package:flutter/material.dart';
import '../solitaire_engine.dart';
import 'card_widget.dart';

class DragCardsView extends StatelessWidget {
  final List<CardModel> cards;
  final Size cardSize;

  const DragCardsView({super.key, required this.cards, required this.cardSize});

  @override
  Widget build(BuildContext context) {
    // tableau 스택 이동이면 여러 장을 살짝 아래로 겹쳐 보이게
    const double dy = 22;
    return Material(
      color: Colors.transparent,
      child: SizedBox(
        width: cardSize.width,
        height: cardSize.height + (cards.length - 1) * dy,
        child: Stack(
          children: [
            for (int i = 0; i < cards.length; i++)
              Positioned(
                top: i * dy,
                left: 0,
                child: CardFront(
                  card: cards[i],
                  width: cardSize.width,
                  height: cardSize.height,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

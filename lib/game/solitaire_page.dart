import 'package:flutter/material.dart';
import 'controller/game_controller.dart';
import 'components/stock_pile.dart';
import 'components/waste_pile.dart';
import 'components/foundation_pile.dart';
import 'components/tableau_pile.dart';

class SolitairePage extends StatefulWidget {
  const SolitairePage({super.key});

  @override
  State<SolitairePage> createState() => _SolitairePageState();
}

class _SolitairePageState extends State<SolitairePage> {
  final c = GameController();

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: c,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: const Color(0xFF3A725D),
          appBar: AppBar(
            title: const Text('Klondike (1-draw)'),
            actions: [
              IconButton(onPressed: c.undo, icon: const Icon(Icons.undo)),
              IconButton(onPressed: c.newGame, icon: const Icon(Icons.refresh)),
            ],
          ),
          body: LayoutBuilder(
            builder: (context, constraints) {
              // 1. Width constraint
              final availWidth =
                  constraints.maxWidth - 24 - 48; // padding(24) + gaps(48)
              final widthBasedCardWidth = availWidth / 7;

              // 2. Height constraint
              final availHeight =
                  constraints.maxHeight - 24; // top/bottom padding
              const double cardAspectRatio = 1056 / 691;
              final heightBasedCardHeight = availHeight / 4.0;
              final heightBasedCardWidth =
                  heightBasedCardHeight / cardAspectRatio;

              // 3. Final Card Size
              final cardWidth = widthBasedCardWidth < heightBasedCardWidth
                  ? widthBasedCardWidth
                  : heightBasedCardWidth;
              final cardHeight = cardWidth * cardAspectRatio;

              return Center(
                child: SizedBox(
                  width: cardWidth * 7 + 48 + 24,
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: [
                          _TopRow(
                            controller: c,
                            cardWidth: cardWidth,
                            cardHeight: cardHeight,
                          ),
                          const SizedBox(height: 12),
                          Expanded(
                            child: _TableauRow(
                              controller: c,
                              cardWidth: cardWidth,
                              cardHeight: cardHeight,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _TopRow extends StatelessWidget {
  final GameController controller;
  final double cardWidth;
  final double cardHeight;

  const _TopRow({
    required this.controller,
    required this.cardWidth,
    required this.cardHeight,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        StockPile(controller: controller, width: cardWidth, height: cardHeight),
        const SizedBox(width: 12),
        WastePile(controller: controller, width: cardWidth, height: cardHeight),
        const Spacer(),
        Row(
          children: List.generate(4, (i) {
            return Padding(
              padding: EdgeInsets.only(left: i == 0 ? 0 : 12),
              child: FoundationPile(
                controller: controller,
                index: i,
                width: cardWidth,
                height: cardHeight,
              ),
            );
          }),
        ),
      ],
    );
  }
}

class _TableauRow extends StatelessWidget {
  final GameController controller;
  final double cardWidth;
  final double cardHeight;

  const _TableauRow({
    required this.controller,
    required this.cardWidth,
    required this.cardHeight,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(7, (col) {
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(left: col == 0 ? 0 : 8),
            child: TableauPile(
              controller: controller,
              col: col,
              cardWidth: cardWidth,
              cardHeight: cardHeight,
            ),
          ),
        );
      }),
    );
  }
}

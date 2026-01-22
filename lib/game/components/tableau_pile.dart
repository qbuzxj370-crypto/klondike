import 'package:flutter/material.dart';
import '../controller/game_controller.dart';
import '../solitaire_engine.dart';
import '../widgets/card_widget.dart';
import '../widgets/draggable_card.dart';

class TableauPile extends StatelessWidget {
  final GameController controller;
  final int col;
  final double cardWidth;
  final double cardHeight;

  const TableauPile({
    super.key,
    required this.controller,
    required this.col,
    required this.cardWidth,
    required this.cardHeight,
  });

  static const double yOffset = 22;

  @override
  Widget build(BuildContext context) {
    final pile = controller.engine.state.tableau[col];

    return Column(
      key: controller.tableauKeys[col],
      children: [
        // pile drop target 영역
        Container(
          width: double.infinity,
          height: cardHeight,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.black12),
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: const SizedBox.shrink(),
        ),
        const SizedBox(height: 6),

        // cards stack
        Expanded(
          child: Stack(
            children: [
              for (int i = 0; i < pile.length; i++)
                Positioned(
                  top: i * yOffset,
                  left: 0,
                  right: 0,
                  child: _buildTableauCard(context, pile, i),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTableauCard(
    BuildContext context,
    List<CardModel> pile,
    int index,
  ) {
    final card = pile[index];

    // 드래그 중이고, 이 tableau에서 startIndex부터 옮기는 중이면 해당 카드들은 숨김(빈자리)
    final isDraggingThisPile =
        controller.dragging &&
        controller.dragFrom?.type == PileType.tableau &&
        controller.dragFrom?.index == col &&
        controller.dragStartIndex != null;

    final shouldHide =
        isDraggingThisPile && index >= (controller.dragStartIndex!);

    if (!card.faceUp) {
      return Opacity(
        opacity: shouldHide ? 0.0 : 1.0,
        child: AspectRatio(
          aspectRatio: cardWidth / cardHeight, // Using ratio to fit width
          child: const CardBack(width: null, height: null),
        ),
      );
    }

    // faceUp 카드: 여기서부터 스택을 잡을 수 있게 함(연속 이동)
    return Opacity(
      opacity: shouldHide ? 0.0 : 1.0,
      child: DraggableCard(
        card: card,
        // width/height not set here to fill the Positioned width (which is constrained by column width),
        // or we can set it explicitly. Let's use AspectRatio to be safe if width is dynamic.
        // Actually DraggableCard uses CardFront which uses Image.asset fit cover.
        // We should probably rely on the parent width constraint (Expanded -> Column width).
        // But DraggableCard wraps GestureDetector -> CardFront -> Image.
        // Let's pass width/height null and wrap in AspectRatio to maintain shape.
        width: null,
        height: null,
        onStart: (globalPos, sourceRect) {
          controller.startDrag(
            context: context,
            from: PileRef(PileType.tableau, col),
            startIndex: index,
            pointerGlobalPos: globalPos,
            sourceRectForOffset: sourceRect,
          );
        },
        onUpdate: controller.updateDrag,
        onEnd: controller.endDrag,
        onCancel: controller.cancelDrag,
      ),
    );
  }
}

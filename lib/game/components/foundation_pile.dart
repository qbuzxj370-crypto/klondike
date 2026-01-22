import 'package:flutter/material.dart';
import '../controller/game_controller.dart';
import '../solitaire_engine.dart';
import '../widgets/draggable_card.dart';
import '../widgets/pile_widget.dart';

class FoundationPile extends StatelessWidget {
  final GameController controller;
  final int index;
  final double width;
  final double height;

  const FoundationPile({
    super.key,
    required this.controller,
    required this.index,
    required this.width,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    final f = controller.engine.state.foundation[index];

    Widget child = const SizedBox.shrink();
    if (f.isNotEmpty) {
      final top = f.last;

      final isDraggingThis =
          controller.dragging &&
          controller.dragFrom?.type == PileType.foundation &&
          controller.dragFrom?.index == index;

      child = Opacity(
        opacity: isDraggingThis ? 0.0 : 1.0,
        child: DraggableCard(
          card: top,
          width: width,
          height: height,
          onStart: (globalPos, sourceRect) {
            controller.startDrag(
              context: context,
              from: PileRef(PileType.foundation, index),
              startIndex: null,
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

    return PileContainer(
      key: controller.foundationKeys[index],
      label: 'F$index',
      width: width,
      height: height,
      child: child,
    );
  }
}

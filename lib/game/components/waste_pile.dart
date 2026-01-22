import 'package:flutter/material.dart';
import '../controller/game_controller.dart';
import '../solitaire_engine.dart';
import '../widgets/draggable_card.dart';
import '../widgets/pile_widget.dart';

class WastePile extends StatelessWidget {
  final GameController controller;
  final double width;
  final double height;

  const WastePile({
    super.key,
    required this.controller,
    required this.width,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    final waste = controller.engine.state.waste;

    Widget child = const SizedBox.shrink();

    if (waste.isNotEmpty) {
      final top = waste.last;
      final isDraggingThis =
          controller.dragging && controller.dragFrom?.type == PileType.waste;

      child = Opacity(
        opacity: isDraggingThis ? 0.0 : 1.0,
        child: DraggableCard(
          card: top,
          width: width,
          height: height,
          onStart: (globalPos, sourceRect) {
            controller.startDrag(
              context: context,
              from: const PileRef(PileType.waste),
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
      key: controller.wasteKey,
      label: 'Waste',
      width: width,
      height: height,
      child: child,
    );
  }
}

import 'package:flutter/material.dart';
import '../solitaire_engine.dart';
import '../widgets/card_widget.dart';

typedef DragStart = void Function(Offset globalPos, Rect sourceRect);
typedef DragUpdate = void Function(Offset globalPos);
typedef DragEnd = void Function();
typedef DragCancel = void Function();

class DraggableCard extends StatelessWidget {
  final CardModel card;
  final double? width;
  final double? height;
  final DragStart onStart;
  final DragUpdate onUpdate;
  final DragEnd onEnd;
  final DragCancel onCancel;

  const DraggableCard({
    super.key,
    required this.card,
    this.width,
    this.height,
    required this.onStart,
    required this.onUpdate,
    required this.onEnd,
    required this.onCancel,
  });

  Rect _globalRectOf(BuildContext context) {
    final box = context.findRenderObject() as RenderBox;
    final topLeft = box.localToGlobal(Offset.zero);
    return topLeft & box.size;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanStart: (d) {
        final rect = _globalRectOf(context);
        onStart(d.globalPosition, rect);
      },
      onPanUpdate: (d) => onUpdate(d.globalPosition),
      onPanEnd: (_) => onEnd(),
      onPanCancel: onCancel,
      child: CardFront(card: card, width: width, height: height),
    );
  }
}

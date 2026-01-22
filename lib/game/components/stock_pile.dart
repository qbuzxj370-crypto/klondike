import 'package:flutter/material.dart';
import '../controller/game_controller.dart';
import '../widgets/card_widget.dart';
import '../widgets/pile_widget.dart';

class StockPile extends StatelessWidget {
  final GameController controller;
  final double width;
  final double height;

  const StockPile({
    super.key,
    required this.controller,
    required this.width,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    return PileContainer(
      key: controller.stockKey,
      label: 'Stock',
      width: width,
      height: height,
      child: GestureDetector(
        onTap: controller.tapStock,
        child: controller.engine.state.stock.isNotEmpty
            ? CardBack(width: width, height: height)
            : SizedBox(width: width, height: height), // Empty
      ),
    );
  }
}

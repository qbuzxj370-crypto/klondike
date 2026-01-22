import 'package:flutter/material.dart';
import '../card_assets.dart';
import '../solitaire_engine.dart';

class CardBack extends StatelessWidget {
  final double? width;
  final double? height;

  const CardBack({super.key, this.width, this.height});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Image.asset(
        cardBackAssetPath,
        width: width,
        height: height,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.high,
      ),
    );
  }
}

class CardFront extends StatelessWidget {
  final CardModel card;
  final double? width;
  final double? height;

  const CardFront({super.key, required this.card, this.width, this.height});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Image.asset(
        cardFrontAssetPath(card),
        width: width,
        height: height,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.high,
      ),
    );
  }
}

import 'package:flutter/material.dart';

class PileContainer extends StatelessWidget {
  final String? label;
  final Widget child;
  final double width;
  final double height;
  final Color? borderColor;

  const PileContainer({
    super.key,
    this.label,
    required this.child,
    required this.width,
    required this.height,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: width,
          height: height,
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(color: borderColor ?? Colors.black26),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(child: child),
          ),
        ),
        if (label != null) ...[
          const SizedBox(height: 4),
          Text(
            label!,
            style: const TextStyle(fontSize: 12, color: Colors.black54),
          ),
        ],
      ],
    );
  }
}

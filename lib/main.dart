import 'package:flutter/material.dart';
import 'game/solitaire_engine.dart';
import 'game/card_assets.dart';

void main() {
  runApp(const SolitaireApp());
}

class SolitaireApp extends StatelessWidget {
  const SolitaireApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: const SolitairePage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

/// 엔진 + 드래그 상태를 함께 들고 있는 컨트롤러(가장 단순한 형태)
class GameController extends ChangeNotifier {
  final SolitaireEngine engine = SolitaireEngine(seed: 42)..newGame();

  // 각 pile의 화면 위치를 알기 위한 key
  final stockKey = GlobalKey();
  final wasteKey = GlobalKey();
  final foundationKeys = List.generate(4, (_) => GlobalKey());
  final tableauKeys = List.generate(7, (_) => GlobalKey());

  // DragState
  bool dragging = false;
  OverlayEntry? _entry;
  Offset pointerGlobal = Offset.zero; // 손가락 위치(글로벌)
  Offset fingerToTopLeft = Offset.zero; // 손가락 - 카드그룹 topLeft 오프셋
  PileRef? dragFrom;
  int? dragStartIndex; // tableau의 시작 인덱스
  List<CardModel> dragCards = const [];
  Size? dragCardSize; // 드래그 중인 카드의 크기

  void newGame() {
    engine.newGame();
    notifyListeners();
  }

  void tapStock() {
    engine.tryTapStock();
    notifyListeners();
  }

  void undo() {
    engine.undo();
    notifyListeners();
  }

  // 드래그 시작(테이블로/웨이스트에서 호출)
  void startDrag({
    required BuildContext context,
    required PileRef from,
    int? startIndex,
    required Offset pointerGlobalPos,
    required Rect sourceRectForOffset,
  }) {
    if (dragging) return;

    // 1) 옮길 카드 계산(엔진 규칙에 맞는지 최소 확인)
    final fromList = _getPileList(from);
    if (fromList.isEmpty) return;

    List<CardModel> moving;
    if (from.type == PileType.tableau) {
      final si = startIndex ?? (fromList.length - 1);
      if (si < 0 || si >= fromList.length) return;
      moving = fromList.sublist(si);
      // faceUp/run 검사: 엔진에서 tryMove에서 걸러지긴 하지만,
      // 드래그 시작 자체를 막아 UX를 좋게 만들기 위해 여기서도 1차 차단
      if (moving.any((c) => !c.faceUp)) return;
    } else if (from.type == PileType.waste ||
        from.type == PileType.foundation) {
      moving = [fromList.last];
      if (!moving.first.faceUp) return;
    } else {
      return;
    }

    dragging = true;
    dragFrom = from;
    dragStartIndex = startIndex;
    dragCards = List.unmodifiable(moving);

    pointerGlobal = pointerGlobalPos;
    dragCardSize = sourceRectForOffset.size;

    // 손가락이 카드 그룹의 topLeft에서 얼마나 떨어져 있는지(자연스러운 드래그)
    fingerToTopLeft = pointerGlobalPos - sourceRectForOffset.topLeft;

    _entry = OverlayEntry(
      builder: (ctx) {
        final topLeft = pointerGlobal - fingerToTopLeft;
        return Positioned(
          left: topLeft.dx,
          top: topLeft.dy,
          child: IgnorePointer(
            child: _DragCardsView(cards: dragCards, cardSize: dragCardSize!),
          ),
        );
      },
    );

    Overlay.of(context, rootOverlay: true).insert(_entry!);
    notifyListeners(); // 원래 자리에서 “빈자리/반투명” 처리하려면 필요
  }

  void updateDrag(Offset pointerGlobalPos) {
    if (!dragging) return;
    pointerGlobal = pointerGlobalPos;
    _entry?.markNeedsBuild();
  }

  void endDrag() {
    if (!dragging) return;

    final from = dragFrom!;
    final to = _hitTestPile(pointerGlobal);

    // overlay 제거는 항상 먼저/나중 아무 때나 가능하지만
    // tryMove 결과에 상관없이 제거하는 게 깔끔
    _removeOverlay();

    if (to != null) {
      engine.tryMove(from, to, startIndex: dragStartIndex);
    }

    // drag state reset
    dragging = false;
    dragFrom = null;
    dragStartIndex = null;
    dragCards = const [];
    notifyListeners();
  }

  void cancelDrag() {
    if (!dragging) return;
    _removeOverlay();
    dragging = false;
    dragFrom = null;
    dragStartIndex = null;
    dragCards = const [];
    notifyListeners();
  }

  void _removeOverlay() {
    _entry?.remove();
    _entry = null;
  }

  // --- pile rect 계산 / drop target 판정 ---
  Rect? _rectOf(GlobalKey key) {
    final ctx = key.currentContext;
    if (ctx == null) return null;
    final box = ctx.findRenderObject();
    if (box is! RenderBox) return null;
    final pos = box.localToGlobal(Offset.zero);
    return pos & box.size;
  }

  PileRef? _hitTestPile(Offset globalPos) {
    // 우선순위: foundation -> tableau
    for (int i = 0; i < 4; i++) {
      final r = _rectOf(foundationKeys[i]);
      if (r != null && r.contains(globalPos)) {
        return PileRef(PileType.foundation, i);
      }
    }
    for (int i = 0; i < 7; i++) {
      final r = _rectOf(tableauKeys[i]);
      if (r != null && r.contains(globalPos)) {
        return PileRef(PileType.tableau, i);
      }
    }
    // waste로 드롭은 보통 금지(엔진도 막음) -> null 반환
    return null;
  }

  List<CardModel> _getPileList(PileRef ref) {
    switch (ref.type) {
      case PileType.stock:
        return engine.state.stock;
      case PileType.waste:
        return engine.state.waste;
      case PileType.tableau:
        return engine.state.tableau[ref.index];
      case PileType.foundation:
        return engine.state.foundation[ref.index];
    }
  }
}

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
              // We want to ensure the card doesn't get so big that the TopRow takes up too much space.
              // Let's say we want the TopRow + Padding + at least 3 card heights of Tableau to fit.
              // Total Height ~= TopRow(1.2 * cardH) + Gap(12) + Tableau(3 * cardH)
              // ~= 4.2 * cardH
              // So cardH should be <= availableHeight / 4.2
              final availHeight =
                  constraints.maxHeight - 24; // top/bottom padding
              // Aspect Ratio: 1056/691 ~= 1.528
              const double cardAspectRatio = 1056 / 691;
              final heightBasedCardHeight =
                  availHeight / 4.0; // Slightly more aggressive constraint
              final heightBasedCardWidth =
                  heightBasedCardHeight / cardAspectRatio;

              // 3. Final Card Size
              final cardWidth = widthBasedCardWidth < heightBasedCardWidth
                  ? widthBasedCardWidth
                  : heightBasedCardWidth;
              final cardHeight = cardWidth * cardAspectRatio;

              return Center(
                child: SizedBox(
                  // Constrain the overall width to the used columns
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

// ---------------- UI Parts ----------------

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
        // Stock
        _PileSlot(
          key: controller.stockKey,
          label: 'Stock',
          width: cardWidth,
          height: cardHeight,
          child: GestureDetector(
            onTap: controller.tapStock,
            child: _CardBackOrEmpty(
              hasCard: controller.engine.state.stock.isNotEmpty,
              width: cardWidth,
              height: cardHeight,
            ),
          ),
        ),
        const SizedBox(width: 12),

        // Waste (top card draggable)
        _PileSlot(
          key: controller.wasteKey,
          label: 'Waste',
          width: cardWidth,
          height: cardHeight,
          child: _WasteTop(
            controller: controller,
            width: cardWidth,
            height: cardHeight,
          ),
        ),
        const Spacer(),

        // Foundations
        Row(
          children: List.generate(4, (i) {
            return Padding(
              padding: EdgeInsets.only(left: i == 0 ? 0 : 12),
              child: _PileSlot(
                key: controller.foundationKeys[i],
                label: 'F$i',
                width: cardWidth,
                height: cardHeight,
                child: _FoundationTop(
                  controller: controller,
                  index: i,
                  width: cardWidth,
                  height: cardHeight,
                ),
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
            child: _TableauPile(
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

class _PileSlot extends StatelessWidget {
  final String label;
  final Widget child;
  final double width;
  final double height;

  const _PileSlot({
    super.key,
    required this.label,
    required this.child,
    required this.width,
    required this.height,
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
              border: Border.all(color: Colors.black26),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(child: child),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.black54),
        ),
      ],
    );
  }
}

// Waste top card view with overlay drag
class _WasteTop extends StatelessWidget {
  final GameController controller;
  final double width;
  final double height;

  const _WasteTop({
    required this.controller,
    required this.width,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    final waste = controller.engine.state.waste;
    if (waste.isEmpty) return const SizedBox.shrink();
    final top = waste.last;

    // 드래그 중이고, 드래그 원본이 waste라면 “원래 위치는 빈자리”로
    final isDraggingThis =
        controller.dragging && controller.dragFrom?.type == PileType.waste;
    final opacity = isDraggingThis ? 0.0 : 1.0;

    return Opacity(
      opacity: opacity,
      child: _DraggableCard(
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
}

// Foundation top card (드래그 허용: foundation -> tableau 등)
class _FoundationTop extends StatelessWidget {
  final GameController controller;
  final int index;
  final double width;
  final double height;

  const _FoundationTop({
    required this.controller,
    required this.index,
    required this.width,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    final f = controller.engine.state.foundation[index];
    if (f.isEmpty) return const SizedBox.shrink();
    final top = f.last;

    final isDraggingThis =
        controller.dragging &&
        controller.dragFrom?.type == PileType.foundation &&
        controller.dragFrom?.index == index;
    final opacity = isDraggingThis ? 0.0 : 1.0;

    return Opacity(
      opacity: opacity,
      child: _DraggableCard(
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
}

class _TableauPile extends StatelessWidget {
  final GameController controller;
  final int col;
  final double cardWidth;
  final double cardHeight;

  const _TableauPile({
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
          aspectRatio: 691 / 1056,
          child: _CardBackOrEmpty(hasCard: true),
        ),
      );
    }

    // faceUp 카드: 여기서부터 스택을 잡을 수 있게 함(연속 이동)
    return Opacity(
      opacity: shouldHide ? 0.0 : 1.0,
      child: _DraggableCard(
        card: card,
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

// ---------------- Drag Widgets ----------------

typedef DragStart = void Function(Offset globalPos, Rect sourceRect);
typedef DragUpdate = void Function(Offset globalPos);
typedef DragEnd = void Function();
typedef DragCancel = void Function();

class _DraggableCard extends StatelessWidget {
  final CardModel card;
  final double? width;
  final double? height;
  final DragStart onStart;
  final DragUpdate onUpdate;
  final DragEnd onEnd;
  final DragCancel onCancel;

  const _DraggableCard({
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
      child: _CardFace(card: card, width: width, height: height),
    );
  }
}

class _DragCardsView extends StatelessWidget {
  final List<CardModel> cards;
  final Size cardSize;
  const _DragCardsView({required this.cards, required this.cardSize});

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
                child: _CardFace(
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

// ---------------- Card render (placeholder) ----------------

class _CardBackOrEmpty extends StatelessWidget {
  final bool hasCard;
  final double? width;
  final double? height;
  const _CardBackOrEmpty({required this.hasCard, this.width, this.height});

  @override
  Widget build(BuildContext context) {
    if (!hasCard) return const SizedBox.shrink();
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

class _CardFace extends StatelessWidget {
  final CardModel card;
  final double? width;
  final double? height;
  const _CardFace({required this.card, this.width, this.height});

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

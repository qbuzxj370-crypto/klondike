import 'package:flutter/material.dart';
import '../solitaire_engine.dart';
import '../widgets/drag_view.dart';

/// 엔진 + 드래그 상태를 함께 들고 있는 컨트롤러
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

  @override
  void dispose() {
    _removeOverlay();
    super.dispose();
  }

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
      // faceUp/run 검사
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

    // 손가락이 카드 그룹의 topLeft에서 얼마나 떨어져 있는지
    fingerToTopLeft = pointerGlobalPos - sourceRectForOffset.topLeft;

    _entry = OverlayEntry(
      builder: (ctx) {
        final topLeft = pointerGlobal - fingerToTopLeft;
        return Positioned(
          left: topLeft.dx,
          top: topLeft.dy,
          child: IgnorePointer(
            child: DragCardsView(cards: dragCards, cardSize: dragCardSize!),
          ),
        );
      },
    );

    Overlay.of(context, rootOverlay: true).insert(_entry!);
    notifyListeners();
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
    // waste로 드롭은 금지 -> null
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

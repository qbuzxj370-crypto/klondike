// lib/game/solitaire_engine.dart
import 'dart:math';

enum Suit { clubs, diamonds, hearts, spades }

extension SuitX on Suit {
  bool get isRed => this == Suit.diamonds || this == Suit.hearts;
}

class CardModel {
  final Suit suit;
  final int rank; // 1..13 (A..K)
  bool faceUp;
  final int id; // unique

  CardModel({
    required this.suit,
    required this.rank,
    required this.faceUp,
    required this.id,
  });

  bool get isRed => suit.isRed;
}

enum PileType { stock, waste, tableau, foundation }

class PileRef {
  final PileType type;
  final int index; // tableau/foundation index, else 0
  const PileRef(this.type, [this.index = 0]);

  @override
  String toString() => 'PileRef($type,$index)';
}

class GameState {
  final List<List<CardModel>> tableau; // 7
  final List<List<CardModel>> foundation; // 4
  final List<CardModel> stock;
  final List<CardModel> waste;

  GameState({
    required this.tableau,
    required this.foundation,
    required this.stock,
    required this.waste,
  });

  factory GameState.empty() => GameState(
    tableau: List.generate(7, (_) => <CardModel>[]),
    foundation: List.generate(4, (_) => <CardModel>[]),
    stock: <CardModel>[],
    waste: <CardModel>[],
  );
}

/// --- Moves (Undo용) ---
sealed class Move {
  const Move();
}

class TransferMove extends Move {
  final PileRef from;
  final PileRef to;
  final int count;

  /// 이동 후 from의 새 top이 뒤집혀 공개되었다면 true
  final bool flippedFrom;

  /// flippedFrom == true 일 때, flip된 카드 id (undo에서 다시 faceDown)
  final int? flippedCardId;

  const TransferMove({
    required this.from,
    required this.to,
    required this.count,
    required this.flippedFrom,
    required this.flippedCardId,
  });
}

class DrawMove extends Move {
  const DrawMove();
}

class ResetMove extends Move {
  final int movedCount; // waste에서 stock으로 옮긴 수(= reset된 카드 수)
  const ResetMove(this.movedCount);
}

/// --- Engine ---
class SolitaireEngine {
  final Random _rng;
  final List<Move> _undo = [];

  GameState state = GameState.empty();

  SolitaireEngine({int? seed})
    : _rng = Random(seed ?? DateTime.now().millisecondsSinceEpoch);

  List<Move> get undoStack => List.unmodifiable(_undo);

  // ---------- Setup ----------
  void newGame() {
    state = GameState.empty();
    _undo.clear();

    final deck = _makeShuffledDeck();
    // Deal: tableau 1..7, each last faceUp
    int cursor = 0;
    for (int col = 0; col < 7; col++) {
      for (int k = 0; k <= col; k++) {
        final c = deck[cursor++];
        c.faceUp = (k == col);
        state.tableau[col].add(c);
      }
    }
    // Remaining -> stock faceDown
    for (; cursor < deck.length; cursor++) {
      final c = deck[cursor];
      c.faceUp = false;
      state.stock.add(c);
    }
  }

  List<CardModel> _makeShuffledDeck() {
    int id = 0;
    final deck = <CardModel>[];
    for (final s in Suit.values) {
      for (int r = 1; r <= 13; r++) {
        deck.add(CardModel(suit: s, rank: r, faceUp: false, id: id++));
      }
    }
    // Fisher-Yates
    for (int i = deck.length - 1; i > 0; i--) {
      final j = _rng.nextInt(i + 1);
      final tmp = deck[i];
      deck[i] = deck[j];
      deck[j] = tmp;
    }
    return deck;
  }

  // ---------- Public actions ----------
  /// Stock 탭: stock 있으면 Draw, 없으면 Reset(무제한), 아무것도 없으면 null
  Move? tryTapStock() {
    if (state.stock.isNotEmpty) {
      final mv = const DrawMove();
      _apply(mv);
      _undo.add(mv);
      return mv;
    }
    if (state.stock.isEmpty && state.waste.isNotEmpty) {
      final mv = ResetMove(state.waste.length);
      _apply(mv);
      _undo.add(mv);
      return mv;
    }
    return null;
  }

  /// from -> to 이동 시도.
  /// tableau에서 시작 인덱스가 필요할 수 있음(startIndex). (waste/foundation은 무시)
  Move? tryMove(PileRef from, PileRef to, {int? startIndex}) {
    final mv = _buildTransferMoveIfValid(from, to, startIndex: startIndex);
    if (mv == null) return null;
    _apply(mv);
    _undo.add(mv);
    return mv;
  }

  bool undo() {
    if (_undo.isEmpty) return false;
    final mv = _undo.removeLast();
    _revert(mv);
    return true;
  }

  bool get isWin {
    for (final f in state.foundation) {
      if (f.length != 13) return false;
    }
    return true;
  }

  // ---------- Move validation/build ----------
  TransferMove? _buildTransferMoveIfValid(
    PileRef from,
    PileRef to, {
    int? startIndex,
  }) {
    final fromList = _getPile(from);
    final toList = _getPile(to);

    if (fromList.isEmpty) return null;

    // Determine moving cards
    List<CardModel> moving;
    if (from.type == PileType.tableau) {
      final si = startIndex ?? (fromList.length - 1);
      if (si < 0 || si >= fromList.length) return null;
      moving = fromList.sublist(si);
      if (!_isMovableRunInTableau(moving)) return null;
    } else {
      // waste/foundation/stock: only top card (stock 직접 이동은 금지)
      if (from.type == PileType.stock) return null;
      moving = [fromList.last];
    }

    // Validate destination
    if (to.type == PileType.tableau) {
      if (!_canPlaceOnTableau(
        moving.first,
        toList.isEmpty ? null : toList.last,
      ))
        return null;
    } else if (to.type == PileType.foundation) {
      if (moving.length != 1) return null;
      if (!_canPlaceOnFoundation(
        moving.first,
        toList.isEmpty ? null : toList.last,
      ))
        return null;
    } else {
      // cannot move into stock/waste directly (waste는 stock 탭으로만 쌓인다고 가정)
      return null;
    }

    // Build TransferMove + flip info (from tableau only)
    bool flipped = false;
    int? flippedId;

    // flip은 apply 이후 알 수 있지만, 규칙상 예측 가능:
    // tableau에서 카드를 떼고 난 뒤 남는 top이 faceDown이면 flip됨
    if (from.type == PileType.tableau) {
      final remainCount = fromList.length - moving.length;
      if (remainCount > 0) {
        final newTop = fromList[remainCount - 1];
        if (!newTop.faceUp) {
          flipped = true;
          flippedId = newTop.id;
        }
      }
    }

    return TransferMove(
      from: from,
      to: to,
      count: moving.length,
      flippedFrom: flipped,
      flippedCardId: flippedId,
    );
  }

  bool _isMovableRunInTableau(List<CardModel> run) {
    if (run.isEmpty) return false;
    if (!run.first.faceUp) return false;
    // 모든 카드가 faceUp이어야 함
    if (run.any((c) => !c.faceUp)) return false;

    for (int i = 0; i < run.length - 1; i++) {
      final upper = run[i]; // 위쪽(먼저 잡은)
      final lower = run[i + 1]; // 그 아래
      // tableau에서 아래로 갈수록 rank는 -1, 색 교대
      if (upper.rank != lower.rank + 1) return false;
      if (upper.isRed == lower.isRed) return false;
    }
    return true;
  }

  bool _canPlaceOnTableau(CardModel movingTop, CardModel? destTop) {
    if (destTop == null) {
      return movingTop.rank == 13; // K only
    }
    if (!destTop.faceUp) return false;
    if (destTop.rank != movingTop.rank + 1) return false;
    if (destTop.isRed == movingTop.isRed) return false;
    return true;
  }

  bool _canPlaceOnFoundation(CardModel card, CardModel? destTop) {
    if (destTop == null) {
      return card.rank == 1; // A
    }
    if (destTop.suit != card.suit) return false;
    return card.rank == destTop.rank + 1;
  }

  // ---------- Apply / Revert ----------
  void _apply(Move mv) {
    switch (mv) {
      case DrawMove():
        final c = state.stock.removeLast();
        c.faceUp = true;
        state.waste.add(c);
        break;

      case ResetMove(:final movedCount):
        // Move all waste -> stock, preserving draw order (standard approach: reverse)
        // waste: [ ... bottom, top ] , after reset stock top should be last drawn (so reverse)
        final temp = List<CardModel>.from(state.waste.reversed);
        state.waste.clear();
        for (final c in temp) {
          c.faceUp = false;
          state.stock.add(c);
        }
        assert(temp.length == movedCount);
        break;

      case TransferMove(
        :final from,
        :final to,
        :final count,
        :final flippedFrom,
        :final flippedCardId,
      ):
        final fromList = _getPile(from);
        final toList = _getPile(to);

        final moving = fromList.sublist(fromList.length - count);
        fromList.removeRange(fromList.length - count, fromList.length);
        toList.addAll(moving);

        if (flippedFrom && flippedCardId != null) {
          // after removing, flip new top if matches id
          final newTop = fromList.isNotEmpty ? fromList.last : null;
          if (newTop != null && newTop.id == flippedCardId) {
            newTop.faceUp = true;
          }
        }
        break;
    }
  }

  void _revert(Move mv) {
    switch (mv) {
      case DrawMove():
        final c = state.waste.removeLast();
        c.faceUp = false;
        state.stock.add(c);
        break;

      case ResetMove(:final movedCount):
        // stock -> waste (undo reset). Take last movedCount from stock, reverse back.
        final slice = state.stock.sublist(state.stock.length - movedCount);
        state.stock.removeRange(
          state.stock.length - movedCount,
          state.stock.length,
        );

        for (final c in slice.reversed) {
          c.faceUp = true;
          state.waste.add(c);
        }
        break;

      case TransferMove(
        :final from,
        :final to,
        :final count,
        :final flippedFrom,
        :final flippedCardId,
      ):
        final fromList = _getPile(from);
        final toList = _getPile(to);

        final moving = toList.sublist(toList.length - count);
        toList.removeRange(toList.length - count, toList.length);
        fromList.addAll(moving);

        if (flippedFrom && flippedCardId != null) {
          // flip back to faceDown (it should still exist in from pile)
          for (int i = fromList.length - 1; i >= 0; i--) {
            if (fromList[i].id == flippedCardId) {
              fromList[i].faceUp = false;
              break;
            }
          }
        }
        break;
    }
  }

  List<CardModel> _getPile(PileRef ref) {
    switch (ref.type) {
      case PileType.stock:
        return state.stock;
      case PileType.waste:
        return state.waste;
      case PileType.tableau:
        return state.tableau[ref.index];
      case PileType.foundation:
        return state.foundation[ref.index];
    }
  }
}

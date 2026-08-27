import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/storage/hive_boxes.dart';
import '../../../core/storage/models/calc_history_entry.dart';
import '../domain/access_trigger_service.dart';
import '../domain/calculator_engine.dart';

class CalculatorState {
  final String expression;
  final String displayValue;
  final double? memoryValue;
  final String? error;
  final bool scientificMode;

  const CalculatorState({
    this.expression = '',
    this.displayValue = '0',
    this.memoryValue,
    this.error,
    this.scientificMode = false,
  });

  CalculatorState copyWith({
    String? expression,
    String? displayValue,
    double? memoryValue,
    bool clearMemory = false,
    String? error,
    bool clearError = false,
    bool? scientificMode,
  }) {
    return CalculatorState(
      expression: expression ?? this.expression,
      displayValue: displayValue ?? this.displayValue,
      memoryValue: clearMemory ? null : (memoryValue ?? this.memoryValue),
      error: clearError ? null : (error ?? this.error),
      scientificMode: scientificMode ?? this.scientificMode,
    );
  }
}

class CalculatorNotifier extends StateNotifier<CalculatorState> {
  CalculatorNotifier(this._ref) : super(const CalculatorState());

  final Ref _ref;
  final _evaluator = ExpressionEvaluator();
  final _uuid = const Uuid();

  void input(String value) {
    if (state.error != null) {
      state = state.copyWith(expression: '', displayValue: '0', clearError: true);
    }
    final newExpr = state.expression + value;
    state = state.copyWith(expression: newExpr, displayValue: newExpr.isEmpty ? '0' : newExpr);
  }

  void clear() {
    state = state.copyWith(expression: '', displayValue: '0', clearError: true);
  }

  void backspace() {
    if (state.expression.isEmpty) return;
    final newExpr = state.expression.substring(0, state.expression.length - 1);
    state = state.copyWith(expression: newExpr, displayValue: newExpr.isEmpty ? '0' : newExpr, clearError: true);
  }

  void toggleSign() {
    if (state.expression.isEmpty) return;
    if (state.expression.startsWith('-')) {
      state = state.copyWith(expression: state.expression.substring(1), displayValue: state.expression.substring(1));
    } else {
      state = state.copyWith(expression: '-${state.expression}', displayValue: '-${state.expression}');
    }
  }

  void toggleScientific() {
    state = state.copyWith(scientificMode: !state.scientificMode);
  }

  void applyFunction(String fn) {
    try {
      final current = _evaluator.evaluate(state.expression.isEmpty ? state.displayValue : state.expression);
      final result = ScientificFunctions.apply(fn, current);
      final formatted = _format(result);
      state = state.copyWith(expression: formatted, displayValue: formatted, clearError: true);
    } catch (e) {
      state = state.copyWith(error: 'Error', displayValue: 'Error');
    }
  }

  void memoryClear() => state = state.copyWith(clearMemory: true);

  void memoryRecall() {
    if (state.memoryValue == null) return;
    final formatted = _format(state.memoryValue!);
    state = state.copyWith(expression: formatted, displayValue: formatted);
  }

  void memoryAdd() {
    final value = _currentValueOrNull();
    if (value == null) return;
    state = state.copyWith(memoryValue: (state.memoryValue ?? 0) + value);
  }

  void memorySubtract() {
    final value = _currentValueOrNull();
    if (value == null) return;
    state = state.copyWith(memoryValue: (state.memoryValue ?? 0) - value);
  }

  void memoryStore() {
    final value = _currentValueOrNull();
    if (value == null) return;
    state = state.copyWith(memoryValue: value);
  }

  double? _currentValueOrNull() {
    try {
      return _evaluator.evaluate(state.expression);
    } catch (_) {
      return null;
    }
  }

  /// Evaluates "=". Returns true if this evaluation matched the vault
  /// access trigger (in which case the UI should navigate to auth instead
  /// of showing a numeric result).
  bool equals() {
    final trigger = _ref.read(accessTriggerServiceProviderRef);
    if (trigger.matchesTrigger(state.expression)) {
      state = state.copyWith(expression: '', displayValue: '0');
      return true;
    }

    try {
      final result = _evaluator.evaluate(state.expression);
      final formatted = _format(result);
      _saveHistory(state.expression, formatted);
      state = state.copyWith(expression: formatted, displayValue: formatted, clearError: true);
    } catch (e) {
      state = state.copyWith(error: 'Error', displayValue: 'Error');
    }
    return false;
  }

  void _saveHistory(String expression, String result) {
    if (expression.trim().isEmpty) return;
    final entry = CalcHistoryEntry(
      id: _uuid.v4(),
      expression: expression,
      result: result,
      createdAt: DateTime.now(),
    );
    HiveBoxes.history.put(entry.id, entry);
  }

  String _format(double value) {
    if (value.isNaN || value.isInfinite) return 'Error';
    if (value == value.roundToDouble() && value.abs() < 1e15) {
      return value.toStringAsFixed(0);
    }
    String s = value.toStringAsFixed(8);
    s = s.replaceFirst(RegExp(r'0+$'), '');
    s = s.replaceFirst(RegExp(r'\.$'), '');
    return s;
  }
}

// Kept as a separate top-level provider reference to avoid a circular import
// between calculator_state.dart and core/providers.dart.
final accessTriggerServiceProviderRef = Provider((ref) => AccessTriggerService());

final calculatorProvider = StateNotifierProvider<CalculatorNotifier, CalculatorState>((ref) {
  return CalculatorNotifier(ref);
});

final calcHistoryListProvider = Provider<List<CalcHistoryEntry>>((ref) {
  return HiveBoxes.history.values.toList().reversed.toList();
});

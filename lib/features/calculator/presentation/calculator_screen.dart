import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'calculator_state.dart';
import 'widgets/calc_button.dart';
import 'widgets/calc_history_sheet.dart';

class CalculatorScreen extends ConsumerWidget {
  const CalculatorScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(calculatorProvider);
    final notifier = ref.read(calculatorProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Calculator'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'History',
            onPressed: () => showCalcHistorySheet(context),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'scientific') notifier.toggleScientific();
              if (value == 'settings') context.push('/settings');
            },
            itemBuilder: (context) => [
              CheckedPopupMenuItem(
                value: 'scientific',
                checked: state.scientificMode,
                child: const Text('Scientific mode'),
              ),
              const PopupMenuItem(value: 'settings', child: Text('Settings')),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (state.memoryValue != null)
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Padding(
                          padding: EdgeInsets.only(bottom: 8),
                          child: Text('M', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    Semantics(
                      label: 'Current expression ${state.expression}',
                      child: Text(
                        state.expression.isEmpty ? ' ' : state.expression,
                        style: TextStyle(fontSize: 20, color: Colors.grey.shade600),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Semantics(
                      label: 'Result ${state.displayValue}',
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Text(
                          state.error ?? state.displayValue,
                          style: const TextStyle(fontSize: 56, fontWeight: FontWeight.w300),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
            _MemoryRow(notifier: notifier),
            if (state.scientificMode) _ScientificRow(notifier: notifier),
            _MainKeypad(notifier: notifier),
          ],
        ),
      ),
    );
  }
}

class _MemoryRow extends StatelessWidget {
  const _MemoryRow({required this.notifier});
  final CalculatorNotifier notifier;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: CalcButton(label: 'MC', style: CalcButtonStyle.function, onTap: notifier.memoryClear)),
        Expanded(child: CalcButton(label: 'MR', style: CalcButtonStyle.function, onTap: notifier.memoryRecall)),
        Expanded(child: CalcButton(label: 'M+', style: CalcButtonStyle.function, onTap: notifier.memoryAdd)),
        Expanded(child: CalcButton(label: 'M−', style: CalcButtonStyle.function, onTap: notifier.memorySubtract)),
        Expanded(child: CalcButton(label: 'MS', style: CalcButtonStyle.function, onTap: notifier.memoryStore)),
      ],
    );
  }
}

class _ScientificRow extends StatelessWidget {
  const _ScientificRow({required this.notifier});
  final CalculatorNotifier notifier;

  @override
  Widget build(BuildContext context) {
    const fns = ['sin', 'cos', 'tan', 'log', 'ln', 'sqrt'];
    return Row(
      children: fns
          .map((fn) => Expanded(
                child: CalcButton(
                  label: fn,
                  style: CalcButtonStyle.function,
                  onTap: () => notifier.applyFunction(fn),
                ),
              ))
          .toList(),
    );
  }
}

class _MainKeypad extends ConsumerWidget {
  const _MainKeypad({required this.notifier});
  final CalculatorNotifier notifier;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        Row(children: [
          Expanded(child: CalcButton(label: 'AC', style: CalcButtonStyle.function, onTap: notifier.clear)),
          Expanded(child: CalcButton(label: '±', style: CalcButtonStyle.function, onTap: notifier.toggleSign)),
          Expanded(child: CalcButton(label: '%', style: CalcButtonStyle.function, onTap: () => notifier.input('%'))),
          Expanded(child: CalcButton(label: '÷', style: CalcButtonStyle.operatorStyle, onTap: () => notifier.input('÷'))),
        ]),
        Row(children: [
          Expanded(child: CalcButton(label: '7', onTap: () => notifier.input('7'))),
          Expanded(child: CalcButton(label: '8', onTap: () => notifier.input('8'))),
          Expanded(child: CalcButton(label: '9', onTap: () => notifier.input('9'))),
          Expanded(child: CalcButton(label: '×', style: CalcButtonStyle.operatorStyle, onTap: () => notifier.input('×'))),
        ]),
        Row(children: [
          Expanded(child: CalcButton(label: '4', onTap: () => notifier.input('4'))),
          Expanded(child: CalcButton(label: '5', onTap: () => notifier.input('5'))),
          Expanded(child: CalcButton(label: '6', onTap: () => notifier.input('6'))),
          Expanded(child: CalcButton(label: '−', style: CalcButtonStyle.operatorStyle, onTap: () => notifier.input('-'))),
        ]),
        Row(children: [
          Expanded(child: CalcButton(label: '1', onTap: () => notifier.input('1'))),
          Expanded(child: CalcButton(label: '2', onTap: () => notifier.input('2'))),
          Expanded(child: CalcButton(label: '3', onTap: () => notifier.input('3'))),
          Expanded(child: CalcButton(label: '+', style: CalcButtonStyle.operatorStyle, onTap: () => notifier.input('+'))),
        ]),
        Row(children: [
          Expanded(
            flex: 2,
            child: CalcButton(label: '0', onTap: () => notifier.input('0')),
          ),
          Expanded(child: CalcButton(label: '.', onTap: () => notifier.input('.'))),
          Expanded(
            child: CalcButton(
              label: '=',
              style: CalcButtonStyle.operatorStyle,
              onTap: () => _onEquals(context, ref),
              // Fallback vault trigger: long-press "=" always opens
              // authentication, regardless of the configured numeric code.
              onLongPress: () {
                HapticFeedback.mediumImpact();
                context.push('/auth');
              },
            ),
          ),
        ]),
      ],
    );
  }

  void _onEquals(BuildContext context, WidgetRef ref) {
    final triggered = notifier.equals();
    if (triggered) {
      context.push('/auth');
    }
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum CalcButtonStyle { number, operatorStyle, function }

const _semanticNames = {
  '0': 'Zero', '1': 'One', '2': 'Two', '3': 'Three', '4': 'Four',
  '5': 'Five', '6': 'Six', '7': 'Seven', '8': 'Eight', '9': 'Nine',
  '+': 'Plus', '-': 'Minus', '−': 'Minus', '×': 'Multiply', '÷': 'Divide',
  '=': 'Equals', '.': 'Decimal point', '%': 'Percent', '±': 'Toggle sign',
  'AC': 'All clear',
};

class CalcButton extends StatelessWidget {
  const CalcButton({
    super.key,
    required this.label,
    required this.onTap,
    this.onLongPress,
    this.style = CalcButtonStyle.number,
  });

  final String label;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final CalcButtonStyle style;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Color bg;
    Color fg;
    switch (style) {
      case CalcButtonStyle.operatorStyle:
        bg = theme.colorScheme.primary;
        fg = theme.colorScheme.onPrimary;
        break;
      case CalcButtonStyle.function:
        bg = theme.colorScheme.surfaceContainerHighest;
        fg = theme.colorScheme.onSurfaceVariant;
        break;
      case CalcButtonStyle.number:
        bg = theme.colorScheme.surface;
        fg = theme.colorScheme.onSurface;
        break;
    }

    return Semantics(
      button: true,
      label: _semanticNames[label] ?? label,
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Material(
          color: bg,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () {
              HapticFeedback.selectionClick();
              onTap();
            },
            onLongPress: onLongPress,
            child: AspectRatio(
              aspectRatio: 1,
              child: Center(
                child: Text(
                  label,
                  style: TextStyle(fontSize: 24, color: fg, fontWeight: FontWeight.w500),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/storage/hive_boxes.dart';
import '../calculator_state.dart';

void showCalcHistorySheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => const _CalcHistorySheet(),
  );
}

class _CalcHistorySheet extends ConsumerWidget {
  const _CalcHistorySheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(calcHistoryListProvider);
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      expand: false,
      builder: (context, controller) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('History', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  TextButton(
                    onPressed: () async {
                      await HiveBoxes.history.clear();
                      ref.invalidate(calcHistoryListProvider);
                    },
                    child: const Text('Clear history'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: history.isEmpty
                  ? const Center(child: Text('No calculations yet'))
                  : ListView.builder(
                      controller: controller,
                      itemCount: history.length,
                      itemBuilder: (context, index) {
                        final entry = history[index];
                        return Dismissible(
                          key: ValueKey(entry.id),
                          onDismissed: (_) async {
                            await HiveBoxes.history.delete(entry.id);
                            ref.invalidate(calcHistoryListProvider);
                          },
                          child: ListTile(
                            title: Text(entry.expression),
                            subtitle: Text(DateFormat.yMMMd().add_jm().format(entry.createdAt)),
                            trailing: Text(entry.result, style: const TextStyle(fontWeight: FontWeight.bold)),
                            onTap: () {
                              Clipboard.setData(ClipboardData(text: entry.result));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Copied to clipboard')),
                              );
                            },
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}

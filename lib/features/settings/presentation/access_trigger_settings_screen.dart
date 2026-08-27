import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';

class AccessTriggerSettingsScreen extends ConsumerStatefulWidget {
  const AccessTriggerSettingsScreen({super.key});

  @override
  ConsumerState<AccessTriggerSettingsScreen> createState() => _AccessTriggerSettingsScreenState();
}

class _AccessTriggerSettingsScreenState extends ConsumerState<AccessTriggerSettingsScreen> {
  late final _controller = TextEditingController(text: ref.read(accessTriggerServiceProvider).getTriggerCode() ?? '');

  @override
  Widget build(BuildContext context) {
    final service = ref.read(accessTriggerServiceProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Vault Access Trigger')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Long-pressing "=" always opens the vault sign-in screen. '
              'Optionally, you can also set a secret numeric code — entering it '
              'and pressing "=" on the calculator opens the vault instead of showing a result.',
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _controller,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Secret code (optional)',
                hintText: 'e.g. 007',
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () async {
                await service.setTriggerCode(_controller.text.isEmpty ? null : _controller.text);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved')));
                }
              },
              child: const Padding(padding: EdgeInsets.symmetric(vertical: 14), child: Text('Save')),
            ),
          ],
        ),
      ),
    );
  }
}

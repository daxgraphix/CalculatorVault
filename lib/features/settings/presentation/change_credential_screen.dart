import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers.dart';
import '../../../core/security/credential_manager.dart';

class ChangeCredentialScreen extends ConsumerStatefulWidget {
  const ChangeCredentialScreen({super.key});

  @override
  ConsumerState<ChangeCredentialScreen> createState() => _ChangeCredentialScreenState();
}

class _ChangeCredentialScreenState extends ConsumerState<ChangeCredentialScreen> {
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  CredentialType _newType = CredentialType.pin;
  String? _error;
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Change PIN / Password')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: ListView(
          children: [
            TextField(
              controller: _current,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Current PIN / password'),
            ),
            const SizedBox(height: 16),
            SegmentedButton<CredentialType>(
              segments: const [
                ButtonSegment(value: CredentialType.pin, label: Text('PIN')),
                ButtonSegment(value: CredentialType.password, label: Text('Password')),
              ],
              selected: {_newType},
              onSelectionChanged: (s) => setState(() => _newType = s.first),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _next,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'New PIN / password'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _confirm,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Confirm new PIN / password'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _busy ? null : _submit,
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 14),
                child: Text('Save'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final credManager = ref.read(credentialManagerProvider);
    final valid = _newType == CredentialType.pin
        ? credManager.isValidPin(_next.text)
        : credManager.isValidPassword(_next.text);
    if (!valid) {
      setState(() => _error = 'New credential does not meet requirements.');
      return;
    }
    if (_next.text != _confirm.text) {
      setState(() => _error = 'New credentials do not match.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    final success = await credManager.changeCredential(
      currentCredential: _current.text,
      newCredential: _next.text,
      newType: _newType,
    );

    if (!mounted) return;
    if (!success) {
      setState(() {
        _busy = false;
        _error = 'Current PIN / password is incorrect.';
      });
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Credential updated')));
    context.pop();
  }
}

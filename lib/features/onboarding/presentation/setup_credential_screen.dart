import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers.dart';
import '../../../core/security/credential_manager.dart';

class SetupCredentialScreen extends ConsumerStatefulWidget {
  const SetupCredentialScreen({super.key, required this.isPin});
  final bool isPin;

  @override
  ConsumerState<SetupCredentialScreen> createState() => _SetupCredentialScreenState();
}

class _SetupCredentialScreenState extends ConsumerState<SetupCredentialScreen> {
  final _first = TextEditingController();
  final _confirm = TextEditingController();
  String? _error;
  bool _confirming = false;
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final controller = _confirming ? _confirm : _first;
    return Scaffold(
      appBar: AppBar(title: Text(widget.isPin ? 'Create PIN' : 'Create Password')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _confirming
                  ? (widget.isPin ? 'Confirm PIN' : 'Confirm Password')
                  : (widget.isPin ? 'Choose 4–8 digits.' : 'At least 8 characters.'),
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: controller,
              autofocus: true,
              obscureText: true,
              keyboardType: widget.isPin ? TextInputType.number : TextInputType.text,
              inputFormatters: widget.isPin ? [FilteringTextInputFormatter.digitsOnly] : null,
              maxLength: widget.isPin ? 8 : null,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 28, letterSpacing: 8),
              decoration: const InputDecoration(counterText: ''),
              onSubmitted: (_) => _onContinue(),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _busy ? null : _onContinue,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Text(_confirming ? 'Confirm' : 'Continue'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _onContinue() async {
    final credManager = ref.read(credentialManagerProvider);
    if (!_confirming) {
      final value = _first.text;
      final valid = widget.isPin ? credManager.isValidPin(value) : credManager.isValidPassword(value);
      if (!valid) {
        setState(() {
          _error = widget.isPin
              ? 'Choose 4–8 digits and avoid obvious sequences like 1234 or 0000.'
              : 'Password must be at least 8 characters.';
        });
        return;
      }
      setState(() {
        _confirming = true;
        _error = null;
      });
      return;
    }

    if (_confirm.text != _first.text) {
      setState(() => _error = 'Does not match. Try again.');
      _confirm.clear();
      return;
    }

    setState(() => _busy = true);
    await credManager.setUpCredential(
      credential: _first.text,
      type: widget.isPin ? CredentialType.pin : CredentialType.password,
    );
    if (!mounted) return;
    context.go('/calculator');
  }
}

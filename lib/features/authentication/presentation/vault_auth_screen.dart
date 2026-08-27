import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers.dart';
import '../../../core/security/credential_manager.dart';

/// Shown whenever the vault needs authenticating: after the calculator
/// access trigger, or on cold start if a session was never established.
class VaultAuthScreen extends ConsumerStatefulWidget {
  const VaultAuthScreen({super.key});

  @override
  ConsumerState<VaultAuthScreen> createState() => _VaultAuthScreenState();
}

class _VaultAuthScreenState extends ConsumerState<VaultAuthScreen> {
  final _controller = TextEditingController();
  String? _error;
  bool _busy = false;
  CredentialType? _type;

  @override
  void initState() {
    super.initState();
    _loadType();
  }

  Future<void> _loadType() async {
    final type = await ref.read(credentialManagerProvider).getCredentialType();
    if (mounted) setState(() => _type = type);
  }

  @override
  Widget build(BuildContext context) {
    final isPin = _type != CredentialType.password;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Unlock Vault'),
        leading: IconButton(icon: const Icon(Icons.close), onPressed: () => context.go('/calculator')),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              isPin ? 'Enter your PIN' : 'Enter your password',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _controller,
              autofocus: true,
              obscureText: true,
              keyboardType: isPin ? TextInputType.number : TextInputType.text,
              inputFormatters: isPin ? [FilteringTextInputFormatter.digitsOnly] : null,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 28, letterSpacing: 8),
              onSubmitted: (_) => _submit(),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _busy ? null : _submit,
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 14),
                child: Text('Unlock'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final credManager = ref.read(credentialManagerProvider);
    final session = ref.read(vaultSessionManagerProvider);

    if (await credManager.isLockedOut()) {
      final remaining = await credManager.lockoutRemaining();
      setState(() => _error = 'Too many attempts. Try again in ${remaining?.inSeconds ?? 0}s.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });
    session.beginAuthenticating();

    final masterKey = await credManager.verifyAndUnwrap(_controller.text);
    if (masterKey == null) {
      session.authenticationFailed();
      final attempts = await credManager.getFailedAttempts();
      setState(() {
        _busy = false;
        _error = 'Incorrect. ${5 - attempts >= 0 ? 5 - attempts : 0} attempts remaining before lockout.';
        _controller.clear();
      });
      return;
    }

    session.unlock(masterKey);
    if (!mounted) return;
    context.go('/vault');
  }
}

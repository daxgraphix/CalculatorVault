import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.calculate_outlined, size: 96),
              const SizedBox(height: 24),
              Text('Calculator Vault', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 12),
              const Text(
                'Calculate. Protect. Keep Private.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 8),
              const Text(
                'An offline calculator with encrypted storage.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => context.push('/onboarding/privacy'),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 14),
                    child: Text('Get Started'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PrivacyIntroScreen extends StatelessWidget {
  const PrivacyIntroScreen({super.key});

  static const _points = [
    'No account required',
    'No cloud, no sync',
    'Fully offline operation',
    'Encrypted vault (AES-256-GCM)',
    'PIN / password protection only',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Your Privacy')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Your files stay on this device.', style: TextStyle(fontSize: 18)),
            const SizedBox(height: 24),
            for (final point in _points)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.green, size: 20),
                    const SizedBox(width: 12),
                    Text(point),
                  ],
                ),
              ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => context.push('/onboarding/security'),
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 14),
                  child: Text('Continue'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SecuritySetupScreen extends StatefulWidget {
  const SecuritySetupScreen({super.key});

  @override
  State<SecuritySetupScreen> createState() => _SecuritySetupScreenState();
}

class _SecuritySetupScreenState extends State<SecuritySetupScreen> {
  String _choice = 'pin';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Protect Your Vault')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Choose an unlock method.', style: TextStyle(fontSize: 16)),
            const SizedBox(height: 16),
            RadioListTile<String>(
              value: 'pin',
              groupValue: _choice,
              onChanged: (v) => setState(() => _choice = v!),
              title: const Text('PIN'),
              subtitle: const Text('Fast numeric authentication (4–8 digits)'),
            ),
            RadioListTile<String>(
              value: 'password',
              groupValue: _choice,
              onChanged: (v) => setState(() => _choice = v!),
              title: const Text('Password'),
              subtitle: const Text('Stronger text authentication'),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => context.push('/onboarding/setup-credential?type=$_choice'),
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 14),
                  child: Text('Continue'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

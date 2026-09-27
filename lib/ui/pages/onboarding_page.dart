import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../api/truenas_client.dart';
import '../../app_state.dart';
import '../theme.dart';

/// First-run screen: enter the TrueNAS URL and an API key. No env files, no
/// CLI flags — the whole connection setup happens here.
class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final _formKey = GlobalKey<FormState>();
  final _urlController = TextEditingController();
  final _keyController = TextEditingController();
  bool _selfSigned = true;
  bool _obscure = true;

  @override
  void dispose() {
    _urlController.dispose();
    _keyController.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final state = context.read<AppState>();
    await state.connect(ConnectionConfig(
      url: _urlController.text.trim(),
      apiKey: _keyController.text.trim(),
      allowSelfSigned: _selfSigned,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final theme = Theme.of(context);
    final connecting = state.status == ConnectionStatus.connecting;

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Panel(
              padding: const EdgeInsets.all(32),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [HymnTheme.accent, HymnTheme.accentAlt],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Icon(Icons.storage,
                            color: Colors.white, size: 36),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Connect to your NAS',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Generate an API key in TrueNAS under the user menu, '
                      'My API Keys, then paste it below.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color:
                            theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(height: 28),
                    TextFormField(
                      controller: _urlController,
                      enabled: !connecting,
                      keyboardType: TextInputType.url,
                      decoration: const InputDecoration(
                        labelText: 'TrueNAS URL',
                        hintText: 'https://truenas.local',
                        prefixIcon: Icon(Icons.dns_outlined),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Enter the server address'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _keyController,
                      enabled: !connecting,
                      obscureText: _obscure,
                      decoration: InputDecoration(
                        labelText: 'API Key',
                        hintText: 'Paste your TrueNAS API key',
                        prefixIcon: const Icon(Icons.key_outlined),
                        suffixIcon: IconButton(
                          icon: Icon(_obscure
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined),
                          onPressed: () =>
                              setState(() => _obscure = !_obscure),
                        ),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Enter the API key'
                          : null,
                    ),
                    const SizedBox(height: 8),
                    Material(
                      type: MaterialType.transparency,
                      child: SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Allow self-signed certificates'),
                        subtitle: const Text(
                            'Common on local NAS installs. Leave on unless you have a valid cert.'),
                        value: _selfSigned,
                        onChanged: connecting
                            ? null
                            : (v) => setState(() => _selfSigned = v),
                      ),
                    ),
                    if (state.status == ConnectionStatus.failed &&
                        state.error != null)
                      Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: HymnTheme.danger.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: HymnTheme.danger.withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          state.error!,
                          style: const TextStyle(
                              color: HymnTheme.danger, fontSize: 13),
                        ),
                      ),
                    const SizedBox(height: 8),
                    FilledButton(
                      onPressed: connecting ? null : _connect,
                      child: connecting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Connect'),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Powered by TrueNAS SCALE',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.labelSmall?.copyWith(
                          color:
                              theme.colorScheme.onSurface.withValues(alpha: 0.4)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

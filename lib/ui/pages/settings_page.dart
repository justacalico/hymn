import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../api/models.dart';
import '../../app_state.dart';
import '../../utils/format.dart';
import '../theme.dart';
import '../widgets/loader.dart';

class _SettingsData {
  final SystemInfo system;
  final List<NasService> services;

  const _SettingsData(this.system, this.services);
}

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DataLoader<_SettingsData>(
      load: (client) async {
        final results = await Future.wait([
          client.getSystemInfo(),
          client.getServices(),
        ]);
        return _SettingsData(
          results[0] as SystemInfo,
          results[1] as List<NasService>,
        );
      },
      builder: (context, data, refresh) =>
          _SettingsView(data: data, refresh: refresh),
    );
  }
}

class _SettingsView extends StatelessWidget {
  final _SettingsData data;
  final VoidCallback refresh;

  const _SettingsView({required this.data, required this.refresh});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = context.watch<AppState>();
    final system = data.system;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Row(
          children: [
            Expanded(
              child: Text('Settings',
                  style: theme.textTheme.headlineMedium
                      ?.copyWith(fontWeight: FontWeight.w700)),
            ),
            IconButton(
              onPressed: refresh,
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh',
            ),
          ],
        ),
        const SizedBox(height: 12),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              sectionLabel(context, 'Server'),
              const SizedBox(height: 12),
              _row('Hostname', system.hostname),
              _row('Version', 'TrueNAS ${system.version}'),
              _row('CPU', '${system.cpuModel} · ${system.cores} cores'),
              _row('Memory', formatBytes(system.physicalMemory)),
              _row('Uptime', formatUptime(system.uptimeSeconds)),
              if (system.timezone.isNotEmpty)
                _row('Timezone', system.timezone),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              sectionLabel(context, 'Services'),
              const SizedBox(height: 8),
              for (final service in data.services)
                _ServiceRow(service: service, onChanged: refresh),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              sectionLabel(context, 'Appearance'),
              const SizedBox(height: 8),
              SegmentedButton<ThemeSetting>(
                segments: const [
                  ButtonSegment(
                      value: ThemeSetting.system,
                      label: Text('System'),
                      icon: Icon(Icons.brightness_auto)),
                  ButtonSegment(
                      value: ThemeSetting.light,
                      label: Text('Light'),
                      icon: Icon(Icons.light_mode)),
                  ButtonSegment(
                      value: ThemeSetting.dark,
                      label: Text('Dark'),
                      icon: Icon(Icons.dark_mode)),
                  ButtonSegment(
                      value: ThemeSetting.oled,
                      label: Text('OLED'),
                      icon: Icon(Icons.brightness_2)),
                ],
                selected: {state.theme},
                onSelectionChanged: (s) => state.setTheme(s.first),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              sectionLabel(context, 'Power'),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _power(context, reboot: true),
                      icon: const Icon(Icons.restart_alt),
                      label: const Text('Reboot'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                          foregroundColor: HymnTheme.danger),
                      onPressed: () => _power(context, reboot: false),
                      icon: const Icon(Icons.power_settings_new),
                      label: const Text('Shut down'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              sectionLabel(context, 'Connection'),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      state.config?.url ?? '',
                      style: theme.textTheme.bodyMedium,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => _disconnect(context),
                    icon: const Icon(Icons.link_off, size: 18),
                    label: const Text('Disconnect'),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _row(String label, String value) {
    return Builder(builder: (context) {
      final theme = Theme.of(context);
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          children: [
            SizedBox(
              width: 90,
              child: Text(label,
                  style: theme.textTheme.bodySmall?.copyWith(
                      color:
                          theme.colorScheme.onSurface.withValues(alpha: 0.5))),
            ),
            Expanded(child: Text(value, style: theme.textTheme.bodyMedium)),
          ],
        ),
      );
    });
  }

  Future<void> _power(BuildContext context, {required bool reboot}) async {
    final client = context.read<AppState>().client;
    if (client == null) return;
    final verb = reboot ? 'Reboot' : 'Shut down';
    final confirmed = await confirmAction(
      context,
      title: '$verb the NAS?',
      message:
          'The TrueNAS server will ${reboot ? 'restart' : 'power off'}. All connections drop.',
      confirmLabel: verb,
    );
    if (!confirmed) return;
    try {
      if (reboot) {
        await client.reboot();
      } else {
        await client.shutdown();
      }
      if (context.mounted) showToast(context, '$verb command sent');
    } catch (e) {
      if (context.mounted) showToast(context, '$e', error: true);
    }
  }

  Future<void> _disconnect(BuildContext context) async {
    final confirmed = await confirmAction(
      context,
      title: 'Disconnect from this NAS?',
      message: 'The saved server address and API key are removed from this device.',
      confirmLabel: 'Disconnect',
    );
    if (!confirmed || !context.mounted) return;
    await context.read<AppState>().disconnect();
  }
}

class _ServiceRow extends StatelessWidget {
  final NasService service;
  final VoidCallback onChanged;

  const _ServiceRow({required this.service, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final client = context.read<AppState>().client;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(service.service.toUpperCase(),
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                Text(service.state,
                    style: theme.textTheme.bodySmall?.copyWith(
                        color: service.running
                            ? HymnTheme.success
                            : theme.colorScheme.onSurface
                                .withValues(alpha: 0.45))),
              ],
            ),
          ),
          Switch(
            value: service.running,
            onChanged: (v) async {
              if (client == null) return;
              try {
                if (v) {
                  await client.startService(service.service);
                } else {
                  await client.stopService(service.service);
                }
                onChanged();
              } catch (e) {
                if (context.mounted) {
                  showToast(context, '$e', error: true);
                }
              }
            },
          ),
        ],
      ),
    );
  }
}

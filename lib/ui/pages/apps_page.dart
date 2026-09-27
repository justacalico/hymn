import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../api/models.dart';
import '../../app_state.dart';
import '../theme.dart';
import '../widgets/loader.dart';

class _AppsData {
  final List<NasApp> installed;
  final List<AvailableApp> available;
  final String? pool;

  const _AppsData(this.installed, this.available, this.pool);
}

class AppsPage extends StatelessWidget {
  const AppsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DataLoader<_AppsData>(
      autoRefresh: const Duration(seconds: 30),
      load: (client) async {
        final results = await Future.wait([
          client.getApps(),
          client.getAvailableApps().catchError((_) => <AvailableApp>[]),
          client.getAppsPool().catchError((_) => null),
        ]);
        return _AppsData(
          results[0] as List<NasApp>,
          results[1] as List<AvailableApp>,
          results[2] as String?,
        );
      },
      builder: (context, data, refresh) =>
          _AppsView(data: data, refresh: refresh),
    );
  }
}

class _AppsView extends StatelessWidget {
  final _AppsData data;
  final VoidCallback refresh;

  const _AppsView({required this.data, required this.refresh});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Row(
          children: [
            Expanded(
              child: Text('Apps',
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
        if (data.pool != null) ...[
          Text('Installed on pool ${data.pool}',
              style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5))),
        ],
        const SizedBox(height: 12),
        if (data.installed.isEmpty)
          const EmptyState(
            icon: Icons.widgets_outlined,
            title: 'No apps installed',
            message:
                'Install apps from the TrueNAS catalog below or through the web UI.',
          )
        else
          LayoutBuilder(builder: (context, c) {
            final cols = c.maxWidth > 900 ? 3 : (c.maxWidth > 560 ? 2 : 1);
            return GridView.count(
              crossAxisCount: cols,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: c.maxWidth > 560 ? 1.6 : 2.4,
              children: [
                for (final app in data.installed)
                  _AppCard(app: app, onChanged: refresh),
              ],
            );
          }),
        if (data.available.isNotEmpty) ...[
          const SizedBox(height: 24),
          sectionLabel(context, 'Catalog (${data.available.length})'),
          const SizedBox(height: 8),
          for (final app in data.available.take(20))
            _AvailableAppTile(app: app),
        ],
        const SizedBox(height: 24),
      ],
    );
  }
}

class _AppCard extends StatelessWidget {
  final NasApp app;
  final VoidCallback onChanged;

  const _AppCard({required this.app, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final client = context.read<AppState>().client;
    return Panel(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: HymnTheme.accentAlt.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: app.iconUrl != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.network(app.iconUrl!,
                            width: 40,
                            height: 40,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => const Icon(
                                Icons.widgets_outlined,
                                size: 20,
                                color: HymnTheme.accentAlt)),
                      )
                    : const Icon(Icons.widgets_outlined,
                        size: 20, color: HymnTheme.accentAlt),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(app.name,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                        overflow: TextOverflow.ellipsis),
                    Text(app.appVersion ?? app.version,
                        style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.5)),
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              StatusChip(app.state),
            ],
          ),
          const Spacer(),
          Row(
            children: [
              if (app.portals.isNotEmpty)
                TextButton.icon(
                  onPressed: () => launchUrl(Uri.parse(app.portals.first),
                      mode: LaunchMode.externalApplication),
                  icon: const Icon(Icons.open_in_new, size: 16),
                  label: const Text('Open'),
                ),
              const Spacer(),
              if (app.running)
                IconButton(
                  icon: const Icon(Icons.stop_circle_outlined, size: 20),
                  tooltip: 'Stop',
                  onPressed: () => _toggle(client, context, false),
                )
              else
                IconButton(
                  icon: const Icon(Icons.play_circle_outline, size: 20),
                  tooltip: 'Start',
                  onPressed: () => _toggle(client, context, true),
                ),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 20),
                tooltip: 'Delete',
                onPressed: () => _delete(client, context),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _toggle(
      dynamic client, BuildContext context, bool start) async {
    if (client == null) return;
    try {
      if (start) {
        await client.startApp(app.id);
      } else {
        await client.stopApp(app.id);
      }
      onChanged();
    } catch (e) {
      if (context.mounted) showToast(context, '$e', error: true);
    }
  }

  Future<void> _delete(dynamic client, BuildContext context) async {
    if (client == null) return;
    final confirmed = await confirmAction(
      context,
      title: 'Delete ${app.name}?',
      message: 'The app and its containers are removed.',
      confirmLabel: 'Delete',
    );
    if (!confirmed) return;
    try {
      await client.deleteApp(app.id);
      if (context.mounted) {
        showToast(context, 'App deleted');
        onChanged();
      }
    } catch (e) {
      if (context.mounted) showToast(context, '$e', error: true);
    }
  }
}

class _AvailableAppTile extends StatelessWidget {
  final AvailableApp app;

  const _AvailableAppTile({required this.app});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Panel(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          const Icon(Icons.inventory_2_outlined,
              size: 18, color: HymnTheme.accent),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(app.title,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                if (app.description.isNotEmpty)
                  Text(app.description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.5))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

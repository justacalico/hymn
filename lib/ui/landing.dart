import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'theme.dart';

/* Hallmark · pre-emit critique: P4 H4 E4 S4 R5 V4 */

/// Product page shown when Hymn is built for the web. The real app targets
/// native platforms; the site explains what it does and where to get it.
class HymnLandingApp extends StatelessWidget {
  const HymnLandingApp({super.key});

  static const gitlabUrl = 'https://gitlab.com/HttpAnimations/hymn';
  static const releasesUrl = 'https://gitlab.com/HttpAnimations/hymn/-/releases';
  static const altstoreUrl =
      'https://hymn-38b0ca.gitlab.io/altstore/apps.json';

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hymn — a simple TrueNAS SCALE client',
      debugShowCheckedModeBanner: false,
      theme: HymnTheme.light(),
      darkTheme: HymnTheme.dark(),
      themeMode: ThemeMode.dark,
      home: const _LandingPage(),
    );
  }
}

class _LandingPage extends StatelessWidget {
  const _LandingPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(builder: (context, constraints) {
        final wide = constraints.maxWidth > 880;
        return SingleChildScrollView(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1080),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _TopBar(),
                    SizedBox(height: wide ? 96 : 56),
                    _Hero(wide: wide),
                    SizedBox(height: wide ? 88 : 56),
                    const _SpecSheet(),
                    SizedBox(height: wide ? 88 : 56),
                    const _Platforms(),
                    const SizedBox(height: 72),
                    const _Footer(),
                  ],
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [HymnTheme.accent, HymnTheme.accentAlt],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(9),
          ),
          child: const Icon(Icons.storage, color: Colors.white, size: 18),
        ),
        const SizedBox(width: 10),
        Text('Hymn',
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w700)),
        const Spacer(),
        TextButton(
          onPressed: () => launchUrl(Uri.parse(HymnLandingApp.gitlabUrl)),
          child: const Text('Source'),
        ),
        const SizedBox(width: 4),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
          onPressed: () => launchUrl(Uri.parse(HymnLandingApp.releasesUrl)),
          child: const Text('Download'),
        ),
      ],
    );
  }
}

class _Hero extends StatelessWidget {
  final bool wide;

  const _Hero({required this.wide});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final headline = theme.textTheme.displaySmall
        ?.copyWith(fontWeight: FontWeight.w800, height: 1.08);
    return wide
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 5, child: _heroCopy(theme, headline)),
              const SizedBox(width: 48),
              const Expanded(flex: 4, child: _HeroPanel()),
            ],
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _heroCopy(theme, headline),
              const SizedBox(height: 36),
              const _HeroPanel(),
            ],
          );
  }

  Widget _heroCopy(ThemeData theme, TextStyle? headline) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Your NAS,\nwithout the\ncontrol panel.', style: headline),
        const SizedBox(height: 20),
        Text(
          'Hymn is a native client for TrueNAS SCALE. Point it at your server, '
          'paste an API key, and manage pools, shares, snapshots and apps from '
          'a clean interface — no browser tabs, no side server, no config files.',
          style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
              height: 1.6),
        ),
        const SizedBox(height: 28),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            FilledButton.icon(
              onPressed: () =>
                  launchUrl(Uri.parse(HymnLandingApp.releasesUrl)),
              icon: const Icon(Icons.download_outlined, size: 18),
              label: const Text('Get the app'),
            ),
            OutlinedButton(
              onPressed: () =>
                  launchUrl(Uri.parse(HymnLandingApp.gitlabUrl)),
              child: const Text('View on GitLab'),
            ),
          ],
        ),
      ],
    );
  }
}

/// A real, honest summary of what the app shows you — styled like the app's
/// own dashboard panels rather than invented marketing mockups.
class _HeroPanel extends StatelessWidget {
  const _HeroPanel();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Panel(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          sectionLabel(context, 'At a glance'),
          const SizedBox(height: 14),
          const _MiniMetric(
            icon: Icons.dns_outlined,
            label: 'Pools',
            caption: 'Health, capacity, scrub state',
          ),
          const _MiniMetric(
            icon: Icons.folder_shared_outlined,
            label: 'Shares',
            caption: 'SMB and NFS in one list',
          ),
          const _MiniMetric(
            icon: Icons.photo_camera_outlined,
            label: 'Snapshots',
            caption: 'Create and roll back in one tap',
          ),
          const _MiniMetric(
            icon: Icons.widgets_outlined,
            label: 'Apps',
            caption: 'Start, stop and open app UIs',
          ),
          const _MiniMetric(
            icon: Icons.query_stats_outlined,
            label: 'Live stats',
            caption: 'CPU, memory, network and disk I/O',
          ),
          const SizedBox(height: 4),
          Divider(color: theme.dividerColor),
          const SizedBox(height: 10),
          Text(
            'Works over the TrueNAS API key you already have.',
            style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
          ),
        ],
      ),
    );
  }
}

class _MiniMetric extends StatelessWidget {
  final IconData icon;
  final String label;
  final String caption;

  const _MiniMetric({
    required this.icon,
    required this.label,
    required this.caption,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: HymnTheme.accent),
          const SizedBox(width: 12),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              caption,
              style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.55)),
            ),
          ),
        ],
      ),
    );
  }
}

class _SpecSheet extends StatelessWidget {
  const _SpecSheet();

  static const _rows = [
    (
      'Storage',
      'Create pools with guided RAID layouts, add datasets from templates '
          '(media, backups, apps, VMs), set quotas, run scrubs, watch capacity.'
    ),
    (
      'Sharing',
      'SMB and NFS exports with read-only, guest access and host lists — '
          'without digging through the full TrueNAS UI.'
    ),
    (
      'Snapshots',
      'One-tap snapshots per dataset, grouped history, rollback and cleanup.'
    ),
    (
      'Apps',
      'See installed catalog apps, start or stop them, and jump straight '
          'into each app\'s own web interface.'
    ),
    (
      'Accounts',
      'Manage users and groups with the SMB flags that matter for file sharing.'
    ),
    (
      'Live view',
      'Realtime CPU, memory, network and disk graphs streamed over the '
          'TrueNAS websocket API.'
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('What it does',
            style: theme.textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 24),
        for (final row in _rows)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 18),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: theme.dividerColor),
              ),
            ),
            child: LayoutBuilder(builder: (context, c) {
              final wide = c.maxWidth > 620;
              final label = SizedBox(
                width: wide ? 180 : null,
                child: Text(row.$1,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600)),
              );
              final body = Text(
                row.$2,
                style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                    height: 1.6),
              );
              if (!wide) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [label, const SizedBox(height: 8), body],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [label, const SizedBox(width: 32), Expanded(child: body)],
              );
            }),
          ),
      ],
    );
  }
}

class _Platforms extends StatelessWidget {
  const _Platforms();

  static const _platforms = [
    ('Android', 'Signed APK and AAB on every release'),
    ('iOS', 'Unsigned IPA — add the AltStore source to sideload'),
    ('Linux', 'tar.gz, deb, rpm and AppImage for x86_64 and arm64'),
    ('Windows', 'Portable zip for x86_64 and arm64'),
    ('macOS', 'DMG and zip for Apple Silicon'),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Get it',
            style: theme.textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Text(
          'Every release is published on GitLab with checksums.',
          style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
        ),
        const SizedBox(height: 20),
        for (final p in _platforms)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              border:
                  Border(bottom: BorderSide(color: theme.dividerColor)),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 110,
                  child: Text(p.$1,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
                Expanded(
                  child: Text(p.$2,
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.6))),
                ),
                TextButton(
                  onPressed: () =>
                      launchUrl(Uri.parse(HymnLandingApp.releasesUrl)),
                  child: const Text('Releases'),
                ),
              ],
            ),
          ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            OutlinedButton.icon(
              onPressed: () =>
                  launchUrl(Uri.parse(HymnLandingApp.altstoreUrl)),
              icon: const Icon(Icons.ios_share, size: 16),
              label: const Text('AltStore source'),
            ),
          ],
        ),
      ],
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: theme.dividerColor)),
      ),
      child: Wrap(
        spacing: 24,
        runSpacing: 8,
        alignment: WrapAlignment.spaceBetween,
        children: [
          Text('Hymn · AGPL-3.0',
              style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5))),
          TextButton(
            onPressed: () => launchUrl(Uri.parse(HymnLandingApp.gitlabUrl)),
            child: const Text('Source on GitLab'),
          ),
        ],
      ),
    );
  }
}

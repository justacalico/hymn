import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../api/models.dart';
import '../../app_state.dart';
import '../../utils/format.dart';
import '../theme.dart';
import '../widgets/loader.dart';

class _DashboardData {
  final SystemInfo system;
  final List<Pool> pools;
  final List<SmbShare> smbShares;
  final List<NfsShare> nfsShares;
  final List<Disk> disks;
  final List<NasService> services;
  final List<NasAlert> alerts;
  final List<NasJob> jobs;

  const _DashboardData({
    required this.system,
    required this.pools,
    required this.smbShares,
    required this.nfsShares,
    required this.disks,
    required this.services,
    required this.alerts,
    required this.jobs,
  });

  int get totalStorage => pools.fold(0, (sum, p) => sum + p.size);
  int get usedStorage => pools.fold(0, (sum, p) => sum + p.allocated);
  int get shareCount => smbShares.length + nfsShares.length;
  int get activeAlerts => alerts.where((a) => !a.dismissed).length;
  int get runningJobs => jobs.where((j) => j.running).length;
}

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DataLoader<_DashboardData>(
      autoRefresh: const Duration(seconds: 30),
      load: (client) async {
        final results = await Future.wait([
          client.getSystemInfo(),
          client.getPools(),
          client.getSmbShares(),
          client.getNfsShares(),
          client.getDisks(),
          client.getServices(),
          client.getAlerts(),
          client.getJobs(),
        ]);
        return _DashboardData(
          system: results[0] as SystemInfo,
          pools: results[1] as List<Pool>,
          smbShares: results[2] as List<SmbShare>,
          nfsShares: results[3] as List<NfsShare>,
          disks: results[4] as List<Disk>,
          services: results[5] as List<NasService>,
          alerts: results[6] as List<NasAlert>,
          jobs: results[7] as List<NasJob>,
        );
      },
      builder: (context, data, refresh) => _DashboardView(
        data: data,
        onRefresh: refresh,
      ),
    );
  }
}

class _DashboardView extends StatelessWidget {
  final _DashboardData data;
  final VoidCallback onRefresh;

  const _DashboardView({required this.data, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Dashboard',
                      style: theme.textTheme.headlineMedium
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  Text(
                    data.system.hostname.isNotEmpty
                        ? '${data.system.hostname} · TrueNAS ${data.system.version}'
                        : 'TrueNAS ${data.system.version}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                        color:
                            theme.colorScheme.onSurface.withValues(alpha: 0.55)),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh',
            ),
          ],
        ),
        const SizedBox(height: 20),
        if (data.activeAlerts > 0) ...[
          _AlertsBanner(count: data.activeAlerts, alerts: data.alerts),
          const SizedBox(height: 16),
        ],
        LayoutBuilder(
          builder: (context, c) {
            final cols = c.maxWidth > 900
                ? 4
                : c.maxWidth > 560
                    ? 2
                    : 1;
            return GridView.count(
              crossAxisCount: cols,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: c.maxWidth > 560 ? 2.6 : 3.4,
              children: [
                StatCard(
                  title: 'Storage pools',
                  value: '${data.pools.length}',
                  subtitle:
                      '${data.pools.where((p) => p.healthy).length} healthy',
                  icon: Icons.dns_outlined,
                  color: HymnTheme.accent,
                ),
                StatCard(
                  title: 'Total storage',
                  value: formatBytes(data.totalStorage),
                  subtitle: data.totalStorage > 0
                      ? '${formatPercent(data.usedStorage / data.totalStorage)} used'
                      : null,
                  icon: Icons.storage_outlined,
                  color: HymnTheme.accentAlt,
                ),
                StatCard(
                  title: 'Shares',
                  value: '${data.shareCount}',
                  subtitle:
                      '${data.smbShares.length} SMB · ${data.nfsShares.length} NFS',
                  icon: Icons.folder_shared_outlined,
                  color: HymnTheme.success,
                ),
                StatCard(
                  title: 'Uptime',
                  value: formatUptime(data.system.uptimeSeconds),
                  subtitle: data.runningJobs > 0
                      ? '${data.runningJobs} jobs running'
                      : 'No jobs running',
                  icon: Icons.schedule_outlined,
                  color: HymnTheme.warning,
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        LayoutBuilder(builder: (context, c) {
          final wide = c.maxWidth > 760;
          final resources = _ResourcesCard(system: data.system);
          final storage = _StorageCard(data: data);
          if (!wide) {
            return Column(children: [
              resources,
              const SizedBox(height: 16),
              storage,
            ]);
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: resources),
              const SizedBox(width: 16),
              Expanded(child: storage),
            ],
          );
        }),
        const SizedBox(height: 16),
        LayoutBuilder(builder: (context, c) {
          final wide = c.maxWidth > 760;
          final services = _ServicesCard(services: data.services);
          final disks = _DisksCard(disks: data.disks);
          if (!wide) {
            return Column(children: [
              services,
              const SizedBox(height: 16),
              disks,
            ]);
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: services),
              const SizedBox(width: 16),
              Expanded(child: disks),
            ],
          );
        }),
        const SizedBox(height: 24),
      ],
    );
  }
}

class _AlertsBanner extends StatelessWidget {
  final int count;
  final List<NasAlert> alerts;

  const _AlertsBanner({required this.count, required this.alerts});

  @override
  Widget build(BuildContext context) {
    final first = alerts.firstWhere((a) => !a.dismissed);
    return Panel(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded,
              color: HymnTheme.warning, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '$count active alert${count == 1 ? '' : 's'} — ${first.message}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          TextButton(
            onPressed: () => _showAlerts(context),
            child: const Text('View'),
          ),
        ],
      ),
    );
  }

  void _showAlerts(BuildContext context) {
    final client = context.read<AppState>().client;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        builder: (context, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          children: [
            Text('Alerts', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            for (final alert in alerts.where((a) => !a.dismissed))
              Card(
                child: ListTile(
                  leading: Icon(
                    alert.level == 'CRITICAL'
                        ? Icons.error_outline
                        : Icons.warning_amber_rounded,
                    color: statusColor(alert.level),
                  ),
                  title: Text(alert.message,
                      style: const TextStyle(fontSize: 14)),
                  subtitle: Text(
                      '${alert.level} · ${formatRelative(alert.datetime)}'),
                  trailing: IconButton(
                    icon: const Icon(Icons.check_circle_outline),
                    tooltip: 'Dismiss',
                    onPressed: () async {
                      try {
                        await client?.dismissAlert(alert.uuid);
                        if (sheetContext.mounted) {
                          Navigator.pop(sheetContext);
                        }
                      } catch (e) {
                        if (sheetContext.mounted) {
                          showToast(sheetContext, '$e', error: true);
                        }
                      }
                    },
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ResourcesCard extends StatefulWidget {
  final SystemInfo system;

  const _ResourcesCard({required this.system});

  @override
  State<_ResourcesCard> createState() => _ResourcesCardState();
}

class _ResourcesCardState extends State<_ResourcesCard> {
  Stream<RealtimeSample>? _stream;

  @override
  void initState() {
    super.initState();
    // Built once so rebuilds never resubscribe.
    _stream = context.read<AppState>().client?.realtimeStats();
  }

  @override
  Widget build(BuildContext context) {
    final system = widget.system;
    final theme = Theme.of(context);
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          sectionLabel(context, 'System'),
          const SizedBox(height: 16),
          StreamBuilder<RealtimeSample>(
            stream: _stream,
            builder: (context, snapshot) {
              final sample = snapshot.data;
              final cpu = sample?.cpuUsage ?? 0;
              final memTotal = sample?.memoryTotal ?? system.physicalMemory;
              final memUsed = sample?.memoryUsed ?? 0;
              return Column(
                children: [
                  _MeterRow(
                    label: 'CPU',
                    detail: cpu > 0 ? formatPercent(cpu / 100) : 'waiting',
                    fraction: cpu / 100,
                    color: HymnTheme.accent,
                  ),
                  const SizedBox(height: 14),
                  _MeterRow(
                    label: 'Memory',
                    detail: memTotal > 0
                        ? '${formatBytes(memUsed)} of ${formatBytes(memTotal)}'
                        : 'waiting',
                    fraction: memTotal > 0 ? memUsed / memTotal : 0,
                    color: HymnTheme.accentAlt,
                  ),
                  if (sample != null &&
                      (sample.networkRxBytesPerSec > 0 ||
                          sample.networkTxBytesPerSec > 0)) ...[
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Icon(Icons.swap_vert,
                            size: 16,
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.5)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${formatBytesPerSec(sample.networkRxBytesPerSec)} in · '
                            '${formatBytesPerSec(sample.networkTxBytesPerSec)} out',
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          if (system.cpuModel.isNotEmpty)
            Text(
              '${system.cpuModel} · ${system.cores} cores',
              style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
            ),
          if (system.loadAverage.isNotEmpty)
            Text(
              'Load ${system.loadAverage.map((l) => l.toStringAsFixed(2)).join(' · ')}',
              style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
            ),
        ],
      ),
    );
  }
}

class _MeterRow extends StatelessWidget {
  final String label;
  final String detail;
  final double fraction;
  final Color color;

  const _MeterRow({
    required this.label,
    required this.detail,
    required this.fraction,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: theme.textTheme.bodyMedium),
            Text(detail,
                style: theme.textTheme.bodySmall?.copyWith(
                    color:
                        theme.colorScheme.onSurface.withValues(alpha: 0.55))),
          ],
        ),
        const SizedBox(height: 6),
        MeterBar(fraction: fraction, color: color),
      ],
    );
  }
}

class _StorageCard extends StatelessWidget {
  final _DashboardData data;

  const _StorageCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          sectionLabel(context, 'Storage'),
          const SizedBox(height: 16),
          if (data.pools.isEmpty)
            Text('No pools configured',
                style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5)))
          else
            for (final pool in data.pools)
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(pool.name,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600)),
                        ),
                        StatusChip(
                            pool.healthy ? pool.status : 'DEGRADED'),
                      ],
                    ),
                    const SizedBox(height: 6),
                    MeterBar(
                      fraction: pool.usedPercent,
                      color: pool.usedPercent > 0.85
                          ? HymnTheme.danger
                          : HymnTheme.accent,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${formatBytes(pool.allocated)} of ${formatBytes(pool.size)} used · ${formatBytes(pool.free)} free',
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.5)),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}

class _ServicesCard extends StatelessWidget {
  final List<NasService> services;

  const _ServicesCard({required this.services});

  static const _interesting = {
    'smb',
    'nfs',
    'ssh',
    'docker',
    'smartd',
    'snmp',
    'ups',
    'ftp',
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shown = services
        .where((s) => _interesting.contains(s.service.toLowerCase()))
        .toList();
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          sectionLabel(context, 'Services'),
          const SizedBox(height: 12),
          if (shown.isEmpty)
            Text('No services reported',
                style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5)))
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [for (final s in shown) _ServiceChip(service: s)],
            ),
        ],
      ),
    );
  }
}

class _ServiceChip extends StatelessWidget {
  final NasService service;

  const _ServiceChip({required this.service});

  @override
  Widget build(BuildContext context) {
    final color =
        service.running ? HymnTheme.success : _disabledColor(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        service.service.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: service.running
              ? HymnTheme.success
              : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45),
        ),
      ),
    );
  }

  Color _disabledColor(BuildContext context) =>
      Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45);
}

class _DisksCard extends StatelessWidget {
  final List<Disk> disks;

  const _DisksCard({required this.disks});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final inUse = disks.where((d) => d.isInUse).length;
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          sectionLabel(context, 'Disks'),
          const SizedBox(height: 12),
          Row(
            children: [
              _DiskStat(label: 'Installed', value: '${disks.length}'),
              const SizedBox(width: 24),
              _DiskStat(label: 'In pools', value: '$inUse'),
              const SizedBox(width: 24),
              _DiskStat(label: 'Unused', value: '${disks.length - inUse}'),
            ],
          ),
          if (disks.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              '${formatBytes(disks.fold(0, (s, d) => s + d.size))} raw capacity across ${disks.length} drive${disks.length == 1 ? '' : 's'}',
              style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
            ),
          ],
        ],
      ),
    );
  }
}

class _DiskStat extends StatelessWidget {
  final String label;
  final String value;

  const _DiskStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value,
            style: theme.textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w700)),
        Text(label,
            style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5))),
      ],
    );
  }
}

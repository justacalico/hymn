import 'package:flutter/material.dart';

import '../../api/models.dart';
import '../../utils/format.dart';
import '../theme.dart';
import '../widgets/loader.dart';

class DisksPage extends StatelessWidget {
  const DisksPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DataLoader<List<Disk>>(
      load: (client) => client.getDisks(),
      builder: (context, disks, refresh) {
        final theme = Theme.of(context);
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('Disks',
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
            const SizedBox(height: 8),
            if (disks.isEmpty)
              const EmptyState(
                icon: Icons.album_outlined,
                title: 'No disks detected',
                message: 'TrueNAS reported no physical disks.',
              )
            else
              for (final disk in disks) _DiskCard(disk: disk),
          ],
        );
      },
    );
  }
}

class _DiskCard extends StatelessWidget {
  final Disk disk;

  const _DiskCard({required this.disk});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Panel(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: (disk.isInUse ? HymnTheme.accent : HymnTheme.warning)
                  .withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              disk.type == 'SSD' ? Icons.memory : Icons.album,
              size: 22,
              color:
                  disk.isInUse ? HymnTheme.accent : HymnTheme.warning,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(disk.name,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                Text(
                  [
                    if (disk.model.isNotEmpty) disk.model,
                    formatBytes(disk.size),
                    if (disk.rotationRate != null && disk.rotationRate! > 0)
                      '${disk.rotationRate} RPM',
                    if (disk.bus.isNotEmpty) disk.bus,
                  ].join(' · '),
                  style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.55)),
                ),
                if (disk.serial.isNotEmpty)
                  Text('S/N ${disk.serial}',
                      style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.4))),
              ],
            ),
          ),
          StatusChip(disk.isInUse ? disk.pool ?? 'IN USE' : 'UNUSED'),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../api/models.dart';
import '../../api/truenas_client.dart';
import '../../app_state.dart';
import '../../utils/format.dart';
import '../theme.dart';
import '../widgets/loader.dart';

class _StorageData {
  final List<Pool> pools;
  final List<Dataset> datasets;
  final List<Disk> unusedDisks;

  const _StorageData({
    required this.pools,
    required this.datasets,
    required this.unusedDisks,
  });
}

class StoragePage extends StatelessWidget {
  const StoragePage({super.key});

  @override
  Widget build(BuildContext context) {
    return DataLoader<_StorageData>(
      load: (client) async {
        final results = await Future.wait([
          client.getPools(),
          client.getDatasets(),
          client.getUnusedDisks(),
        ]);
        return _StorageData(
          pools: results[0] as List<Pool>,
          datasets: results[1] as List<Dataset>,
          unusedDisks: results[2] as List<Disk>,
        );
      },
      builder: (context, data, refresh) => _StorageView(
        data: data,
        refresh: refresh,
      ),
    );
  }
}

class _StorageView extends StatelessWidget {
  final _StorageData data;
  final VoidCallback refresh;

  const _StorageView({required this.data, required this.refresh});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Row(
          children: [
            Expanded(
              child: Text('Storage',
                  style: theme.textTheme.headlineMedium
                      ?.copyWith(fontWeight: FontWeight.w700)),
            ),
            IconButton(
              onPressed: () => _showCreatePool(context),
              icon: const Icon(Icons.add_circle_outline),
              tooltip: 'Create pool',
            ),
            IconButton(
              onPressed: refresh,
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh',
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (data.pools.isEmpty)
          const EmptyState(
            icon: Icons.dns_outlined,
            title: 'No storage pools',
            message: 'Create a pool to start storing data.',
          )
        else
          for (final pool in data.pools) ...[
            _PoolCard(
              pool: pool,
              datasets: data.datasets
                  .where((d) => d.pool == pool.name && d.name != pool.name)
                  .toList(),
              onChanged: refresh,
            ),
            const SizedBox(height: 16),
          ],
      ],
    );
  }

  void _showCreatePool(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: _CreatePoolSheet(unused: data.unusedDisks, onDone: refresh),
      ),
    );
  }
}

class _PoolCard extends StatelessWidget {
  final Pool pool;
  final List<Dataset> datasets;
  final VoidCallback onChanged;

  const _PoolCard({
    required this.pool,
    required this.datasets,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final client = context.read<AppState>().client;
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(pool.name,
                        style: theme.textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    Text(
                      '${pool.raidLevel} · ${formatBytes(pool.size)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.55)),
                    ),
                  ],
                ),
              ),
              StatusChip(pool.healthy ? pool.status : 'DEGRADED'),
              PopupMenuButton<String>(
                onSelected: (action) =>
                    _poolAction(context, client, action),
                itemBuilder: (context) => [
                  const PopupMenuItem(
                      value: 'scrub', child: Text('Run scrub')),
                  const PopupMenuItem(
                      value: 'export', child: Text('Export pool')),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          MeterBar(
            fraction: pool.usedPercent,
            color: pool.usedPercent > 0.85
                ? HymnTheme.danger
                : HymnTheme.accent,
          ),
          const SizedBox(height: 6),
          Text(
            '${formatBytes(pool.allocated)} used · ${formatBytes(pool.free)} free'
            '${pool.scanState != null ? ' · scrub ${pool.scanState}' : ''}',
            style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              sectionLabel(context, 'Datasets'),
              TextButton.icon(
                onPressed: () => _showCreateDataset(context, client),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('New dataset'),
              ),
            ],
          ),
          if (datasets.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text('No datasets yet',
                  style: theme.textTheme.bodySmall?.copyWith(
                      color:
                          theme.colorScheme.onSurface.withValues(alpha: 0.45))),
            )
          else
            for (final ds in datasets) _DatasetRow(dataset: ds, onChanged: onChanged),
        ],
      ),
    );
  }

  Future<void> _poolAction(
      BuildContext context, TrueNasClient? client, String action) async {
    if (client == null) return;
    if (action == 'scrub') {
      try {
        await client.scrubPool(pool.id);
        if (context.mounted) {
          showToast(context, 'Scrub started on ${pool.name}');
        }
      } catch (e) {
        if (context.mounted) showToast(context, '$e', error: true);
      }
    } else if (action == 'export') {
      final confirmed = await confirmAction(
        context,
        title: 'Export ${pool.name}?',
        message:
            'Exporting takes the pool offline. Data is kept and the pool can be imported again later.',
        confirmLabel: 'Export',
      );
      if (!confirmed) return;
      try {
        await client.exportPool(pool.id);
        if (context.mounted) {
          showToast(context, 'Pool ${pool.name} exported');
          onChanged();
        }
      } catch (e) {
        if (context.mounted) showToast(context, '$e', error: true);
      }
    }
  }

  void _showCreateDataset(BuildContext context, TrueNasClient? client) {
    if (client == null) return;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child:
            _CreateDatasetSheet(pool: pool.name, client: client, onDone: onChanged),
      ),
    );
  }
}

class _DatasetRow extends StatelessWidget {
  final Dataset dataset;
  final VoidCallback onChanged;

  const _DatasetRow({required this.dataset, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final client = context.read<AppState>().client;
    final total = dataset.used + dataset.available;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.folder_outlined, size: 20),
      title: Text(dataset.shortName,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
      subtitle: Text(
        '${formatBytes(dataset.used)} used'
        '${dataset.quota != null ? ' · quota ${formatBytes(dataset.quota!)}' : ''}'
        ' · ${dataset.compression}',
        style: theme.textTheme.bodySmall,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (total > 0)
            SizedBox(
              width: 60,
              child: MeterBar(fraction: dataset.used / total, height: 6),
            ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 20),
            tooltip: 'Delete dataset',
            onPressed: () => _delete(context, client),
          ),
        ],
      ),
    );
  }

  Future<void> _delete(BuildContext context, TrueNasClient? client) async {
    if (client == null) return;
    final confirmed = await confirmAction(
      context,
      title: 'Delete ${dataset.name}?',
      message: 'This deletes the dataset and everything in it.',
      confirmLabel: 'Delete',
    );
    if (!confirmed) return;
    try {
      await client.deleteDataset(dataset.id, recursive: true);
      if (context.mounted) {
        showToast(context, 'Dataset deleted');
        onChanged();
      }
    } catch (e) {
      if (context.mounted) showToast(context, '$e', error: true);
    }
  }
}

/// Template presets, matching the original app's opinionated defaults.
const datasetTemplates = <(String, String, String, String)>[
  ('media', 'Media', 'LZ4', 'SMB'),
  ('backups', 'Backups', 'GZIP-9', 'GENERIC'),
  ('docker', 'Apps', 'LZ4', 'APPS'),
  ('vms', 'Virtual machines', 'OFF', 'GENERIC'),
  ('documents', 'Documents', 'LZ4', 'SMB'),
  ('general', 'General', 'LZ4', 'GENERIC'),
];

class _CreateDatasetSheet extends StatefulWidget {
  final String pool;
  final TrueNasClient client;
  final VoidCallback onDone;

  const _CreateDatasetSheet({
    required this.pool,
    required this.client,
    required this.onDone,
  });

  @override
  State<_CreateDatasetSheet> createState() => _CreateDatasetSheetState();
}

class _CreateDatasetSheetState extends State<_CreateDatasetSheet> {
  final _nameController = TextEditingController();
  final _quotaController = TextEditingController();
  int _template = 5;
  bool _busy = false;

  @override
  void dispose() {
    _nameController.dispose();
    _quotaController.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final name = _nameController.text.trim();
    if (name.isEmpty || name.contains('/')) {
      showToast(context, 'Enter a dataset name', error: true);
      return;
    }
    setState(() => _busy = true);
    try {
      final quotaGiB = int.tryParse(_quotaController.text.trim());
      final tpl = datasetTemplates[_template];
      await widget.client.createDataset(
        name: '${widget.pool}/$name',
        compression: tpl.$3,
        shareType: tpl.$4,
        quota: quotaGiB != null && quotaGiB > 0 ? quotaGiB * 1024 * 1024 * 1024 : null,
      );
      if (mounted) {
        Navigator.pop(context);
        showToast(context, 'Dataset $name created');
        widget.onDone();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        showToast(context, '$e', error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('New dataset in ${widget.pool}',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          TextField(
            controller: _nameController,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Name',
              hintText: 'e.g. media',
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            initialValue: _template,
            decoration: const InputDecoration(labelText: 'Template'),
            items: [
              for (var i = 0; i < datasetTemplates.length; i++)
                DropdownMenuItem(
                    value: i, child: Text(datasetTemplates[i].$2)),
            ],
            onChanged: (v) => setState(() => _template = v ?? 5),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _quotaController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Quota (GiB, optional)',
              hintText: 'Leave empty for no limit',
            ),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _busy ? null : _create,
            child: _busy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Text('Create dataset'),
          ),
        ],
      ),
    );
  }
}

class _CreatePoolSheet extends StatefulWidget {
  final List<Disk> unused;
  final VoidCallback onDone;

  const _CreatePoolSheet({required this.unused, required this.onDone});

  @override
  State<_CreatePoolSheet> createState() => _CreatePoolSheetState();
}

class _CreatePoolSheetState extends State<_CreatePoolSheet> {
  final _nameController = TextEditingController();
  final Set<String> _selected = {};
  String _raid = 'RAIDZ1';
  bool _busy = false;

  static const _raidOptions = {
    'STRIPE': 'Stripe — no redundancy, all capacity',
    'MIRROR': 'Mirror — drives copy each other',
    'RAIDZ1': 'RAIDZ1 — survives one failed drive (3+ disks)',
    'RAIDZ2': 'RAIDZ2 — survives two failed drives (4+ disks)',
    'RAIDZ3': 'RAIDZ3 — survives three failed drives (5+ disks)',
  };

  int get _minDisks => switch (_raid) {
        'RAIDZ1' => 3,
        'RAIDZ2' => 4,
        'RAIDZ3' => 5,
        'MIRROR' => 2,
        _ => 1,
      };

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final client = context.read<AppState>().client;
    if (client == null) return;
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      showToast(context, 'Enter a pool name', error: true);
      return;
    }
    if (_selected.length < _minDisks) {
      showToast(context, 'Select at least $_minDisks disks', error: true);
      return;
    }
    setState(() => _busy = true);
    try {
      await client.createPool(
        name: name,
        type: _raid,
        disks: _selected.toList(),
      );
      if (mounted) {
        Navigator.pop(context);
        showToast(context, 'Pool $name created');
        widget.onDone();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        showToast(context, '$e', error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Create pool', style: theme.textTheme.titleLarge),
          const SizedBox(height: 16),
          TextField(
            controller: _nameController,
            decoration:
                const InputDecoration(labelText: 'Pool name', hintText: 'tank'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _raid,
            decoration: const InputDecoration(labelText: 'Layout'),
            items: [
              for (final e in _raidOptions.entries)
                DropdownMenuItem(value: e.key, child: Text(e.value)),
            ],
            onChanged: (v) => setState(() => _raid = v ?? 'RAIDZ1'),
          ),
          const SizedBox(height: 12),
          sectionLabel(context, 'Disks (${_selected.length} selected, need $_minDisks+)'),
          const SizedBox(height: 8),
          if (widget.unused.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text('No unused disks available',
                  style: theme.textTheme.bodySmall),
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 240),
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final disk in widget.unused)
                    CheckboxListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(disk.name,
                          style:
                              const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(
                          '${disk.model} · ${formatBytes(disk.size)}',
                          style: theme.textTheme.bodySmall),
                      value: _selected.contains(disk.name),
                      onChanged: (v) => setState(() {
                        if (v == true) {
                          _selected.add(disk.name);
                        } else {
                          _selected.remove(disk.name);
                        }
                      }),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _busy ? null : _create,
            child: _busy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Text('Create pool'),
          ),
        ],
      ),
    );
  }
}

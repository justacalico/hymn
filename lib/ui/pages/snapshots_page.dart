import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../api/models.dart';
import '../../app_state.dart';
import '../../utils/format.dart';
import '../theme.dart';
import '../widgets/loader.dart';

class _SnapshotData {
  final List<Snapshot> snapshots;
  final List<Dataset> datasets;

  const _SnapshotData(this.snapshots, this.datasets);
}

class SnapshotsPage extends StatelessWidget {
  const SnapshotsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DataLoader<_SnapshotData>(
      load: (client) async {
        final results = await Future.wait([
          client.getSnapshots(),
          client.getDatasets(),
        ]);
        return _SnapshotData(
          results[0] as List<Snapshot>,
          results[1] as List<Dataset>,
        );
      },
      builder: (context, data, refresh) {
        final theme = Theme.of(context);
        final grouped = <String, List<Snapshot>>{};
        for (final snap in data.snapshots) {
          grouped.putIfAbsent(snap.dataset, () => []).add(snap);
        }
        final datasets = grouped.keys.toList()..sort();
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('Snapshots',
                      style: theme.textTheme.headlineMedium
                          ?.copyWith(fontWeight: FontWeight.w700)),
                ),
                IconButton(
                  onPressed: () => _createSnapshot(context, data.datasets),
                  icon: const Icon(Icons.add_a_photo_outlined),
                  tooltip: 'New snapshot',
                ),
                IconButton(
                  onPressed: refresh,
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Refresh',
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (data.snapshots.isEmpty)
              const EmptyState(
                icon: Icons.photo_camera_outlined,
                title: 'No snapshots',
                message:
                    'Snapshots capture a dataset at a point in time and let you roll back later.',
              )
            else
              for (final ds in datasets) ...[
                const SizedBox(height: 12),
                sectionLabel(context, ds),
                const SizedBox(height: 4),
                for (final snap in grouped[ds]!)
                  _SnapshotTile(
                    snapshot: snap,
                    onChanged: refresh,
                  ),
              ],
            const SizedBox(height: 24),
          ],
        );
      },
    );
  }

  void _createSnapshot(BuildContext context, List<Dataset> datasets) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: _CreateSnapshotSheet(datasets: datasets),
      ),
    );
  }
}

class _SnapshotTile extends StatelessWidget {
  final Snapshot snapshot;
  final VoidCallback onChanged;

  const _SnapshotTile({required this.snapshot, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Panel(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const Icon(Icons.photo_camera_outlined,
              size: 18, color: HymnTheme.accentAlt),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(snapshot.name,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                Text(
                  '${formatRelative(snapshot.created)} · ${formatBytes(snapshot.referenced)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                      color:
                          theme.colorScheme.onSurface.withValues(alpha: 0.5)),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.undo, size: 18),
            tooltip: 'Roll back to this snapshot',
            onPressed: () => _rollback(context),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 18),
            tooltip: 'Delete snapshot',
            onPressed: () => _delete(context),
          ),
        ],
      ),
    );
  }

  Future<void> _rollback(BuildContext context) async {
    final client = context.read<AppState>().client;
    if (client == null) return;
    final confirmed = await confirmAction(
      context,
      title: 'Roll back ${snapshot.dataset}?',
      message:
          'The dataset returns to the state captured by ${snapshot.name}. Changes made after the snapshot are lost.',
      confirmLabel: 'Roll back',
    );
    if (!confirmed) return;
    try {
      await client.rollbackSnapshot(snapshot.id);
      if (context.mounted) showToast(context, 'Rolled back');
    } catch (e) {
      if (context.mounted) showToast(context, '$e', error: true);
    }
  }

  Future<void> _delete(BuildContext context) async {
    final client = context.read<AppState>().client;
    if (client == null) return;
    final confirmed = await confirmAction(
      context,
      title: 'Delete snapshot?',
      message: 'Delete ${snapshot.id}? This cannot be undone.',
      confirmLabel: 'Delete',
    );
    if (!confirmed) return;
    try {
      await client.deleteSnapshot(snapshot.id);
      if (context.mounted) {
        showToast(context, 'Snapshot deleted');
        onChanged();
      }
    } catch (e) {
      if (context.mounted) showToast(context, '$e', error: true);
    }
  }
}

class _CreateSnapshotSheet extends StatefulWidget {
  final List<Dataset> datasets;

  const _CreateSnapshotSheet({required this.datasets});

  @override
  State<_CreateSnapshotSheet> createState() => _CreateSnapshotSheetState();
}

class _CreateSnapshotSheetState extends State<_CreateSnapshotSheet> {
  final _nameController = TextEditingController();
  String? _dataset;
  bool _recursive = false;
  bool _busy = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final client = context.read<AppState>().client;
    if (client == null) return;
    if (_dataset == null) {
      showToast(context, 'Pick a dataset', error: true);
      return;
    }
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      showToast(context, 'Enter a snapshot name', error: true);
      return;
    }
    setState(() => _busy = true);
    try {
      await client.createSnapshot(
          dataset: _dataset!, name: name, recursive: _recursive);
      if (mounted) {
        Navigator.pop(context);
        showToast(context, 'Snapshot created');
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
    final now = DateTime.now();
    final suggested =
        'manual-${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}-${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
    _nameController.text = _nameController.text.isEmpty && !_busy
        ? suggested
        : _nameController.text;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('New snapshot', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _dataset,
            decoration: const InputDecoration(labelText: 'Dataset'),
            items: [
              for (final d in widget.datasets)
                DropdownMenuItem(value: d.name, child: Text(d.name)),
            ],
            onChanged: (v) => setState(() => _dataset = v),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(labelText: 'Snapshot name'),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Include child datasets'),
            value: _recursive,
            onChanged: (v) => setState(() => _recursive = v),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _busy ? null : _create,
            child: _busy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Text('Create snapshot'),
          ),
        ],
      ),
    );
  }
}

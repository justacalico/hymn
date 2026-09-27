import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../api/models.dart';
import '../../app_state.dart';
import '../theme.dart';
import '../widgets/loader.dart';

class _SharesData {
  final List<SmbShare> smb;
  final List<NfsShare> nfs;
  final List<Dataset> datasets;

  const _SharesData(this.smb, this.nfs, this.datasets);
}

class SharesPage extends StatelessWidget {
  const SharesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DataLoader<_SharesData>(
      load: (client) async {
        final results = await Future.wait([
          client.getSmbShares(),
          client.getNfsShares(),
          client.getDatasets(),
        ]);
        return _SharesData(
          results[0] as List<SmbShare>,
          results[1] as List<NfsShare>,
          results[2] as List<Dataset>,
        );
      },
      builder: (context, data, refresh) =>
          _SharesView(data: data, refresh: refresh),
    );
  }
}

class _SharesView extends StatelessWidget {
  final _SharesData data;
  final VoidCallback refresh;

  const _SharesView({required this.data, required this.refresh});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Row(
          children: [
            Expanded(
              child: Text('Shares',
                  style: theme.textTheme.headlineMedium
                      ?.copyWith(fontWeight: FontWeight.w700)),
            ),
            TextButton.icon(
              onPressed: () => _createShare(context, 'smb'),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('SMB'),
            ),
            TextButton.icon(
              onPressed: () => _createShare(context, 'nfs'),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('NFS'),
            ),
            IconButton(
              onPressed: refresh,
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh',
            ),
          ],
        ),
        const SizedBox(height: 12),
        sectionLabel(context, 'SMB / Windows shares (${data.smb.length})'),
        const SizedBox(height: 8),
        if (data.smb.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text('No SMB shares'),
          )
        else
          for (final share in data.smb)
            _ShareTile(
              icon: Icons.folder_shared_outlined,
              title: share.name,
              subtitle: '${share.path}${share.comment.isNotEmpty ? ' · ${share.comment}' : ''}',
              status: share.enabled ? 'ENABLED' : 'DISABLED',
              onDelete: () => _deleteSmb(context, share),
            ),
        const SizedBox(height: 20),
        sectionLabel(context, 'NFS shares (${data.nfs.length})'),
        const SizedBox(height: 8),
        if (data.nfs.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text('No NFS shares'),
          )
        else
          for (final share in data.nfs)
            _ShareTile(
              icon: Icons.lan_outlined,
              title: share.path,
              subtitle: [
                if (share.comment.isNotEmpty) share.comment,
                if (share.networks.isNotEmpty)
                  'networks: ${share.networks.join(', ')}',
                if (share.hosts.isNotEmpty)
                  'hosts: ${share.hosts.join(', ')}',
              ].join(' · '),
              status: share.enabled ? 'ENABLED' : 'DISABLED',
              onDelete: () => _deleteNfs(context, share),
            ),
        const SizedBox(height: 24),
      ],
    );
  }

  void _createShare(BuildContext context, String protocol) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: _CreateShareSheet(
          protocol: protocol,
          datasets: data.datasets,
          onDone: refresh,
        ),
      ),
    );
  }

  Future<void> _deleteSmb(BuildContext context, SmbShare share) async {
    final client = context.read<AppState>().client;
    if (client == null) return;
    final confirmed = await confirmAction(
      context,
      title: 'Delete share ${share.name}?',
      message: 'The share is removed but the data stays on disk.',
      confirmLabel: 'Delete',
    );
    if (!confirmed) return;
    try {
      await client.deleteSmbShare(share.id);
      if (context.mounted) {
        showToast(context, 'Share deleted');
        refresh();
      }
    } catch (e) {
      if (context.mounted) showToast(context, '$e', error: true);
    }
  }

  Future<void> _deleteNfs(BuildContext context, NfsShare share) async {
    final client = context.read<AppState>().client;
    if (client == null) return;
    final confirmed = await confirmAction(
      context,
      title: 'Delete NFS share?',
      message: 'Remove the export for ${share.path}?',
      confirmLabel: 'Delete',
    );
    if (!confirmed) return;
    try {
      await client.deleteNfsShare(share.id);
      if (context.mounted) {
        showToast(context, 'Share deleted');
        refresh();
      }
    } catch (e) {
      if (context.mounted) showToast(context, '$e', error: true);
    }
  }
}

class _ShareTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String status;
  final VoidCallback onDelete;

  const _ShareTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.status,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Panel(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Icon(icon, size: 20, color: HymnTheme.accent),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                if (subtitle.isNotEmpty)
                  Text(subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.5))),
              ],
            ),
          ),
          StatusChip(status),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 20),
            onPressed: onDelete,
            tooltip: 'Delete share',
          ),
        ],
      ),
    );
  }
}

class _CreateShareSheet extends StatefulWidget {
  final String protocol;
  final List<Dataset> datasets;
  final VoidCallback onDone;

  const _CreateShareSheet({
    required this.protocol,
    required this.datasets,
    required this.onDone,
  });

  @override
  State<_CreateShareSheet> createState() => _CreateShareSheetState();
}

class _CreateShareSheetState extends State<_CreateShareSheet> {
  final _nameController = TextEditingController();
  final _commentController = TextEditingController();
  final _hostsController = TextEditingController();
  String? _path;
  bool _readOnly = false;
  bool _guestOk = false;
  bool _busy = false;

  bool get isSmb => widget.protocol == 'smb';

  @override
  void dispose() {
    _nameController.dispose();
    _commentController.dispose();
    _hostsController.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final client = context.read<AppState>().client;
    if (client == null) return;
    if (_path == null) {
      showToast(context, 'Pick a dataset to share', error: true);
      return;
    }
    if (isSmb && _nameController.text.trim().isEmpty) {
      showToast(context, 'Enter a share name', error: true);
      return;
    }
    setState(() => _busy = true);
    try {
      if (isSmb) {
        await client.createSmbShare(
          path: _path!,
          name: _nameController.text.trim(),
          comment: _commentController.text.trim(),
          readOnly: _readOnly,
          guestOk: _guestOk,
        );
      } else {
        await client.createNfsShare(
          path: _path!,
          comment: _commentController.text.trim(),
          readOnly: _readOnly,
          hosts: _hostsController.text
              .split(',')
              .map((h) => h.trim())
              .where((h) => h.isNotEmpty)
              .toList(),
        );
      }
      if (mounted) {
        // capture before pop; the sheet's context dies with it
        final messenger = ScaffoldMessenger.of(context);
        Navigator.pop(context);
        messenger.showSnackBar(SnackBar(content: Text('Share created')));
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
    final paths = widget.datasets
        .where((d) => d.mountpoint.isNotEmpty)
        .map((d) => d.mountpoint)
        .toList();
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('New ${widget.protocol.toUpperCase()} share',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          if (isSmb) ...[
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                  labelText: 'Share name', hintText: 'e.g. media'),
            ),
            const SizedBox(height: 12),
          ],
          DropdownButtonFormField<String>(
            initialValue: _path,
            decoration: const InputDecoration(labelText: 'Path'),
            items: [
              for (final p in paths)
                DropdownMenuItem(value: p, child: Text(p)),
            ],
            onChanged: (v) => setState(() => _path = v),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _commentController,
            decoration: const InputDecoration(
                labelText: 'Comment (optional)'),
          ),
          if (!isSmb) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _hostsController,
              decoration: const InputDecoration(
                labelText: 'Allowed hosts (comma separated, optional)',
                hintText: 'e.g. 192.168.1.0/24',
              ),
            ),
          ],
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Read only'),
            value: _readOnly,
            onChanged: (v) => setState(() => _readOnly = v),
          ),
          if (isSmb)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Guest access'),
              subtitle: const Text('Allow connections without a login'),
              value: _guestOk,
              onChanged: (v) => setState(() => _guestOk = v),
            ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _busy ? null : _create,
            child: _busy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Text('Create share'),
          ),
        ],
      ),
    );
  }
}

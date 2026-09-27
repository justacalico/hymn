import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../api/models.dart';
import '../../app_state.dart';
import '../theme.dart';
import '../widgets/loader.dart';

class _UsersData {
  final List<NasUser> users;
  final List<NasGroup> groups;

  const _UsersData(this.users, this.groups);
}

class UsersPage extends StatelessWidget {
  const UsersPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DataLoader<_UsersData>(
      load: (client) async {
        final results = await Future.wait([
          client.getUsers(),
          client.getGroups(),
        ]);
        return _UsersData(
          results[0] as List<NasUser>,
          results[1] as List<NasGroup>,
        );
      },
      builder: (context, data, refresh) {
        final theme = Theme.of(context);
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('Users',
                      style: theme.textTheme.headlineMedium
                          ?.copyWith(fontWeight: FontWeight.w700)),
                ),
                IconButton(
                  onPressed: () => _createUser(context, refresh),
                  icon: const Icon(Icons.person_add_outlined),
                  tooltip: 'New user',
                ),
                IconButton(
                  onPressed: refresh,
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Refresh',
                ),
              ],
            ),
            const SizedBox(height: 8),
            sectionLabel(context, 'Accounts (${data.users.length})'),
            const SizedBox(height: 8),
            if (data.users.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('No users'),
              )
            else
              for (final user in data.users)
                _UserTile(user: user, onChanged: refresh),
            const SizedBox(height: 20),
            sectionLabel(context, 'Groups (${data.groups.length})'),
            const SizedBox(height: 8),
            if (data.groups.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('No groups'),
              )
            else
              for (final group in data.groups) _GroupTile(group: group),
            const SizedBox(height: 24),
          ],
        );
      },
    );
  }

  void _createUser(BuildContext context, VoidCallback refresh) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: _CreateUserSheet(onDone: refresh),
      ),
    );
  }
}

class _UserTile extends StatelessWidget {
  final NasUser user;
  final VoidCallback onChanged;

  const _UserTile({required this.user, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Panel(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: HymnTheme.accent.withValues(alpha: 0.15),
            child: Text(
              user.username.isNotEmpty ? user.username[0].toUpperCase() : '?',
              style: const TextStyle(
                  color: HymnTheme.accent, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(user.username,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    if (user.builtin)
                      Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: Text('system',
                            style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onSurface
                                    .withValues(alpha: 0.4))),
                      ),
                    if (user.locked)
                      const Padding(
                        padding: EdgeInsets.only(left: 6),
                        child: Icon(Icons.lock_outline,
                            size: 14, color: HymnTheme.danger),
                      ),
                  ],
                ),
                Text(
                  [
                    if (user.fullName.isNotEmpty) user.fullName,
                    'uid ${user.uid}',
                    if (user.smb) 'SMB',
                    if (user.email != null && user.email!.isNotEmpty)
                      user.email!,
                  ].join(' · '),
                  style: theme.textTheme.bodySmall?.copyWith(
                      color:
                          theme.colorScheme.onSurface.withValues(alpha: 0.5)),
                ),
              ],
            ),
          ),
          if (!user.builtin)
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 20),
              tooltip: 'Delete user',
              onPressed: () => _delete(context),
            ),
        ],
      ),
    );
  }

  Future<void> _delete(BuildContext context) async {
    final client = context.read<AppState>().client;
    if (client == null) return;
    final confirmed = await confirmAction(
      context,
      title: 'Delete ${user.username}?',
      message: 'The account is removed. Files it owns are kept.',
      confirmLabel: 'Delete',
    );
    if (!confirmed) return;
    try {
      await client.deleteUser(user.id, deleteGroup: true);
      if (context.mounted) {
        showToast(context, 'User deleted');
        onChanged();
      }
    } catch (e) {
      if (context.mounted) showToast(context, '$e', error: true);
    }
  }
}

class _GroupTile extends StatelessWidget {
  final NasGroup group;

  const _GroupTile({required this.group});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Panel(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          const Icon(Icons.group_outlined, size: 20, color: HymnTheme.success),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(group.name,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                Text('gid ${group.gid} · ${group.users.length} members',
                    style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.5))),
              ],
            ),
          ),
          if (group.builtin)
            Text('system',
                style: theme.textTheme.labelSmall?.copyWith(
                    color:
                        theme.colorScheme.onSurface.withValues(alpha: 0.4))),
        ],
      ),
    );
  }
}

class _CreateUserSheet extends StatefulWidget {
  final VoidCallback onDone;

  const _CreateUserSheet({required this.onDone});

  @override
  State<_CreateUserSheet> createState() => _CreateUserSheetState();
}

class _CreateUserSheetState extends State<_CreateUserSheet> {
  final _username = TextEditingController();
  final _fullName = TextEditingController();
  final _password = TextEditingController();
  final _email = TextEditingController();
  bool _smb = true;
  bool _busy = false;

  @override
  void dispose() {
    _username.dispose();
    _fullName.dispose();
    _password.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final client = context.read<AppState>().client;
    if (client == null) return;
    if (_username.text.trim().isEmpty || _password.text.isEmpty) {
      showToast(context, 'Username and password are required', error: true);
      return;
    }
    setState(() => _busy = true);
    try {
      await client.createUser(
        username: _username.text.trim(),
        fullName: _fullName.text.trim(),
        password: _password.text,
        email: _email.text.trim().isEmpty ? null : _email.text.trim(),
        smb: _smb,
      );
      if (mounted) {
        // capture before pop; the sheet's context dies with it
        final messenger = ScaffoldMessenger.of(context);
        Navigator.pop(context);
        messenger.showSnackBar(SnackBar(content: Text('User created')));
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
          Text('New user', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          TextField(
            controller: _username,
            decoration:
                const InputDecoration(labelText: 'Username'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _fullName,
            decoration:
                const InputDecoration(labelText: 'Full name (optional)'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _password,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Password'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            decoration:
                const InputDecoration(labelText: 'Email (optional)'),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Allow SMB access'),
            value: _smb,
            onChanged: (v) => setState(() => _smb = v),
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
                : const Text('Create user'),
          ),
        ],
      ),
    );
  }
}

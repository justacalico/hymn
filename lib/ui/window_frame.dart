import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';

import 'theme.dart';

/// Wraps [child] with the custom title bar on desktop builds. Android and
/// iOS have no window chrome, so the child is returned untouched.
class WindowFrame extends StatelessWidget {
  const WindowFrame({super.key, required this.child});

  /// Lets widget tests exercise the non-desktop path on a Linux host.
  @visibleForTesting
  static bool? desktopOverride;

  final Widget child;

  static bool get _isDesktop =>
      desktopOverride ??
      (Platform.isLinux || Platform.isWindows || Platform.isMacOS);

  @override
  Widget build(BuildContext context) {
    if (!_isDesktop) return child;
    return Column(
      children: [
        const DesktopTitleBar(),
        Expanded(child: child),
      ],
    );
  }
}

/// The window strip drawn on desktop builds: app mark on the left, caption
/// buttons on the right, and the space between drags the window. macOS
/// keeps its traffic lights, so it gets a left inset and no caption
/// buttons instead.
class DesktopTitleBar extends StatelessWidget {
  const DesktopTitleBar({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: theme.dividerColor)),
        ),
        child: Row(
          children: [
            // The native traffic lights float over this spot on macOS.
            if (Platform.isMacOS) const SizedBox(width: 78),
            const SizedBox(width: 12),
            const DragToMoveArea(child: _TitleMark()),
            const Expanded(
              child: DragToMoveArea(child: SizedBox.expand()),
            ),
            if (!Platform.isMacOS) const _CaptionButtons(),
          ],
        ),
      ),
    );
  }
}

/// Small gradient app mark matching the navigation rail logo.
class _TitleMark extends StatelessWidget {
  const _TitleMark();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [HymnTheme.accent, HymnTheme.accentAlt],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Icon(Icons.storage, color: Colors.white, size: 13),
        ),
        const SizedBox(width: 8),
        Text(
          'Hymn',
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
          ),
        ),
      ],
    );
  }
}

/// Minimize, maximize/restore and close buttons for Windows and Linux.
class _CaptionButtons extends StatefulWidget {
  const _CaptionButtons();

  @override
  State<_CaptionButtons> createState() => _CaptionButtonsState();
}

class _CaptionButtonsState extends State<_CaptionButtons>
    with WindowListener {
  bool _maximized = false;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    _syncMaximized();
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  @override
  void onWindowMaximize() => setState(() => _maximized = true);

  @override
  void onWindowUnmaximize() => setState(() => _maximized = false);

  Future<void> _syncMaximized() async {
    try {
      final maximized = await windowManager.isMaximized();
      if (mounted) setState(() => _maximized = maximized);
    } on MissingPluginException {
      // There is no window channel under widget tests.
    }
  }

  Future<void> _toggleMaximize() async {
    if (await windowManager.isMaximized()) {
      await windowManager.unmaximize();
    } else {
      await windowManager.maximize();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _CaptionButton(
          icon: Icons.remove,
          tooltip: 'Minimize',
          onPressed: windowManager.minimize,
        ),
        _CaptionButton(
          icon: _maximized ? Icons.filter_none : Icons.crop_square,
          tooltip: _maximized ? 'Restore' : 'Maximize',
          onPressed: _toggleMaximize,
        ),
        _CaptionButton(
          icon: Icons.close,
          tooltip: 'Close',
          danger: true,
          onPressed: windowManager.close,
        ),
      ],
    );
  }
}

/// One square caption button. [danger] paints the hover red, matching the
/// close button convention on Windows.
class _CaptionButton extends StatelessWidget {
  const _CaptionButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.danger = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        hoverColor: danger
            ? HymnTheme.danger.withValues(alpha: 0.9)
            : theme.colorScheme.onSurface.withValues(alpha: 0.08),
        child: SizedBox(
          width: 46,
          height: 40,
          child: Icon(
            icon,
            size: 16,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
          ),
        ),
      ),
    );
  }
}

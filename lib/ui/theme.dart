import 'package:flutter/material.dart';

/// Hymn's visual language: dark slate surfaces with a restrained blue accent,
/// rounded corners, and flat cards with hairline borders instead of heavy
/// shadows. Light mode mirrors the same structure on a neutral canvas.
class HymnTheme {
  static const accent = Color(0xFF5B8DEF);
  static const accentAlt = Color(0xFF8B5CF6);
  static const success = Color(0xFF34C77B);
  static const warning = Color(0xFFE8A33D);
  static const danger = Color(0xFFE15B64);

  static const darkBg = Color(0xFF0C0F14);
  static const darkSurface = Color(0xFF141922);
  static const darkCard = Color(0xFF1A2029);
  static const darkBorder = Color(0xFF262E3B);

  static const lightBg = Color(0xFFF4F5F7);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightCard = Color(0xFFFFFFFF);
  static const lightBorder = Color(0xFFE3E6EB);

  static ThemeData dark() {
    final scheme = ColorScheme.dark(
      primary: accent,
      secondary: accentAlt,
      surface: darkSurface,
      error: danger,
      onPrimary: Colors.white,
      onSurface: const Color(0xFFE8EAED),
    );
    return _base(scheme).copyWith(
      scaffoldBackgroundColor: darkBg,
      cardColor: darkCard,
      dividerColor: darkBorder,
    );
  }

  static ThemeData light() {
    final scheme = ColorScheme.light(
      primary: accent,
      secondary: accentAlt,
      surface: lightSurface,
      error: danger,
      onPrimary: Colors.white,
      onSurface: const Color(0xFF1A1D23),
    );
    return _base(scheme).copyWith(
      scaffoldBackgroundColor: lightBg,
      cardColor: lightCard,
      dividerColor: lightBorder,
    );
  }

  static ThemeData _base(ColorScheme scheme) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.outline.withValues(alpha: 0.3)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.outline.withValues(alpha: 0.25)),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 48),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 44),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: EdgeInsets.zero,
      ),
      snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
    );
  }

  /// Card decoration used by the dashboard panels.
  static BoxDecoration cardDecoration(BuildContext context) {
    final theme = Theme.of(context);
    return BoxDecoration(
      color: theme.cardColor,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: theme.dividerColor),
    );
  }
}

/// Section header label: small, muted, medium weight.
Widget sectionLabel(BuildContext context, String text) => Text(
      text.toUpperCase(),
      style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55),
            letterSpacing: 0.8,
            fontWeight: FontWeight.w600,
          ),
    );

/// A flat rounded panel.
class Panel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const Panel({super.key, required this.child, this.padding = const EdgeInsets.all(20)});

  @override
  Widget build(BuildContext context) => Container(
        decoration: HymnTheme.cardDecoration(context),
        padding: padding,
        child: child,
      );
}

/// Big metric card used at the top of the dashboard.
class StatCard extends StatelessWidget {
  final String title;
  final String value;
  final String? subtitle;
  final IconData icon;
  final Color color;

  const StatCard({
    super.key,
    required this.title,
    required this.value,
    this.subtitle,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Panel(
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
                const SizedBox(height: 2),
                Text(value,
                    style: theme.textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w700),
                    overflow: TextOverflow.ellipsis),
                if (subtitle != null)
                  Text(subtitle!,
                      style: theme.textTheme.bodySmall?.copyWith(
                          color:
                              theme.colorScheme.onSurface.withValues(alpha: 0.5)),
                      overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Progress bar with percentage used by pool and memory indicators.
class MeterBar extends StatelessWidget {
  final double fraction;
  final Color color;
  final double height;

  const MeterBar({
    super.key,
    required this.fraction,
    this.color = HymnTheme.accent,
    this.height = 8,
  });

  @override
  Widget build(BuildContext context) {
    final clamped = fraction.clamp(0.0, 1.0);
    return ClipRRect(
      borderRadius: BorderRadius.circular(height / 2),
      child: SizedBox(
        height: height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(color: Theme.of(context).dividerColor.withValues(alpha: 0.4)),
            FractionallySizedBox(
              widthFactor: clamped,
              alignment: Alignment.centerLeft,
              child: ColoredBox(color: color),
            ),
          ],
        ),
      ),
    );
  }
}

Color statusColor(String status) {
  switch (status.toUpperCase()) {
    case 'ONLINE':
    case 'RUNNING':
    case 'HEALTHY':
    case 'SUCCESS':
      return HymnTheme.success;
    case 'DEGRADED':
    case 'WARNING':
    case 'WAITING':
      return HymnTheme.warning;
    case 'OFFLINE':
    case 'FAILED':
    case 'STOPPED':
    case 'CRITICAL':
      return HymnTheme.danger;
    default:
      return HymnTheme.accent;
  }
}

/// Small colored dot + status text.
class StatusChip extends StatelessWidget {
  final String status;

  const StatusChip(this.status, {super.key});

  @override
  Widget build(BuildContext context) {
    final color = statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            status.toUpperCase(),
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}

/// Centered placeholder for empty or failed page loads.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? message;
  final VoidCallback? onRetry;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 44,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.35)),
            const SizedBox(height: 16),
            Text(title, style: theme.textTheme.titleMedium),
            if (message != null) ...[
              const SizedBox(height: 8),
              Text(message!,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.55))),
            ],
            if (onRetry != null) ...[
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Try again'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Confirms a destructive action before running it.
Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirm',
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: HymnTheme.danger),
          onPressed: () => Navigator.pop(context, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}

void showToast(BuildContext context, String message, {bool error = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor:
          error ? HymnTheme.danger : Theme.of(context).colorScheme.inverseSurface,
    ));
}

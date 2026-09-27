/// Human-readable formatting helpers shared across the app.
library;

String formatBytes(int bytes) {
  if (bytes <= 0) return '0 B';
  const units = ['B', 'KiB', 'MiB', 'GiB', 'TiB', 'PiB'];
  var value = bytes.toDouble();
  var unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  final text = unit == 0
      ? value.toStringAsFixed(0)
      : value >= 100
          ? value.toStringAsFixed(0)
          : value.toStringAsFixed(1);
  return '$text ${units[unit]}';
}

String formatBytesPerSec(double bytesPerSec) => '${formatBytes(bytesPerSec.round())}/s';

String formatUptime(int seconds) {
  if (seconds <= 0) return 'just started';
  final days = seconds ~/ 86400;
  final hours = (seconds % 86400) ~/ 3600;
  final minutes = (seconds % 3600) ~/ 60;
  if (days > 0) return '${days}d ${hours}h';
  if (hours > 0) return '${hours}h ${minutes}m';
  return '${minutes}m';
}

String formatPercent(double fraction) =>
    '${(fraction * 100).clamp(0, 100).toStringAsFixed(1)}%';

String formatDateTime(DateTime? dt) {
  if (dt == null) return 'unknown';
  final local = dt.toLocal();
  String two(int v) => v.toString().padLeft(2, '0');
  return '${local.year}-${two(local.month)}-${two(local.day)} '
      '${two(local.hour)}:${two(local.minute)}';
}

String formatRelative(DateTime? dt) {
  if (dt == null) return 'unknown';
  final diff = DateTime.now().difference(dt);
  if (diff.isNegative) return 'just now';
  if (diff.inDays > 0) return '${diff.inDays}d ago';
  if (diff.inHours > 0) return '${diff.inHours}h ago';
  if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
  return 'just now';
}

import 'package:flutter_test/flutter_test.dart';
import 'package:hymn/utils/format.dart';

void main() {
  group('formatBytes', () {
    test('zero and small', () {
      expect(formatBytes(0), '0 B');
      expect(formatBytes(-5), '0 B');
      expect(formatBytes(512), '512 B');
    });

    test('unit scaling', () {
      expect(formatBytes(2048), '2.0 KiB');
      expect(formatBytes(5 * 1024 * 1024), '5.0 MiB');
      expect(formatBytes(3 * 1024 * 1024 * 1024), '3.0 GiB');
      expect(formatBytes(1024 * 1024 * 1024 * 1024), '1.0 TiB');
      expect(formatBytes(150 * 1024), '150 KiB');
    });
  });

  test('formatBytesPerSec', () {
    expect(formatBytesPerSec(2048), '2.0 KiB/s');
  });

  group('formatUptime', () {
    test('durations', () {
      expect(formatUptime(0), 'just started');
      expect(formatUptime(600), '10m');
      expect(formatUptime(3661), '1h 1m');
      expect(formatUptime(90000), '1d 1h');
    });
  });

  test('formatPercent', () {
    expect(formatPercent(0.5), '50.0%');
    expect(formatPercent(1.5), '100.0%');
    expect(formatPercent(-1), '0.0%');
  });

  test('formatDateTime', () {
    expect(formatDateTime(null), 'unknown');
    expect(formatDateTime(DateTime(2026, 3, 4, 5, 6)), '2026-03-04 05:06');
  });

  test('formatRelative', () {
    expect(formatRelative(null), 'unknown');
    expect(formatRelative(DateTime.now().add(const Duration(days: 1))), 'just now');
    expect(formatRelative(DateTime.now().subtract(const Duration(minutes: 2))), '2m ago');
    expect(formatRelative(DateTime.now().subtract(const Duration(hours: 3))), '3h ago');
    expect(formatRelative(DateTime.now().subtract(const Duration(days: 4))), '4d ago');
    expect(formatRelative(DateTime.now().subtract(const Duration(seconds: 10))), 'just now');
  });
}

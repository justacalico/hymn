import 'dart:collection';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../api/models.dart';
import '../../app_state.dart';
import '../../utils/format.dart';
import '../theme.dart';
import '../widgets/loader.dart';

/// Rolling window of realtime samples for the charts.
class SampleHistory {
  static const capacity = 120; // ~4 minutes at 2s resolution
  final Queue<RealtimeSample> samples = Queue();

  void add(RealtimeSample s) {
    samples.add(s);
    while (samples.length > capacity) {
      samples.removeFirst();
    }
  }
}

class StatsPage extends StatelessWidget {
  const StatsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DataLoader<SystemInfo>(
      load: (client) => client.getSystemInfo(),
      builder: (context, system, refresh) =>
          _StatsView(system: system, refresh: refresh),
    );
  }
}

class _StatsView extends StatefulWidget {
  final SystemInfo system;
  final VoidCallback refresh;

  const _StatsView({required this.system, required this.refresh});

  @override
  State<_StatsView> createState() => _StatsViewState();
}

class _StatsViewState extends State<_StatsView> {
  final _history = SampleHistory();

  @override
  Widget build(BuildContext context) {
    final client = context.read<AppState>().client;
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Row(
          children: [
            Expanded(
              child: Text('Stats',
                  style: theme.textTheme.headlineMedium
                      ?.copyWith(fontWeight: FontWeight.w700)),
            ),
            IconButton(
              onPressed: widget.refresh,
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh',
            ),
          ],
        ),
        const SizedBox(height: 8),
        StreamBuilder<RealtimeSample>(
          stream: client?.realtimeStats(),
          builder: (context, snapshot) {
            final sample = snapshot.data;
            if (sample != null) _history.add(sample);
            final cpuSpots = _spots((s) => s.cpuUsage);
            final memSpots =
                _spots((s) => s.memoryTotal > 0 ? s.memoryUsed / s.memoryTotal * 100 : 0);
            final rxSpots = _spots((s) => s.networkRxBytesPerSec);
            final txSpots = _spots((s) => s.networkTxBytesPerSec);
            final drSpots = _spots((s) => s.diskReadBytesPerSec);
            final dwSpots = _spots((s) => s.diskWriteBytesPerSec);
            return Column(
              children: [
                _ChartPanel(
                  title: 'CPU',
                  value: sample != null
                      ? '${sample.cpuUsage.toStringAsFixed(1)}%'
                      : 'waiting',
                  spots: cpuSpots,
                  color: HymnTheme.accent,
                  maxY: 100,
                ),
                const SizedBox(height: 16),
                _ChartPanel(
                  title: 'Memory',
                  value: sample != null && sample.memoryTotal > 0
                      ? '${formatBytes(sample.memoryUsed)} / ${formatBytes(sample.memoryTotal)}'
                      : 'waiting',
                  spots: memSpots,
                  color: HymnTheme.accentAlt,
                  maxY: 100,
                ),
                const SizedBox(height: 16),
                _ChartPanel(
                  title: 'Network',
                  value: sample != null
                      ? '${formatBytesPerSec(sample.networkRxBytesPerSec)} in · ${formatBytesPerSec(sample.networkTxBytesPerSec)} out'
                      : 'waiting',
                  spots: rxSpots,
                  secondSpots: txSpots,
                  color: HymnTheme.success,
                  secondColor: HymnTheme.warning,
                ),
                const SizedBox(height: 16),
                _ChartPanel(
                  title: 'Disk I/O',
                  value: sample != null
                      ? '${formatBytesPerSec(sample.diskReadBytesPerSec)} read · ${formatBytesPerSec(sample.diskWriteBytesPerSec)} write'
                      : 'waiting',
                  spots: drSpots,
                  secondSpots: dwSpots,
                  color: HymnTheme.accent,
                  secondColor: HymnTheme.danger,
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              sectionLabel(context, 'System'),
              const SizedBox(height: 12),
              _InfoRow('Version', 'TrueNAS ${widget.system.version}'),
              _InfoRow('Hostname', widget.system.hostname),
              _InfoRow('CPU',
                  '${widget.system.cpuModel} · ${widget.system.cores} cores'),
              _InfoRow('Memory', formatBytes(widget.system.physicalMemory)),
              _InfoRow('Uptime', formatUptime(widget.system.uptimeSeconds)),
            ],
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  List<FlSpot> _spots(double Function(RealtimeSample) pick) {
    var i = 0;
    return [
      for (final s in _history.samples) FlSpot((i++).toDouble(), pick(s)),
    ];
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(label,
                style: theme.textTheme.bodySmall?.copyWith(
                    color:
                        theme.colorScheme.onSurface.withValues(alpha: 0.5))),
          ),
          Expanded(child: Text(value, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}

class _ChartPanel extends StatelessWidget {
  final String title;
  final String value;
  final List<FlSpot> spots;
  final List<FlSpot>? secondSpots;
  final Color color;
  final Color? secondColor;
  final double? maxY;

  const _ChartPanel({
    required this.title,
    required this.value,
    required this.spots,
    this.secondSpots,
    required this.color,
    this.secondColor,
    this.maxY,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              sectionLabel(context, title),
              Text(value, style: theme.textTheme.bodySmall),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 120,
            child: spots.isEmpty
                ? Center(
                    child: Text('Collecting data…',
                        style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.4))),
                  )
                : LineChart(
                    LineChartData(
                      minY: 0,
                      maxY: maxY,
                      gridData: const FlGridData(show: false),
                      borderData: FlBorderData(show: false),
                      titlesData: const FlTitlesData(show: false),
                      lineTouchData: const LineTouchData(enabled: false),
                      lineBarsData: [
                        _line(spots, color),
                        if (secondSpots != null)
                          _line(secondSpots!,
                              secondColor ?? HymnTheme.warning),
                      ],
                    ),
                    duration: Duration.zero,
                  ),
          ),
        ],
      ),
    );
  }

  LineChartBarData _line(List<FlSpot> data, Color c) => LineChartBarData(
        spots: data,
        isCurved: true,
        preventCurveOverShooting: true,
        color: c,
        barWidth: 2,
        dotData: const FlDotData(show: false),
        belowBarData: BarAreaData(
          show: true,
          color: c.withValues(alpha: 0.12),
        ),
      );
}

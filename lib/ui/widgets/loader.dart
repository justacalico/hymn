import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../api/truenas_client.dart';
import '../../app_state.dart';
import '../theme.dart';

/// Loads data through the TrueNAS client once on mount and exposes a manual
/// refresh. Shows a spinner while loading and an [EmptyState] on failure.
class DataLoader<T> extends StatefulWidget {
  final Future<T> Function(TrueNasClient client) load;
  final Widget Function(BuildContext context, T data, VoidCallback refresh)
      builder;
  final Duration? autoRefresh;
  final String loadingLabel;

  const DataLoader({
    super.key,
    required this.load,
    required this.builder,
    this.autoRefresh,
    this.loadingLabel = 'Loading',
  });

  @override
  State<DataLoader<T>> createState() => _DataLoaderState<T>();
}

class _DataLoaderState<T> extends State<DataLoader<T>> {
  T? _data;
  Object? _error;
  bool _loading = true;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _refresh();
    if (widget.autoRefresh != null) {
      _timer = Timer.periodic(widget.autoRefresh!, (_) => _refresh(quiet: true));
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _refresh({bool quiet = false}) async {
    final client = context.read<AppState>().client;
    if (client == null) return;
    if (!quiet) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final data = await widget.load(client);
      if (!mounted) return;
      setState(() {
        _data = data;
        _error = null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _data == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _data == null) {
      return EmptyState(
        icon: Icons.cloud_off_outlined,
        title: 'Could not load data',
        message: _error is TrueNasException
            ? (_error as TrueNasException).message
            : _error.toString(),
        onRetry: _refresh,
      );
    }
    return RefreshIndicator(
      onRefresh: () => _refresh(quiet: true),
      child: widget.builder(context, _data as T, _refresh),
    );
  }
}

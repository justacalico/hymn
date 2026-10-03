/// Data models for the TrueNAS SCALE API.
///
/// Every model parses defensively: TrueNAS versions differ in which fields
/// they return, so missing keys fall back to sane defaults instead of
/// throwing.
library;

Map<String, dynamic> _map(dynamic v) =>
    v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};

List<dynamic> _list(dynamic v) => v is List ? v : const [];

/// Values of a map, or elements of a list — TrueNAS sometimes reports
/// collections keyed by device name instead of as arrays.
Iterable<dynamic> _values(dynamic v) => v is Map ? v.values : _list(v);

int _int(dynamic v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? 0;
  return 0;
}

double _double(dynamic v) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v) ?? 0;
  return 0;
}

String _str(dynamic v, [String fallback = '']) => v?.toString() ?? fallback;

bool _bool(dynamic v) => v == true;

/// Raw byte fields in TrueNAS responses arrive either as numbers or as
/// `{parsed: ..., rawvalue: "123"}` objects.
int bytesOf(dynamic v) {
  if (v is num) return v.toInt();
  if (v is Map) return _int(v['rawvalue']);
  if (v is String) return int.tryParse(v) ?? 0;
  return 0;
}

class SystemInfo {
  final String version;
  final String hostname;
  final int uptimeSeconds;
  final List<double> loadAverage;
  final int physicalMemory;
  final int cores;
  final String cpuModel;
  final String timezone;
  final DateTime? buildTime;

  const SystemInfo({
    required this.version,
    required this.hostname,
    required this.uptimeSeconds,
    required this.loadAverage,
    required this.physicalMemory,
    required this.cores,
    required this.cpuModel,
    required this.timezone,
    this.buildTime,
  });

  factory SystemInfo.fromJson(Map<String, dynamic> json) => SystemInfo(
        version: _str(json['version']),
        hostname: _str(json['hostname']),
        uptimeSeconds: _int(json['uptime_seconds']),
        loadAverage:
            _list(json['loadavg']).map((e) => _double(e)).toList(growable: false),
        physicalMemory: _int(json['physmem']),
        cores: _int(json['cores']),
        cpuModel: _str(json['model']),
        timezone: _str(json['timezone']),
        buildTime: json['datetime'] != null
            ? DateTime.fromMillisecondsSinceEpoch(
                _int(json['datetime']) > 10000000000000
                    ? _int(json['datetime']) ~/ 1000
                    : _int(json['datetime']),
              )
            : null,
      );
}

class NasVersion {
  final String version;
  final String buildTime;

  const NasVersion({required this.version, required this.buildTime});

  factory NasVersion.fromJson(Map<String, dynamic> json) => NasVersion(
        version: _str(json['version']),
        buildTime: _str(json['buildtime']),
      );
}

class VDev {
  final String name;
  final String type;
  final String status;
  final int size;
  final int allocated;
  final int readErrors;
  final int writeErrors;
  final int checksumErrors;
  final List<String> disks;
  final List<VDev> children;

  const VDev({
    required this.name,
    required this.type,
    required this.status,
    this.size = 0,
    this.allocated = 0,
    this.readErrors = 0,
    this.writeErrors = 0,
    this.checksumErrors = 0,
    this.disks = const [],
    this.children = const [],
  });

  factory VDev.fromJson(Map<String, dynamic> json) {
    final stats = _map(json['stats']);
    final children =
        _list(json['children']).map((c) => VDev.fromJson(_map(c))).toList();
    return VDev(
      name: _str(json['name']),
      type: _str(json['type']),
      status: _str(json['status']),
      size: _int(stats['size']),
      allocated: _int(stats['allocated']),
      readErrors: _int(stats['read_errors']),
      writeErrors: _int(stats['write_errors']),
      checksumErrors: _int(stats['checksum_errors']),
      disks: _list(json['disks']).map((d) => _str(d)).toList(),
      children: children,
    );
  }

  /// Total error count across this vdev and its children.
  int get errorCount {
    var total = readErrors + writeErrors + checksumErrors;
    for (final c in children) {
      total += c.errorCount;
    }
    return total;
  }
}

class Pool {
  final int id;
  final String name;
  final String status;
  final bool healthy;
  final int size;
  final int allocated;
  final int free;
  final List<VDev> dataVDevs;
  final double? scanPercent;
  final String? scanState;

  const Pool({
    required this.id,
    required this.name,
    required this.status,
    required this.healthy,
    required this.size,
    required this.allocated,
    required this.free,
    required this.dataVDevs,
    this.scanPercent,
    this.scanState,
  });

  factory Pool.fromJson(Map<String, dynamic> json) {
    final topology = _map(json['topology']);
    final scan = _map(json['scan']);
    return Pool(
      id: _int(json['id']),
      name: _str(json['name']),
      status: _str(json['status']),
      healthy: _bool(json['healthy']),
      size: _int(json['size']),
      allocated: _int(json['allocated']),
      free: _int(json['free']),
      dataVDevs: _list(topology['data'])
          .map((v) => VDev.fromJson(_map(v)))
          .toList(growable: false),
      scanPercent: scan['percentage'] != null ? _double(scan['percentage']) : null,
      scanState: scan['state']?.toString(),
    );
  }

  double get usedPercent => size > 0 ? allocated / size : 0;

  String get raidLevel {
    if (dataVDevs.isEmpty) return 'Stripe';
    final types = dataVDevs.map((v) => v.type).toSet();
    if (types.length == 1) return dataVDevs.first.type;
    return types.join(' + ');
  }
}

class Dataset {
  final String id;
  final String name;
  final String pool;
  final String mountpoint;
  final int used;
  final int available;
  final int? quota;
  final String compression;
  final String shareType;
  final bool encrypted;
  final bool locked;
  final String? comments;

  const Dataset({
    required this.id,
    required this.name,
    required this.pool,
    required this.mountpoint,
    required this.used,
    required this.available,
    this.quota,
    required this.compression,
    required this.shareType,
    this.encrypted = false,
    this.locked = false,
    this.comments,
  });

  factory Dataset.fromJson(Map<String, dynamic> json) => Dataset(
        id: _str(json['id']),
        name: _str(json['name']),
        pool: _str(json['pool']),
        mountpoint: _str(json['mountpoint']),
        used: bytesOf(json['used']),
        available: bytesOf(json['available']),
        quota: json['quota'] != null && _int(_map(json['quota'])['rawvalue']) > 0
            ? _int(_map(json['quota'])['rawvalue'])
            : null,
        compression: _str(_map(json['compression'])['value'],
            _str(json['compression'], 'LZ4')),
        shareType: _str(_map(json['share_type'])['value'],
            _str(json['share_type'], 'GENERIC')),
        encrypted: _bool(json['encrypted']),
        locked: _bool(json['locked']),
        comments: json['comments'] != null
            ? _str(_map(json['comments'])['value'], _str(json['comments']))
            : null,
      );

  /// Dataset name relative to its pool (the part after `pool/`).
  String get shortName =>
      name.startsWith('$pool/') ? name.substring(pool.length + 1) : name;
}

class Disk {
  final String name;
  final String identifier;
  final int size;
  final String model;
  final String serial;
  final String type;
  final int? rotationRate;
  final String? pool;
  final String bus;
  final bool smartEnabled;

  const Disk({
    required this.name,
    required this.identifier,
    required this.size,
    required this.model,
    required this.serial,
    required this.type,
    this.rotationRate,
    this.pool,
    required this.bus,
    this.smartEnabled = false,
  });

  factory Disk.fromJson(Map<String, dynamic> json) => Disk(
        name: _str(json['name']),
        identifier: _str(json['identifier']),
        size: _int(json['size']),
        model: _str(json['model']),
        serial: _str(json['serial']),
        type: _str(json['type']),
        rotationRate:
            json['rotationrate'] != null ? _int(json['rotationrate']) : null,
        pool: json['pool']?.toString(),
        bus: _str(json['bus']),
        smartEnabled: _bool(json['togglesmart']),
      );

  bool get isInUse => pool != null && pool!.isNotEmpty;
}

class SmbShare {
  final int id;
  final String name;
  final String path;
  final String comment;
  final bool enabled;
  final bool readOnly;
  final bool browsable;
  final bool guestOk;

  const SmbShare({
    required this.id,
    required this.name,
    required this.path,
    required this.comment,
    required this.enabled,
    required this.readOnly,
    required this.browsable,
    required this.guestOk,
  });

  factory SmbShare.fromJson(Map<String, dynamic> json) {
    final options = _map(json['options']);
    return SmbShare(
      id: _int(json['id']),
      name: _str(json['name']),
      path: _str(json['path']),
      comment: _str(json['comment']),
      enabled: _bool(json['enabled']),
      readOnly: _bool(json['ro']),
      browsable: _bool(json['browsable']),
      guestOk: _bool(options['guestok']) || _bool(json['guestok']),
    );
  }
}

class NfsShare {
  final int id;
  final String path;
  final String comment;
  final bool enabled;
  final bool readOnly;
  final List<String> networks;
  final List<String> hosts;

  const NfsShare({
    required this.id,
    required this.path,
    required this.comment,
    required this.enabled,
    required this.readOnly,
    required this.networks,
    required this.hosts,
  });

  factory NfsShare.fromJson(Map<String, dynamic> json) => NfsShare(
        id: _int(json['id']),
        path: _str(json['path']),
        comment: _str(json['comment']),
        enabled: _bool(json['enabled']),
        readOnly: _bool(json['ro']),
        networks: _list(json['networks']).map((e) => _str(e)).toList(),
        hosts: _list(json['hosts']).map((e) => _str(e)).toList(),
      );
}

class Snapshot {
  final String id;
  final String dataset;
  final String name;
  final DateTime? created;
  final int referenced;

  const Snapshot({
    required this.id,
    required this.dataset,
    required this.name,
    this.created,
    this.referenced = 0,
  });

  factory Snapshot.fromJson(Map<String, dynamic> json) {
    final props = _map(json['properties']);
    final creation = _map(props['creation']);
    var created = _int(creation['rawvalue'].toString().isNotEmpty
        ? creation['rawvalue']
        : creation['value']);
    DateTime? date;
    if (created > 0) {
      date = DateTime.fromMillisecondsSinceEpoch(created * 1000);
    } else if (creation['value'] != null) {
      date = DateTime.tryParse(creation['value'].toString());
    }
    final full = _str(json['id'] ?? json['snapshot_name']);
    final atIndex = full.indexOf('@');
    return Snapshot(
      id: full,
      dataset: atIndex >= 0 ? full.substring(0, atIndex) : _str(json['dataset']),
      name: atIndex >= 0 ? full.substring(atIndex + 1) : full,
      created: date,
      referenced: bytesOf(props['referenced']),
    );
  }
}

class NasApp {
  final String id;
  final String name;
  final String state;
  final String version;
  final String? iconUrl;
  final String? appVersion;
  final bool upgradeAvailable;
  final List<String> portals;
  final Map<String, String> webPorts;

  const NasApp({
    required this.id,
    required this.name,
    required this.state,
    required this.version,
    this.iconUrl,
    this.appVersion,
    this.upgradeAvailable = false,
    this.portals = const [],
    this.webPorts = const {},
  });

  factory NasApp.fromJson(Map<String, dynamic> json) {
    final portals = <String>[];
    final activeWorkloads = _map(json['active_workloads']);
    for (final p in _list(activeWorkloads['portals'])) {
      final host = _str(_map(p)['host']);
      final port = _map(p)['port'];
      final proto = _str(_map(p)['protocol'], 'http');
      if (host.isNotEmpty) {
        portals.add('$proto://$host${port.isNotEmpty ? ':$port' : ''}');
      }
    }
    final metadata = _map(json['metadata']);
    return NasApp(
      id: _str(json['id']),
      name: _str(metadata['name'], _str(json['name'])),
      state: _str(json['state'], 'UNKNOWN'),
      version: _str(json['version']),
      iconUrl: metadata['icon']?.toString(),
      appVersion: _str(json['human_version'], _str(metadata['app_version'])),
      upgradeAvailable: _bool(json['upgrade_available']),
      portals: portals,
      webPorts: {},
    );
  }

  bool get running => state.toUpperCase() == 'RUNNING';
}

class AvailableApp {
  final String name;
  final String title;
  final String description;
  final String? iconUrl;
  final List<String> categories;
  final String catalog;
  final String train;

  const AvailableApp({
    required this.name,
    required this.title,
    required this.description,
    this.iconUrl,
    this.categories = const [],
    required this.catalog,
    required this.train,
  });

  factory AvailableApp.fromJson(Map<String, dynamic> json) => AvailableApp(
        name: _str(json['name']),
        title: _str(json['title'], _str(json['name'])),
        description: _str(json['description']),
        iconUrl: json['icon_url']?.toString(),
        categories: _list(json['categories']).map((e) => _str(e)).toList(),
        catalog: _str(json['catalog'], 'TRUENAS'),
        train: _str(json['train'], 'community'),
      );
}

class NasService {
  final int id;
  final String service;
  final bool enable;
  final String state;

  const NasService({
    required this.id,
    required this.service,
    required this.enable,
    required this.state,
  });

  factory NasService.fromJson(Map<String, dynamic> json) => NasService(
        id: _int(json['id']),
        service: _str(json['service']),
        enable: _bool(json['enable']),
        state: _str(json['state'], 'UNKNOWN'),
      );

  bool get running => state.toUpperCase() == 'RUNNING';
}

class NasAlert {
  final String uuid;
  final String level;
  final String message;
  final String source;
  final DateTime? datetime;
  final bool dismissed;
  final bool oneShot;

  const NasAlert({
    required this.uuid,
    required this.level,
    required this.message,
    required this.source,
    this.datetime,
    this.dismissed = false,
    this.oneShot = false,
  });

  factory NasAlert.fromJson(Map<String, dynamic> json) {
    DateTime? date;
    final raw = json['datetime'];
    if (raw is Map) {
      final epoch = _int(raw[r'$date']);
      if (epoch > 0) {
        date = DateTime.fromMillisecondsSinceEpoch(epoch);
      }
    }
    return NasAlert(
      uuid: _str(json['uuid']),
      level: _str(json['level'], 'INFO'),
      message: _str(json['message']),
      source: _str(json['source']),
      datetime: date,
      dismissed: _bool(json['dismissed']),
      oneShot: _bool(json['one_shot']),
    );
  }
}

class NasJob {
  final int id;
  final String method;
  final String state;
  final double progress;
  final String? description;
  final String? error;
  final DateTime? finishedAt;

  const NasJob({
    required this.id,
    required this.method,
    required this.state,
    required this.progress,
    this.description,
    this.error,
    this.finishedAt,
  });

  factory NasJob.fromJson(Map<String, dynamic> json) {
    final progress = _map(json['progress']);
    final timeFinished = _map(json['time_finished']);
    return NasJob(
      id: _int(json['id']),
      method: _str(json['method']),
      state: _str(json['state'], 'UNKNOWN'),
      progress: _double(progress['percent']),
      description: progress['description']?.toString(),
      error: json['error']?.toString(),
      finishedAt: timeFinished[r'$date'] != null
          ? DateTime.fromMillisecondsSinceEpoch(_int(timeFinished[r'$date']))
          : null,
    );
  }

  bool get running => state == 'RUNNING' || state == 'WAITING';
  bool get failed => state == 'FAILED';
}

/// One sample from the TrueNAS `reporting.realtime` websocket stream.
class RealtimeSample {
  final double cpuUsage;
  final int memoryTotal;
  final int memoryUsed;
  final double networkRxBytesPerSec;
  final double networkTxBytesPerSec;
  final double diskReadBytesPerSec;
  final double diskWriteBytesPerSec;

  const RealtimeSample({
    this.cpuUsage = 0,
    this.memoryTotal = 0,
    this.memoryUsed = 0,
    this.networkRxBytesPerSec = 0,
    this.networkTxBytesPerSec = 0,
    this.diskReadBytesPerSec = 0,
    this.diskWriteBytesPerSec = 0,
  });

  factory RealtimeSample.fromJson(Map<String, dynamic> json) {
    // TrueNAS reports cpu/interfaces/disks as maps keyed by device name
    // (cpu, cpu0, ... / eth0, ... / sda, ...). Accept lists too so the parser
    // works with both payload variants.
    double rx = 0, tx = 0;
    for (final iface in _values(json['interfaces'])) {
      final stats = _map(iface)['stats'];
      if (stats is Map) {
        rx += _double(stats['received_bytes_rate']);
        tx += _double(stats['sent_bytes_rate']);
      } else {
        rx += _double(_map(iface)['received_bytes_rate']);
        tx += _double(_map(iface)['sent_bytes_rate']);
      }
    }
    double dr = 0, dw = 0;
    for (final disk in _values(json['disks'])) {
      dr += _double(_map(disk)['read_bytes']);
      dw += _double(_map(disk)['write_bytes']);
    }
    final cpuAll = _map(json['cpu']);
    // the aggregate entry is keyed 'cpu'; fall back to a flat object
    final cpu = _map(cpuAll['cpu'] ?? json['cpu']);
    final memory = _map(json['memory']);
    var cpuUsage = _double(cpu['user']) + _double(cpu['system']);
    if (cpuUsage > 100) cpuUsage = 100;
    return RealtimeSample(
      cpuUsage: cpuUsage,
      memoryTotal: _int(_map(memory['physical'])['total'] ?? memory['physmem']),
      memoryUsed: _int(
          _map(memory['physical'])['used'] ?? _map(memory['real_used'])['used']),
      networkRxBytesPerSec: rx,
      networkTxBytesPerSec: tx,
      diskReadBytesPerSec: dr,
      diskWriteBytesPerSec: dw,
    );
  }
}

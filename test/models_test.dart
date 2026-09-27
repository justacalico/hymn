import 'package:flutter_test/flutter_test.dart';
import 'package:hymn/api/models.dart';

void main() {
  group('SystemInfo', () {
    test('parses a full response', () {
      final info = SystemInfo.fromJson({
        'version': '25.04.1',
        'hostname': 'nas',
        'uptime_seconds': 3600,
        'loadavg': [0.5, 0.4, 0.3],
        'physmem': 16000000000,
        'cores': 8,
        'model': 'Ryzen',
        'timezone': 'UTC',
        'datetime': 1700000000000,
      });
      expect(info.hostname, 'nas');
      expect(info.cores, 8);
      expect(info.loadAverage, [0.5, 0.4, 0.3]);
      expect(info.buildTime, isNotNull);
    });

    test('tolerates missing fields', () {
      final info = SystemInfo.fromJson(const {});
      expect(info.hostname, '');
      expect(info.cores, 0);
      expect(info.buildTime, isNull);
    });

    test('handles second-precision datetime', () {
      final info = SystemInfo.fromJson({'datetime': 1700000000});
      expect(info.buildTime, isNotNull);
    });
  });

  group('Pool', () {
    final poolJson = {
      'id': 1,
      'name': 'tank',
      'status': 'ONLINE',
      'healthy': true,
      'size': 100,
      'allocated': 40,
      'free': 60,
      'scan': {'state': 'FINISHED', 'percentage': 100.0},
      'topology': {
        'data': [
          {
            'name': 'raidz1-0',
            'type': 'RAIDZ1',
            'status': 'ONLINE',
            'stats': {'size': 100, 'allocated': 40, 'read_errors': 0, 'write_errors': 1, 'checksum_errors': 0},
            'disks': ['sda', 'sdb', 'sdc'],
          }
        ],
      },
    };

    test('parses pool with topology', () {
      final pool = Pool.fromJson(poolJson);
      expect(pool.name, 'tank');
      expect(pool.usedPercent, closeTo(0.4, 0.001));
      expect(pool.raidLevel, 'RAIDZ1');
      expect(pool.scanState, 'FINISHED');
      expect(pool.dataVDevs.single.errorCount, 1);
    });

    test('empty topology is a stripe', () {
      final pool = Pool.fromJson({'name': 'x'});
      expect(pool.raidLevel, 'Stripe');
      expect(pool.usedPercent, 0);
    });

    test('mixed vdev types join with +', () {
      final json = Map<String, dynamic>.from(poolJson);
      json['topology'] = {
        'data': [
          {'name': 'a', 'type': 'MIRROR'},
          {'name': 'b', 'type': 'RAIDZ1'},
        ]
      };
      expect(Pool.fromJson(json).raidLevel, contains('+'));
    });
  });

  group('Dataset', () {
    test('parses byte fields and quota', () {
      final ds = Dataset.fromJson({
        'id': 'tank/media',
        'name': 'tank/media',
        'pool': 'tank',
        'mountpoint': '/mnt/tank/media',
        'used': {'rawvalue': '1073741824'},
        'available': {'rawvalue': '1073741824'},
        'quota': {'rawvalue': '2147483648'},
        'compression': {'value': 'LZ4'},
        'share_type': {'value': 'SMB'},
        'comments': {'value': 'movies'},
      });
      expect(ds.shortName, 'media');
      expect(ds.quota, 2147483648);
      expect(ds.compression, 'LZ4');
      expect(ds.comments, 'movies');
    });

    test('zero quota becomes null', () {
      final ds = Dataset.fromJson({
        'id': 'a/b',
        'name': 'a/b',
        'pool': 'a',
        'quota': {'rawvalue': '0'},
      });
      expect(ds.quota, isNull);
      expect(ds.shortName, 'b');
    });

    test('name equal to pool stays whole', () {
      final ds = Dataset.fromJson({'id': 'tank', 'name': 'tank', 'pool': 'tank'});
      expect(ds.shortName, 'tank');
    });
  });

  group('Disk', () {
    test('parses and detects pool membership', () {
      final inUse = Disk.fromJson({'name': 'sda', 'pool': 'tank', 'size': 1024});
      final free = Disk.fromJson({'name': 'sdb'});
      expect(inUse.isInUse, isTrue);
      expect(free.isInUse, isFalse);
    });
  });

  group('shares', () {
    test('smb parses options.guestok', () {
      final share = SmbShare.fromJson({
        'id': 1,
        'name': 'media',
        'path': '/mnt/tank/media',
        'enabled': true,
        'ro': false,
        'browsable': true,
        'options': {'guestok': true},
      });
      expect(share.guestOk, isTrue);
      expect(share.enabled, isTrue);
    });

    test('nfs parses lists', () {
      final share = NfsShare.fromJson({
        'id': 2,
        'path': '/mnt/tank/x',
        'networks': ['10.0.0.0/8'],
        'hosts': ['nas'],
        'ro': true,
      });
      expect(share.networks, ['10.0.0.0/8']);
      expect(share.readOnly, isTrue);
    });
  });

  group('Snapshot', () {
    test('splits id into dataset and name, parses creation', () {
      final snap = Snapshot.fromJson({
        'id': 'tank/media@snap1',
        'properties': {
          'creation': {'rawvalue': '1700000000'},
          'referenced': {'rawvalue': '4096'},
        },
      });
      expect(snap.dataset, 'tank/media');
      expect(snap.name, 'snap1');
      expect(snap.created, isNotNull);
      expect(snap.referenced, 4096);
    });

    test('tolerates missing properties', () {
      final snap = Snapshot.fromJson({'id': 'a@b'});
      expect(snap.dataset, 'a');
      expect(snap.created, isNull);
    });
  });

  group('apps', () {
    test('parses installed app with portals', () {
      final app = NasApp.fromJson({
        'id': 'plex',
        'name': 'plex',
        'state': 'RUNNING',
        'version': '1.0.0',
        'human_version': '1.41_1.0.0',
        'metadata': {'name': 'plex', 'icon': 'https://x/i.png'},
        'active_workloads': {
          'portals': [
            {'host': 'nas.local', 'port': '32400', 'protocol': 'http'}
          ]
        },
      });
      expect(app.running, isTrue);
      expect(app.portals.single, 'http://nas.local:32400');
      expect(app.iconUrl, 'https://x/i.png');
    });

    test('stopped app', () {
      final app = NasApp.fromJson({'id': 'x', 'state': 'STOPPED'});
      expect(app.running, isFalse);
    });

    test('catalog app', () {
      final app = AvailableApp.fromJson({
        'name': 'jellyfin',
        'title': 'Jellyfin',
        'description': 'media server',
        'categories': ['media'],
      });
      expect(app.catalog, 'TRUENAS');
      expect(app.categories, ['media']);
    });
  });

  group('users and groups', () {
    test('user parses', () {
      final u = NasUser.fromJson({
        'id': 7,
        'uid': 1001,
        'username': 'calico',
        'full_name': 'Calico',
        'email': 'c@x.com',
        'smb': true,
        'builtin': false,
        'locked': false,
        'groups': [1, 2],
        'group': {'id': 5},
        'home': '/var/empty',
        'shell': '/usr/sbin/nologin',
      });
      expect(u.groups, [1, 2]);
      expect(u.groupId, 5);
      expect(u.smb, isTrue);
    });

    test('group id as int also parses', () {
      final u = NasUser.fromJson({'username': 'x', 'group': 42});
      expect(u.groupId, 42);
    });

    test('group parses', () {
      final g = NasGroup.fromJson({
        'id': 3,
        'gid': 2001,
        'name': 'media',
        'builtin': false,
        'smb': true,
        'users': [1001],
      });
      expect(g.users, [1001]);
    });
  });

  group('services, alerts, jobs', () {
    test('service', () {
      final s = NasService.fromJson(
          {'id': 1, 'service': 'cifs', 'enable': true, 'state': 'RUNNING'});
      expect(s.running, isTrue);
    });

    test('alert with date', () {
      final a = NasAlert.fromJson({
        'uuid': 'u1',
        'level': 'WARNING',
        'message': 'hi',
        'source': 'sys',
        'datetime': {r'$date': 1700000000000},
      });
      expect(a.datetime, isNotNull);
      expect(a.dismissed, isFalse);
    });

    test('alert without date', () {
      final a = NasAlert.fromJson({'uuid': 'u2'});
      expect(a.datetime, isNull);
    });

    test('job progress and states', () {
      final running = NasJob.fromJson({
        'id': 1,
        'method': 'pool.scrub',
        'state': 'RUNNING',
        'progress': {'percent': 55.5, 'description': 'busy'},
      });
      expect(running.running, isTrue);
      expect(running.progress, 55.5);
      expect(running.description, 'busy');
      final failed = NasJob.fromJson({'id': 2, 'state': 'FAILED'});
      expect(failed.failed, isTrue);
    });
  });

  group('RealtimeSample', () {
    test('parses websocket fields', () {
      final s = RealtimeSample.fromJson({
        'cpu': {'user': 10.0, 'system': 5.0},
        'memory': {
          'physical': {'total': 1000, 'used': 400}
        },
        'interfaces': [
          {'stats': {'received_bytes_rate': 100.0, 'sent_bytes_rate': 50.0}}
        ],
        'disks': [
          {'read_bytes': 10.0, 'write_bytes': 20.0}
        ],
      });
      expect(s.cpuUsage, 15.0);
      expect(s.memoryTotal, 1000);
      expect(s.networkRxBytesPerSec, 100.0);
      expect(s.diskWriteBytesPerSec, 20.0);
    });

    test('caps cpu at 100', () {
      final s = RealtimeSample.fromJson({'cpu': {'user': 80, 'system': 50}});
      expect(s.cpuUsage, 100);
    });

    test('empty payload', () {
      const s = RealtimeSample();
      expect(s.cpuUsage, 0);
    });
  });
}

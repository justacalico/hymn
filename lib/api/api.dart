/// Abstract surface for everything the app asks of TrueNAS.
///
/// [TrueNasClient] implements this over the real REST + websocket APIs; tests
/// substitute a fake without touching the network.
library;

import 'models.dart';

abstract class TrueNasApi {
  Future<String> healthCheck();

  Future<SystemInfo> getSystemInfo();
  Future<NasVersion> getVersion();
  Future<void> reboot();
  Future<void> shutdown();

  Future<List<NasAlert>> getAlerts();
  Future<void> dismissAlert(String uuid);

  Future<List<NasJob>> getJobs();

  Future<List<Pool>> getPools();
  Future<void> createPool({
    required String name,
    required String type,
    required List<String> disks,
    List<String> spareDisks,
  });
  Future<void> exportPool(int id, {bool delete});
  Future<void> scrubPool(int id);

  Future<List<Dataset>> getDatasets();
  Future<void> createDataset({
    required String name,
    String compression,
    String shareType,
    String comments,
    int? quota,
    bool readonly,
  });
  Future<void> updateDataset(String id,
      {String? comments, String? compression, int? quota});
  Future<void> deleteDataset(String id, {bool recursive});

  Future<List<Disk>> getDisks();
  Future<List<Disk>> getUnusedDisks();

  Future<List<SmbShare>> getSmbShares();
  Future<void> createSmbShare({
    required String path,
    required String name,
    String comment,
    bool enabled,
    bool readOnly,
    bool browsable,
    bool guestOk,
  });
  Future<void> deleteSmbShare(int id);

  Future<List<NfsShare>> getNfsShares();
  Future<void> createNfsShare({
    required String path,
    String comment,
    bool enabled,
    bool readOnly,
    List<String> networks,
    List<String> hosts,
  });
  Future<void> deleteNfsShare(int id);

  Future<List<Snapshot>> getSnapshots({String? dataset});
  Future<void> createSnapshot({
    required String dataset,
    required String name,
    bool recursive,
  });
  Future<void> deleteSnapshot(String id);
  Future<void> rollbackSnapshot(String id);

  Future<List<NasApp>> getApps();
  Future<List<AvailableApp>> getAvailableApps();
  Future<List<String>> getAppCategories();
  Future<String?> getAppsPool();
  Future<void> setAppsPool(String pool);
  Future<void> installApp({
    required String name,
    required String catalog,
    required String train,
    required String version,
    Map<String, dynamic> values,
  });
  Future<void> startApp(String id);
  Future<void> stopApp(String id);
  Future<void> deleteApp(String id, {bool removeImages});

  Future<List<NasUser>> getUsers();
  Future<int> createUser({
    required String username,
    required String fullName,
    required String password,
    String? email,
    bool smb,
    String home,
    String shell,
  });
  Future<void> updateUser(int id,
      {String? fullName,
      String? password,
      String? email,
      bool? smb,
      bool? locked});
  Future<void> deleteUser(int id, {bool deleteGroup});

  Future<List<NasGroup>> getGroups();
  Future<int> createGroup(String name, {bool smb});
  Future<void> deleteGroup(int id, {bool deleteUsers});

  Future<List<NasService>> getServices();
  Future<void> startService(String name);
  Future<void> stopService(String name);
  Future<void> restartService(String name);
  Future<void> setServiceEnabled(String name, bool enabled);

  Stream<RealtimeSample> realtimeStats();
}

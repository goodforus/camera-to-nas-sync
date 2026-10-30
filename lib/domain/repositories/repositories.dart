/// Domain repository interfaces (clean architecture boundary).
import '../../domain/entities/entities.dart';

abstract class NasConfigRepository {
  Future<List<NasConfig>> getAll();
  Future<NasConfig?> getById(String id);
  Future<String> insert(NasConfig config);
  Future<int> update(NasConfig config);
  Future<int> delete(String id);
  /// The single active (selected) NAS config, if any.
  Future<NasConfig?> getActive();
  Future<int> setActive(String? configId);
}

abstract class SyncRepository {
  Future<List<SyncItem>> getItems({SyncStatus? status});
  Future<String> insert(SyncItem item);
  Future<int> update(SyncItem item);
  Future<int> delete(String id);
  Future<int> markSynced(String id);
  Future<int> markFailed(String id, String error);
  Future<bool> exists(String localPath);
}

abstract class NetworkRangeRepository {
  Future<List<NetworkRange>> getAll();
  Future<String> insert(NetworkRange range);
  Future<int> update(NetworkRange range);
  Future<int> delete(String id);
}

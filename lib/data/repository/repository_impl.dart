/// Data-layer implementations backed by SQLite + Android Keystore.
import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart';
import '../../core/db/database.dart';
import '../../data/services/smb_service.dart';
import '../../domain/entities/entities.dart';
import '../../domain/repositories/repositories.dart';

class NasConfigRepositoryImpl implements NasConfigRepository {
  NasConfigRepositoryImpl(this._secureStorage);
  final SecureStorage _secureStorage;

  static const _pwPrefix = 'nas_pw_';

  @override
  Future<List<NasConfig>> getAll() async {
    final db = await AppDatabase.instance.db;
    final maps = await db.query('nas_configs', orderBy: 'updated_at DESC');
    return Future.wait(maps.map((m) async {
      final config = NasConfig.fromMap(m);
      final pw = await _secureStorage.read('$_pwPrefix${config.id}');
      return config.copyWith(password: pw);
    }));
  }

  @override
  Future<NasConfig?> getById(String id) async {
    final db = await AppDatabase.instance.db;
    final maps = await db.query('nas_configs', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    final config = NasConfig.fromMap(maps.first);
    final pw = await _secureStorage.read('$_pwPrefix${config.id}');
    return config.copyWith(password: pw);
  }

  @override
  Future<String> insert(NasConfig config) async {
    final db = await AppDatabase.instance.db;
    final id = config.id ?? const Uuid().v4();
    final now = DateTime.now().millisecondsSinceEpoch;
    final toStore = config.copyWith(
      id: id,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      password: null, // password not persisted in SQLite
    );
    await db.insert('nas_configs', toStore.toMap());
    if (config.password != null && config.password!.isNotEmpty) {
      await _secureStorage.write('$_pwPrefix$id', config.password!);
    }
    return id;
  }

  @override
  Future<int> update(NasConfig config) async {
    if (config.id == null) return 0;
    final db = await AppDatabase.instance.db;
    final toStore = config.copyWith(
      updatedAt: DateTime.now(),
      password: null,
    );
    final count = await db.update(
      'nas_configs',
      toStore.toMap(),
      where: 'id = ?',
      whereArgs: [config.id],
    );
    if (config.password != null) {
      if (config.password!.isNotEmpty) {
        await _secureStorage.write('$_pwPrefix${config.id}', config.password!);
      } else {
        await _secureStorage.delete('$_pwPrefix${config.id}');
      }
    }
    return count;
  }

  @override
  Future<int> delete(String id) async {
    await _secureStorage.delete('$_pwPrefix$id');
    final db = await AppDatabase.instance.db;
    return db.delete('nas_configs', where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<NasConfig?> getActive() async {
    final db = await AppDatabase.instance.db;
    // Active config = most recently updated one (simple single-active model).
    final maps = await db.query(
      'nas_configs',
      orderBy: 'updated_at DESC',
      limit: 1,
    );
    if (maps.isEmpty) return null;
    final config = NasConfig.fromMap(maps.first);
    final pw = await _secureStorage.read('$_pwPrefix${config.id}');
    return config.copyWith(password: pw);
  }

  @override
  Future<int> setActive(String? configId) async {
    // Simple model: touching updated_at marks active. No separate flag column.
    if (configId == null) return 0;
    final db = await AppDatabase.instance.db;
    return db.update(
      'nas_configs',
      {'updated_at': DateTime.now().millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: [configId],
    );
  }
}

class SyncRepositoryImpl implements SyncRepository {
  @override
  Future<List<SyncItem>> getItems({SyncStatus? status}) async {
    final db = await AppDatabase.instance.db;
    final maps = await db.query(
      'sync_items',
      where: status != null ? 'status = ?' : null,
      whereArgs: status != null ? [status.index] : null,
      orderBy: 'created_at DESC',
    );
    return maps.map(SyncItem.fromMap).toList();
  }

  @override
  Future<String> insert(SyncItem item) async {
    final db = await AppDatabase.instance.db;
    final id = const Uuid().v4();
    await db.insert('sync_items', item.copyWith(id: id).toMap());
    return id;
  }

  @override
  Future<int> update(SyncItem item) async {
    if (item.id == null) return 0;
    final db = await AppDatabase.instance.db;
    return db.update(
      'sync_items',
      item.toMap(),
      where: 'id = ?',
      whereArgs: [item.id],
    );
  }

  @override
  Future<int> delete(String id) async {
    final db = await AppDatabase.instance.db;
    return db.delete('sync_items', where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<int> markSynced(String id) async {
    final db = await AppDatabase.instance.db;
    return db.update(
      'sync_items',
      {'status': SyncStatus.synced.index, 'synced_at': DateTime.now().millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<int> markFailed(String id, String error) async {
    final db = await AppDatabase.instance.db;
    // Increment attempt_count safely via a read-modify-write.
    final current = await db.query(
      'sync_items',
      columns: ['attempt_count'],
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    final nextAttempt = (current.isNotEmpty
            ? (current.first['attempt_count'] as int?) ?? 0
            : 0) +
        1;
    return db.update(
      'sync_items',
      {
        'status': SyncStatus.failed.index,
        'error_message': error,
        'attempt_count': nextAttempt,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<bool> exists(String localPath) async {
    final db = await AppDatabase.instance.db;
    final maps = await db.query(
      'sync_items',
      where: 'local_path = ?',
      whereArgs: [localPath],
      limit: 1,
    );
    return maps.isNotEmpty;
  }
}

class NetworkRangeRepositoryImpl implements NetworkRangeRepository {
  @override
  Future<List<NetworkRange>> getAll() async {
    final db = await AppDatabase.instance.db;
    final maps = await db.query('network_ranges', orderBy: 'created_at ASC');
    return maps.map(NetworkRange.fromMap).toList();
  }

  @override
  Future<String> insert(NetworkRange range) async {
    final db = await AppDatabase.instance.db;
    final id = const Uuid().v4();
    await db.insert('network_ranges', range.copyWith(id: id).toMap());
    return id;
  }

  @override
  Future<int> update(NetworkRange range) async {
    if (range.id == null) return 0;
    final db = await AppDatabase.instance.db;
    return db.update('network_ranges', range.toMap(), where: 'id = ?', whereArgs: [range.id]);
  }

  @override
  Future<int> delete(String id) async {
    final db = await AppDatabase.instance.db;
    return db.delete('network_ranges', where: 'id = ?', whereArgs: [id]);
  }
}

/// Minimal UUID v4 generator (avoids adding a uuid package dependency).
class Uuid {
  const Uuid();
  String v4() {
    final r = Random.secure();
    final bytes = List<int>.generate(16, (_) => r.nextInt(256));
    bytes[6] = (bytes[6] & 0x0F) | 0x40; // version 4
    bytes[8] = (bytes[8] & 0x3F) | 0x80; // variant 10xx
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }
}

/// Android Keystore-backed secure storage via platform channel.
///
/// Method channel: com.pandasf.nas_sync/secure_storage
/// Methods: write(key,value), read(key), delete(key), containsKey(key)
class AndroidKeystoreSecureStorage implements SecureStorage {
  static const _channel = MethodChannel('com.pandasf.nas_sync/secure_storage');

  Future<T> _invoke<T>(Future<T?> Function() action, T onError) {
    try {
      final result = action();
      return result.then((v) => v ?? onError);
    } on MissingPluginException {
      // Headless / background worker may not have the channel registered.
      // Degrade gracefully rather than crashing.
      return Future.value(onError);
    } catch (_) {
      return Future.value(onError);
    }
  }

  @override
  Future<bool> write(String key, String value) async =>
      _invoke(() => _channel.invokeMethod<bool>('write', {'key': key, 'value': value}), false);

  @override
  Future<String?> read(String key) async =>
      _invoke(() => _channel.invokeMethod<String?>('read', {'key': key}), null);

  @override
  Future<bool> delete(String key) async =>
      _invoke(() => _channel.invokeMethod<bool>('delete', {'key': key}), false);

  @override
  Future<bool> containsKey(String key) async =>
      _invoke(() => _channel.invokeMethod<bool>('containsKey', {'key': key}), false);
}

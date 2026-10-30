/// Local SQLite database for sync state, NAS config metadata, and network ranges.
///
/// Passwords are NOT stored here. NasConfig.password lives only in memory and
/// in Android Keystore (via [SecureStorage]).
import 'dart:io';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();

  Database? _db;

  static const _version = 1;

  Future<Database> get db async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final dir = await getApplicationDocumentsDirectory();
    final path = join(dir.path, 'nas_sync.db');
    return openDatabase(
      path,
      version: _version,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE nas_configs (
        id TEXT PRIMARY KEY,
        host TEXT NOT NULL,
        port INTEGER NOT NULL DEFAULT 445,
        share TEXT NOT NULL,
        username TEXT NOT NULL,
        domain TEXT NOT NULL DEFAULT '',
        encryption_required INTEGER NOT NULL DEFAULT 1,
        signing_required INTEGER NOT NULL DEFAULT 1,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE sync_items (
        id TEXT PRIMARY KEY,
        local_path TEXT NOT NULL,
        remote_path TEXT NOT NULL,
        file_name TEXT NOT NULL,
        file_size INTEGER NOT NULL DEFAULT 0,
        captured_at INTEGER NOT NULL,
        status INTEGER NOT NULL DEFAULT 0,
        error_message TEXT,
        attempt_count INTEGER NOT NULL DEFAULT 0,
        synced_at INTEGER,
        created_at INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE network_ranges (
        id TEXT PRIMARY KEY,
        cidr TEXT NOT NULL,
        label TEXT NOT NULL DEFAULT '',
        created_at INTEGER NOT NULL
      )
    ''');
    await db.execute('CREATE INDEX idx_sync_items_status ON sync_items(status)');
    await db.execute('CREATE INDEX idx_sync_items_local_path ON sync_items(local_path)');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // No migrations yet; bump _version and add ALTER TABLE here when needed.
  }

  Future<void> close() async {
    if (_db != null) await _db!.close();
    _db = null;
  }
}

/// Abstract secure storage. On Android this is backed by Android Keystore.
abstract class SecureStorage {
  /// Store [value] under [key]. Returns true on success.
  Future<bool> write(String key, String value);
  /// Read value under [key]. Null if absent.
  Future<String?> read(String key);
  /// Delete value under [key]. Returns true if a value was removed.
  Future<bool> delete(String key);
  /// Check whether a value exists under [key].
  Future<bool> containsKey(String key);
}

/// In-memory (unencrypted) fallback used on non-Android platforms or while the
/// native Keystore bridge is unavailable. NOT for production password storage.
class MemorySecureStorage implements SecureStorage {
  final Map<String, String> _store = {};
  @override
  Future<bool> write(String key, String value) async {
    _store[key] = value;
    return true;
  }
  @override
  Future<String?> read(String key) async => _store[key];
  @override
  Future<bool> delete(String key) async => _store.remove(key) != null;
  @override
  Future<bool> containsKey(String key) async => _store.containsKey(key);
}

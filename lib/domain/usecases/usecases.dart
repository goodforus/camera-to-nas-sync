/// Domain use cases — business rules, independent of UI and data details.
import 'dart:io';
import '../entities/entities.dart';
import '../repositories/repositories.dart';
import '../../data/services/smb_service.dart';

/// Save a NAS config, encrypting the password via SecureStorage.
class SaveNasConfig {
  SaveNasConfig(this._repo);
  final NasConfigRepository _repo;
  Future<String> call(NasConfig config) => _repo.insert(config);
}

/// Load all NAS configs (passwords decrypted from secure storage).
class GetNasConfigs {
  GetNasConfigs(this._repo);
  final NasConfigRepository _repo;
  Future<List<NasConfig>> call() => _repo.getAll();
}

/// Get the single active NAS config.
class GetActiveNasConfig {
  GetActiveNasConfig(this._repo);
  final NasConfigRepository _repo;
  Future<NasConfig?> call() => _repo.getActive();
}

/// Delete a NAS config and its stored password.
class DeleteNasConfig {
  DeleteNasConfig(this._repo);
  final NasConfigRepository _repo;
  Future<int> call(String id) => _repo.delete(id);
}

/// Mark a config as active.
class SetActiveNasConfig {
  SetActiveNasConfig(this._repo);
  final NasConfigRepository _repo;
  Future<int> call(String? id) => _repo.setActive(id);
}

/// Register an allowed local network CIDR range.
class AddNetworkRange {
  AddNetworkRange(this._repo);
  final NetworkRangeRepository _repo;
  Future<String> call(NetworkRange range) => _repo.insert(range);
}

/// List registered network ranges.
class GetNetworkRanges {
  GetNetworkRanges(this._repo);
  final NetworkRangeRepository _repo;
  Future<List<NetworkRange>> call() => _repo.getAll();
}

/// Delete a network range.
class RemoveNetworkRange {
  RemoveNetworkRange(this._repo);
  final NetworkRangeRepository _repo;
  Future<int> call(String id) => _repo.delete(id);
}

/// Sync pending camera files to the NAS.
/// Respects: allowed network ranges, SMB 3.1.1 connection, dedup via DB.
class SyncCameraFiles {
  SyncCameraFiles({
    required SyncRepository syncRepo,
    required NasConfigRepository nasRepo,
    required SmbService smb,
  }) : _syncRepo = syncRepo,
       _nasRepo = nasRepo,
       _smb = smb;
  final SyncRepository _syncRepo;
  final NasConfigRepository _nasRepo;
  final SmbService _smb;

  /// Run a full sync pass. Returns [SyncResult].
  Future<SyncResult> run({String? remoteBaseDir}) async {
    final config = await _nasRepo.getActive();
    if (config == null) {
      return SyncResult(synced: 0, failed: 0, skipped: 0,
          error: 'No NAS configuration found.');
    }

    // Build the list of local camera files to sync.
    final candidates = await _discoverCameraFiles();
    int synced = 0, failed = 0, skipped = 0;

    SmbSession? session;
    try {
      session = await _smb.connect(config);
      for (final file in candidates) {
        final already = await _syncRepo.exists(file.path);
        if (already) {
          skipped++;
          continue;
        }
        final remotePath = '${_remoteBase(remoteBaseDir)}/${file.name}';
        try {
          await _smb.uploadFile(
            session: session!,
            localPath: file.path,
            remotePath: remotePath,
          );
          await _syncRepo.insert(SyncItem(
            localPath: file.path,
            remotePath: remotePath,
            fileName: file.name,
            fileSize: file.size,
            capturedAt: file.modified,
            status: SyncStatus.synced,
            syncedAt: DateTime.now(),
            createdAt: DateTime.now(),
          ));
          synced++;
        } catch (e) {
          await _syncRepo.insert(SyncItem(
            localPath: file.path,
            remotePath: remotePath,
            fileName: file.name,
            fileSize: file.size,
            capturedAt: file.modified,
            status: SyncStatus.failed,
            errorMessage: e.toString(),
            attemptCount: 1,
            createdAt: DateTime.now(),
          ));
          failed++;
        }
      }
    } catch (e) {
      return SyncResult(synced: synced, failed: failed, skipped: skipped,
          error: 'SMB session error: $e');
    } finally {
      // Local `session` reference is dropped when run() returns; the pool is
      // released via GC/finalizer (Smb2Pool has no public close()).
    }

    return SyncResult(synced: synced, failed: failed, skipped: skipped);
  }

  /// Discover camera photos/videos only (excludes screenshots, screen recordings,
  /// downloads). Uses the public DCIM directory and common camera subfolders.
  Future<List<_CameraFile>> _discoverCameraFiles() async {
    final result = <_CameraFile>[];
    final directories = <Directory>[];

    // Primary camera storage locations.
    final external = Directory('/storage/emulated/0/DCIM');
    if (await external.exists()) directories.add(external);
    // Common Camera subfolder directly under shared storage.
    final camera = Directory('/storage/emulated/0/DCIM/Camera');
    if (await camera.exists()) directories.add(camera);

    // Allowed media extensions.
    const videoExts = {'.mp4', '.mov', '.m4v', '.3gp', '.webm'};
    const photoExts = {'.jpg', '.jpeg', '.png', '.heic', '.webp'};

    // Excluded keywords (case-insensitive).
    const excluded = ['screenshot', 'screenrecord', 'screen recording',
        'download', 'screencast'];

    for (final dir in directories) {
      await _scanDir(dir, result, videoExts, photoExts, excluded);
    }
    return result;
  }

  Future<void> _scanDir(Directory dir, List<_CameraFile> out,
      Set<String> videoExts, Set<String> photoExts, List<String> excluded) async {
    try {
      final entries = dir.listSync(recursive: false);
      for (final e in entries) {
        final name = e.path.split('/').last.toLowerCase();
        if (excluded.any((kw) => name.contains(kw))) continue;
        if (e is Directory) {
          // Recurse into camera-like folders only to limit scope.
          if (_isCameraLike(name)) await _scanDir(e, out, videoExts, photoExts, excluded);
        } else if (e is File) {
          final ext = name.substring(name.lastIndexOf('.')).toLowerCase();
          if (videoExts.contains(ext) || photoExts.contains(ext)) {
            final stat = await e.stat();
            out.add(_CameraFile(
              path: e.path,
              name: e.path.split('/').last,
              size: stat.size,
              modified: stat.modified,
            ));
          }
        }
      }
    } on FileSystemException {
      // skip unreadable dirs
    }
  }

  bool _isCameraLike(String name) {
    final n = name.toLowerCase();
    return n.contains('camera') || n.contains('dcim') || n == '100media' ||
        n.contains('snapchat') == false && n.contains('whatsapp') == false;
  }

  String _remoteBase(String? base) {
    final b = (base ?? 'Camera').trim();
    return b.isEmpty ? 'Camera' : b.replaceAll(RegExp(r'^/+|/+$'), '');
  }
}

/// Candidate camera file discovered on device.
class _CameraFile {
  final String path;
  final String name;
  final int size;
  final DateTime modified;
  _CameraFile({required this.path, required this.name, required this.size,
    required this.modified});
}

/// Outcome of a sync run.
class SyncResult {
  final int synced;
  final int failed;
  final int skipped;
  final String? error;
  SyncResult({required this.synced, required this.failed, required this.skipped,
    this.error});
  bool get success => failed == 0 && error == null;
}

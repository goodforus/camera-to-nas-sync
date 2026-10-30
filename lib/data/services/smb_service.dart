/// SMB service wrapping dart_smb2.
///
/// Provides: connect/auth, share enumeration (auto-discovery), upload (streaming
/// write), connection test, and disconnect. All SMB operations target SMB 3.x
/// with SMB 3.1.1 preferred and encryption + signing required by default.
import 'dart:io';
import 'dart:typed_data';
import 'package:dart_smb2/dart_smb2.dart';
import 'package:nas_sync/domain/entities/entities.dart';

class SmbException implements Exception {
  final String message;
  final dynamic cause;
  SmbException(this.message, [this.cause]);
  @override
  String toString() => 'SmbException: $message${cause != null ? ' (cause: $cause)' : ''}';
}

/// Result of share auto-discovery.
class ShareDiscoveryResult {
  final bool success;
  final List<SmbShare> shares;
  final SmbException? error;
  ShareDiscoveryResult.success(this.shares)
      : success = true, error = null;
  ShareDiscoveryResult.failure(this.error)
      : success = false, shares = const [];
}

/// Connection handle for an active SMB session.
class SmbSession {
  final Smb2Pool pool;
  final NasConfig config;
  SmbSession({required this.pool, required this.config});
}

class SmbService {
  SmbService();
  SmbSession? _session;

  bool get isConnected => _session != null;

  /// Connect to the NAS and authenticate. Negotiates SMB 3.x, preferring 3.1.1,
  /// with encryption and signing required.
  Future<SmbSession> connect(NasConfig config) async {
    if (_session != null) {
      await disconnect();
    }
    try {
      final pool = await Smb2Pool.connect(
        host: config.host,
        share: config.share,
        user: config.username,
        password: config.password ?? '',
        domain: config.domain.isEmpty ? null : config.domain,
        seal: config.encryptionRequired,
        signing: config.signingRequired,
        version: Smb2Version.v311, // SMB 3.1.1 preferred
        workers: 2,
        timeout: const Duration(seconds: 15),
      );
      _session = SmbSession(pool: pool, config: config);
      return _session!;
    } on Smb2Exception catch (e) {
      throw SmbException('SMB connection failed: ${_friendlyError(e)}', e);
    } catch (e) {
      throw SmbException('SMB connection failed: $e', e);
    }
  }

  /// Test connectivity + auth without keeping a session open.
  Future<bool> testConnection(NasConfig config) async {
    try {
      await connect(config);
      return true;
    } catch (_) {
      return false;
    } finally {
      await disconnect();
    }
  }

  /// Enumerate accessible SMB shares on the host (auto-discovery).
  /// Uses Smb2Pool.listSharesOn (static, no open share required).
  /// Note: this dart_smb2 version does not expose a port parameter for share
  /// enumeration; port 445 is used.
  Future<ShareDiscoveryResult> listShares({
    required String host,
    String? username,
    String? password,
    String? domain,
  }) async {
    try {
      final shares = await Smb2Pool.listSharesOn(
        host: host,
        user: username,
        password: password ?? '',
        domain: domain,
        timeout: const Duration(seconds: 15),
      );
      final result = shares
          .map((s) => SmbShare(name: s.name, remark: s.remark))
          .toList();
      return ShareDiscoveryResult.success(result);
    } on Smb2Exception catch (e) {
      return ShareDiscoveryResult.failure(
          SmbException('Share discovery failed: ${_friendlyError(e)}', e));
    } catch (e) {
      return ShareDiscoveryResult.failure(SmbException('Share discovery failed: $e', e));
    }
  }

  /// Upload a local file to the remote share path using streaming write.
  /// [remotePath] is relative to the share root (e.g. "Camera/IMG_0001.jpg").
  Future<void> uploadFile({
    required SmbSession session,
    required String localPath,
    required String remotePath,
    void Function(int sent, int total)? onProgress,
  }) async {
    if (!_isValidRemotePath(remotePath)) {
      throw SmbException('Invalid remote path: $remotePath');
    }
    final file = File(localPath);
    if (!await file.exists()) {
      throw SmbException('Local file not found: $localPath');
    }
    final size = await file.length();
    try {
      final stream = file.openRead().map((chunk) => Uint8List.fromList(chunk));
      await session.pool.streamWrite(
        remotePath,
        stream,
      );
      if (onProgress != null) onProgress(size, size);
    } on Smb2Exception catch (e) {
      throw SmbException('Upload failed: ${_friendlyError(e)}', e);
    } catch (e) {
      throw SmbException('Upload failed: $e', e);
    }
  }

  /// Disconnect and drop the session reference (pool is released via GC/finalizer).
  Future<void> disconnect() async {
    _session = null;
  }

  bool _isValidRemotePath(String p) {
    return p.isNotEmpty &&
        !p.contains('..') &&
        !p.startsWith('/') &&
        !p.contains('\0');
  }

  String _friendlyError(Smb2Exception e) {
    final msg = e.toString();
    final lower = msg.toLowerCase();
    if (lower.contains('auth') ||
        lower.contains('logon') ||
        lower.contains('status_access_denied') ||
        lower.contains('nt_status_access_denied')) {
      return '인증 실패: 사용자 ID 또는 비밀번호를 확인하세요.';
    }
    if (lower.contains('connect') ||
        lower.contains('network') ||
        lower.contains('timeout') ||
        lower.contains('unreachable') ||
        lower.contains('refused')) {
      return '네트워크 오류: NAS에 도달할 수 없습니다. 주소와 네트워크를 확인하세요.';
    }
    if (lower.contains('not found') ||
        lower.contains('object_name_not_found') ||
        lower.contains('share')) {
      return '공유 폴더를 찾을 수 없습니다: 공유 이름을 확인하세요.';
    }
    return msg;
  }
}

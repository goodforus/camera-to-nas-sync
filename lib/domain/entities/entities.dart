/// Domain entity: NAS connection configuration.
///
/// Password is never stored in plaintext in this object after loading from
/// secure storage; the [password] field holds the decrypted value only while
/// the object lives in memory.
class NasConfig {
  final String? id;
  final String host;
  final int port;
  final String share;
  final String username;
  /// Plaintext password — held in memory only. Never persist this field.
  final String? password;
  final String domain;
  final bool encryptionRequired;
  final bool signingRequired;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  NasConfig({
    this.id,
    required this.host,
    this.port = 445,
    required this.share,
    required this.username,
    this.password,
    this.domain = '',
    this.encryptionRequired = true,
    this.signingRequired = true,
    this.createdAt,
    this.updatedAt,
  });

  NasConfig copyWith({
    String? id,
    String? host,
    int? port,
    String? share,
    String? username,
    String? password,
    String? domain,
    bool? encryptionRequired,
    bool? signingRequired,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return NasConfig(
      id: id ?? this.id,
      host: host ?? this.host,
      port: port ?? this.port,
      share: share ?? this.share,
      username: username ?? this.username,
      password: password ?? this.password,
      domain: domain ?? this.domain,
      encryptionRequired: encryptionRequired ?? this.encryptionRequired,
      signingRequired: signingRequired ?? this.signingRequired,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'host': host,
      'port': port,
      'share': share,
      'username': username,
      'domain': domain,
      'encryption_required': encryptionRequired ? 1 : 0,
      'signing_required': signingRequired ? 1 : 0,
      'created_at': createdAt?.millisecondsSinceEpoch,
      'updated_at': updatedAt?.millisecondsSinceEpoch,
      // password intentionally excluded — stored via Android Keystore only.
    };
  }

  factory NasConfig.fromMap(Map<String, dynamic> map) {
    return NasConfig(
      id: map['id']?.toString(),
      host: map['host'] ?? '',
      port: (map['port'] ?? 445) as int,
      share: map['share'] ?? '',
      username: map['username'] ?? '',
      domain: map['domain'] ?? '',
      encryptionRequired: (map['encryption_required'] ?? 1) == 1,
      signingRequired: (map['signing_required'] ?? 1) == 1,
      createdAt: map['created_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int)
          : null,
      updatedAt: map['updated_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int)
          : null,
    );
  }

  @override
  String toString() {
    return 'NasConfig(id: $id, host: $host, port: $port, share: $share, username: $username)';
  }
}

/// Domain entity: a discovered SMB share.
class SmbShare {
  final String name;
  final String? remark;

  SmbShare({required this.name, this.remark});

  @override
  String toString() => 'SmbShare(name: $name, remark: $remark)';
}

/// Domain entity: a file queued for / already synced to NAS.
class SyncItem {
  final String? id;
  final String localPath;
  final String remotePath;
  final String fileName;
  final int fileSize;
  final DateTime capturedAt;
  final SyncStatus status;
  final String? errorMessage;
  final int attemptCount;
  final DateTime? syncedAt;
  final DateTime createdAt;

  SyncItem({
    this.id,
    required this.localPath,
    required this.remotePath,
    required this.fileName,
    required this.fileSize,
    required this.capturedAt,
    this.status = SyncStatus.pending,
    this.errorMessage,
    this.attemptCount = 0,
    this.syncedAt,
    required this.createdAt,
  });

  SyncItem copyWith({
    String? id,
    String? localPath,
    String? remotePath,
    String? fileName,
    int? fileSize,
    DateTime? capturedAt,
    SyncStatus? status,
    String? errorMessage,
    int? attemptCount,
    DateTime? syncedAt,
    DateTime? createdAt,
  }) {
    return SyncItem(
      id: id ?? this.id,
      localPath: localPath ?? this.localPath,
      remotePath: remotePath ?? this.remotePath,
      fileName: fileName ?? this.fileName,
      fileSize: fileSize ?? this.fileSize,
      capturedAt: capturedAt ?? this.capturedAt,
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
      attemptCount: attemptCount ?? this.attemptCount,
      syncedAt: syncedAt ?? this.syncedAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'local_path': localPath,
      'remote_path': remotePath,
      'file_name': fileName,
      'file_size': fileSize,
      'captured_at': capturedAt.millisecondsSinceEpoch,
      'status': status.index,
      'error_message': errorMessage,
      'attempt_count': attemptCount,
      'synced_at': syncedAt?.millisecondsSinceEpoch,
      'created_at': createdAt.millisecondsSinceEpoch,
    };
  }

  factory SyncItem.fromMap(Map<String, dynamic> map) {
    return SyncItem(
      id: map['id']?.toString(),
      localPath: map['local_path'] ?? '',
      remotePath: map['remote_path'] ?? '',
      fileName: map['file_name'] ?? '',
      fileSize: (map['file_size'] ?? 0) as int,
      capturedAt: DateTime.fromMillisecondsSinceEpoch(map['captured_at'] as int),
      status: SyncStatus.values[map['status'] ?? 0],
      errorMessage: map['error_message'],
      attemptCount: (map['attempt_count'] ?? 0) as int,
      syncedAt: map['synced_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['synced_at'] as int)
          : null,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
    );
  }
}

enum SyncStatus {
  pending,
  uploading,
  synced,
  failed,
  skipped,
}

/// Domain entity: an allowed local network CIDR range.
class NetworkRange {
  final String? id;
  final String cidr; // e.g. "192.168.11.0/24"
  final String label;
  final DateTime createdAt;

  NetworkRange({
    this.id,
    required this.cidr,
    this.label = '',
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'cidr': cidr,
      'label': label,
      'created_at': createdAt.millisecondsSinceEpoch,
    };
  }

  NetworkRange copyWith({
    String? id,
    String? cidr,
    String? label,
    DateTime? createdAt,
  }) {
    return NetworkRange(
      id: id ?? this.id,
      cidr: cidr ?? this.cidr,
      label: label ?? this.label,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory NetworkRange.fromMap(Map<String, dynamic> map) {
    return NetworkRange(
      id: map['id']?.toString(),
      cidr: map['cidr'] ?? '',
      label: map['label'] ?? '',
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
    );
  }
}

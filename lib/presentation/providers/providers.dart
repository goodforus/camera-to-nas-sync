/// State providers using ChangeNotifier.
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/db/database.dart';
import '../../core/network/cidr_checker.dart';
import '../../data/repository/repository_impl.dart';
import '../../data/services/smb_service.dart';
import '../../domain/entities/entities.dart';
import '../../domain/repositories/repositories.dart';
import '../../domain/usecases/usecases.dart';

class NasConfigProvider extends ChangeNotifier {
  NasConfigProvider(this._repo);
  final NasConfigRepository _repo;

  List<NasConfig> _configs = [];
  NasConfig? _active;
  bool _loading = false;
  String? _error;

  List<NasConfig> get configs => _configs;
  NasConfig? get active => _active;
  bool get loading => _loading;
  String? get error => _error;

  Future<void> load() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _configs = await _repo.getAll();
      _active = await _repo.getActive();
    } catch (e) {
      _error = e.toString();
    }
    _loading = false;
    notifyListeners();
  }

  Future<bool> save(NasConfig config) async {
    _loading = true;
    notifyListeners();
    try {
      await _repo.insert(config);
      await load();
      return true;
    } catch (e) {
      _error = e.toString();
      _loading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> setActive(String id) async {
    try {
      await _repo.setActive(id);
      await load();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> delete(String id) async {
    try {
      await _repo.delete(id);
      await load();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }
}

class NetworkRangeProvider extends ChangeNotifier {
  NetworkRangeProvider(this._repo);
  final NetworkRangeRepository _repo;

  List<NetworkRange> _ranges = [];
  bool _loading = false;
  String? _error;

  List<NetworkRange> get ranges => _ranges;
  bool get loading => _loading;
  String? get error => _error;

  Future<void> load() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _ranges = await _repo.getAll();
    } catch (e) {
      _error = e.toString();
    }
    _loading = false;
    notifyListeners();
  }

  Future<bool> add(String cidr, {String label = ''}) async {
    if (!NetworkRangeChecker.isValidCidr(cidr)) {
      _error = '유효하지 않은 CIDR 형식입니다 (예: 192.168.11.0/24).';
      notifyListeners();
      return false;
    }
    try {
      await _repo.insert(NetworkRange(
        cidr: cidr,
        label: label,
        createdAt: DateTime.now(),
      ));
      await load();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> remove(String id) async {
    try {
      await _repo.delete(id);
      await load();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }
}

class SyncProvider extends ChangeNotifier {
  SyncProvider(this._syncRepo, this._nasRepo, this._smb);

  final SyncRepository _syncRepo;
  final NasConfigRepository _nasRepo;
  final SmbService _smb;

  List<SyncItem> _items = [];
  bool _syncing = false;
  SyncResult? _lastResult;
  String? _error;

  List<SyncItem> get items => _items;
  bool get syncing => _syncing;
  SyncResult? get lastResult => _lastResult;
  String? get error => _error;

  Future<void> loadItems() async {
    try {
      _items = await _syncRepo.getItems();
    } catch (e) {
      _error = e.toString();
    }
    notifyListeners();
  }

  Future<SyncResult?> runSync({String? remoteBaseDir}) async {
    _syncing = true;
    _error = null;
    _lastResult = null;
    notifyListeners();
    try {
      final result = await SyncCameraFiles(
        syncRepo: _syncRepo,
        nasRepo: _nasRepo,
        smb: _smb,
      ).run(remoteBaseDir: remoteBaseDir);
      _lastResult = result;
      _error = result.error;
      await loadItems();
      return result;
    } catch (e) {
      _error = e.toString();
      return null;
    } finally {
      _syncing = false;
      notifyListeners();
    }
  }
}

/// Checks whether the device is currently on an allowed local network (CIDR).
/// Returns (allowed, reason).
class NetworkGuard {
  NetworkGuard();
  final _connectivity = Connectivity();

  /// Check current network interfaces against registered ranges.
  Future<(bool allowed, String reason, List<String> ips)> check(
      List<NetworkRange> ranges) async {
    if (ranges.isEmpty) {
      return (false, '등록된 로컬 네트워크 대역이 없습니다. 대역을 등록해주세요.', <String>[]);
    }

    // Determine connection type — reject mobile data.
    final connectivityResult = await _connectivity.checkConnectivity();
    final isMobile = connectivityResult.contains(ConnectivityResult.mobile);
    if (isMobile && !connectivityResult.contains(ConnectivityResult.wifi)) {
      return (false, '모바일 데이터에서는 동기화할 수 없습니다.', <String>[]);
    }

    final ips = await WifiIpExtractor.candidateIpv4Addresses();
    if (ips.isEmpty) {
      return (false, 'Wi-Fi 인터페이스 IPv4 주소를 찾을 수 없습니다.', <String>[]);
    }

    final checker = NetworkRangeChecker.instance;
    for (final ip in ips) {
      if (checker.ipAllowed(ip, ranges)) {
        return (true, '허용된 네트워크 대역입니다 ($ip).', ips);
      }
    }

    return (false,
        '현재 IP(${ips.join(', ')})는 등록된 로컬 네트워크 대역에 속하지 않습니다.', ips);
  }

  /// Verify NAS is actually reachable by attempting a connection + share probe.
  Future<(bool ok, String message)> verifyNas(NasConfig config) async {
    final smb = SmbService();
    try {
      final ok = await smb.testConnection(config);
      return (ok, ok ? 'NAS에 연결되었습니다.' : 'NAS 연결에 실패했습니다.');
    } catch (e) {
      return (false, 'NAS 연결 오류: $e');
    }
  }
}

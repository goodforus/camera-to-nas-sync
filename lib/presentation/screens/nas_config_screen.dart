import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/services/smb_service.dart';
import '../../domain/entities/entities.dart';
import '../providers/providers.dart';

class NasConfigScreen extends StatefulWidget {
  const NasConfigScreen({super.key});

  @override
  State<NasConfigScreen> createState() => _NasConfigScreenState();
}

class _NasConfigScreenState extends State<NasConfigScreen> {
  final _formKey = GlobalKey<FormState>();
  final _hostCtrl = TextEditingController();
  final _shareCtrl = TextEditingController();
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _domainCtrl = TextEditingController();
  int _port = 445;
  bool _encryption = true;
  bool _signing = true;
  bool _saving = false;
  String? _message;
  bool _messageError = false;
  bool _discovering = false;
  List<String> _shares = [];

  @override
  void dispose() {
    _hostCtrl.dispose();
    _shareCtrl.dispose();
    _userCtrl.dispose();
    _passCtrl.dispose();
    _domainCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<NasConfigProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('NAS 연결 설정')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _hostCtrl,
              decoration: const InputDecoration(
                labelText: 'NAS 주소 (IP 또는 호스트)',
                hintText: '예: 192.168.11.50',
                border: OutlineInputBorder(),
              ),
              validator: (v) => (v == null || v.isEmpty) ? '주소를 입력하세요' : null,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _shareCtrl,
                    decoration: const InputDecoration(
                      labelText: 'SMB 공유 폴더',
                      hintText: '예: backup',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => (v == null || v.isEmpty) ? '공유 폴더를 입력하세요' : null,
                  ),
                ),
                const SizedBox(width: 8),
                if (_discovering)
                  const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                else
                  OutlinedButton.icon(
                    onPressed: _hostCtrl.text.isEmpty ? null : _discoverShares,
                    icon: const Icon(Icons.search),
                    label: const Text('검색'),
                  ),
              ],
            ),
            if (_shares.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: _shares
                    .map((s) => ChoiceChip(
                          label: Text(s),
                          selected: _shareCtrl.text == s,
                          onSelected: (_) => setState(() => _shareCtrl.text = s),
                        ))
                    .toList(),
              ),
            ],
            const SizedBox(height: 12),
            TextFormField(
              controller: _userCtrl,
              decoration: const InputDecoration(
                labelText: '사용자 ID',
                hintText: '예: admin',
                border: OutlineInputBorder(),
              ),
              validator: (v) => (v == null || v.isEmpty) ? '사용자 ID를 입력하세요' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _passCtrl,
              decoration: const InputDecoration(
                labelText: '비밀번호',
                hintText: '••••••••',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
              validator: (v) => (v == null || v.isEmpty) ? '비밀번호를 입력하세요' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _domainCtrl,
              decoration: const InputDecoration(
                labelText: '도메인/워크그룹 (선택)',
                hintText: '예: WORKGROUP',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: _port.toString(),
                    decoration: const InputDecoration(
                      labelText: '포트',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (v) => _port = int.tryParse(v) ?? 445,
                  ),
                ),
                const SizedBox(width: 16),
                const Text('포트'),
              ],
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              title: const Text('SMB 3.x 암호화 필요'),
              subtitle: const Text('SMB 3.1.1 우선 협상'),
              value: _encryption,
              onChanged: (v) => setState(() => _encryption = v),
            ),
            SwitchListTile(
              title: const Text('메시지 서명 필요'),
              value: _signing,
              onChanged: (v) => setState(() => _signing = v),
            ),
            const SizedBox(height: 16),
            if (_message != null)
              Container(
                padding: const EdgeInsets.all(12),
                color: _messageError ? Colors.red.shade50 : Colors.green.shade50,
                child: Text(_message!,
                    style: TextStyle(color: _messageError ? Colors.red.shade900 : Colors.green.shade900)),
              ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _saving ? null : () => _saveConfig(context),
                    icon: const Icon(Icons.save),
                    label: const Text('설정 저장'),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: _saving ? null : () => _testConnection(context),
                  icon: const Icon(Icons.network_check),
                  label: const Text('연결 테스트'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text('등록된 NAS 구성', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (provider.configs.isEmpty)
              const Text('등록된 구성이 없습니다.')
            else
              ...provider.configs.map((c) => ListTile(
                    leading: const Icon(Icons.storage),
                    title: Text('${c.host}:${c.port}'),
                    subtitle: Text('공유: ${c.share} / 사용자: ${c.username}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.check_circle),
                          color: provider.active?.id == c.id
                              ? Colors.green
                              : null,
                          onPressed: () async {
                            await provider.setActive(c.id!);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('활성 NAS로 설정됨')),
                            );
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () async {
                            await provider.delete(c.id!);
                          },
                        ),
                      ],
                    ),
                  )),
          ],
        ),
      ),
    );
  }

  Future<void> _discoverShares() async {
    setState(() {
      _discovering = true;
      _message = null;
      _shares = [];
    });
    try {
      // Use a temporary unauthenticated share discovery; many NAS allow
      // anonymous share enumeration. Falls back gracefully.
      final smb = SmbService();
      final result = await smb.listShares(
        host: _hostCtrl.text.trim(),
        username: _userCtrl.text.trim().isEmpty ? null : _userCtrl.text.trim(),
        password: _passCtrl.text,
        domain: _domainCtrl.text.trim().isEmpty ? null : _domainCtrl.text.trim(),
      );
      if (result.success) {
        setState(() => _shares = result.shares
            .whereType<SmbShare>()
            .map((s) => s.name)
            .toList());
        if (_shares.isNotEmpty) {
          setState(() => _message = '${_shares.length}개의 공유 폴더를 발견했습니다.');
          _messageError = false;
        } else {
          setState(() {
            _message = '검색된 공유 폴더가 없습니다. 직접 입력해주세요.';
            _messageError = true;
          });
        }
      } else {
        setState(() {
          _message = '공유 검색 실패: ${result.error}';
          _messageError = true;
        });
      }
    } catch (e) {
      setState(() {
        _message = '공유 검색 오류: $e';
        _messageError = true;
      });
    } finally {
      setState(() => _discovering = false);
    }
  }

  Future<void> _saveConfig(BuildContext context) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _message = null;
    });
    try {
      final config = NasConfig(
        host: _hostCtrl.text.trim(),
        port: _port,
        share: _shareCtrl.text.trim(),
        username: _userCtrl.text.trim(),
        password: _passCtrl.text,
        domain: _domainCtrl.text.trim(),
        encryptionRequired: _encryption,
        signingRequired: _signing,
      );
      await context.read<NasConfigProvider>().save(config);
      setState(() {
        _message = 'NAS 구성이 저장되었습니다 (비밀번호는 안전 저장소에 보관).';
        _messageError = false;
        _saving = false;
      });
    } catch (e) {
      setState(() {
        _message = '저장 실패: $e';
        _messageError = true;
        _saving = false;
      });
    }
  }

  Future<void> _testConnection(BuildContext context) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _message = null;
    });
    try {
      final config = NasConfig(
        host: _hostCtrl.text.trim(),
        port: _port,
        share: _shareCtrl.text.trim(),
        username: _userCtrl.text.trim(),
        password: _passCtrl.text,
        domain: _domainCtrl.text.trim(),
        encryptionRequired: _encryption,
        signingRequired: _signing,
      );
      final smb = SmbService();
      final ok = await smb.testConnection(config);
      setState(() {
        _message = ok ? 'NAS 연결 성공!' : 'NAS 연결 실패 (인증/주소 확인).';
        _messageError = !ok;
        _saving = false;
      });
      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('NAS 연결 테스트 성공')),
        );
      }
    } catch (e) {
      setState(() {
        _message = '연결 테스트 오류: $e';
        _messageError = true;
        _saving = false;
      });
    }
  }
}

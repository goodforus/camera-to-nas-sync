import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/providers.dart';

class NetworkRangeScreen extends StatefulWidget {
  const NetworkRangeScreen({super.key});

  @override
  State<NetworkRangeScreen> createState() => _NetworkRangeScreenState();
}

class _NetworkRangeScreenState extends State<NetworkRangeScreen> {
  final _cidrCtrl = TextEditingController();
  final _labelCtrl = TextEditingController();
  String? _message;
  bool _messageError = false;

  @override
  void dispose() {
    _cidrCtrl.dispose();
    _labelCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<NetworkRangeProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('허용 네트워크 대역 (CIDR)')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '동기화를 허용할 로컬 네트워크 IP 대역(CIDR)을 등록하세요. '
                  'SSID가 아닌 실제 IP 대역 기준으로 판단합니다.',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextFormField(
                        controller: _cidrCtrl,
                        decoration: const InputDecoration(
                          labelText: 'CIDR (예: 192.168.11.0/24)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: _labelCtrl,
                        decoration: const InputDecoration(
                          labelText: '라벨 (선택)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () => _addRange(context),
                      child: const Text('추가'),
                    ),
                  ],
                ),
                if (_message != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      _message!,
                      style: TextStyle(
                        color: _messageError ? Colors.red.shade700 : Colors.green.shade700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                const Text('등록된 대역',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 8),
                const Text(
                  '모바일 데이터/VPN 인터페이스는 자동으로 제외됩니다. IPv4만 검증됩니다.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
          Expanded(
            child: provider.ranges.isEmpty
                ? const Center(child: Text('등록된 네트워크 대역이 없습니다.'))
                : ListView.builder(
                    itemCount: provider.ranges.length,
                    itemBuilder: (context, i) {
                      final r = provider.ranges[i];
                      return Dismissible(
                        key: Key(r.id!),
                        background: Container(color: Colors.red),
                        onDismissed: (_) => provider.remove(r.id!),
                        child: ListTile(
                          leading: const Icon(Icons.wifi, color: Colors.blue),
                          title: Text(r.cidr),
                          subtitle: Text(r.label.isEmpty ? '(라벨 없음)' : r.label),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => provider.remove(r.id!),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _addRange(BuildContext context) async {
    final cidr = _cidrCtrl.text.trim();
    if (cidr.isEmpty) {
      setState(() {
        _message = 'CIDR을 입력하세요.';
        _messageError = true;
      });
      return;
    }
    final ok = await context.read<NetworkRangeProvider>().add(
          cidr,
          label: _labelCtrl.text.trim(),
        );
    if (ok) {
      _cidrCtrl.clear();
      _labelCtrl.clear();
      setState(() {
        _message = '네트워크 대역이 등록되었습니다.';
        _messageError = false;
      });
    }
  }
}

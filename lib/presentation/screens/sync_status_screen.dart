import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../domain/entities/entities.dart';
import '../../domain/usecases/usecases.dart';
import '../providers/providers.dart';

class SyncStatusScreen extends StatefulWidget {
  const SyncStatusScreen({super.key});

  @override
  State<SyncStatusScreen> createState() => _SyncStatusScreenState();
}

class _SyncStatusScreenState extends State<SyncStatusScreen> {
  String _remoteBase = 'Camera';

  @override
  Widget build(BuildContext context) {
    final sync = context.watch<SyncProvider>();
    final nas = context.watch<NasConfigProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('동기화 상태')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '활성 NAS: ${nas.active != null ? '${nas.active!.host}:${nas.active!.port} / ${nas.active!.share}' : '설정 안 됨'}',
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        initialValue: _remoteBase,
                        decoration: const InputDecoration(
                          labelText: '원격 저장 폴더 (공유 내)',
                          hintText: '예: Camera/2026',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (v) => _remoteBase = v,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: sync.syncing ? null : () => sync.runSync(remoteBaseDir: _remoteBase),
                    icon: sync.syncing
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.cloud_upload),
                    label: Text(sync.syncing ? '동기화 중...' : '지금 카메라 파일 동기화'),
                  ),
                ),
                const SizedBox(height: 8),
                if (sync.lastResult != null)
                  _ResultChip(result: sync.lastResult!),
                if (sync.error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text('오류: ${sync.error}',
                        style: const TextStyle(color: Colors.red, fontSize: 13)),
                  ),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: sync.items.isEmpty
                ? const Center(child: Text('동기화 이력이 없습니다.'))
                : ListView.builder(
                    itemCount: sync.items.length,
                    itemBuilder: (context, i) {
                      final item = sync.items[i];
                      return ListTile(
                        leading: Icon(
                          item.status == SyncStatus.synced
                              ? Icons.check_circle
                              : item.status == SyncStatus.failed
                                  ? Icons.error
                                  : Icons.pending,
                          color: item.status == SyncStatus.synced
                              ? Colors.green
                              : item.status == SyncStatus.failed
                                  ? Colors.red
                                  : Colors.amber,
                        ),
                        title: Text(item.fileName),
                        subtitle: Text(
                          '${item.localPath} → ${item.remotePath} '
                          '(${item.fileSize} 바이트)',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: Text(
                          item.status.name.toUpperCase(),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: item.status == SyncStatus.synced
                                ? Colors.green
                                : item.status == SyncStatus.failed
                                    ? Colors.red
                                    : Colors.grey,
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
}

class _ResultChip extends StatelessWidget {
  const _ResultChip({required this.result});
  final SyncResult result;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      color: result.success ? Colors.green.shade50 : Colors.amber.shade50,
      child: Row(
        children: [
          Expanded(
            child: Text(
              '완료: ${result.synced}건, 실패: ${result.failed}건, 건너뜀: ${result.skipped}건',
              style: TextStyle(
                color: result.success ? Colors.green.shade900 : Colors.amber.shade900,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          if (result.error != null)
            Expanded(child: Text(result.error!,
                style: const TextStyle(color: Colors.red, fontSize: 12))),
        ],
      ),
    );
  }
}

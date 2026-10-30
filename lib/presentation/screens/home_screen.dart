import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/providers.dart';
import 'nas_config_screen.dart';
import 'network_range_screen.dart';
import 'sync_status_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('NAS Camera Sync'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.settings), text: 'NAS 설정'),
              Tab(icon: Icon(Icons.wifi), text: '네트워크 대역'),
              Tab(icon: Icon(Icons.sync), text: '동기화'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            NasConfigScreen(),
            NetworkRangeScreen(),
            SyncStatusScreen(),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            final sync = context.read<SyncProvider>();
            sync.runSync();
          },
          child: const Icon(Icons.cloud_upload),
          tooltip: '지금 동기화',
        ),
      ),
    );
  }
}

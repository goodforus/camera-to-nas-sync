import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/db/database.dart';
import 'data/repository/repository_impl.dart';
import 'data/services/smb_service.dart';
import 'domain/entities/entities.dart';
import 'domain/usecases/usecases.dart';
import 'presentation/providers/providers.dart';
import 'presentation/screens/home_screen.dart';
import 'presentation/screens/nas_config_screen.dart';
import 'presentation/screens/network_range_screen.dart';
import 'presentation/screens/sync_status_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(const NasSyncApp());
}

class NasSyncApp extends StatelessWidget {
  const NasSyncApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NAS Camera Sync',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.blue),
      home: const AppRoot(),
    );
  }
}

class AppRoot extends StatefulWidget {
  const AppRoot({super.key});

  @override
  State<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<AppRoot> {
  late final NasConfigProvider _nasProvider;
  late final NetworkRangeProvider _rangeProvider;
  late final SyncProvider _syncProvider;

  @override
  void initState() {
    super.initState();
    // Providers are created synchronously so they are always initialized
    // after initState (avoids late-final errors if the widget unmounts early).
    final secureStorage = AndroidKeystoreSecureStorage();
    final nasRepo = NasConfigRepositoryImpl(secureStorage);
    final syncRepo = SyncRepositoryImpl();
    final rangeRepo = NetworkRangeRepositoryImpl();
    final smb = SmbService();
    _nasProvider = NasConfigProvider(nasRepo);
    _rangeProvider = NetworkRangeProvider(rangeRepo);
    _syncProvider = SyncProvider(syncRepo, nasRepo, smb);

    // Load data asynchronously; UI renders providers immediately.
    _nasProvider.load();
    _rangeProvider.load();
    _syncProvider.loadItems();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: _nasProvider),
        ChangeNotifierProvider.value(value: _rangeProvider),
        ChangeNotifierProvider.value(value: _syncProvider),
      ],
      child: const HomeScreen(),
    );
  }

  @override
  void dispose() {
    _nasProvider.dispose();
    _rangeProvider.dispose();
    _syncProvider.dispose();
    super.dispose();
  }
}

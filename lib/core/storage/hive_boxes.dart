import 'package:hive_flutter/hive_flutter.dart';

import 'models/calc_history_entry.dart';
import 'models/vault_file.dart';
import 'models/vault_folder.dart';

/// Central place for Hive box names and initialization. Vault file content
/// itself is never stored in Hive — only metadata. Actual bytes live as
/// AES-256-GCM encrypted files in app-private storage (see FileManager).
class HiveBoxes {
  HiveBoxes._();

  static const String vaultFiles = 'vault_files';
  static const String vaultFolders = 'vault_folders';
  static const String calcHistory = 'calc_history';
  static const String settings = 'settings';

  static Future<void> init() async {
    await Hive.initFlutter();

    Hive.registerAdapter(VaultFileAdapter());
    Hive.registerAdapter(VaultFolderAdapter());
    Hive.registerAdapter(CalcHistoryEntryAdapter());

    await Hive.openBox<VaultFile>(vaultFiles);
    await Hive.openBox<VaultFolder>(vaultFolders);
    await Hive.openBox<CalcHistoryEntry>(calcHistory);
    await Hive.openBox(settings); // dynamic box for primitive settings values
  }

  static Box<VaultFile> get files => Hive.box<VaultFile>(vaultFiles);
  static Box<VaultFolder> get folders => Hive.box<VaultFolder>(vaultFolders);
  static Box<CalcHistoryEntry> get history => Hive.box<CalcHistoryEntry>(calcHistory);
  static Box get settingsBox => Hive.box(settings);

  /// Wipes all local data. Used by "Reset App".
  static Future<void> wipeAll() async {
    await files.clear();
    await folders.clear();
    await history.clear();
    await settingsBox.clear();
  }
}

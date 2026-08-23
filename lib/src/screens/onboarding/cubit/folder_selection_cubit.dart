import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:obsi/src/screens/settings/settings_controller.dart';
import 'package:path/path.dart' as p;
import 'package:permission_handler/permission_handler.dart';

part 'folder_selection_state.dart';

/// Vault auto-scan and manual-selection logic, relocated unchanged from
/// `InitCubit` (formerly `lib/src/screens/init/cubit/init_cubit.dart`) as
/// the last step of the unified onboarding sequence (FR-006, research.md
/// §6). Auto-scan remains Android-only; iOS falls back to manual selection,
/// matching today's existing, already-disclosed platform behavior.
///
/// Unlike the old `InitCubit`, this cubit does not navigate on its own —
/// choosing a folder only updates local state. The screen drives completion
/// through `OnboardingFlowCubit.complete()`, which is the single place that
/// persists the vault directory and marks onboarding complete.
class FolderSelectionCubit extends Cubit<FolderSelectionState> {
  String? vaultDirectory;

  FolderSelectionCubit(SettingsController settings)
      : vaultDirectory = settings.vaultDirectory,
        super(FolderSelectionInitial());

  Future<void> startScanning(BuildContext context) async {
    // Only auto-scan on Android; other platforms fall back to manual selection
    if (!Platform.isAndroid) {
      emit(FolderSelectionNoVaultsFound());
      return;
    }

    emit(FolderSelectionScanning());

    try {
      var granted = await SettingsController.storagePermissionsGranted();
      if (!granted) {
        final status =
            await SettingsController.requestAndroidPermission(context);
        granted = status == PermissionStatus.granted;
      }

      if (!granted) {
        emit(FolderSelectionNoVaultsFound());
        return;
      }

      final vaults = await _scanForVaults();
      if (vaults.isEmpty) {
        emit(FolderSelectionNoVaultsFound());
      } else {
        emit(FolderSelectionScanResults(vaults));
      }
    } catch (e) {
      emit(FolderSelectionError(e.toString()));
    }
  }

  Future<List<String>> _scanForVaults() async {
    final Set<String> vaultPaths = {};

    Future<void> scanRecursive(String basePath) async {
      final baseDir = Directory(basePath);
      if (!await baseDir.exists()) return;

      await for (final entity
          in baseDir.list(recursive: true, followLinks: false)) {
        if (entity is Directory && p.basename(entity.path) == '.obsidian') {
          final parent = p.dirname(entity.path);
          vaultPaths.add(parent);
        }
      }
    }

    Future<void> scanRootLevel(String rootPath) async {
      final rootDir = Directory(rootPath);
      if (!await rootDir.exists()) return;

      await for (final entity
          in rootDir.list(recursive: false, followLinks: false)) {
        if (entity is Directory) {
          final obsidianDir = Directory(p.join(entity.path, '.obsidian'));
          if (await obsidianDir.exists()) {
            vaultPaths.add(entity.path);
          }
        }
      }
    }

    // Scan specific directories and their subfolders
    await scanRecursive('/storage/emulated/0/Documents/');
    await scanRecursive('/storage/emulated/0/Download/');
    await scanRecursive('/storage/emulated/0/Obsidian/');

    // Scan root level folders only
    await scanRootLevel('/storage/emulated/0/');

    return vaultPaths.toList()..sort();
  }

  Future<void> selectDirectory(BuildContext context) async {
    try {
      vaultDirectory = await SettingsController.selectVaultDirectory(context);
      if (vaultDirectory == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No folder selected.')),
          );
        }
        return;
      }

      emit(FolderChosen(vaultDirectory!));
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('An error occurred: $e')),
        );
      }
    }
  }

  void selectScannedVault(String path) {
    vaultDirectory = path;
    emit(FolderChosen(path));
  }
}

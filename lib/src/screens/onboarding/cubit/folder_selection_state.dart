part of 'folder_selection_cubit.dart';

@immutable
sealed class FolderSelectionState {}

final class FolderSelectionInitial extends FolderSelectionState {}

final class FolderSelectionScanning extends FolderSelectionState {}

final class FolderSelectionScanResults extends FolderSelectionState {
  final List<String> vaultPaths;
  FolderSelectionScanResults(this.vaultPaths);
}

final class FolderSelectionNoVaultsFound extends FolderSelectionState {}

final class FolderSelectionError extends FolderSelectionState {
  final String message;
  FolderSelectionError(this.message);
}

final class FolderChosen extends FolderSelectionState {
  final String vaultDirectory;
  FolderChosen(this.vaultDirectory);
}

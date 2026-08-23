import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:obsi/src/screens/onboarding/cubit/folder_selection_cubit.dart';
import 'package:obsi/src/screens/onboarding/cubit/onboarding_flow_cubit.dart';
import 'package:obsi/src/screens/settings/settings_controller.dart';
import 'package:obsi/src/widgets/obsi_title.dart';
import 'package:url_launcher/url_launcher.dart';

/// Screen 3 of the onboarding sequence — replaces the standalone `Init`
/// screen (`lib/src/screens/init/init.dart`). Folder selection is required:
/// there is no way to proceed past this screen until a valid folder is
/// chosen (FR-007), and there is no Skip control (FR-008).
class FolderSelectionScreen extends StatelessWidget {
  const FolderSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => FolderSelectionCubit(SettingsController.getInstance()),
      child: const _FolderSelectionView(),
    );
  }
}

class _FolderSelectionView extends StatefulWidget {
  const _FolderSelectionView();

  @override
  State<_FolderSelectionView> createState() => _FolderSelectionViewState();
}

class _FolderSelectionViewState extends State<_FolderSelectionView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<FolderSelectionCubit>().startScanning(context);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(title: const ObsiTitle()),
        body: SafeArea(
            bottom: true,
            child: BlocBuilder<FolderSelectionCubit, FolderSelectionState>(
                builder: (context, state) {
              return Center(
                  child: SingleChildScrollView(
                      child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Icon(
                        Icons.folder_open,
                        size: 80,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(height: 20),
                      const Text(
                          "Pick the folder where your Obsidian vault is stored.\n\nVaultMate needs this to find and show your tasks.",
                          textAlign: TextAlign.center),
                      const SizedBox(height: 24),
                      _buildContentForState(context, state),
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: () =>
                            context.read<OnboardingFlowCubit>().back(),
                        child: const Text('Back'),
                      ),
                      Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Column(children: [
                            const Text("Contact the developer:"),
                            GestureDetector(
                              onTap: () => _launchEmail(context),
                              child: const Text("support@vaultmate.app",
                                  style: TextStyle(
                                    color: Colors.blue,
                                    fontSize: 16,
                                    decoration: TextDecoration.underline,
                                  )),
                            )
                          ]))
                    ]),
              )));
            })));
  }

  Widget _buildContentForState(
      BuildContext context, FolderSelectionState state) {
    if (state is FolderSelectionScanning) {
      return Column(
        children: const [
          SizedBox(height: 16),
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text("Searching for your vaults..."),
        ],
      );
    }

    if (state is FolderSelectionScanResults) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            "Select one of the vaults we found:",
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 300),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: state.vaultPaths.length,
              itemBuilder: (context, index) {
                final path = state.vaultPaths[index];
                final name = path.split('/').where((e) => e.isNotEmpty).last;
                return Card(
                  child: ListTile(
                    title: Text(name),
                    subtitle: Text(path),
                    onTap: () => _chooseAndComplete(context, path),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 24),
          _buildManualSelectionSection(context, state),
        ],
      );
    }

    if (state is FolderSelectionError) {
      return Column(
        children: [
          Text(
            'Error while searching for vaults: ${state.message}',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () =>
                context.read<FolderSelectionCubit>().startScanning(context),
            child: const Text('Try Again'),
          ),
          const SizedBox(height: 16),
          _buildManualSelectionSection(context, state),
        ],
      );
    }

    // FolderSelectionInitial, FolderSelectionNoVaultsFound, FolderChosen
    return _buildManualSelectionSection(context, state);
  }

  Widget _buildManualSelectionSection(
      BuildContext context, FolderSelectionState state) {
    final cubit = context.read<FolderSelectionCubit>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (state is FolderSelectionNoVaultsFound)
          const Text(
            "We could not find any Obsidian vaults automatically.",
            textAlign: TextAlign.center,
          ),
        const SizedBox(height: 12),
        Text(
          cubit.vaultDirectory ?? "<Please choose the folder>",
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: () => cubit.selectDirectory(context),
          child: const Text("Select Folder Manually"),
        ),
        const SizedBox(height: 12),
        FilledButton.tonal(
          onPressed: state is FolderChosen
              ? () => _complete(context, state.vaultDirectory)
              : null,
          child: const Text("Continue"),
        ),
      ],
    );
  }

  void _chooseAndComplete(BuildContext context, String path) {
    context.read<FolderSelectionCubit>().selectScannedVault(path);
    _complete(context, path);
  }

  void _complete(BuildContext context, String vaultDirectory) {
    context.read<OnboardingFlowCubit>().complete(vaultDirectory);
  }

  Future<void> _launchEmail(BuildContext context) async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: "support@vaultmate.app",
      query: 'subject=VaultMate', // Optional query parameters
    );
    if (await canLaunchUrl(emailUri)) {
      await launchUrl(emailUri);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not launch $emailUri')),
        );
      }
    }
  }
}

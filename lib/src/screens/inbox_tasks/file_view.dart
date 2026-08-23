import 'package:flutter/material.dart';
import 'package:obsi/src/core/utils.dart';
import 'package:path/path.dart' as p;
import 'package:url_launcher/url_launcher.dart';

class FileView extends Card {
  final List<Widget> taskCards;
  final String? highlightedText;
  final String vaultName;
  final String? fileName;

  /// Increment 2 (User Story 4): non-null only when this file has at least
  /// one collapsible task - otherwise no header control is shown at all
  /// (nothing to collapse or expand). true means every collapsible task in
  /// this file is currently collapsed (so the control shows "expand all");
  /// false means at least one is still expanded (so it shows "collapse all").
  final bool? allCollapsed;
  final VoidCallback? onToggleCollapseAll;

  const FileView(
    this.taskCards, {
    super.key,
    this.highlightedText,
    required this.vaultName,
    required this.fileName,
    this.allCollapsed,
    this.onToggleCollapseAll,
  });

  @override
  Widget build(BuildContext context) {
    var displayFileName =
        fileName != null ? p.basenameWithoutExtension(fileName!) : null;

    var defaultTextStyle =
        TextStyle(color: Theme.of(context).colorScheme.onSurface);
    var hightlightedTextStyle = DefaultTextStyle.of(context).style.copyWith(
          backgroundColor: Colors.yellow,
          color: Colors.black,
        );

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 10),
          child: Row(children: [
            Align(alignment: Alignment.centerLeft, child: Text('File: ')),
            Expanded(
              child: GestureDetector(
                onTap: () async {
                  if (displayFileName == null || displayFileName.isEmpty) {
                    return;
                  }
                  final Uri obsidianUri = Uri.parse(
                      'obsidian://open?vault=$vaultName&file=$displayFileName');
                  if (await canLaunchUrl(obsidianUri)) {
                    await launchUrl(obsidianUri);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text(
                              'Could not open $displayFileName in Obsidian')),
                    );
                  }
                },
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: displayFileName != null &&
                          highlightedText != null &&
                          displayFileName
                              .toLowerCase()
                              .contains(highlightedText!)
                      ? RichText(
                          overflow: TextOverflow.ellipsis,
                          text: TextSpan(
                            style: const TextStyle(
                              color: Colors.blue,
                              decoration: TextDecoration.underline,
                            ),
                            children: buildHighlightedTextSpans(
                                displayFileName,
                                highlightedText!,
                                defaultTextStyle.copyWith(
                                  color: Colors.blue,
                                  decoration: TextDecoration.underline,
                                ),
                                hightlightedTextStyle),
                          ),
                        )
                      : Text(
                          displayFileName ?? "",
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                          style: const TextStyle(
                            color: Colors.blue,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                ),
              ),
            ),
            if (allCollapsed != null && onToggleCollapseAll != null)
              IconButton(
                key: const Key('file_view_collapse_toggle'),
                onPressed: onToggleCollapseAll,
                icon: Icon(
                  allCollapsed! ? Icons.unfold_more : Icons.unfold_less,
                  size: 20,
                ),
                tooltip: allCollapsed! ? 'Expand all' : 'Collapse all',
              ),
          ]),
        ),
        ListView(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          children: taskCards,
        ),
      ],
    );
  }
}

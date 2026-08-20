import 'package:flutter/material.dart';
import 'package:obsi/src/core/utils.dart';
import 'package:path/path.dart' as p;
import 'package:url_launcher/url_launcher.dart';

class FileView extends Card {
  final List<Widget> taskCards;
  final String? highlightedText;
  final String vaultName;
  final String? fileName;

  const FileView(
    this.taskCards, {
    super.key,
    this.highlightedText,
    required this.vaultName,
    required this.fileName,
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
            GestureDetector(
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
                        displayFileName.toLowerCase().contains(highlightedText!)
                    ? RichText(
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
                        style: const TextStyle(
                          color: Colors.blue,
                          decoration: TextDecoration.underline,
                        ),
                      ),
              ),
            )
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

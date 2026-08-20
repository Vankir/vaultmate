import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:obsi/src/core/utils.dart';
import 'package:obsi/src/screens/settings/settings_controller.dart';

class CalendarView extends Card {
  final List<Widget> taskCards;
  final String? highlightedText;
  final DateTime? scheduledDate;

  const CalendarView(
    this.taskCards, {
    super.key,
    this.highlightedText,
    required this.scheduledDate,
  });

  @override
  Widget build(BuildContext context) {
    String? dateString;
    String? dayOfWeekString;
    var template = SettingsController.getInstance().dateTemplate;

    if (scheduledDate != null) {
      dateString = DateFormat(template).format(scheduledDate!);
      dayOfWeekString =
          DateFormat('EEEE').format(scheduledDate!); // Full day name
    }

    var defaultTextStyle =
        TextStyle(color: Theme.of(context).colorScheme.onSurface);
    var hightlightedTextStyle = DefaultTextStyle.of(context).style.copyWith(
          backgroundColor: Colors.yellow,
          color: Colors.black,
        );

    Widget buildDateHeader() {
      // Create a combined display text
      String displayText = dateString ?? 'Undefined Date';

      return Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color:
              Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (dayOfWeekString != null) ...[
              Text(
                dayOfWeekString,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 2),
            ],
            highlightedText != null && displayText.contains(highlightedText!)
                ? RichText(
                    textAlign: TextAlign.center,
                    text: TextSpan(
                      children: buildHighlightedTextSpans(
                          displayText,
                          highlightedText!,
                          defaultTextStyle.copyWith(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                          hightlightedTextStyle),
                    ),
                  )
                : Text(
                    dateString ?? '',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                    textAlign: TextAlign.center,
                  ),
          ],
        ),
      );
    }

    return Column(
      children: [
        buildDateHeader(),
        ListView(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          children: taskCards,
        ),
      ],
    );
  }
}

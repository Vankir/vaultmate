import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:logger/logger.dart';
import 'package:obsi/src/core/tasks/markdown_task_markers.dart';
import 'package:obsi/src/core/tasks/task.dart';
import 'package:obsi/src/core/tasks/task_manager.dart';
import 'package:obsi/src/core/utils.dart';
import 'package:obsi/src/screens/settings/settings_controller.dart';

class TaskCard extends Card {
  final Task task;
  final Function(bool?)? taskDonePressed;
  final VoidCallback? rightButtonPressed;
  final VoidCallback? editTaskPressed;
  final VoidCallback? startWorkflowPressed;
  final IconData? rightButtonIcon;
  final String? hightlightedText;

  /// How many ancestor tasks lie between this task and the top level of its
  /// note (see Task.depth). 0 (the default) renders exactly as before this
  /// field existed - purely visual, callers opt in per view (see
  /// _createFileViews/_createTaskCard in inbox_tasks.dart).
  final int depth;

  /// Deeper nesting than this renders at the same indentation as this cap,
  /// rather than continuing to shift further right (FR-006).
  static const int maxVisualDepth = 5;

  const TaskCard(this.task,
      {super.key,
      this.hightlightedText,
      this.taskDonePressed,
      this.rightButtonPressed,
      this.editTaskPressed,
      this.startWorkflowPressed,
      this.rightButtonIcon,
      this.depth = 0});

  @override
  Widget build(BuildContext context) {
    final cardContent = _buildCardContent(context);
    if (depth <= 0) {
      return cardContent;
    }

    final effectiveDepth = depth.clamp(0, maxVisualDepth);
    return Padding(
      key: const Key('task_card_depth_indent'),
      padding: EdgeInsets.only(left: 12.0 * effectiveDepth),
      // IntrinsicHeight gives the Row below a concrete height to stretch
      // against. Without it, a ListView item's incoming height constraint
      // is unbounded, and Row(crossAxisAlignment: stretch) can't resolve
      // "stretch to fill" against an unbounded height - that's what threw
      // the "RenderBox was not laid out: 'hasSize'" error.
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var level = 0; level < effectiveDepth; level++)
              Container(
                key: Key('task_card_depth_marker_$level'),
                width: 2,
                margin: const EdgeInsets.only(right: 4),
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            Expanded(child: cardContent),
          ],
        ),
      ),
    );
  }

  Widget _buildCardContent(BuildContext context) {
    var defaultTextStyle = Theme.of(context).textTheme.bodyMedium!.copyWith(
          color: Theme.of(context).colorScheme.onSurface,
        );
    var hightlightedTextStyle =
        Theme.of(context).textTheme.bodyMedium!.copyWith(
              backgroundColor: Colors.yellow,
              color: Colors.black,
            );

    return Container(
      margin: const EdgeInsets.fromLTRB(2.0, 1.0, 1.0, 1.0),
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            color: getTaskScheduleStateColor(task),
            width: 4,
          ),
        ),
      ),
      child: Card(
        margin: const EdgeInsets.all(0.0),
        child: ListTile(
          leading: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              startWorkflowPressed == null
                  ? Checkbox(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      value: task.status == TaskStatus.done ? true : false,
                      onChanged: taskDonePressed,
                    )
                  : SizedBox(
                      height: 28,
                      width: 28,
                      child: IconButton(
                        onPressed: startWorkflowPressed,
                        icon: Icon(
                          Icons.play_arrow,
                          color: Theme.of(context).colorScheme.primary,
                          size: 22,
                        ),
                        padding: const EdgeInsets.all(4),
                        tooltip: 'Start',
                      ),
                    ),
            ],
          ),
          onTap: editTaskPressed,
          contentPadding: const EdgeInsets.symmetric(
              horizontal: 0.0), // Adjust padding here
          title: hightlightedText != null &&
                  hightlightedText!.isNotEmpty &&
                  task.description!.toLowerCase().contains(hightlightedText!)
              ? RichText(
                  text: TextSpan(
                  children: buildHighlightedTextSpans(
                      _trancateDescription(task.description!),
                      hightlightedText!,
                      task.status == TaskStatus.done
                          ? defaultTextStyle.copyWith(
                              decoration: TextDecoration.lineThrough)
                          : defaultTextStyle,
                      task.status == TaskStatus.done
                          ? hightlightedTextStyle.copyWith(
                              decoration: TextDecoration.lineThrough)
                          : hightlightedTextStyle),
                  style: defaultTextStyle, // Ensure consistent font size
                ))
              : Text(
                  _trancateDescription(task.description!),
                  style: task.status == TaskStatus.done
                      ? defaultTextStyle.copyWith(
                          decoration: TextDecoration.lineThrough)
                      : defaultTextStyle,
                ),
          subtitle: _getSubtitle(context),
          trailing: (rightButtonPressed != null)
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (rightButtonPressed != null)
                      ElevatedButton(
                        onPressed: rightButtonPressed,
                        style: ElevatedButton.styleFrom(
                          shape: const CircleBorder(),
                          padding: const EdgeInsets.all(8),
                        ),
                        child: rightButtonIcon != null
                            ? Icon(rightButtonIcon!)
                            : null,
                      ),
                  ],
                )
              : null,
        ),
      ),
    );
  }

  Widget _getSubtitle(BuildContext context) {
    var template = SettingsController.getInstance().dateTemplate;
    var subtitle = MarkdownTaskMarkers().getPriorityMarker(task.priority);

    if (task.scheduled != null) {
      var scheduledTemplate = template;
      if (task.scheduledTime) {
        scheduledTemplate += " HH:mm";
      }
      subtitle +=
          "\n${MarkdownTaskMarkers.scheduledDateMarker} ${DateFormat(scheduledTemplate).format(task.scheduled!)}";
      if (task.recurrenceRule != null) {
        subtitle +=
            " ${MarkdownTaskMarkers.recurringDateMarker} ${task.recurrenceRule}";
      }
    }

    if (task.due != null) {
      var scheduledTemplate = template;
      subtitle +=
          "\n${MarkdownTaskMarkers.dueDateMarker} ${DateFormat(scheduledTemplate).format(task.due!)}";
    }

    // bool debug = true;

    // if (debug) {
    //   subtitle += _debugInfo(task);
    // }

    // If no tags, return simple text
    if (task.tags.isEmpty) {
      return Text(
        subtitle,
        style: Theme.of(context).textTheme.bodySmall,
      );
    }

    // Build subtitle with inline tags
    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: subtitle,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (subtitle.isNotEmpty) const TextSpan(text: ' '),
          ...task.tags.map((tag) => WidgetSpan(
                child: Container(
                  margin: const EdgeInsets.only(right: 4.0),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 4.0, vertical: 1.0),
                  decoration: BoxDecoration(
                    color:
                        Theme.of(context).colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8.0),
                    border: Border.all(
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withOpacity(0.3),
                      width: 0.5,
                    ),
                  ),
                  child: Text(
                    '#$tag',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontSize: 9,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              )),
        ],
      ),
    );
  }

  String _trancateDescription(String description) {
    const maxLength = 40;
    return description!.length > maxLength
        ? '${description.substring(0, maxLength)}...'
        : description;
  }

  String _debugInfo(Task task) {
    String result = "";
    if (task.taskSource != null) {
      result += task.taskSource.toString();
    }

    return result;
  }

  Color getTaskScheduleStateColor(Task task) {
    Color color = Colors.transparent;
    switch (TaskManager.getTaskScheduleState(task)) {
      case TaskScheduleState.dueToday:
        color = Colors.orange;
      case TaskScheduleState.overdue:
        color = Colors.red;
      default:
        color = Colors.transparent;
    }

    return color;
  }
}

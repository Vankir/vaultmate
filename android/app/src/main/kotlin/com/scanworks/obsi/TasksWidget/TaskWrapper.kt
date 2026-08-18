package com.scanworks.obsi
import org.json.JSONArray
import org.json.JSONObject

data class TaskWrapper(
      val description: String = "",
    val status: String = "todo",
    val priority: String = "normal",
    val created: String? = null,
    val done: String? = null,
    val cancelled: String? = null,
    val due: String? = null,
    val start: String? = null,
    val scheduled: String? = null,
    val recurrenceRule: String? = null,
    val filePath: String? = null,
    val fileOffset: String? = null,
    val tags: List<String> = emptyList()
) {
    fun toJsonObject(): JSONObject {
        return JSONObject().apply {
            put("description", description)
            put("status", status)
            put("priority", priority)
            put("created", created)
            put("done", done)
            put("cancelled", cancelled)
            put("due", due)
            put("start", start)
            put("scheduled", scheduled)
            put("recurrenceRule", recurrenceRule)
            put("filePath", filePath)
            put("fileOffset", fileOffset)
            put("tags", JSONArray(tags))
        }
    }

      /**
     * Finds the task in the file at [filePath] using [fileOffset] and changes its status to done ([x]) or in progress ([ ]).
     * @param done true for done ([x]), false for in progress ([ ])
     * Returns true if the update was successful, false otherwise.
     */
    fun updateTaskStatusInFile(done: Boolean): Boolean {
        val TAG = "TaskWrapper"
        if (filePath.isNullOrEmpty() || fileOffset.isNullOrEmpty()) {
            android.util.Log.w(TAG, "filePath or fileOffset is null or empty: filePath=$filePath, fileOffset=$fileOffset")
            return false
        }
        try {
            val file = java.io.File(filePath)
            if (!file.exists()) {
                android.util.Log.w(TAG, "File does not exist: $filePath")
                return false
            }
            val content = file.readText()
            val offset = fileOffset.toIntOrNull() ?: run {
                android.util.Log.w(TAG, "fileOffset is not a valid integer: $fileOffset")
                return false
            }
            if (offset < 0 || offset >= content.length) {
                android.util.Log.w(TAG, "Offset out of bounds: $offset (content length: ${content.length})")
                return false
            }

            // Search for the markdown task substring starting from the offset
            val statusRegex = Regex("- \\[([ xX])\\]")
            val startIdx = content.indexOf('-', offset)
            if (startIdx == -1) {
                android.util.Log.w(TAG, "No '-' found after offset $offset in file $filePath")
                return false
            }
            val matcher = statusRegex.find(content, startIdx)
            if (matcher == null) {
                android.util.Log.w(TAG, "No markdown task status found after offset $offset in file $filePath")
                return false
            }

            // Find the line containing the match
            val before = content.substring(0, matcher.range.first)
            val lineStart = before.lastIndexOf('\n') + 1
            val lineEnd = content.indexOf('\n', matcher.range.first)
            val lineEndFinal = if (lineEnd == -1) content.length else lineEnd
            val line = content.substring(lineStart, lineEndFinal)

            android.util.Log.d(TAG, "Original line: '$line'")

            // Update the status in the found line
            val newLine = updateLineWithStatus(line, done, statusRegex)

            android.util.Log.d(TAG, "Updated line: '$newLine'")

            // If this completes a recurring task, insert a new task line for the next occurrence,
            // mirroring TaskManager._manageRecurrentTask on the Dart side.
            val recurringLine = if (done) buildNextOccurrenceLine() else null
            if (recurringLine != null) {
                android.util.Log.d(TAG, "Next occurrence line: '$recurringLine'")
            }

            // Replace the line in the content
            val newContent = buildString {
                append(content.substring(0, lineStart))
                if (recurringLine != null) {
                    append(recurringLine)
                    append("\n")
                }
                append(newLine)
                append(content.substring(lineEndFinal))
            }
            file.writeText(newContent)
            android.util.Log.i(TAG, "Task status updated in file: $filePath at offset $offset")
            return true
        } catch (e: Exception) {
            android.util.Log.e(TAG, "Exception in updateTaskStatusInFile", e)
            return false
        }
    }

    /**
     * If this task is recurring and scheduled, builds the markdown line for its next
     * occurrence (mirroring TaskManager._manageRecurrentTask / RecurrentTask.calculateNextOccurrence
     * on the Dart side). Returns null if the task is not recurring, has no scheduled date,
     * or the recurrence rule can't be parsed.
     */
    private fun buildNextOccurrenceLine(): String? {
        val rule = recurrenceRule
        if (rule.isNullOrBlank() || scheduled.isNullOrBlank()) {
            return null
        }
        return try {
            val lastDate = java.time.LocalDate.parse(scheduled.substring(0, 10))
            val nextDate = RecurrenceCalculator.calculateNextOccurrence(lastDate, rule)
            val today = java.time.LocalDate.now().toString()

            val tagsSuffix = if (tags.isNotEmpty()) tags.joinToString("") { " #$it" } else ""
            val prioritySuffix = priorityMarker(priority)?.let { " $it" } ?: ""

            "- [ ] $description$tagsSuffix$prioritySuffix ➕ $today ⏳ $nextDate 🔁 $rule"
        } catch (e: Exception) {
            android.util.Log.w("TaskWrapper", "Could not compute next occurrence for rule '$rule'", e)
            null
        }
    }

    companion object {
        private fun priorityMarker(priority: String): String? {
            return when (priority.lowercase()) {
                "lowest" -> "⏬"
                "low" -> "🔽"
                "medium" -> "🔼"
                "high" -> "⏫"
                "highest" -> "🔺"
                else -> null
            }
        }

    private fun updateLineWithStatus(line: String, done: Boolean, statusRegex: Regex): String {
        return if (done) {
            // Add done date in yyyy-MM-dd format with prefix ✅ at the end
            val date = java.time.LocalDate.now().toString()
            // Remove any previous done mark and date (if present)
            val lineNoDate = line.replace(Regex("\\s*✅ \\d{4}-\\d{2}-\\d{2}$"), "")
            lineNoDate.replace(statusRegex, "- [x]") + " ✅ $date"
        } else {
            // Remove any done mark and date if unchecking
            line.replace(statusRegex, "- [ ]").replace(Regex("\\s*✅ \\d{4}-\\d{2}-\\d{2}$"), "")
        }
    }
        fun fromJson(obj: JSONObject): TaskWrapper {
            val tagsArray = obj.optJSONArray("tags")
            val tags = if (tagsArray != null) {
                List(tagsArray.length()) { i -> tagsArray.optString(i) }
            } else {
                emptyList()
            }
            return TaskWrapper(
                description = obj.optString("description", ""),
                status = obj.optString("status", "todo"),
                priority = obj.optString("priority", "normal"),
                created = obj.optString("created", null),
                done = obj.optString("done", null),
                cancelled = obj.optString("cancelled", null),
                due = obj.optString("due", null),
                start = obj.optString("start", null),
                scheduled = obj.optString("scheduled", null),
                recurrenceRule = obj.optString("recurrenceRule", null),
                filePath = obj.optString("filePath", null),
                fileOffset = obj.optString("fileOffset", null),
                tags = tags
            )
        }
    }
}
package com.scanworks.obsi

import HomeWidgetGlanceState
import HomeWidgetGlanceStateDefinition
import android.content.Context
import android.util.Log
import androidx.datastore.preferences.core.MutablePreferences
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.glance.GlanceId
import androidx.glance.action.ActionParameters
import androidx.glance.appwidget.action.ActionCallback
import androidx.glance.appwidget.state.updateAppWidgetState
import androidx.glance.state.PreferencesGlanceStateDefinition
import es.antonborri.home_widget.HomeWidgetPlugin
import org.json.JSONObject

class TaskCheckActionCallback : ActionCallback {
    private val TAG = "TaskCheckActionCallback"

    companion object {
        const val TASK_JSON_KEY = "taskJson"
        const val NEW_STATUS_KEY = "newStatus"
    }

    override suspend fun onAction(
        context: Context,
        glanceId: GlanceId,
        parameters: ActionParameters
    ) {
        val taskJson = parameters[ActionParameters.Key<String>(TASK_JSON_KEY)] ?: return
        val newStatus = parameters[ActionParameters.Key(NEW_STATUS_KEY)] ?: false
        val changedTask = TaskWrapper.fromJson(JSONObject(taskJson))
        // The global task filter is not part of a task: the parser strips it out, so it
        // never reaches the widget data as a tag. Read it from the widget state (written
        // by HomeWidgetHandler on the Dart side) and write it onto the next occurrence —
        // otherwise the new task is filtered out in the app and in Tasks queries (#63).
        val taskFilter = HomeWidgetPlugin.getData(context)
            .getString(ObsiWidget.GLOBAL_TASK_FILTER_KEY, null)
        changedTask.updateTaskStatusInFile(newStatus, taskFilter)

        // Update the Glance widget's state
        updateAppWidgetState(context,
            HomeWidgetGlanceStateDefinition(), glanceId) { obsiPrefs ->
            // currentState is HomeWidgetGlanceState (or whatever your state definition provides)
            // Assuming HomeWidgetGlanceState has a 'preferences' field from home_widget plugin
            val prefs = obsiPrefs.preferences
            val tasksString = prefs.getString(ObsiWidget.TASKS_JSON_KEY, null)
            Log.d(TAG, "onAction: tasksString=$tasksString")
            if (tasksString != null) {
                try {
                    val tasks = ObsiWidget.parseTasksFromState(tasksString).toMutableList()
                    var taskUpdatedInState = false
                    // Find and update the changed task
                    for (i in tasks.indices) {
                        val t = tasks[i]
                        // Ensure comparison logic is robust. Comparing file paths and offsets.
                        if (t.filePath == changedTask.filePath && t.fileOffset == changedTask.fileOffset) {
                            tasks[i] = t.copy(status = if (newStatus) "done" else "todo")
                            taskUpdatedInState = true
                            Log.d(TAG, "Task updated in Glance state: ${tasks[i]}")
                            break
                        }
                    }

                    if (!taskUpdatedInState) {
                       Log.d(TAG, "Task to update not found in Glance state: ${changedTask.filePath}")
                    }


                    ObsiWidget.saveTasksToState(ObsiWidget.TASKS_JSON_KEY, tasks, prefs)
                    obsiPrefs// This is the new Preferences object to be returned
                } catch (e: Exception) {
                    Log.e(TAG, "Error processing tasks from Glance state preferences", e)
                    obsiPrefs // Return current state in case of error
                }
            } else {
                Log.w(TAG, "No 'tasks' string found in Glance state preferences.")
                obsiPrefs // Return current state if no tasks string
            }
        }

        // After updating the state, tell the widget to recompose
        ObsiWidget().update(context, glanceId)
        Log.d(TAG, "ObsiWidget.update() called for glanceId: $glanceId")
    }
}



package com.scanworks.obsi

import HomeWidgetGlanceState
import HomeWidgetGlanceStateDefinition
import android.content.Context
import android.content.SharedPreferences
import android.util.Log
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import androidx.core.content.edit
import androidx.glance.GlanceId
import androidx.glance.GlanceModifier
import androidx.glance.GlanceTheme
import androidx.glance.Image
import androidx.glance.ImageProvider
import androidx.glance.action.ActionParameters
import androidx.glance.action.actionParametersOf
import androidx.glance.action.actionStartActivity
import androidx.glance.action.clickable
import androidx.glance.appwidget.CheckBox
import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.SizeMode
import androidx.glance.appwidget.action.actionRunCallback
import androidx.glance.appwidget.lazy.LazyColumn
import androidx.glance.appwidget.provideContent
import androidx.glance.background
import androidx.glance.color.ColorProviders
import androidx.glance.currentState
import androidx.glance.layout.Alignment.Companion.CenterVertically
import androidx.glance.layout.Column
import androidx.glance.layout.Row
import androidx.glance.layout.Spacer
import androidx.glance.layout.fillMaxWidth
import androidx.glance.layout.height
import androidx.glance.layout.padding
import androidx.glance.layout.width
import androidx.glance.state.GlanceStateDefinition
import androidx.glance.text.FontWeight
import androidx.glance.text.Text
import androidx.glance.text.TextStyle
import androidx.glance.unit.ColorProvider
import org.json.JSONArray
import androidx.compose.ui.unit.sp


class ObsiWidget : GlanceAppWidget() {
    private val TAG = "ObsiWidget"
    override val sizeMode = SizeMode.Single
    override val stateDefinition: GlanceStateDefinition<*>
        get() = HomeWidgetGlanceStateDefinition()

    override suspend fun provideGlance(context: Context, id: GlanceId) {
        provideContent {
            GlanceContent(context, currentState())
        }
    }

    @Composable
    private fun getWidgetBackgroundColor(context: Context): ColorProvider {
        // val prefs = context.getSharedPreferences("obsi_widget_prefs", Context.MODE_PRIVATE)
        // val theme = prefs.getString("widget_theme_global", WidgetConfigureActivity.THEME_LIGHT)
        //     ?: WidgetConfigureActivity.THEME_LIGHT
        return GlanceTheme.colors.background
        //     when (theme) {
        //         // For "black" theme use pure black background
        //         WidgetConfigureActivity.THEME_BLACK -> GlanceTheme.colors.background//ColorProvider(Color(0xFF000000))
        //         else -> GlanceTheme.colors.background//ColorProvider(Color(0xFFFFFFFF))
        //     }
        // } catch (e: Exception) {
        //     Log.e("ObsiWidget", "Failed to load widget theme", e)
        //     GlanceTheme.colors.background//ColorProvider(Color(0xFFFFFFFF))
        // }
    }

    @Composable
    private fun getFontColor(context: Context): ColorProvider {
        // val prefs = context.getSharedPreferences("obsi_widget_prefs", Context.MODE_PRIVATE)
        // val theme = prefs.getString("widget_theme_global", WidgetConfigureActivity.THEME_LIGHT)
        //     ?: WidgetConfigureActivity.THEME_LIGHT
         return GlanceTheme.colors.onBackground
        // return when (theme) {

        //     WidgetConfigureActivity.THEME_BLACK -> GlanceTheme.colors.onBackground
        //     else -> GlanceTheme.colors.onBackground
        // }
    }

    @Composable
    private fun GlanceContent(context: Context, currentState: HomeWidgetGlanceState) {

        val prefs = currentState.preferences
        val tasksString = prefs.getString(TASKS_JSON_KEY, null)
        var errorString = prefs.getString(TASKS_ERROR, null)
        
        //tasks was not fetched yet
        if(tasksString == null){
            Log.i(TAG, "Tasks were not fetched yet")
            //requestTasks(context)
            return
        }

        if(errorString.isNullOrEmpty().not()) {
            prefs.edit { remove(TASKS_ERROR) }
        }

        Log.d(TAG, "GlanceContent with tasks: $tasksString")

        var tasks:List<TaskWrapper> = emptyList()
        try{
            tasks = parseTasksFromState(tasksString)

        } catch (e: Exception) {
            Log.e(TAG, "Failed to parse tasks JSON", e)
            errorString = "Failed to parse tasks: ${e.message}"
        }
        
       

        WidgetContent(context, tasks, errorString)
    }

    @Composable
    private fun WidgetContent(context: Context, tasks: List<TaskWrapper>, errorString: String?) {
        val backgroundColor = getWidgetBackgroundColor(context)
        var fontColor = getFontColor(context)
        Column(
            modifier = GlanceModifier
                .background(backgroundColor)
                .padding(horizontal = 12.dp, vertical = 10.dp)
        ) {
            buildCaption(context, tasks, fontColor)

            val minRows = 4 // Adjust this value to match your widget's visible rows
            val totalRows = maxOf(tasks.size, minRows)
            LazyColumn(
                modifier = GlanceModifier
                    .padding(top = 4.dp, start = 2.dp, end = 2.dp)
            ) {
                if (tasks.isEmpty() ||
                    !errorString.isNullOrEmpty()
                ) {
                    item {
                        if (!errorString.isNullOrEmpty()) {
                            Text(errorString, style = TextStyle(color = fontColor))
                        } else {
                            Text("No tasks", style = TextStyle(color = fontColor))
                        }
                    }
                    // Fill with empty rows
                    items(minRows - 1) { _ -> Spacer(modifier = GlanceModifier.padding(vertical = 10.dp)) }
                } else {

                    items(totalRows){ i ->
                        if (i < tasks.size) {
                            RowWithCheckbox(tasks[i], fontColor)
                        } else {
                            // Add empty space rows to fill widget
                            Spacer(modifier = GlanceModifier.padding(vertical = 10.dp))
                        }
                    }
                }
            }
        }
    }

    @Composable
    private fun buildCaption(context: Context, tasks: List<TaskWrapper>, fontColor: ColorProvider) {
        Row(
            modifier = GlanceModifier
                .fillMaxWidth()
                .padding(bottom = 6.dp),
            verticalAlignment = CenterVertically
        ) {
            // App icon and name on the left, both clickable to launch MainActivity
            val launchAppAction = actionStartActivity(MainActivity::class.java)
            Image(
                provider = ImageProvider(resId = R.drawable.ic_launcher),
                contentDescription = "Obsi icon",
                modifier = GlanceModifier
                    .height(24.dp)
                    .width(24.dp)
                    .clickable(launchAppAction)
            )
            val doneCount = tasks.count { it.status == "done" }
            val totalCount = tasks.size
            Text(
                text = if (totalCount > 0) "Today tasks $doneCount/$totalCount" else "Today tasks",
                modifier = GlanceModifier
                    .padding(start = 6.dp, end = 8.dp)
                    .clickable(launchAppAction),
                style = TextStyle(
                    color = fontColor,
                    fontWeight = FontWeight.Bold,
                    fontSize = 18.sp
                )
            )
            Spacer(modifier = GlanceModifier.defaultWeight())
            Image(
                provider = ImageProvider(resId = R.drawable.circular_add_button),
                contentDescription = "Add task",
                modifier = GlanceModifier
                    .height(32.dp)
                    .width(32.dp)
                    .clickable(actionRunCallback<AddTaskActionCallback>())
            )
        }
    }

    @Composable
    private fun RowWithCheckbox(task: TaskWrapper, fontColor: ColorProvider) {
        Row(
            modifier = GlanceModifier
                .fillMaxWidth()
                .padding(vertical = 4.dp)
        ) {
            val checkboxParams = actionParametersOf(
                ActionParameters.Key<String>(TaskCheckActionCallback.TASK_JSON_KEY) to task.toJsonObject().toString(),
                ActionParameters.Key<Boolean>(TaskCheckActionCallback.NEW_STATUS_KEY) to (task.status != "done")
            )
            
            val openTaskParams = actionParametersOf(
                ActionParameters.Key<String>(OpenTaskActionCallback.TASK_JSON_KEY) to task.toJsonObject().toString()
            )

            CheckBox(
                checked = task.status == "done",
                onCheckedChange = actionRunCallback<TaskCheckActionCallback>(checkboxParams)
            )
            Text(
                text = task.description,
                modifier = GlanceModifier
                    .padding(start = 4.dp)
                    .clickable(actionRunCallback<OpenTaskActionCallback>(openTaskParams)),
                style = TextStyle(
                         color = fontColor,
                         fontSize = 16.sp)
            )
        }
    }

    companion object {
        const val TASKS_JSON_KEY = "tasks"

        /**
         * Key written by HomeWidgetHandler (Dart) holding the global task filter, so the
         * widget can re-create a recurring task exactly like the app does (see #63).
         */
        const val GLOBAL_TASK_FILTER_KEY = "globalTaskFilter"
        const val TASKS_ERROR = "error"

        @JvmStatic
        fun parseTasksFromState(tasksString: String): List<TaskWrapper> {
            Log.d("ObsiWidget", "parseTasksFromState: tasksString=$tasksString")
            if (tasksString.isEmpty()) return emptyList()
            val jsonArray = JSONArray(tasksString)
            return List(jsonArray.length()) { i ->
                TaskWrapper.fromJson(jsonArray.getJSONObject(i))
            }
        }

        @JvmStatic
        fun saveTasksToState(tasksString: String, tasks: List<TaskWrapper>, prefs: SharedPreferences) {
            val jsonArray = JSONArray()
            for (task in tasks) {
                jsonArray.put(task.toJsonObject())
            }
            val tasksJsonString = jsonArray.toString()
            Log.d("ObsiWidget", "saveTasksToState: tasksString=$tasksString, tasks=$tasksJsonString")
            prefs.edit {
                putString(tasksString, tasksJsonString)
            }
        }
    }

    // private fun requestTasks(context: Context){
    //     Log.d(TAG, "requestTasks")
    //     val backgroundIntent = HomeWidgetBackgroundIntent.getBroadcast(context,
    //         "obsiWidget://request_tasks".toUri())
    //     backgroundIntent.send()
    // }
}


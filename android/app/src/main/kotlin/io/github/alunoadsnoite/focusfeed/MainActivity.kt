package io.github.alunoadsnoite.focusfeed

import android.Manifest
import android.app.Activity
import android.app.usage.UsageStatsManager
import org.json.JSONArray
import org.json.JSONObject
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import java.util.Calendar
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val main = Handler(Looper.getMainLooper())
    private var notificationResult: MethodChannel.Result? = null
    private var backupResult: MethodChannel.Result? = null
    private val backupCreateCode = 7101
    private val backupRestoreCode = 7102
    private val backupPrefs = listOf("earn_time_data", "focusfeed_progress", "focusfeed_options")
    private fun awaitMonitorState(
        expectedRunning: Boolean,
        result: MethodChannel.Result,
        attempts: Int = 0,
    ) {
        if (EarnTimeMonitorService.running == expectedRunning) {
            result.success(true)
        } else if (attempts >= 30) {
            val message = if (expectedRunning) {
                "Android no confirmó el inicio del seguimiento. Comprueba el permiso de acceso al uso y vuelve a intentarlo."
            } else {
                "Android todavía no confirmó que el seguimiento se haya detenido. Actualiza el estado en unos segundos."
            }
            result.error("monitor_state_timeout", message, null)
        } else {
            main.postDelayed({ awaitMonitorState(expectedRunning, result, attempts + 1) }, 100L)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "focusfeed/earn_time")
            .setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "createBackup", "restoreBackup" -> {
                            check(backupResult == null) { "Ya hay una operación de copia en curso." }
                            backupResult = result
                            val creating = call.method == "createBackup"
                            val intent = Intent(if (creating) Intent.ACTION_CREATE_DOCUMENT else Intent.ACTION_OPEN_DOCUMENT)
                            intent.addCategory(Intent.CATEGORY_OPENABLE)
                            intent.type = "application/json"
                            if (creating) intent.putExtra(Intent.EXTRA_TITLE, "EarnYourTime-backup.json")
                            startActivityForResult(intent, if (creating) backupCreateCode else backupRestoreCode)
                            return@setMethodCallHandler
                        }
                        "configure" -> {
                            val productive = (call.argument<List<String>>("productivePackages") ?: emptyList()).toSet()
                            val distracting = (call.argument<List<String>>("distractingPackages") ?: emptyList()).toSet()
                            EarnTimeStore.configure(this, productive, distracting)
                            val allowance = call.argument<Number>("dailyAllowanceSeconds")?.toLong()
                            val numerator = call.argument<Number>("rewardNumerator")?.toLong()
                            val denominator = call.argument<Number>("rewardDenominator")?.toLong()
                            if (allowance != null || numerator != null || denominator != null) {
                                val current = EarnTimeStore.settings(this)
                                EarnTimeStore.saveSettings(this, EarnTimeSettings(
                                    allowance ?: current.dailyAllowanceSeconds,
                                    numerator ?: current.rewardNumerator,
                                    denominator ?: current.rewardDenominator,
                                ))
                            }
                            result.success(EarnTimeStore.snapshot(this))
                        }
                        "startMonitor" -> {
                            check(NativeAccess.usage(this)) { "Activa el acceso al uso de aplicaciones." }
                            check(android.provider.Settings.canDrawOverlays(this)) {
                                "Activa el permiso «Mostrar sobre otras aplicaciones» para que Earn Your Time pueda bloquear las apps distractoras cuando tu saldo llegue a cero."
                            }
                            val intent = Intent(this, EarnTimeMonitorService::class.java)
                            if (Build.VERSION.SDK_INT >= 26) startForegroundService(intent) else startService(intent)
                            awaitMonitorState(true, result)
                            return@setMethodCallHandler
                        }
                        "stopMonitor" -> {
                            stopService(Intent(this, EarnTimeMonitorService::class.java))
                            awaitMonitorState(false, result)
                            return@setMethodCallHandler
                        }
                        "status" -> result.success(
                            EarnTimeStore.snapshot(this) + mapOf("monitorRunning" to EarnTimeMonitorService.running,
                                "usagePermission" to NativeAccess.usage(this),
                                "overlayPermission" to Settings.canDrawOverlays(this))
                        ),
                        "appUsage" -> {
                            check(NativeAccess.usage(this)) { "Activa el acceso al uso de aplicaciones para consultar el historial." }
                            val categories = EarnTimeStore.categories(this)
                            val selected = categories.first + categories.second
                            val end = System.currentTimeMillis()
                            val startCalendar = Calendar.getInstance().apply {
                                timeInMillis = end
                                set(Calendar.HOUR_OF_DAY, 0)
                                set(Calendar.MINUTE, 0)
                                set(Calendar.SECOND, 0)
                                set(Calendar.MILLISECOND, 0)
                                add(Calendar.DAY_OF_YEAR, -6)
                            }
                            val start = startCalendar.timeInMillis
                            val manager = getSystemService(USAGE_STATS_SERVICE) as UsageStatsManager
                            val usage = manager.queryAndAggregateUsageStats(start, end)
                            val items = usage.entries
                                .filter { it.key in selected && it.value.totalTimeInForeground > 0L }
                                .mapNotNull { (pkg, stats) ->
                                    try {
                                        val appInfo = packageManager.getApplicationInfo(pkg, 0)
                                        mapOf(
                                            "package" to pkg,
                                            "label" to packageManager.getApplicationLabel(appInfo).toString(),
                                            "seconds" to (stats.totalTimeInForeground / 1000L),
                                            "category" to if (pkg in categories.first) "productive" else "distracting",
                                        )
                                    } catch (_: Exception) { null }
                                }
                                .sortedByDescending { (it["seconds"] as Long) }
                            result.success(mapOf("items" to items, "startTime" to start, "endTime" to end))
                        }
                        else -> result.notImplemented()
                    }
                } catch (error: Exception) {
                    result.error("earn_time_error", error.message ?: "No se pudo actualizar Earn Your Time.", null)
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "focusfeed/permissions")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "check" -> result.success(mapOf("supported" to true, "usage" to NativeAccess.usage(this), "overlay" to Settings.canDrawOverlays(this)))
                    "request" -> {
                        val intent = when (call.argument<String>("permission")) {
                            "usage" -> Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS)
                            "overlay" -> Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION, Uri.parse("package:$packageName"))
                            else -> null
                        }
                        try {
                            requireNotNull(intent) { "Permissão desconhecida" }
                            startActivity(intent)
                            result.success(null)
                        } catch (_: Exception) { result.error("settings_unavailable", "Não foi possível abrir as configurações.", null) }
                    }
                    else -> result.notImplemented()
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "focusfeed/settings")
            .setMethodCallHandler { call, result ->
                val options = getSharedPreferences("focusfeed_options", MODE_PRIVATE)
                when (call.method) {
                    "loadTheme" -> result.success(options.getString("theme", "system"))
                    "loadLanguage" -> result.success(options.getString(AppLanguage.KEY, AppLanguage.DEFAULT_TAG))
                    "saveLanguage" -> {
                        val value = call.argument<String>("value")
                        if (value == null || value !in AppLanguage.supported) {
                            result.error("invalid_language", "Unsupported language.", null)
                        } else {
                            options.edit().putString(AppLanguage.KEY, value).apply()
                            result.success(null)
                        }
                    }
                    "saveTheme" -> {
                        val value = call.argument<String>("value")
                        if (value == null || (value != "system" && value != "light" && value != "dark")) {
                            result.error("invalid_theme", "Tema desconhecido.", null)
                        } else {
                            options.edit().putString("theme", value).apply()
                            result.success(null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "focusfeed/session")
            .setMethodCallHandler { call, result ->
                if (call.method == "requestNotifications") {
                    if (Build.VERSION.SDK_INT >= 33 && checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
                        if (notificationResult != null) { result.error("busy", "Solicitação já aberta.", null); return@setMethodCallHandler }
                        val options = getSharedPreferences("focusfeed_options", MODE_PRIVATE)
                        if (options.getBoolean("notifications_asked", false) && !shouldShowRequestPermissionRationale(Manifest.permission.POST_NOTIFICATIONS)) {
                            startActivity(Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).putExtra(Settings.EXTRA_APP_PACKAGE, packageName))
                            result.success(false)
                            return@setMethodCallHandler
                        }
                        options.edit().putBoolean("notifications_asked", true).apply()
                        notificationResult = result
                        requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 41)
                    } else result.success(FocusNotifications.enabled(this))
                    return@setMethodCallHandler
                }
                val arguments = call.arguments as? Map<*, *> ?: emptyMap<Any, Any>()
                NativeSessionRepository.worker.execute {
                    try {
                        if (call.method == "apps") {
                            val apps = InstalledApps.list(this)
                            main.post { result.success(apps) }
                            return@execute
                        }
                        var p = if (call.method == "initialize" || call.method == "status") NativeSessionRepository.restore(this)
                            else NativeSessionRepository.load(this)
                        if (FocusBlockingService.running) p = NativeSessionRepository.advance(this)
                        val backup = NativeSessionRepository.copy(p)
                        p = NativeSessionRepository.copy(p)
                        val elapsed = SystemClock.elapsedRealtime()
                        val wall = System.currentTimeMillis()
                        val boot = NativeSessionRepository.boot(this)
                        var launch = false
                        when (call.method) {
                            "initialize", "status" -> {
                                if (p.session.phase == "locked" && call.method == "initialize" && NativeAccess.canBlock(this)) launch = true
                            }
                            "start" -> {
                                check(NativeAccess.canBlock(this)) { "Ative acesso ao uso e sobreposição no painel de permissões." }
                                SessionEngine.start(p, (arguments["seconds"] as? Number)?.toLong() ?: p.session.focusTotalSeconds, elapsed, wall, boot)
                                launch = true
                            }
                            "pause" -> SessionEngine.pause(p)
                            "stop" -> SessionEngine.stop(p)
                            "reward" -> {
                                check(NativeAccess.canBlock(this)) { "Ative acesso ao uso e sobreposição antes de liberar as redes." }
                                SessionEngine.reward(p, (arguments["seconds"] as? Number)?.toLong() ?: 0, elapsed, wall, boot)
                                launch = true
                            }
                            "duration" -> {
                                require(p.session.phase == "idle") { "Pare a sessão antes de alterar a duração." }
                                val seconds = (arguments["seconds"] as? Number)?.toLong() ?: 0
                                require(seconds in 60..3600)
                                p.session.focusTotalSeconds = seconds
                                p.session.focusRemainingSeconds = seconds
                            }
                            "select" -> {
                                require(p.session.phase == "idle") { "Pare o bloqueio antes de alterar a seleção." }
                                val pkg = arguments["package"] as? String ?: error("App ausente")
                                require(pkg != packageName && pkg.matches(Regex("[A-Za-z0-9_.]+")))
                                p.apps[pkg] = arguments["selected"] as? Boolean ?: false
                            }
                            else -> { main.post { result.notImplemented() }; return@execute }
                        }
                        // Snapshot includes the debit AND reward phase atomically.
                        if (call.method !in setOf("initialize", "status")) NativeSessionRepository.save(this, p)
                        FocusNotifications.drain(this, p)
                        val snapshot = NativeSessionRepository.encode(p).toString()
                        main.post {
                            try {
                                if (launch) {
                                    val intent = Intent(this, FocusBlockingService::class.java)
                                    if (Build.VERSION.SDK_INT >= 26) startForegroundService(intent) else startService(intent)
                                } else if (!SessionEngine.active(p.session)) stopService(Intent(this, FocusBlockingService::class.java))
                                result.success(status(snapshot))
                            } catch (_: Exception) {
                                NativeSessionRepository.worker.execute {
                                    try { NativeSessionRepository.save(this, backup) } finally {
                                        main.post { result.error("service_unavailable", "Não foi possível iniciar o serviço; a alteração foi desfeita.", null) }
                                    }
                                }
                            }
                        }
                    } catch (error: Exception) {
                        main.post { result.error("session_error", error.message ?: "Falha ao salvar a sessão.", null) }
                    }
                }
            }
    }
    private fun backupJson(): JSONObject {
        EarnTimeStore.flush(this)
        NativeSessionRepository.advance(this, forceSave = true)
        val prefs = JSONObject()
        backupPrefs.forEach { name ->
            val values = JSONObject()
            getSharedPreferences(name, MODE_PRIVATE).all.forEach { (key, value) ->
                val entry = JSONObject()
                when (value) {
                    is String -> entry.put("type", "string").put("value", value)
                    is Boolean -> entry.put("type", "boolean").put("value", value)
                    is Int -> entry.put("type", "int").put("value", value)
                    is Long -> entry.put("type", "long").put("value", value.toString())
                    is Float -> entry.put("type", "float").put("value", value.toDouble())
                    is Set<*> -> entry.put("type", "stringSet").put("value", JSONArray(value.filterIsInstance<String>()))
                    else -> throw IllegalStateException("Tipo de dato no compatible en la copia.")
                }
                values.put(key, entry)
            }
            prefs.put(name, values)
        }
        return JSONObject().put("format", "earn-your-time-backup").put("version", 2).put("preferences", prefs)
    }

    private fun restoreJson(root: JSONObject) {
        require(root.optString("format") == "earn-your-time-backup" && root.optInt("version") == 2) { "Archivo incompatible o de una versión anterior." }
        val all = root.getJSONObject("preferences")
        backupPrefs.forEach { name ->
            val values = all.getJSONObject(name)
            val editor = getSharedPreferences(name, MODE_PRIVATE).edit().clear()
            values.keys().forEach { key ->
                val entry = values.getJSONObject(key)
                when (entry.getString("type")) {
                    "string" -> editor.putString(key, entry.getString("value"))
                    "boolean" -> editor.putBoolean(key, entry.getBoolean("value"))
                    "int" -> editor.putInt(key, entry.getInt("value"))
                    "long" -> editor.putLong(key, entry.getString("value").toLong())
                    "float" -> editor.putFloat(key, entry.getDouble("value").toFloat())
                    "stringSet" -> {
                        val array = entry.getJSONArray("value")
                        editor.putStringSet(key, (0 until array.length()).map { array.getString(it) }.toSet())
                    }
                    else -> error("Tipo de dato desconocido en la copia.")
                }
            }
            check(editor.commit()) { "No se pudo restaurar " + name }
        }
        EarnTimeStore.forgetCacheForBackupRestore()
        NativeSessionRepository.forgetCacheForTests()
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != backupCreateCode && requestCode != backupRestoreCode) return
        if (resultCode != Activity.RESULT_OK || data?.data == null) {
            backupResult?.success(false); backupResult = null; return
        }
        try {
            val uri = data.data!!
            if (requestCode == backupCreateCode) {
                contentResolver.openOutputStream(uri, "wt")!!.use { it.write(backupJson().toString(2).toByteArray(Charsets.UTF_8)) }
            } else {
                val raw = contentResolver.openInputStream(uri)!!.bufferedReader(Charsets.UTF_8).use { it.readText() }
                restoreJson(JSONObject(raw))
            }
            backupResult?.success(true)
        } catch (error: Exception) {
            backupResult?.error("backup_error", error.message ?: "Error de copia.", null)
        }
        backupResult = null
    }

    private fun status(snapshot: String) = mapOf("progress" to snapshot,
        "monitorRunning" to FocusBlockingService.running,
        "permissionsReady" to NativeAccess.canBlock(this),
        "notificationsEnabled" to FocusNotifications.enabled(this), "platform" to "android")
    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == 41) {
            notificationResult?.success(FocusNotifications.enabled(this))
            notificationResult = null
        }
    }
    override fun onDestroy() {
        notificationResult?.error("interrupted", "Solicitação de notificação interrompida.", null)
        notificationResult = null
        super.onDestroy()
    }
}

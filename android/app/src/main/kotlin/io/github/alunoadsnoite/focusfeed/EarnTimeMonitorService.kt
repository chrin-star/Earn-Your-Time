package io.github.alunoadsnoite.focusfeed

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.app.KeyguardManager
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager

/**
 * Explicitly started, low-frequency UsageStats monitor. It does not block apps
 * yet; it is the first real-device tracking milestone.
 */
class EarnTimeMonitorService : Service() {
    companion object {
        @Volatile var running = false
            private set
        private const val NOTIFICATION_ID = 42
        private const val POLL_ACTIVE_MS = 3_000L
        private const val POLL_IDLE_MS = 15_000L
        private const val OVERLAP_MS = 10_000L
    }

    private val main = Handler(Looper.getMainLooper())
    private var processor: EarnTimeUsageEventProcessor? = null
    private var lastQueryWallTime = 0L
    private var destroyed = false
    private var lastSaveElapsed = 0L

    private val poll = object : Runnable {
        override fun run() {
            if (destroyed) return
            try {
                val power = getSystemService(Context.POWER_SERVICE) as PowerManager
                val keyguard = getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
                val usable = power.isInteractive && !keyguard.isKeyguardLocked
                val nowWall = System.currentTimeMillis()
                val nowElapsed = android.os.SystemClock.elapsedRealtime()
                var delta = EarnTimeUsageDelta()
                if (usable) {
                    val start = if (lastQueryWallTime == 0L) nowWall - 60_000L
                        else maxOf(0L, lastQueryWallTime - OVERLAP_MS)
                    val usage = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
                    val stream = usage.queryEvents(start, nowWall)
                    val events = ArrayList<EarnTimeUsageEventProcessor.ForegroundEvent>()
                    val event = UsageEvents.Event()
                    while (stream.hasNextEvent()) {
                        stream.getNextEvent(event)
                        val type = when (event.eventType) {
                            UsageEvents.Event.ACTIVITY_RESUMED,
                            UsageEvents.Event.MOVE_TO_FOREGROUND ->
                                EarnTimeUsageEventProcessor.EventType.RESUMED
                            UsageEvents.Event.ACTIVITY_PAUSED,
                            UsageEvents.Event.MOVE_TO_BACKGROUND ->
                                EarnTimeUsageEventProcessor.EventType.PAUSED
                            else -> null
                        } ?: continue
                        events += EarnTimeUsageEventProcessor.ForegroundEvent(
                            type, event.packageName, event.className, event.timeStamp
                        )
                    }
                    if (processor == null) {
                        val categories = EarnTimeStore.categories(this@EarnTimeMonitorService)
                        processor = EarnTimeUsageEventProcessor(categories.first, categories.second)
                    }
                    delta = processor!!.process(events, nowWall, nowElapsed, true)
                    lastQueryWallTime = nowWall
                } else if (processor == null) {
                    val categories = EarnTimeStore.categories(this@EarnTimeMonitorService)
                    processor = EarnTimeUsageEventProcessor(categories.first, categories.second)
                    delta = processor!!.process(emptyList(), nowWall, nowElapsed, false)
                } else {
                    delta = processor!!.process(emptyList(), nowWall, nowElapsed, false)
                }

                EarnTimeStore.record(this@EarnTimeMonitorService, delta)
                if (nowElapsed - lastSaveElapsed >= 15_000L) lastSaveElapsed = nowElapsed
                main.postDelayed(this, if (usable) POLL_ACTIVE_MS else POLL_IDLE_MS)
            } catch (_: SecurityException) {
                stopSelf()
            } catch (_: Exception) {
                // Keep the service alive; a later UsageStats window may recover.
                main.postDelayed(this, POLL_IDLE_MS)
            }
        }
    }

    override fun onCreate() {
        super.onCreate()
        running = true
        promote()
    }

    private fun promote() {
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= 26) {
            manager.createNotificationChannel(
                NotificationChannel("earn_time_monitor", "Earn Your Time", NotificationManager.IMPORTANCE_LOW)
            )
        }
        val builder = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(this, "earn_time_monitor")
            else @Suppress("DEPRECATION") Notification.Builder(this)
        val notification = builder
            .setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
            .setContentTitle("Earn Your Time")
            .setContentText("Contabilizando el uso de tus aplicaciones seleccionadas")
            .setOngoing(true)
            .setContentIntent(android.app.PendingIntent.getActivity(
                this, 42, Intent(this, MainActivity::class.java),
                android.app.PendingIntent.FLAG_UPDATE_CURRENT or android.app.PendingIntent.FLAG_IMMUTABLE
            ))
            .build()
        if (Build.VERSION.SDK_INT >= 34) {
            startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE)
        } else startForeground(NOTIFICATION_ID, notification)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (!NativeAccess.usage(this)) {
            stopSelf()
            return START_NOT_STICKY
        }
        main.removeCallbacks(poll)
        main.post(poll)
        return START_STICKY
    }

    override fun onDestroy() {
        destroyed = true
        running = false
        main.removeCallbacksAndMessages(null)
        processor?.let {
            try {
                val nowWall = System.currentTimeMillis()
                val nowElapsed = android.os.SystemClock.elapsedRealtime()
                EarnTimeStore.record(this, it.process(emptyList(), nowWall, nowElapsed, false))
            } catch (_: Exception) { }
        }
        stopForeground(STOP_FOREGROUND_REMOVE)
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null
}

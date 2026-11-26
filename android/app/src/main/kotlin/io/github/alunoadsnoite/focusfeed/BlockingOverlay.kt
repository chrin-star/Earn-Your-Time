package io.github.alunoadsnoite.focusfeed

import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.graphics.PixelFormat
import android.hardware.display.DisplayManager
import android.view.Display
import android.os.Build
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView

class BlockingOverlay(private val context: Context) {
    companion object { @Volatile var visible = false; private set }
    @Suppress("DEPRECATION")
    private val type = if (Build.VERSION.SDK_INT >= 26) WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY else WindowManager.LayoutParams.TYPE_PHONE
    private val viewContext = if (Build.VERSION.SDK_INT >= 30) {
        val display = (context.getSystemService(Context.DISPLAY_SERVICE) as DisplayManager).getDisplay(Display.DEFAULT_DISPLAY)
        context.createDisplayContext(display).createWindowContext(type, null)
    } else context
    private val manager = viewContext.getSystemService(Context.WINDOW_SERVICE) as WindowManager
    private var view: LinearLayout? = null
    private var detailView: TextView? = null
    private var headingView: TextView? = null
    private var backButton: Button? = null

    fun show(noBalance: Boolean, detail: String = "") {
        val strings = AppLanguage.resources(context)
        val message = detail.ifEmpty {
            if (noBalance) strings.getString(R.string.block_empty) else ""
        }
        showContent(
            strings.getString(R.string.block_heading),
            message,
            strings.getString(R.string.block_back),
            strings.getString(R.string.block_accessibility, message),
        )
    }

    fun showEarnTime() {
        val strings = AppLanguage.resources(context)
        val message = strings.getString(R.string.earn_block_detail)
        showContent(
            strings.getString(R.string.earn_block_heading),
            message,
            strings.getString(R.string.earn_block_back),
            strings.getString(R.string.earn_block_accessibility, message),
        )
    }

    private fun showContent(heading: String, message: String, backLabel: String, accessibility: String) {
        if (view != null) {
            headingView?.text = heading
            backButton?.text = backLabel
            backButton?.contentDescription = backLabel
            detailView?.text = message
            detailView?.visibility = if (message.isEmpty()) View.GONE else View.VISIBLE
            view?.contentDescription = accessibility
            return
        }
        val layout = LinearLayout(viewContext).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setPadding(32, 64, 32, 64)
            setBackgroundColor(Color.rgb(12, 46, 44))
        }
        val headingText = TextView(viewContext).apply {
            text = heading
            textSize = 26f
            gravity = Gravity.CENTER
            setTextColor(Color.WHITE)
        }
        headingView = headingText
        layout.addView(headingText, LinearLayout.LayoutParams(-1, -2))
        val detailText = TextView(viewContext).apply {
            text = message
            textSize = 16f
            gravity = Gravity.CENTER
            setTextColor(Color.WHITE)
            visibility = if (message.isEmpty()) View.GONE else View.VISIBLE
        }
        layout.addView(detailText, LinearLayout.LayoutParams(-1, -2).apply { topMargin = 24 })
        detailView = detailText
        val back = Button(viewContext).apply {
            text = backLabel
            contentDescription = backLabel
            setOnClickListener {
                try {
                    context.startActivity(Intent(context, MainActivity::class.java).apply {
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
                    })
                    hide()
                } catch (_: Exception) {
                    // Keep the blocker visible if navigation fails.
                }
            }
        }
        backButton = back
        layout.addView(back, LinearLayout.LayoutParams(-1, -2).apply { topMargin = 32 })
        layout.contentDescription = accessibility
        val params = WindowManager.LayoutParams(-1, -1, type,
            WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE,
            PixelFormat.TRANSLUCENT)
        params.title = "EarnYourTimeBlocker"
        manager.addView(layout, params)
        view = layout
        visible = true
    }

    fun hide() {
        val current = view ?: return
        view = null
        detailView = null
        headingView = null
        backButton = null
        visible = false
        try { manager.removeViewImmediate(current) } catch (_: IllegalArgumentException) { }
    }
}

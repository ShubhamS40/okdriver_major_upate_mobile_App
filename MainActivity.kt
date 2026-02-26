package com.dark.assig

import android.content.Context
import android.content.Intent
import android.os.Build
import android.view.View
import androidx.camera.view.PreviewView
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.dark.okdriver/recorder"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

         flutterEngine.platformViewsController.registry.registerViewFactory(
            "camera_preview_view", CameraPreviewFactory()
        )

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            val intent = Intent(this, BackgroundVideoService::class.java)
            when (call.method) {
                "startService" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) startForegroundService(intent)
                    else startService(intent)
                    result.success(true)
                }
                "stopService" -> {
                    stopService(intent)
                    result.success(true)
                }
                "switchCamera" -> {
                    intent.action = "ACTION_SWITCH_CAMERA"
                    startService(intent)
                    result.success(true)
                }
                "updateVisibility" -> {
                    val isVisible = call.argument<Boolean>("visible") ?: true
                    intent.action = "ACTION_UPDATE_VISIBILITY"
                    intent.putExtra("isVisible", isVisible)
                    startService(intent)
                    result.success(true)
                }
                "isRunning" -> result.success(BackgroundVideoService.isServiceRunning)
                else -> result.notImplemented()
            }
        }
    }
}

class CameraPreviewView(context: Context) : PlatformView {
    private val previewView: PreviewView = PreviewView(context)
    init { BackgroundVideoService.currentPreviewView = previewView }
    override fun getView(): View = previewView
    override fun dispose() { BackgroundVideoService.currentPreviewView = null }
}

class CameraPreviewFactory : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    override fun create(context: Context, viewId: Int, args: Any?): PlatformView = CameraPreviewView(context)
}
package com.Hearthio.lite

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.provider.Settings
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var pendingCameraResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            SYSTEM_PERMISSION_CHANNEL,
        ).setMethodCallHandler(::handlePermissionCall)
    }

    private fun handlePermissionCall(call: MethodCall, result: MethodChannel.Result) {
        if (call.method == "openSettings") {
            val intent = Intent(
                Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                Uri.fromParts("package", packageName, null),
            )
            result.success(runCatching { startActivity(intent) }.isSuccess)
            return
        }

        val permission = call.argument<String>("permission")
        when (call.method) {
            "check" -> result.success(permissionStatus(permission))
            "request" -> requestPermission(permission, result)
            else -> result.notImplemented()
        }
    }

    private fun permissionStatus(permission: String?): String = when (permission) {
        "camera" -> {
            if (ContextCompat.checkSelfPermission(this, Manifest.permission.CAMERA) ==
                PackageManager.PERMISSION_GRANTED
            ) {
                "granted"
            } else if (!getPreferences(MODE_PRIVATE).getBoolean(CAMERA_PROMPTED, false)) {
                "notDetermined"
            } else {
                "denied"
            }
        }
        else -> "unavailable"
    }

    private fun requestPermission(permission: String?, result: MethodChannel.Result) {
        if (permission != "camera" || pendingCameraResult != null) {
            result.success("unavailable")
            return
        }
        if (permissionStatus(permission) == "granted") {
            result.success("granted")
            return
        }
        getPreferences(MODE_PRIVATE).edit().putBoolean(CAMERA_PROMPTED, true).apply()
        pendingCameraResult = result
        ActivityCompat.requestPermissions(
            this,
            arrayOf(Manifest.permission.CAMERA),
            CAMERA_PERMISSION_REQUEST,
        )
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != CAMERA_PERMISSION_REQUEST) return
        pendingCameraResult?.success(permissionStatus("camera"))
        pendingCameraResult = null
    }

    companion object {
        private const val SYSTEM_PERMISSION_CHANNEL = "hearthio/system_permissions"
        private const val CAMERA_PERMISSION_REQUEST = 3101
        private const val CAMERA_PROMPTED = "camera_permission_prompted"
    }
}

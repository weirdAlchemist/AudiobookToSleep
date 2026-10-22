package com.weirdalchemist.audiobook_to_sleep

import android.app.Activity
import android.content.Context
import android.hardware.camera2.CameraCharacteristics
import android.hardware.camera2.CameraManager
import android.view.WindowManager
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

// Lights for waving at the camera in the dark (lib/answers/device_light.dart):
// the flashlight, switched on independently of the camera in use, so it also
// works while the front camera watches; and the screen at full brightness.
class DeviceBridge(private val activity: Activity) : MethodChannel.MethodCallHandler {
    companion object {
        const val CHANNEL = "audiobook_to_sleep/device"
    }

    private val cameras = activity.getSystemService(Context.CAMERA_SERVICE) as CameraManager
    private var torchId: String? = null

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "setTorch" -> result.success(
                setTorch(call.argument<Boolean>("on") ?: false, call.argument<String>("prefer") ?: "back")
            )
            "setScreenBrightness" -> {
                // null puts the system brightness back.
                val value = call.argument<Number>("value")?.toFloat()
                    ?: WindowManager.LayoutParams.BRIGHTNESS_OVERRIDE_NONE
                val attributes = activity.window.attributes
                attributes.screenBrightness = value
                activity.window.attributes = attributes
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    // Returns false if there's no flash unit or it can't be switched (e.g. the
    // camera that owns it is open).
    private fun setTorch(on: Boolean, prefer: String): Boolean = try {
        if (!on) {
            torchId?.let { cameras.setTorchMode(it, false) }
            torchId = null
            true
        } else {
            val preferred = if (prefer == "front") CameraCharacteristics.LENS_FACING_FRONT
            else CameraCharacteristics.LENS_FACING_BACK
            val id = cameras.cameraIdList
                .filter { cameras.getCameraCharacteristics(it).get(CameraCharacteristics.FLASH_INFO_AVAILABLE) == true }
                .sortedBy { if (cameras.getCameraCharacteristics(it).get(CameraCharacteristics.LENS_FACING) == preferred) 0 else 1 }
                .firstOrNull()
            if (id == null) {
                false
            } else {
                cameras.setTorchMode(id, true)
                torchId = id
                true
            }
        }
    } catch (e: Exception) {
        false
    }
}

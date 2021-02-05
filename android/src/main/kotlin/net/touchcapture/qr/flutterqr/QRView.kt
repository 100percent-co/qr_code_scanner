package net.touchcapture.qr.flutterqr

import android.Manifest
import android.app.Activity
import android.app.Application
import android.content.pm.PackageManager
import android.os.Bundle
import android.view.View
import com.google.zxing.ResultPoint
import android.hardware.Camera.CameraInfo
import android.os.Build
import com.google.zxing.BarcodeFormat
import com.journeyapps.barcodescanner.BarcodeCallback
import com.journeyapps.barcodescanner.BarcodeResult
import com.journeyapps.barcodescanner.BarcodeView
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.platform.PlatformView
class QRView(messenger: BinaryMessenger, id: Int, private val params: HashMap<String, Any>) :
        PlatformView, MethodChannel.MethodCallHandler {

    private var isTorchOn: Boolean = false
    private var barcodeView: BarcodeView? = null
    private val channel: MethodChannel

    init {
        checkAndRequestPermission(null)
        channel = MethodChannel(messenger, "net.touchcapture.qr.flutterqr/qrview_$id")
        channel.setMethodCallHandler(this)
        Shared.activity?.application?.registerActivityLifecycleCallbacks(object : Application.ActivityLifecycleCallbacks {
            override fun onActivityPaused(p0: Activity) {
                if (p0 == Shared.activity) {
                    barcodeView?.pause()
                }
            }

            override fun onActivityResumed(p0: Activity) {
                if (p0 == Shared.activity) {
                    barcodeView?.resume()
                }
            }

            override fun onActivityStarted(p0: Activity) {
            }

            override fun onActivityDestroyed(p0: Activity) {
            }

            override fun onActivitySaveInstanceState(p0: Activity, p1: Bundle) {
            }

            override fun onActivityStopped(p0: Activity) {
            }

            override fun onActivityCreated(p0: Activity, p1: Bundle?) {
            }
        })
    }

    override fun dispose() {
        barcodeView?.pause()
        barcodeView = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when(call.method) {
            "startScan" -> startScan(call.arguments as? List<Int>, result)
            "stopScan" -> stopScan()
            "flipCamera" -> flipCamera(result)
            "toggleFlash" -> toggleFlash(result)
            "pauseCamera" -> pauseCamera(result)
            // Stopping camera is the same as pausing camera
            "stopCamera" -> pauseCamera(result)
            "resumeCamera" -> resumeCamera(result)
            "requestPermissions" -> checkAndRequestPermission(result)
            "getCameraInfo" -> getCameraInfo(result)
            "getFlashInfo" -> getFlashInfo(result)
            "getSystemFeatures" -> getSystemFeatures(result)
            else -> result.notImplemented()
        }
    }

    private fun getCameraInfo(result: MethodChannel.Result) {
        if (barcodeView == null) {
            return barCodeViewNotSet(result)
        }
        result.success(barcodeView!!.cameraSettings.requestedCameraId)
    }

    private fun flipCamera(result: MethodChannel.Result) {
        if (barcodeView == null) {
            return barCodeViewNotSet(result)
        } else if (!hasCameraPermission()) {
            return cameraPermissionNotSet(result)
        }

        barcodeView!!.pause()
        val settings = barcodeView!!.cameraSettings

        if(settings.requestedCameraId == CameraInfo.CAMERA_FACING_FRONT)
            settings.requestedCameraId = CameraInfo.CAMERA_FACING_BACK
        else
            settings.requestedCameraId = CameraInfo.CAMERA_FACING_FRONT

        barcodeView!!.cameraSettings = settings
        barcodeView!!.resume()
        result.success(settings.requestedCameraId)
    }

    private fun getFlashInfo(result: MethodChannel.Result) {
        if (barcodeView == null) {
            return barCodeViewNotSet(result)
        }
        result.success(isTorchOn)
    }

    private fun toggleFlash(result: MethodChannel.Result) {
        if (barcodeView == null) {
            return barCodeViewNotSet(result)
        } else if (!hasCameraPermission()) {
            return cameraPermissionNotSet(result)
        }

        if (hasFlash()) {
            barcodeView!!.setTorch(!isTorchOn)
            isTorchOn = !isTorchOn
            result.success(isTorchOn)
        } else {
            result.error("404", "This device doesn't support flash", null)
        }

    }

    private fun pauseCamera(result: MethodChannel.Result) {
        if (barcodeView == null) {
            return barCodeViewNotSet(result)
        } else if (!hasCameraPermission()) {
            return cameraPermissionNotSet(result)
        }

        if (barcodeView!!.isPreviewActive) {
            barcodeView!!.pause()
        }
        result.success(true)
    }

    private fun resumeCamera(result: MethodChannel.Result) {
        if (barcodeView == null) {
            return barCodeViewNotSet(result)
        } else if (!hasCameraPermission()) {
            return cameraPermissionNotSet(result)
        }

        if (!barcodeView!!.isPreviewActive) {
            barcodeView!!.resume()
        }
        result.success(true)
    }

    private fun hasFlash(): Boolean {
        return hasSystemFeature(PackageManager.FEATURE_CAMERA_FLASH)
    }

    private fun hasBackCamera(): Boolean {
        return hasSystemFeature(PackageManager.FEATURE_CAMERA)
    }

    private fun hasFrontCamera(): Boolean {
        return hasSystemFeature(PackageManager.FEATURE_CAMERA_FRONT)
    }

    private fun hasSystemFeature(feature: String): Boolean {
        return Shared.activity!!.packageManager
                .hasSystemFeature(feature)
    }

    private fun barCodeViewNotSet(result: MethodChannel.Result) {
        result.error("404", "No barcode view found", null)
    }

    private fun cameraPermissionNotSet(result: MethodChannel.Result) {
         result.error("cameraPermission", " Permission denied to access the camera", null)
    }

    override fun getView(): View {
        return initBarCodeView().apply {}!!
    }

    private fun initBarCodeView(): BarcodeView? {
        if (barcodeView == null) {
            barcodeView = BarcodeView(Shared.activity)
            if (params["cameraFacing"] as Int == 1) {
                barcodeView?.cameraSettings?.requestedCameraId = CameraInfo.CAMERA_FACING_FRONT
            }
            barcodeView!!.resume()
        }
        return barcodeView
    }

    private fun startScan(arguments: List<Int>?, result: MethodChannel.Result) {
        if (!hasCameraPermission()) {
            return cameraPermissionNotSet(result)
        }

        val allowedBarcodeTypes = mutableListOf<BarcodeFormat>()
        try {
            arguments?.forEach {
                allowedBarcodeTypes.add(BarcodeFormat.values()[it])
            }
        } catch (e: java.lang.Exception) {
            result.error(null, null, null)
        }

        barcodeView?.decodeContinuous(
                object : BarcodeCallback {
                    override fun barcodeResult(result: BarcodeResult) {
                        if (allowedBarcodeTypes.size == 0 || allowedBarcodeTypes.contains(result.barcodeFormat)) {
                            val code = mapOf(
                                    "code" to result.text,
                                    "type" to result.barcodeFormat.name,
                                    "rawBytes" to result.rawBytes)
                            channel.invokeMethod("onRecognizeQR", code)
                        }

                    }

                    override fun possibleResultPoints(resultPoints: List<ResultPoint>) {}
                }
        )
    }

    private fun stopScan() {
        barcodeView?.stopDecoding()
    }

    private fun getSystemFeatures(result: MethodChannel.Result) {
        try {
            result.success(mapOf("hasFrontCamera" to hasFrontCamera(),
                    "hasBackCamera" to hasBackCamera(), "hasFlash" to hasFlash(),
                    "activeCamera" to barcodeView?.cameraSettings?.requestedCameraId))
        } catch (e: Exception) {
            result.error(null, null, null)
        }
    }

    private fun hasCameraPermission(): Boolean {
        return Build.VERSION.SDK_INT < Build.VERSION_CODES.M ||
                Shared.activity?.checkSelfPermission(Manifest.permission.CAMERA) == PackageManager.PERMISSION_GRANTED
    }

    private fun checkAndRequestPermission(result: MethodChannel.Result?) {
        when {
            hasCameraPermission() -> result?.success(true)
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.M -> {
                Shared.activity?.requestPermissions(
                        arrayOf(Manifest.permission.CAMERA),
                        Shared.CAMERA_REQUEST_ID)
            }
            else -> {
                result?.error("cameraPermission", "Platform Version to low for camera permission check", null)
            }
        }
    }
}


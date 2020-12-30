//
//  QRView.swift
//  flutter_qr
//
//  Created by Julius Canute on 21/12/18.
//

import Foundation
import MTBBarcodeScanner

public class QRView:NSObject,FlutterPlatformView {
    @IBOutlet var previewView: UIView!
    var scanner: MTBBarcodeScanner?
    var registrar: FlutterPluginRegistrar
    var channel: FlutterMethodChannel
    var cameraFacing: MTBCamera
    
    var allowedBarcodeTypes: Array<AVMetadataObject.ObjectType> = []
    
    var QRCodeTypes = [
          0: AVMetadataObject.ObjectType.aztec,
          1: AVMetadataObject.ObjectType.code128,
          2: AVMetadataObject.ObjectType.code39,
          3: AVMetadataObject.ObjectType.code93,
          4: AVMetadataObject.ObjectType.dataMatrix,
          5: AVMetadataObject.ObjectType.ean13,
          6: AVMetadataObject.ObjectType.ean8,
          7: AVMetadataObject.ObjectType.interleaved2of5,
          8: AVMetadataObject.ObjectType.pdf417,
          9: AVMetadataObject.ObjectType.qr,
          10: AVMetadataObject.ObjectType.upce
         ]
    
    public init(withFrame frame: CGRect, withRegistrar registrar: FlutterPluginRegistrar, withId id: Int64, params: Dictionary<String, Any>){
        self.registrar = registrar
        previewView = UIView(frame: frame)
        cameraFacing = MTBCamera.init(rawValue: UInt(Int(params["cameraFacing"] as! Double))) ?? MTBCamera.back
        channel = FlutterMethodChannel(name: "net.touchcapture.qr.flutterqr/qrview_\(id)", binaryMessenger: registrar.messenger())
    }
    
    deinit {
        scanner?.stopScanning()
    }
    
    public func view() -> UIView {
        channel.setMethodCallHandler({
            [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
            switch(call.method){
                case "setDimensions":
                    let arguments = call.arguments as! Dictionary<String, Double>
                    self?.setDimensions(width: arguments["width"] ?? 0, height: arguments["height"] ?? 0, scanArea: arguments["scanArea"] ?? 0)
                case "startScan":
                    self?.startScan(result)
                case "flipCamera":
                    self?.flipCamera(result)
                case "toggleFlash":
                    self?.toggleFlash(result)
                case "pauseCamera":
                    self?.pauseCamera(result)
                case "resumeCamera":
                    self?.resumeCamera(result)
                case "getCameraInfo":
                    self?.getCameraInfo(result)
                case "getFlashInfo":
                    self?.getFlashInfo(result)
                case "showNativeAlertDialog":
                    self?.showNativeAlertDialog(result)
                case "getSystemFeatures":
                    self?.getSystemFeatures(result)
                case "setAllowedBarcodeFormats":
                    self?.setBarcodeFormats(call.arguments as! Array<Int>, result)
                default:
                    result(FlutterMethodNotImplemented)
                    return
            }
        })
        return previewView
    }
    
    func setDimensions(width: Double, height: Double, scanArea: Double) -> Void {
        previewView.frame = CGRect(x: 0, y: 0, width: width, height: height)
        let midX = self.view().bounds.midX
        let midY = self.view().bounds.midY
        if let sc: MTBBarcodeScanner = scanner {
            if let previewLayer = sc.previewLayer {
                previewLayer.frame = previewView.bounds;
            }
        } else {
            scanner = MTBBarcodeScanner(previewView: previewView)
            
            if (scanArea != 0) {
                scanner?.didStartScanningBlock = {
                    self.scanner?.scanRect = CGRect(x: Double(midX) - (scanArea / 2), y: Double(midY) - (scanArea / 2), width: scanArea, height: scanArea)
                }
            }
        }
    }
    
    func startScan(_ result: @escaping FlutterResult) -> Void {
        scanner = MTBBarcodeScanner(previewView: previewView)
        
        MTBBarcodeScanner.requestCameraPermission(success: { permissionGranted in
            if permissionGranted {
                do {
                    try self.scanner?.startScanning(with: self.cameraFacing, resultBlock: { [weak self] codes in
                        if let codes = codes {
                            for code in codes {
                                var typeString: String;
                                switch(code.type) {
                                    case AVMetadataObject.ObjectType.aztec:
                                       typeString = "AZTEC"
                                    case AVMetadataObject.ObjectType.code39:
                                        typeString = "CODE_39"
                                    case AVMetadataObject.ObjectType.code93:
                                        typeString = "CODE_93"
                                    case AVMetadataObject.ObjectType.code128:
                                        typeString = "CODE_128"
                                    case AVMetadataObject.ObjectType.dataMatrix:
                                        typeString = "DATA_MATRIX"
                                    case AVMetadataObject.ObjectType.ean8:
                                        typeString = "EAN_8"
                                    case AVMetadataObject.ObjectType.ean13:
                                        typeString = "EAN_13"
                                    case AVMetadataObject.ObjectType.itf14:
                                        typeString = "ITF"
                                    case AVMetadataObject.ObjectType.pdf417:
                                        typeString = "PDF_417"
                                    case AVMetadataObject.ObjectType.qr:
                                        typeString = "QR_CODE"
                                    case AVMetadataObject.ObjectType.upce:
                                        typeString = "UPC_E"
                                    default:
                                        return
                                }
                                guard let stringValue = code.stringValue else { continue }
                                let result = ["code": stringValue, "type": typeString]
                                if self!.allowedBarcodeTypes.count == 0 || self!.allowedBarcodeTypes.contains(code.type) {
                                    self?.channel.invokeMethod("onRecognizeQR", arguments: result)
                                }
                                
                            }
                        }
                    })
                } catch {
                    let error = FlutterError(code: "unknown-error", message: "Unable to start scanning", details: nil)
                    result(error)
                }
            } else {
                let error = FlutterError(code: "cameraPermission", message: "Permission denied to access the camera", details: nil)
                result(error)
            }
        })
    }
    
    func stopScan(){
        if let sc: MTBBarcodeScanner = scanner {
            if sc.isScanning() {
                sc.stopScanning()
            }
        }
    }
    
    func getCameraInfo(_ result: @escaping FlutterResult) -> Void {
        if let sc: MTBBarcodeScanner = scanner {
            result(sc.camera.rawValue)
        } else {
            let error = FlutterError(code: "cameraInformationError", message: "Could not get camera information", details: nil)
            result(error)
        }
    }
    
    func flipCamera(_ result: @escaping FlutterResult){
        if let sc: MTBBarcodeScanner = scanner {
            if sc.hasOppositeCamera() {
                sc.flipCamera()
            }
            return result(sc.camera.rawValue)
        }
        return result(FlutterError(code: "404", message: "No barcode scanner found", details: nil))
    }
    
    func getFlashInfo(_ result: @escaping FlutterResult) -> Void {
        if let sc: MTBBarcodeScanner = scanner {
            result(sc.torchMode.rawValue != 0)
        } else {
            let error = FlutterError(code: "cameraInformationError", message: "Could not get flash information", details: nil)
            result(error)
        }
    }
    
    func toggleFlash(_ result: @escaping FlutterResult){
        if let sc: MTBBarcodeScanner = scanner {
            if sc.hasTorch() {
                sc.toggleTorch()
                return result(sc.torchMode == MTBTorchMode(rawValue: 1))
            }
            return result(FlutterError(code: "404", message: "This device doesn\'t support flash", details: nil))
        }
        return result(FlutterError(code: "404", message: "No barcode scanner found", details: nil))
    }
    
    func pauseCamera(_ result: @escaping FlutterResult) {
        if let sc: MTBBarcodeScanner = scanner {
            if sc.isScanning() {
                sc.freezeCapture()
            }
            return result(true)
        }
        return result(FlutterError(code: "404", message: "No barcode scanner found", details: nil))
    }
    
    func resumeCamera(_ result: @escaping FlutterResult) {
        if let sc: MTBBarcodeScanner = scanner {
            if !sc.isScanning() {
                sc.unfreezeCapture()
            }
            return result(true)
        }
        return result(FlutterError(code: "404", message: "No barcode scanner found", details: nil))
    }
    
    func showNativeAlertDialog(_ result: @escaping FlutterResult) -> Void {
        UIAlertView(title: "Scanning Unavailable", message: "This app does not have permission to access the camera", delegate: nil, cancelButtonTitle: nil, otherButtonTitles: "Ok").show()
        return result(true)
    }

    func getSystemFeatures(_ result: @escaping FlutterResult) -> Void {
        if let sc: MTBBarcodeScanner = scanner {
            var hasBackCameraVar = false
            var hasFrontCameraVar = false
            let camera = sc.camera

            if(camera == MTBCamera(rawValue: 0)){
                hasBackCameraVar = true
                if sc.hasOppositeCamera() {
                    hasFrontCameraVar = true
                }
            }else{
                hasFrontCameraVar = true
                if sc.hasOppositeCamera() {
                    hasBackCameraVar = true
                }
            }
            return result([
                "hasFrontCamera": hasFrontCameraVar,
                "hasBackCamera": hasBackCameraVar,
                "hasFlash": sc.hasTorch(),
                "activeCamera": camera.rawValue
            ])
        }
        return result(FlutterError(code: "404", message: nil, details: nil))
    }

    func setBarcodeFormats(_ arguments: Array<Int>, _ result: @escaping FlutterResult){
        do{
            allowedBarcodeTypes.removeAll()
            try arguments.forEach { arg in
                allowedBarcodeTypes.append(try QRCodeTypes[arg]!)
            }
            result(true)
        }catch{
            result(FlutterError(code: "404", message: nil, details: nil))
        }
    }
 }

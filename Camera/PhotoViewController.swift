//
//  PhotoViewController.swift
//  Camera
//
//  Created by bytedance on 2021/11/2.
//

import UIKit
import AVFoundation
import SnapKit
import Photos

enum CaptureMode {
    case singlePhoto
    case seriesPhoto
    case livePhoto
}

class PhotoViewController: UIViewController {
    
    var session = AVCaptureSession()
    
    var videoDevice: AVCaptureDevice!
    
    var photoOutput = AVCapturePhotoOutput()
    
    var mode: CaptureMode = .livePhoto
    
    var photoPreview = UIImageView(frame: .zero)
    
    var livePhotoURL: URL?
    
    var photoData: Data?
    
    var matteDataArr = [Data]()
    
    var settings = AVCapturePhotoSettings()
    
    lazy var context = CIContext()

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        
        session.beginConfiguration()
        
        session.sessionPreset = .photo
        
        do {
            let discoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInDualCamera, .builtInDualWideCamera, .builtInWideAngleCamera], mediaType: .video, position: .unspecified)
            guard let videoDevice = discoverySession.devices.first else {
                print("没摄像头啊")
                session.commitConfiguration()
                return
            }
            
            self.videoDevice = videoDevice
            
            let videoDeviceInput = try AVCaptureDeviceInput(device: videoDevice)
            
            if session.canAddInput(videoDeviceInput) {
                session.addInput(videoDeviceInput)
            } else {
                print("加不了镜头")
                session.commitConfiguration()
                return
            }
        } catch {
            print("镜头输出不了")
            session.commitConfiguration()
            return
        }
        
        do {
            guard let audioDevice = AVCaptureDevice.default(for: .audio) else {
                print("没麦克风啊")
                session.commitConfiguration()
                return
            }
            let audioDeviceInput = try AVCaptureDeviceInput(device: audioDevice)
            
            if session.canAddInput(audioDeviceInput) {
                session.addInput(audioDeviceInput)
            } else {
                print("加不了麦克风")
                session.commitConfiguration()
                return
            }
        } catch {
            print("麦克风没输出")
            session.commitConfiguration()
            return
        }
        
        if session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
            
            photoOutput.isHighResolutionCaptureEnabled = true
            photoOutput.isLivePhotoCaptureEnabled = photoOutput.isLivePhotoCaptureSupported
            photoOutput.isDepthDataDeliveryEnabled = photoOutput.isDepthDataDeliverySupported
            //12 pro机型支持
            photoOutput.isAppleProRAWEnabled = photoOutput.isAppleProRAWSupported
            photoOutput.maxPhotoQualityPrioritization = .quality
            photoOutput.isPortraitEffectsMatteDeliveryEnabled = photoOutput.isPortraitEffectsMatteDeliverySupported
            photoOutput.enabledSemanticSegmentationMatteTypes = photoOutput.availableSemanticSegmentationMatteTypes
        }
        
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.frame = view.bounds
        view.layer.addSublayer(previewLayer)
        
        session.commitConfiguration()
        session.startRunning()
        
        view.isUserInteractionEnabled = true
        view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(takePhoto(gesture:))))
        view.addGestureRecognizer(UIPinchGestureRecognizer(target: self, action: #selector(scaleControl(gesture:))))
        
        photoPreview.layer.borderColor = UIColor.white.cgColor
        photoPreview.layer.borderWidth = 3.0
        photoPreview.layer.cornerRadius = 8.0
        photoPreview.layer.masksToBounds = true
        photoPreview.alpha = 0.0
        self.view.addSubview(photoPreview)
        photoPreview.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.height.width.equalToSuperview().multipliedBy(0.5)
        }
        
//        torchControl()
    }
    
    @objc func scaleControl(gesture: UIPinchGestureRecognizer) {
        if gesture.state == .began {
            gesture.scale = 1.0
            return
        }
        let zoom = max(min(videoDevice.videoZoomFactor * gesture.scale, videoDevice.maxAvailableVideoZoomFactor), videoDevice.minAvailableVideoZoomFactor)
        do {
            try videoDevice.lockForConfiguration()
            videoDevice.ramp(toVideoZoomFactor: zoom, withRate: 10.0)
            videoDevice.unlockForConfiguration()
        } catch {
            print(error.localizedDescription)
        }
    }
    
    @objc func takePhoto(gesture: UITapGestureRecognizer) {
        
        switch mode {
        case .singlePhoto:
            settings = AVCapturePhotoSettings()
        case .seriesPhoto:
            guard let rawFormat = photoOutput.availableRawPhotoPixelFormatTypes.first else {
                return
            }
            let bracketSettings = AVCapturePhotoBracketSettings(rawPixelFormatType: rawFormat, processedFormat: nil, bracketedSettings: [
                AVCaptureAutoExposureBracketedStillImageSettings.autoExposureSettings(exposureTargetBias: -2),
                AVCaptureAutoExposureBracketedStillImageSettings.autoExposureSettings(exposureTargetBias: 0),
                AVCaptureAutoExposureBracketedStillImageSettings.autoExposureSettings(exposureTargetBias: 2)])
            bracketSettings.isLensStabilizationEnabled = true
            settings = bracketSettings
        case .livePhoto:
            settings = AVCapturePhotoSettings()
            settings.isHighResolutionPhotoEnabled = true
            settings.livePhotoMovieFileURL = URL(fileURLWithPath: "\(NSTemporaryDirectory())/\(settings.uniqueID).mov")
        }
        settings.enabledSemanticSegmentationMatteTypes = photoOutput.enabledSemanticSegmentationMatteTypes
        settings.isPortraitEffectsMatteDeliveryEnabled = photoOutput.isPortraitEffectsMatteDeliveryEnabled
        photoOutput.capturePhoto(with: settings, delegate: self)
    }
    
    func torchControl() {
        do {
            try videoDevice.lockForConfiguration()
            videoDevice.torchMode = .on
            videoDevice.unlockForConfiguration()
        } catch {
            print(error.localizedDescription)
        }
    }
    
    
}

extension PhotoViewController: AVCapturePhotoCaptureDelegate {
    //拍摄输出已解析设置，并将很快开始拍照流程
    func photoOutput(_ output: AVCapturePhotoOutput, willBeginCaptureFor resolvedSettings: AVCaptureResolvedPhotoSettings) {
        //如果请求将flashMode属性设置为AVCaptureFlashModeAuto进行拍摄，则已解析的照片设置flashEnabled属性指示在拍摄期间是否会触发闪光灯
        print("很快开始拍照流程", resolvedSettings.isFlashEnabled)
    }
    
    //即将拍摄照片,若有快门声，快门声后立即调用
    func photoOutput(_ output: AVCapturePhotoOutput, willCapturePhotoFor resolvedSettings: AVCaptureResolvedPhotoSettings) {
        print("即将拍摄")
    }
    
    //已拍摄照片, 曝光结束立即调用
    func photoOutput(_ output: AVCapturePhotoOutput, didCapturePhotoFor resolvedSettings: AVCaptureResolvedPhotoSettings) {
        print("已拍摄")
    }
    
    //拍摄完成,整个过程完成后调用，此后不再调用任何协议方法
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishCaptureFor resolvedSettings: AVCaptureResolvedPhotoSettings, error: Error?) {
        print("结束拍照流程")
        
        guard let imageData = photoData else {
            return
        }
        
        photoData = nil
        
        PHPhotoLibrary.shared().performChanges {
            let creationRequest = PHAssetCreationRequest.forAsset()
            let options = PHAssetResourceCreationOptions()
            options.uniformTypeIdentifier = self.settings.processedFileType.map { $0.rawValue }
            creationRequest.addResource(with: .photo, data: imageData, options: options)
            if let liveURL = self.livePhotoURL {
                self.livePhotoURL = nil
                let options = PHAssetResourceCreationOptions()
                options.shouldMoveFile = true
                creationRequest.addResource(with: .pairedVideo, fileURL: liveURL, options: options)
            }
            
            for data in self.matteDataArr {
                let creationRequest = PHAssetCreationRequest.forAsset()
                creationRequest.addResource(with: .photo, data: data, options: nil)
            }
            
            self.matteDataArr.removeAll()
        } completionHandler: { success, error in
            print(success, error?.localizedDescription as Any)
        }
    }
    
    //静态照片回调 AVCapturePhoto实例包装单个图像结果。 例如，如果请求对3张图像进行拍摄，则回调将被调用3次，每次都会传送一个AVCapturePhoto对象。
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        print("拍到一张")
        
        photoData = photo.fileDataRepresentation()
        
        handleMatteData(photo, ssmType: nil)
        for type in output.availableSemanticSegmentationMatteTypes {
            handleMatteData(photo, ssmType: type)
        }
        
        guard let imageData = photo.fileDataRepresentation() else {
            return
        }
        
        guard let image = UIImage(data: imageData) else {
            return
        }
        
        DispatchQueue.main.async { [weak self] in
            self?.photoPreview.image = image
            self?.photoPreview.alpha = 1.0
            UIView.animate(withDuration: 0.5, delay: 2.0, options: .transitionCurlDown, animations: {[weak self] in
                self?.photoPreview.alpha = 0.0
            }, completion: nil)
        }
    }
    
    //动态照片回调
    //DidFinishRecordingLive
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishRecordingLivePhotoMovieForEventualFileAt outputFileURL: URL, resolvedSettings: AVCaptureResolvedPhotoSettings) {
        print("DidFinishRecordingLive")
    }
    
    //DidFinishProcessingLive
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingLivePhotoToMovieFileAt outputFileURL: URL, duration: CMTime, photoDisplayTime: CMTime, resolvedSettings: AVCaptureResolvedPhotoSettings, error: Error?) {
        print("DidFinishProcessingLive")
        if error != nil {
            print("Error processing Live Photo companion movie: \(String(describing: error))")
            return
        }
        livePhotoURL = outputFileURL
    }
    
    func handleMatteData(_ photo: AVCapturePhoto, ssmType: AVSemanticSegmentationMatte.MatteType?) {
        
        guard let perceptualColorSpace = CGColorSpace(name: CGColorSpace.sRGB) else { return }
        
        if let type = ssmType {
            guard var segmentationMatte = photo.semanticSegmentationMatte(for: type) else { return }
            
            if let orientation = photo.metadata[String(kCGImagePropertyOrientation)] as? UInt32,
                let exifOrientation = CGImagePropertyOrientation(rawValue: orientation) {
                // Apply the Exif orientation to the matte image.
                segmentationMatte = segmentationMatte.applyingExifOrientation(exifOrientation)
            }
            
            var imageOption: CIImageOption!
            
            // Switch on the AVSemanticSegmentationMatteType value.
            switch type {
            case .hair:
                imageOption = .auxiliarySemanticSegmentationHairMatte
            case .skin:
                imageOption = .auxiliarySemanticSegmentationSkinMatte
            case .teeth:
                imageOption = .auxiliarySemanticSegmentationTeethMatte
            case .glasses:
                imageOption = .auxiliarySemanticSegmentationGlassesMatte
            default:
                print("This semantic segmentation type is not supported!")
                return
            }
            
            let ciImage = CIImage( cvImageBuffer: segmentationMatte.mattingImage,
                                   options: [imageOption: true,
                                             .colorSpace: perceptualColorSpace])
            
            guard let imageData = context.heifRepresentation(of: ciImage,
                                                             format: .RGBA8,
                                                             colorSpace: perceptualColorSpace,
                                                             options: [.depthImage: ciImage]) else { return }
            
            matteDataArr.append(imageData)
        } else {
            guard var portraitEffectsMatte = photo.portraitEffectsMatte else {
                return
            }
            if let orientation = photo.metadata[ String(kCGImagePropertyOrientation) ] as? UInt32 {
                portraitEffectsMatte = portraitEffectsMatte.applyingExifOrientation(CGImagePropertyOrientation(rawValue: orientation)!)
            }
            
            let portraitEffectsMattePixelBuffer = portraitEffectsMatte.mattingImage
            let portraitEffectsMatteImage = CIImage( cvImageBuffer: portraitEffectsMattePixelBuffer, options: [ .auxiliaryPortraitEffectsMatte: true ] )
                
            if let matteData = context.heifRepresentation(of: portraitEffectsMatteImage,
                                                       format: .RGBA8,
                                                       colorSpace: perceptualColorSpace,
                                                          options: [.portraitEffectsMatteImage: portraitEffectsMatteImage]) {
                matteDataArr.append(matteData)
            }
        }
    }
}

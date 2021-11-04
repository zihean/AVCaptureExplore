//
//  AudioPreviewViewController.swift
//  Camera
//
//  Created by bytedance on 2021/11/2.
//

import UIKit
import AVFoundation

class DepthDataViewController: UIViewController {
    
    var captureSession = AVCaptureSession()
    
    var depthOutput = AVCaptureDepthDataOutput()
    
    var depthImageView = UIImageView()
    
    var photoOutput = AVCapturePhotoOutput()
    
    let captureQueue = DispatchQueue(label: "AVCapture")

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        
        // Select a depth-capable capture device.
        guard let videoDevice = AVCaptureDevice.default(.builtInDualWideCamera,
            for: .video, position: .unspecified)
            else { fatalError("No dual camera.") }
        guard let videoDeviceInput = try? AVCaptureDeviceInput(device: videoDevice),
            self.captureSession.canAddInput(videoDeviceInput)
            else { fatalError("Can't add video input.") }
        self.captureSession.beginConfiguration()
        self.captureSession.addInput(videoDeviceInput)

        
        guard self.captureSession.canAddOutput(photoOutput)
            else { fatalError("Can't add photo output.") }
        self.captureSession.addOutput(photoOutput)
        // Set up photo output for depth data capture.
        photoOutput.isDepthDataDeliveryEnabled = photoOutput.isDepthDataDeliverySupported
//        photoOutput.connection(with: .video)?.videoOrientation = .landscapeLeft
        
        guard self.captureSession.canAddOutput(depthOutput) else {
            self.captureSession.commitConfiguration()
            return
        }
        self.captureSession.addOutput(depthOutput)
        depthOutput.setDelegate(self, callbackQueue: captureQueue)
        if let connection = depthOutput.connection(with: .video) {
            connection.videoOrientation = .landscapeLeft
        }
        
        self.captureSession.sessionPreset = .photo
        self.captureSession.commitConfiguration()
        
        let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.frame = view.bounds
//        previewLayer.connection?.videoOrientation = .landscapeLeft
        view.layer.addSublayer(previewLayer)
        
        depthImageView.frame = view.bounds
        view.addSubview(depthImageView)
        
        self.captureSession.startRunning()
        
        view.isUserInteractionEnabled = true
        view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(getPhoto(gesture:))))
    }
    
    @objc func getPhoto(gesture: UITapGestureRecognizer) {
        let photoSettings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.hevc])
        photoSettings.isDepthDataDeliveryEnabled = photoOutput.isDepthDataDeliverySupported

        photoOutput.capturePhoto(with: photoSettings, delegate: self)
    }
}

extension DepthDataViewController: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        var depthData = photo.depthData

        guard let buffer = depthData?.depthDataMap else {
            return
        }
        
        let ciImage = CIImage(cvImageBuffer: buffer)
        let uiImage = UIImage(ciImage: ciImage)
        
        DispatchQueue.main.async {[weak self] in
            guard let parentView = self?.view else {
                return
            }
            let aView = UIImageView(frame: parentView.bounds)
            aView.image = uiImage
            parentView.addSubview(aView)
            UIView.animate(withDuration: 0.5, delay: 5, options: .curveEaseOut) {
                aView.alpha = 0
            } completion: { _ in
                aView.removeFromSuperview()
            }
        }
    }
}

extension DepthDataViewController: AVCaptureDepthDataOutputDelegate {
    func depthDataOutput(_ output: AVCaptureDepthDataOutput, didOutput depthData: AVDepthData, timestamp: CMTime, connection: AVCaptureConnection) {
        print("来活了")
        let buffer = depthData.depthDataMap
        
        let ciImage = CIImage(cvImageBuffer: buffer)
        let uiImage = UIImage(ciImage: ciImage)
        
        let imageRect = CGRect(origin: .zero, size: uiImage.size)
        let radian = CGFloat(Double.pi / 2)
        let rotatedTransform = CGAffineTransform.identity.rotated(by: radian)
        var rotatedRect = imageRect.applying(rotatedTransform)
        rotatedRect.origin.x = 0
        rotatedRect.origin.y = 0
        UIGraphicsBeginImageContext(rotatedRect.size)
        guard let context = UIGraphicsGetCurrentContext() else { return }
        context.translateBy(x: rotatedRect.width / 2, y: rotatedRect.height / 2)
        context.rotate(by: radian)
        context.translateBy(x: -uiImage.size.width / 2, y: -uiImage.size.height / 2)
        uiImage.draw(at: .zero)
        let rotatedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        DispatchQueue.main.async {[weak self] in
            self?.depthImageView.image = rotatedImage
        }
    }
    
    func depthDataOutput(_ output: AVCaptureDepthDataOutput, didDrop depthData: AVDepthData, timestamp: CMTime, connection: AVCaptureConnection, reason: AVCaptureOutput.DataDroppedReason) {
        print("丢了丢了")
    }
}

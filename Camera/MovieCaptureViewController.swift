//
//  MovieCaptureViewController.swift
//  Camera
//
//  Created by bytedance on 2021/11/2.
//

import UIKit
import AVFoundation
import AVKit
import Vision

class MovieCaptureViewController: UIViewController {
    
    var session = AVCaptureSession()
    
    var fileOutput = AVCaptureMovieFileOutput()
    
    var videoDataOutput = AVCaptureVideoDataOutput()
    var audioDataOutput = AVCaptureAudioDataOutput()
    var assetWriter: AVAssetWriter?
    var assetWriterVideoInput: AVAssetWriterInput?
    var assetWriterAudioInput: AVAssetWriterInput?
    
    var previewLayer: AVCaptureVideoPreviewLayer!
    
    var captureQueue: DispatchQueue!
    var predictQueue = DispatchQueue.global()
    var canWrite = false
    
    var tmpMovieURL1 = URL(fileURLWithPath: NSTemporaryDirectory() + "\\" + "movie1.mp4")
    var tmpMovieURL2 = URL(fileURLWithPath: NSTemporaryDirectory() + "\\" + "movie2.mp4")
    
    var sequenceHandler = VNSequenceRequestHandler()
    var faceView = FaceView()

    override func viewDidLoad() {
        super.viewDidLoad()
        
        //开始配置
        session.beginConfiguration()
        
        session.sessionPreset = .medium
        
        do {
            let discoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInDualCamera, .builtInDualWideCamera, .builtInWideAngleCamera], mediaType: .video, position: .unspecified)
            guard let videoDevice = discoverySession.devices.first else {
                print("没摄像头啊")
                session.commitConfiguration()
                return
            }
            
            for format in videoDevice.formats {
                if format.videoSupportedFrameRateRanges.count > 20 {
                    do {
                        try videoDevice.lockForConfiguration()
                        videoDevice.activeFormat = format
                        videoDevice.unlockForConfiguration()
                    } catch {
                        print(error.localizedDescription)
                    }
                }
            }
            
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
        
//        if session.canAddOutput(fileOutput) {
//            session.addOutput(fileOutput)
//        }
        
        captureQueue = DispatchQueue(label: "AVCapture")
        
        if session.canAddOutput(videoDataOutput) {
            videoDataOutput.setSampleBufferDelegate(self, queue: captureQueue)
            session.addOutput(videoDataOutput)
            
            guard let connection = videoDataOutput.connection(with: .video) else {
                return
            }
            
            connection.videoOrientation = .portrait
        }
        
        if session.canAddOutput(audioDataOutput) {
            audioDataOutput.setSampleBufferDelegate(self, queue: captureQueue)
            session.addOutput(audioDataOutput)
        }
        
        previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.frame = view.bounds
        view.layer.addSublayer(previewLayer)
        
        faceView.backgroundColor = .clear
        faceView.frame = view.bounds
        view.addSubview(faceView)
        
        session.commitConfiguration()
        session.startRunning()
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(tapFired(gesture:)))
        view.addGestureRecognizer(tapGesture)
        view.isUserInteractionEnabled = true
    }
    
    @objc func tapFired(gesture: UITapGestureRecognizer) {
        if fileOutput.isRecording {
            fileOutput.stopRecording()
        } else if fileOutput.connections.count > 0 {
            try? FileManager.default.removeItem(at: tmpMovieURL1)
            fileOutput.startRecording(to: tmpMovieURL1, recordingDelegate: self)
        }
        if let _ = assetWriter {
            captureQueue.async {[weak self] in
                guard let writer = self?.assetWriter, writer.status == .writing else {
                    return
                }
                print("status", self?.assetWriter?.status.rawValue as Any)
                
                self?.assetWriterVideoInput?.markAsFinished()
                self?.assetWriterAudioInput?.markAsFinished()
                
                writer.finishWriting {[weak self] in
                    self?.assetWriterVideoInput = nil
                    self?.assetWriterAudioInput = nil
                    self?.assetWriter = nil
                    print("录制完成2号")
                }
            }
        } else {
            captureQueue.async { [weak self] in
                guard let self = self else {
                    return
                }
                try? FileManager.default.removeItem(at: self.tmpMovieURL2)
                self.assetWriter = try! AVAssetWriter(url: self.tmpMovieURL2, fileType: .mp4)
                self.assetWriterVideoInput = AVAssetWriterInput(mediaType: .video, outputSettings: [
                    AVVideoCodecKey: AVVideoCodecType.h264,
                    AVVideoWidthKey: 720,
                    AVVideoHeightKey: 1280
                ])
                self.assetWriterVideoInput?.expectsMediaDataInRealTime = true
                
                self.assetWriterAudioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: [
                    AVEncoderBitRatePerChannelKey : 28000,
                    AVFormatIDKey : kAudioFormatMPEG4AAC,
                    AVNumberOfChannelsKey : 1,
                    AVSampleRateKey : 22050
                ])
                self.assetWriterAudioInput?.expectsMediaDataInRealTime = true
                
                if self.assetWriter!.canAdd(self.assetWriterVideoInput!) {
                    self.assetWriter!.add(self.assetWriterVideoInput!)
                }
                if self.assetWriter!.canAdd(self.assetWriterAudioInput!) {
                    self.assetWriter!.add(self.assetWriterAudioInput!)
                }
                
                self.canWrite = true
                print("开始录制2号")
            }
        }
    }
}

extension MovieCaptureViewController: AVCaptureFileOutputRecordingDelegate {
    
    func fileOutput(_ output: AVCaptureFileOutput, didStartRecordingTo fileURL: URL, from connections: [AVCaptureConnection]) {
        print("开始录制")
    }
    
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        print("结束录制")
    }
}

extension MovieCaptureViewController: AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate {
    //被丢弃的帧
    func captureOutput(_ output: AVCaptureOutput, didDrop sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
//        print("丢帧了")
    }
    
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        
        if output == videoDataOutput {
//            print("视频帧来了")
            if let assetWriter = assetWriter, assetWriter.status == .unknown {
                assetWriter.startWriting()
                assetWriter.startSession(atSourceTime: sampleBuffer.presentationTimeStamp)
                canWrite = true
            }
            
            if canWrite && assetWriterVideoInput?.isReadyForMoreMediaData ?? false {
                assetWriterVideoInput?.append(sampleBuffer)
            }
            
            let request = VNDetectFaceLandmarksRequest(completionHandler: detectedFace(request:error:))
            
            do {
                try sequenceHandler.perform([request], on: sampleBuffer, orientation: .leftMirrored)
            } catch {
                print(error.localizedDescription)
            }
        }
        
        if output == audioDataOutput {
//            print("音频采样缓存来了")
            if canWrite && assetWriterAudioInput?.isReadyForMoreMediaData ?? false {
                assetWriterAudioInput?.append(sampleBuffer)
            }
        }
    }
}

//人脸
extension MovieCaptureViewController {
    func detectedFace(request: VNRequest, error: Error?) {
      // 1
        guard let results = request.results as? [VNFaceObservation], let result = results.first else {
              // 2
            faceView.clear()
            return
        }
        
      // 3
        updateFaceView(for: result)
    }
    
    func convert(rect: CGRect) -> CGRect {
      // 1
        let origin = previewLayer.layerPointConverted(fromCaptureDevicePoint: rect.origin)
        
        var aPoint = CGPoint(x: rect.origin.x + rect.width, y: rect.origin.y + rect.height)
      
        aPoint = previewLayer.layerPointConverted(fromCaptureDevicePoint: aPoint)
      
      // 3
        return CGRect(origin: origin, size: CGSize(width: aPoint.x - origin.x, height: aPoint.y - origin.y))
    }
    
    func landmark(point: CGPoint, to rect: CGRect) -> CGPoint {
      // 2
        let absolute = CGPoint(x: rect.origin.x + rect.width * point.x, y: rect.origin.y + rect.height * point.y)
      
      // 3
      let converted = previewLayer.layerPointConverted(fromCaptureDevicePoint: absolute)
      
      // 4
      return converted
    }
    
    func landmark(points: [CGPoint]?, to rect: CGRect) -> [CGPoint]? {
      return points?.compactMap { landmark(point: $0, to: rect) }
    }
    
    func updateFaceView(for result: VNFaceObservation) {
      defer {
        DispatchQueue.main.async {
          self.faceView.setNeedsDisplay()
        }
      }

      let box = result.boundingBox
      faceView.boundingBox = convert(rect: box)

      guard let landmarks = result.landmarks else {
        return
      }
        
      if let leftEye = landmark(
        points: landmarks.leftEye?.normalizedPoints,
        to: result.boundingBox) {
        faceView.leftEye = leftEye
      }
        
        if let rightEye = landmark(
          points: landmarks.rightEye?.normalizedPoints,
          to: result.boundingBox) {
          faceView.rightEye = rightEye
        }
            
        if let leftEyebrow = landmark(
          points: landmarks.leftEyebrow?.normalizedPoints,
          to: result.boundingBox) {
          faceView.leftEyebrow = leftEyebrow
        }
            
        if let rightEyebrow = landmark(
          points: landmarks.rightEyebrow?.normalizedPoints,
          to: result.boundingBox) {
          faceView.rightEyebrow = rightEyebrow
        }
            
        if let nose = landmark(
          points: landmarks.nose?.normalizedPoints,
          to: result.boundingBox) {
          faceView.nose = nose
        }
            
        if let outerLips = landmark(
          points: landmarks.outerLips?.normalizedPoints,
          to: result.boundingBox) {
          faceView.outerLips = outerLips
        }
            
        if let innerLips = landmark(
          points: landmarks.innerLips?.normalizedPoints,
          to: result.boundingBox) {
          faceView.innerLips = innerLips
        }
            
        if let faceContour = landmark(
          points: landmarks.faceContour?.normalizedPoints,
          to: result.boundingBox) {
          faceView.faceContour = faceContour
        }
    }
}

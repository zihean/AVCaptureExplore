//
//  MetaInputViewController.swift
//  Camera
//
//  Created by bytedance on 2021/11/2.
//

import UIKit
import AVFoundation
import CoreLocation

class MetaInputViewController: UIViewController {
    
    var captureSession = AVCaptureSession()
    
    var videoDeviceInput: AVCaptureDeviceInput!
    
    var videoLocationInput: AVCaptureMetadataInput!
    
    var movieFileOutput = AVCaptureMovieFileOutput()
    
    let mp4URL = URL(fileURLWithPath: NSTemporaryDirectory() + "\\" + "location.mp4")

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        
        captureSession.beginConfiguration()
        
        let specs = [
            [
                kCMMetadataFormatDescriptionMetadataSpecificationKey_Identifier: AVMetadataIdentifier.quickTimeMetadataLocationISO6709,
                kCMMetadataFormatDescriptionMetadataSpecificationKey_DataType: kCMMetadataDataType_QuickTimeMetadataLocation_ISO6709
            ]
        ]
        
        var desc: CMMetadataFormatDescription? = nil
        CMMetadataFormatDescriptionCreateWithMetadataSpecifications(allocator: kCFAllocatorDefault, metadataType: kCMMetadataFormatType_Boxed, metadataSpecifications: specs as CFArray, formatDescriptionOut: &desc)
        guard let desc = desc else {
            return
        }
        
        videoLocationInput = AVCaptureMetadataInput(formatDescription: desc, clock: CMClock.hostTimeClock)
        
        if captureSession.canAddInput(videoLocationInput) {
            captureSession.addInputWithNoConnections(videoLocationInput)
        }
        
        if captureSession.canAddOutput(movieFileOutput) {
            captureSession.addOutput(movieFileOutput)
        }
        
        let locationPort = videoLocationInput.ports.first!
        let connection = AVCaptureConnection(inputPorts: [locationPort], output: movieFileOutput)
        if captureSession.canAddConnection(connection) {
            captureSession.addConnection(connection)
        }
        
        captureSession.commitConfiguration()
        captureSession.startRunning()
        
        view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(recordControl(gesture:))))
    }
    
    @objc func recordControl(gesture: UITapGestureRecognizer) {
        if movieFileOutput.isRecording {
            movieFileOutput.stopRecording()
        } else {
            movieFileOutput.startRecording(to: mp4URL, recordingDelegate: self)
        }
    }
    
    
    
    func updateLocationInfo() {
        let newLocationMetadataItem = AVMutableMetadataItem()
        newLocationMetadataItem.identifier = AVMetadataIdentifier.quickTimeMetadataLocationISO6709
        newLocationMetadataItem.dataType = kCMMetadataDataType_QuickTimeMetadataLocation_ISO6709 as String
        newLocationMetadataItem.value = CLLocationManager().location!
        let metadataItemGroup = AVTimedMetadataGroup(items: [newLocationMetadataItem], timeRange: CMTimeRange(start: CMClock.hostTimeClock.time, end: CMTime.invalid))
        try? videoLocationInput.append(metadataItemGroup)
    }
    
    
    func connectSpecificMetadataPort(metadataIdentifier: String) {
        for inputPort in videoDeviceInput.ports {
            if let formatDescription = inputPort.formatDescription, formatDescription.mediaType == .metadata {
                let metadataIdentifiers = formatDescription.identifiers
                if metadataIdentifiers.contains(metadataIdentifier) {
                    let connection = AVCaptureConnection(inputPorts: [inputPort], output: self.movieFileOutput)
                    if captureSession.canAddConnection(connection) {
                        captureSession.addConnection(connection)
                    }
                }
            }
        }
    }
}

extension MetaInputViewController: AVCaptureFileOutputRecordingDelegate {
    
    func fileOutput(_ output: AVCaptureFileOutput, didStartRecordingTo fileURL: URL, from connections: [AVCaptureConnection]) {
        print("开始录制")
    }
    
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        print("结束录制")
        
        let playerItem = AVPlayerItem(url: mp4URL)
        
    }
}

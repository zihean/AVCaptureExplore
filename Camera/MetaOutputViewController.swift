//
//  MetaOutputViewController.swift
//  Camera
//
//  Created by bytedance on 2021/11/3.
//

import UIKit
import AVFoundation

class MetaOutputViewController: UIViewController {
    
    var captureSession = AVCaptureSession()
    
    var metaDataOutput = AVCaptureMetadataOutput()
    
    let captureQueue = DispatchQueue(label: "AVCapture")

    override func viewDidLoad() {
        super.viewDidLoad()

        captureSession.beginConfiguration()
        
        guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            captureSession.commitConfiguration()
            return
        }

        guard let videoDeviceInput = try? AVCaptureDeviceInput(device: videoDevice) else {
            captureSession.commitConfiguration()
            return
        }

        guard captureSession.canAddInput(videoDeviceInput) else {
            captureSession.commitConfiguration()
            return
        }
        captureSession.addInput(videoDeviceInput)
        
        metaDataOutput.setMetadataObjectsDelegate(self, queue: captureQueue)
        guard captureSession.canAddOutput(metaDataOutput) else {
            captureSession.commitConfiguration()
            return
        }
        captureSession.addOutput(metaDataOutput)
        metaDataOutput.metadataObjectTypes = metaDataOutput.availableMetadataObjectTypes
        AVMetadataObject.ObjectType.catBody
        
        let preview = AVCaptureVideoPreviewLayer(session: captureSession)
        preview.frame = view.bounds
        view.layer.addSublayer(preview)
        
        captureSession.commitConfiguration()
        captureSession.startRunning()
    }
    

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}

extension MetaOutputViewController: AVCaptureMetadataOutputObjectsDelegate{
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        print("有了有了")
        for metadataObject in metadataObjects {
            print(metadataObject.bounds)
            print(metadataObject.type)
        }
    }
}

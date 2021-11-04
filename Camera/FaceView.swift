//
//  FaceView.swift
//  Camera
//
//  Created by bytedance on 2021/11/4.
//

import UIKit

class FaceView: UIView {
    
    var boundingBox: CGRect = .zero
    
    var leftEye = [CGPoint]()
    
    var rightEye = [CGPoint]()
    
    var leftEyebrow = [CGPoint]()
    
    var rightEyebrow = [CGPoint]()
    
    var nose = [CGPoint]()
    
    var outerLips = [CGPoint]()
    
    var innerLips = [CGPoint]()
    
    var faceContour = [CGPoint]()

    override func draw(_ rect: CGRect) {
        // 1
        guard let context = UIGraphicsGetCurrentContext() else {
          return
        }

        context.clear(self.bounds)
        
        // 2
        context.saveGState()

        // 3
        defer {
          context.restoreGState()
        }
            
        // 4
        context.addRect(boundingBox)

        // 5
        UIColor.red.setStroke()

        // 6
        context.strokePath()
        
        
        UIColor.white.setStroke()
            
        if !leftEye.isEmpty {
          // 2
          context.addLines(between: leftEye)
          
          // 3
          context.closePath()
          
          // 4
          context.strokePath()
        }
        
        if !rightEye.isEmpty {
          context.addLines(between: rightEye)
          context.closePath()
          context.strokePath()
        }
            
        if !leftEyebrow.isEmpty {
          context.addLines(between: leftEyebrow)
          context.strokePath()
        }
            
        if !rightEyebrow.isEmpty {
          context.addLines(between: rightEyebrow)
          context.strokePath()
        }
        
        if !nose.isEmpty {
          context.addLines(between: nose)
          context.strokePath()
        }
            
        if !outerLips.isEmpty {
          context.addLines(between: outerLips)
          context.closePath()
          context.strokePath()
        }
            
        if !innerLips.isEmpty {
          context.addLines(between: innerLips)
          context.closePath()
          context.strokePath()
        }
            
        if !faceContour.isEmpty {
          context.addLines(between: faceContour)
          context.strokePath()
        }
    }

    func clear() {
        defer {
          DispatchQueue.main.async {
            self.setNeedsDisplay()
          }
        }
        
        boundingBox = .zero
        leftEye.removeAll()
        rightEye.removeAll()
        leftEyebrow.removeAll()
        rightEyebrow.removeAll()
        nose.removeAll()
        outerLips.removeAll()
        innerLips.removeAll()
        faceContour.removeAll()
    }
}

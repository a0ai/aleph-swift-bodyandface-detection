import UIKit
import Vision

class FaceView: UIView {
  var leftEye: [CGPoint] = []
  var rightEye: [CGPoint] = []
  var leftEyebrow: [CGPoint] = []
  var rightEyebrow: [CGPoint] = []
  var nose: [CGPoint] = []
  var outerLips: [CGPoint] = []
  var innerLips: [CGPoint] = []
  var faceContour: [CGPoint] = []

  var boundingBox = CGRect.zero
  var diagonal: [CGPoint] = []
  
  func clear() {
    leftEye = []
    rightEye = []
    leftEyebrow = []
    rightEyebrow = []
    nose = []
    outerLips = []
    innerLips = []
    faceContour = []
    
    boundingBox = .zero
    
    DispatchQueue.main.async {
      self.setNeedsDisplay()
    }
  }
  
  override func draw(_ rect: CGRect) {
    // 1
    guard let context = UIGraphicsGetCurrentContext() else {
      return
    }

    // 2
    context.saveGState()

    // 3
    defer {
      context.restoreGState()
    }
    
    
    UIColor.blue.setStroke()
    
    let topleftPoint = CGPoint(x:floor(boundingBox.origin.x), y:floor(boundingBox.origin.y))
    let topleftstring = NSCoder.string(for: topleftPoint)
    let font = UIFont.systemFont(ofSize: 12)
    let string = NSAttributedString(string: topleftstring, attributes: [NSAttributedString.Key.font: font, NSAttributedString.Key.foregroundColor: UIColor.green])
    string.draw(at: boundingBox.origin)
    
    
    // 4
    context.addRect(boundingBox)

    
    
    // 5
    UIColor.red.setStroke()
    // 6
    context.strokePath()

    // 1
    UIColor.white.setStroke()

    if !leftEye.isEmpty {
      
      context.addLines(between: leftEye)
      context.closePath()
      let leftEyeBox = context.boundingBoxOfPath
      context.strokePath()
      
      let topleftEyePoint = CGPoint(x:floor(leftEyeBox.origin.x), y:floor(leftEyeBox.origin.y))
      let topleftEyeString = NSCoder.string(for: topleftEyePoint)
      let string = NSAttributedString(string: topleftEyeString, attributes: [NSAttributedString.Key.font: font, NSAttributedString.Key.foregroundColor: UIColor.green])
      string.draw(at: leftEyeBox.origin)
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
}

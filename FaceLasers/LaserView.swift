

import UIKit

struct Laser {
  var origin: CGPoint
  var focus: CGPoint
}

class LaserView: UIView {
  private var lasers: [Laser] = []
  
  func add(laser: Laser) {
    lasers.append(laser)
  }
  
  func clear() {
    lasers.removeAll()
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
    for laser in lasers {
      // 4
      context.addLines(between: [laser.origin, laser.focus])

      context.setStrokeColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.5)
      context.setLineWidth(4.5)
      context.strokePath()

      // 5
      context.addLines(between: [laser.origin, laser.focus])

      context.setStrokeColor(red: 1.0, green: 0.0, blue: 0.0, alpha: 0.8)
      context.setLineWidth(3.0)
      context.strokePath()
    }

    // 6
    context.restoreGState()
  }
}

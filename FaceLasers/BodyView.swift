

import UIKit


class BodyView: UIView {
  
  var bodyRect = CGRect.zero
  
  func clear() {
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

    context.addRect(bodyRect)
    // 6
    context.restoreGState()
  }
}

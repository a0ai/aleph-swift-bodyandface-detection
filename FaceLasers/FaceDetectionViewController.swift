/// Copyright (c) 2019 Razeware LLC
///
/// Permission is hereby granted, free of charge, to any person obtaining a copy
/// of this software and associated documentation files (the "Software"), to deal
/// in the Software without restriction, including without limitation the rights
/// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
/// copies of the Software, and to permit persons to whom the Software is
/// furnished to do so, subject to the following conditions:
///
/// The above copyright notice and this permission notice shall be included in
/// all copies or substantial portions of the Software.
///
/// Notwithstanding the foregoing, you may not use, copy, modify, merge, publish,
/// distribute, sublicense, create a derivative work, and/or sell copies of the
/// Software in any work that is designed, intended, or marketed for pedagogical or
/// instructional purposes related to programming, coding, application development,
/// or information technology.  Permission for such use, copying, modification,
/// merger, publication, distribution, sublicensing, creation of derivative works,
/// or sale is expressly withheld.
///
/// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
/// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
/// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
/// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
/// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
/// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
/// THE SOFTWARE.

import AVFoundation
import UIKit
import Vision

class FaceDetectionViewController: UIViewController {
  var sequenceHandler = VNSequenceRequestHandler()

  @IBOutlet var faceView: FaceView!
  @IBOutlet var laserView: LaserView!
  @IBOutlet var faceBodyLabel: UILabel!
  
  var captureSession: AVCaptureSession?
  var previewLayer: AVCaptureVideoPreviewLayer!
  var currentCaptureDevice: AVCaptureDevice?
  var videoOutput: AVCaptureVideoDataOutput!
  let dataOutputQueue = DispatchQueue(
    label: "video data queue",
    qos: .userInitiated,
    attributes: [],
    autoreleaseFrequency: .workItem)

  var faceDetection = true
  
  var maxX: CGFloat = 0.0
  var midY: CGFloat = 0.0
  var maxY: CGFloat = 0.0
   
  
  override func viewDidLoad() {
    super.viewDidLoad()
    /*maxX = view.bounds.maxX
    midY = view.bounds.midY
    maxY = view.bounds.maxY*/
    loadCamera()
    /*configureCaptureSession(campos: AVCaptureDevice.Position.front)
    laserView.isHidden = true*/
    
  }
  
  
}

// MARK: - Session and Camera Switching
extension FaceDetectionViewController{
  func getFrontCamera() -> AVCaptureDevice?{
    guard let frontDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) else {
      return nil
    }
    return frontDevice
  }
  func getBackCamera() -> AVCaptureDevice?{
    guard let backDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
      return nil
    }
    return backDevice
  }
  
  func purgeSessionInputs(){
    if (captureSession == nil) { captureSession = AVCaptureSession() }
    for i : AVCaptureDeviceInput in (self.captureSession?.inputs as! [AVCaptureDeviceInput]){
      self.captureSession?.removeInput(i)
    }
  }
  func connectVideoInputToSession(){
    //(Re)connect Capture Device to the session.
    currentCaptureDevice = faceDetection ? getFrontCamera() : getBackCamera()
    do {
      let videoInput = try AVCaptureDeviceInput(device: currentCaptureDevice!)
      captureSession!.addInput(videoInput)
    } catch{
      fatalError(error.localizedDescription)
    }
    
  }
  func connectSessionToVideoOutput(){
    // Create the video data output where the video frames will be gotten from.
      
    let videoOutput = AVCaptureVideoDataOutput()
    videoOutput.setSampleBufferDelegate(self, queue: dataOutputQueue)
    videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
    videoOutput.connection(with: .video)?.videoOrientation = .portrait
      
    //Connect Session to videoutput
    if captureSession!.canAddOutput(videoOutput){
      captureSession!.addOutput(videoOutput)
    }
    
  }
  func configurePreviewLayer(){
    if previewLayer == nil {
      previewLayer = AVCaptureVideoPreviewLayer(session: captureSession!)
      previewLayer.videoGravity = .resizeAspectFill
      previewLayer.frame = view.bounds
      view.layer.insertSublayer(previewLayer, at: 0)
    }
  }
}

// MARK: - Gesture methods

extension FaceDetectionViewController {
  @IBAction func handleTap(_ sender: UITapGestureRecognizer) {
    faceDetection = !faceDetection
    print("Face Detection: ",faceDetection)
    if faceDetection {
      faceBodyLabel.text = "Face"
    } else {
      faceBodyLabel.text = "Body"
    }
    loadCamera()
  }
}

// MARK: - Video Processing methods

extension FaceDetectionViewController {
  func loadCamera(){
    
    //Purge Session
    purgeSessionInputs()
    
    //(Re)Connect Capture Device Input to the Session
    connectVideoInputToSession()
    
    //(Re)Connect Session to Data Ouput
    connectSessionToVideoOutput()
    
    //Set the view
    configurePreviewLayer()
    
    //Capture Session start
    DispatchQueue.main.async {
      self.captureSession!.startRunning()
    }
  }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate methods

extension FaceDetectionViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
  func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
    // 1
    guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
      return
    }

    // 2
    if faceDetection {

      let detectFaceRequest = VNDetectFaceLandmarksRequest(completionHandler: detectedFace)
      do {
        try sequenceHandler.perform([detectFaceRequest], on: imageBuffer, orientation: .leftMirrored)
      } catch { print(error.localizedDescription) }

    } else {
      
      let detectBodyRequest = VNDetectHumanRectanglesRequest(completionHandler: detectedBody)
      do {
        try sequenceHandler.perform([detectBodyRequest], on: imageBuffer, orientation: .leftMirrored)
      } catch { print(error.localizedDescription) }
    
    }
  }
}

extension FaceDetectionViewController {
  func convert(rect: CGRect) -> CGRect {
    // 1
    let origin = previewLayer.layerPointConverted(fromCaptureDevicePoint: rect.origin)

    // 2
    let size = previewLayer.layerPointConverted(fromCaptureDevicePoint: rect.size.cgPoint)

    // 3
    return CGRect(origin: origin, size: size.cgSize)
  }

  // 1
  func landmark(point: CGPoint, to rect: CGRect) -> CGPoint {
    // 2
    let absolute = point.absolutePoint(in: rect)

    // 3
    let converted = previewLayer.layerPointConverted(fromCaptureDevicePoint: absolute)

    // 4
    return converted
  }

  func landmark(points: [CGPoint]?, to rect: CGRect) -> [CGPoint]? {
    guard let points = points else {
      return nil
    }

    return points.compactMap { landmark(point: $0, to: rect) }
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

  // 1
  func updateLaserView(for result: VNFaceObservation) {
    // 2
    laserView.clear()

    // 3
    let yaw = result.yaw ?? 0.0

    // 4
    if yaw == 0.0 {
      return
    }

    // 5
    var origins: [CGPoint] = []

    // 6
    if let point = result.landmarks?.leftPupil?.normalizedPoints.first {
      let origin = landmark(point: point, to: result.boundingBox)
      origins.append(origin)
    }

    // 7
    if let point = result.landmarks?.rightPupil?.normalizedPoints.first {
      let origin = landmark(point: point, to: result.boundingBox)
      origins.append(origin)
    }

    // 1
    let avgY = origins.map { $0.y }.reduce(0.0, +) / CGFloat(origins.count)

    // 2
    let focusY = (avgY < midY) ? 0.75 * maxY : 0.25 * maxY

    // 3
    let focusX = (yaw.doubleValue < 0.0) ? -100.0 : maxX + 100.0

    // 4
    let focus = CGPoint(x: focusX, y: focusY)

    // 5
    for origin in origins {
      let laser = Laser(origin: origin, focus: focus)
      laserView.add(laser: laser)
    }

    // 6
    DispatchQueue.main.async {
      self.laserView.setNeedsDisplay()
    }
  }
  func detectedBody(request: VNRequest, error: Error?) {
    
  }
  func detectedFace(request: VNRequest, error: Error?) {
    // 1
    guard
      let results = request.results as? [VNFaceObservation],
      let result = results.first
      else {
        // 2
        faceView.clear()
        return
    }

    if faceDetection {
      updateFaceView(for: result)
    } else {
      updateLaserView(for: result)
    }
  }
}

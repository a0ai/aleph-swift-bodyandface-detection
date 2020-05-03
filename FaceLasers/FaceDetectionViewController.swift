

import AVFoundation
import UIKit
import Vision

class FaceDetectionViewController: UIViewController {
  var sequenceHandler = VNSequenceRequestHandler()

  @IBOutlet var faceView: FaceView!
  @IBOutlet var bodyView: BodyView!
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
      let previewBounds = view.bounds
      previewLayer.frame = previewBounds
      view.layer.insertSublayer(previewLayer, at: 0)
    }
  }
}

// MARK: - Gesture methods

extension FaceDetectionViewController {
  @IBAction func handleTap(_ sender: UITapGestureRecognizer) {
    /*
    faceDetection = !faceDetection
    print("Face Detection: ",faceDetection)
    if faceDetection {
      faceBodyLabel.text = "Face"
    } else {
      faceBodyLabel.text = "Body"
    }
    loadCamera()*/
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
      } catch {
        print(error.localizedDescription)
        
      }
    
    }
  }
}

func swapxy<swapType>( _ a: inout swapType, _ b: inout swapType) {
  (a, b) = (b, a)
}

extension FaceDetectionViewController {
  
  func convert(_ rect: inout CGRect) {
    // 1
    let pvwLyrBnds = previewLayer.bounds
    //rect.origin.y = 1 - rect.origin.y
    rect.origin.x *= pvwLyrBnds.size.width
    rect.origin.y = 1 - rect.origin.y - rect.size.height
    rect.origin.y *= pvwLyrBnds.size.height
    rect.size.width *= pvwLyrBnds.size.width
    rect.size.height *= pvwLyrBnds.size.height
    
  }

  // 1
  func landmark(point: CGPoint, to rect: CGRect) -> CGPoint {
    // 2
    let absolute = point.absolutePoint(in: rect)
    var apoint = absolute
    swapxy(&apoint.x, &apoint.y)
    apoint.x = 1.0 - apoint.x
    // 3
    let converted = previewLayer.layerPointConverted(fromCaptureDevicePoint: apoint)

    // 4
    return converted
  }

  func landmark(points: [CGPoint]?, to rect: CGRect) -> [CGPoint]? {
    guard let points = points else {
      return nil
    }

    return points.compactMap {
      landmark(point: $0, to: rect)
      
    }
  }
  
  func updateFaceView(for result: VNFaceObservation) {
    defer {
      DispatchQueue.main.async {
        self.faceView.setNeedsDisplay()
      }
    }

    var box = result.boundingBox
    convert(&box)
    faceView.boundingBox = box
    
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
  func updateBodyView(for result: VNRectangleObservation) {

    // 6
    defer{
      DispatchQueue.main.async {
        self.bodyView.setNeedsDisplay()
      }
    }
    self.bodyView.bodyRect = result.boundingBox
    
  }
  
  func detectedBody(request: VNRequest, error: Error?) {
    // 1
    guard
      let results = request.results as? [VNRectangleObservation],
      let result = results.first
      else {
        // 2
        faceView.clear()
        return
    }
    updateBodyView(for: result)

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

    updateFaceView(for: result)
    
  }
}

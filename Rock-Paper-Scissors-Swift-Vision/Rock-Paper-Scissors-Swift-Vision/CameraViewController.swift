import UIKit
import AVFoundation
import Vision

class CameraViewController: UIViewController {

    private var cameraView: CameraView { view as! CameraView }
    @IBOutlet weak var userGesture: UILabel!
    @IBOutlet weak var cpuGesture: UILabel!
    @IBOutlet weak var topHeaderText: UILabel!
    @IBOutlet weak var resetInstruction: UILabel!
    
    let game = Game()
    var finished = false
    
    private let videoDataOutputQueue = DispatchQueue(label: "CameraFeedDataOutput", qos: .userInteractive)
    private var cameraFeedSession: AVCaptureSession?
    private var handPoseRequest = VNDetectHumanHandPoseRequest()
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        handPoseRequest.maximumHandCount = 1
        resetInstruction.isHidden = true
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        do {
            if cameraFeedSession == nil {
                cameraView.previewLayer.videoGravity = .resizeAspectFill
                try setupAVSession()
                cameraView.previewLayer.session = cameraFeedSession
            }
            cameraFeedSession?.startRunning()
        } catch {
            AppError.display(error, inViewController: self)
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        cameraFeedSession?.stopRunning()
        super.viewWillDisappear(animated)
    }
    
    func setupAVSession() throws {
        // Select a front facing camera, make an input.
        guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) else {
            throw AppError.captureSessionSetup(reason: "Could not find a front facing camera.")
        }
        
        guard let deviceInput = try? AVCaptureDeviceInput(device: videoDevice) else {
            throw AppError.captureSessionSetup(reason: "Could not create video device input.")
        }
        
        let session = AVCaptureSession()
        session.beginConfiguration()
        session.sessionPreset = AVCaptureSession.Preset.high
        
        // Add a video input.
        guard session.canAddInput(deviceInput) else {
            throw AppError.captureSessionSetup(reason: "Could not add video device input to the session")
        }
        session.addInput(deviceInput)
        
        let dataOutput = AVCaptureVideoDataOutput()
        if session.canAddOutput(dataOutput) {
            session.addOutput(dataOutput)
            // Add a video data output.
            dataOutput.alwaysDiscardsLateVideoFrames = true
            dataOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange)]
            dataOutput.setSampleBufferDelegate(self, queue: videoDataOutputQueue)
        } else {
            throw AppError.captureSessionSetup(reason: "Could not add video data output to the session")
        }
        session.commitConfiguration()
        cameraFeedSession = session
}
    
    func processPoints(_ points: [CGPoint?]) {
        
        let previewLayer = cameraView.previewLayer
        var pointsConverted: [CGPoint] = []
        for point in points {
            pointsConverted.append(previewLayer.layerPointConverted(fromCaptureDevicePoint: point!))
        }
        
        cameraView.showPoints(pointsConverted)
        
        var winner: String?
        
        //asigning important landmarks to variables
        let wrist = pointsConverted[pointsConverted.count - 1]
        let indexTip = pointsConverted[4]
        let indexMcp = pointsConverted[7]
        let ringTip = pointsConverted[12]
        let ringMcp = pointsConverted[15]
        let thumbTip = pointsConverted[0]

        //gather distance from landmarks to wrist
        let indexTipWristDistance = indexTip.distance(from: wrist)
        let indexMcpWristDistance = indexMcp.distance(from: wrist)
        let ringTipWristDistance = ringTip.distance(from: wrist)
        let ringMcpWristDistance = ringMcp.distance(from: wrist)
        
        //calculate percentage difference between finger-tip to wrist and finger mcp to wrist
        let testDifferenceIndex = CGPoint.percentDifference(indexMcpWristDistance, indexTipWristDistance)
        let testDifferenceRing = CGPoint.percentDifference(ringMcpWristDistance, ringTipWristDistance)
        
        //calculate distance between thumb tip and index tip
        let pinchDistance = indexTip.distance(from: thumbTip)
        
        // if index and thumb are pinched, and ring finger is extended
        if finished == false {
            
            if pinchDistance < 38 && testDifferenceRing < 55 {
                userGesture.text = "👌"
                topHeaderText.text = "SHOOT!"
                game.getCPUPlay()
            }
            
            if userGesture.text == "👌"{
                //gathers evidence of rock/paper/scissors states, returns true once gesture is confidently recognized
                finished = game.gatherEvidence(testDifferenceRing, testDifferenceIndex)
            }
        }
        if finished == true {
            winner = game.getWinner()
            userGesture.text = game.userPlay
            cpuGesture.text = game.cpuPlay
            if winner == "DRAW" || winner == "error"  {
                topHeaderText.text = "DRAW"
            } else {
                topHeaderText.text = "WINNER: \(winner!)"
            }
            //makes reset instruction visible
            resetInstruction.isHidden = false
        }
        //sends recognized points to camera view for display
        
    }
    
    //reset function triggers on screen tap
    @IBAction func resetBoard(_ sender: UITapGestureRecognizer) {
        game.reset()
        topHeaderText.text = "👌 TO PLAY"
        userGesture.text = "YOU"
        cpuGesture.text = "CPU"
        resetInstruction.isHidden = true
        finished = false
    }
}

extension CameraViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    public func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        
        var thumbTip: CGPoint?
        var thumbIp: CGPoint?
        var thumbMp: CGPoint?
        var thumbCmc: CGPoint?
        var indexTip: CGPoint?
        var indexDip: CGPoint?
        var indexPip: CGPoint?
        var indexMcp: CGPoint?
        var middleTip: CGPoint?
        var middleDip: CGPoint?
        var middlePip: CGPoint?
        var middleMcp: CGPoint?
        var ringTip: CGPoint?
        var ringDip: CGPoint?
        var ringPip: CGPoint?
        var ringMcp: CGPoint?
        var pinkyTip: CGPoint?
        var pinkyDip: CGPoint?
        var pinkyPip: CGPoint?
        var pinkyMcp: CGPoint?
        var wrist: CGPoint?

        let handler = VNImageRequestHandler(cmSampleBuffer: sampleBuffer, orientation: .up, options: [:])
        do {
            try handler.perform([handPoseRequest])
            
            // only bother processing first hand found
            guard let observation = handPoseRequest.results?.first else {
                cameraView.showPoints([])
                return
            }
            
            // get recognized points for each finger
            let thumbPoints = try observation.recognizedPoints(.thumb)
            let indexFingerPoints = try observation.recognizedPoints(.indexFinger)
            let middleFingerPoints = try observation.recognizedPoints(.middleFinger)
            let ringFingerPoints = try observation.recognizedPoints(.ringFinger)
            let pinkyFingerPoints = try observation.recognizedPoints(.littleFinger)
            let wristPoints = try observation.recognizedPoints(.all)
            
            // extract each recognized point from point groups
            guard let thumbTipPoint = thumbPoints[.thumbTip],
                  let thumbIpPoint = thumbPoints[.thumbIP],
                  let thumbMpPoint = thumbPoints[.thumbMP],
                  let thumbCmcPoint = thumbPoints[.thumbCMC],
                  let indexTipPoint = indexFingerPoints[.indexTip],
                  let indexDipPoint = indexFingerPoints[.indexDIP],
                  let indexPipPoint = indexFingerPoints[.indexPIP],
                  let indexMcpPoint = indexFingerPoints[.indexMCP],
                  let middleTipPoint = middleFingerPoints[.middleTip],
                  let middleDipPoint = middleFingerPoints[.middleDIP],
                  let middlePipPoint = middleFingerPoints[.middlePIP],
                  let middleMcpPoint = middleFingerPoints[.middleMCP],
                  let ringTipPoint = ringFingerPoints[.ringTip],
                  let ringDipPoint = ringFingerPoints[.ringDIP],
                  let ringPipPoint = ringFingerPoints[.ringPIP],
                  let ringMcpPoint = ringFingerPoints[.ringMCP],
                  let pinkyTipPoint = pinkyFingerPoints[.littleTip],
                  let pinkyDipPoint = pinkyFingerPoints[.littleDIP],
                  let pinkyPipPoint = pinkyFingerPoints[.littlePIP],
                  let pinkyMcpPoint = pinkyFingerPoints[.littleMCP],
                  let wristPoint = wristPoints[.wrist]
            else {
                cameraView.showPoints([])
                return
            }
            // ignore low confidence points.
            let confidenceThreshold: Float = 0.3
            guard thumbTipPoint.confidence > confidenceThreshold &&
                    thumbIpPoint.confidence > confidenceThreshold &&
                    thumbMpPoint.confidence > confidenceThreshold &&
                    thumbCmcPoint.confidence > confidenceThreshold &&
                    indexTipPoint.confidence > confidenceThreshold &&
                    indexDipPoint.confidence > confidenceThreshold &&
                    indexPipPoint.confidence > confidenceThreshold &&
                    indexMcpPoint.confidence > confidenceThreshold &&
                    middleTipPoint.confidence > confidenceThreshold &&
                    middleDipPoint.confidence > confidenceThreshold &&
                    middlePipPoint.confidence > confidenceThreshold &&
                    middleMcpPoint.confidence > confidenceThreshold &&
                    ringTipPoint.confidence > confidenceThreshold &&
                    ringDipPoint.confidence > confidenceThreshold &&
                    ringPipPoint.confidence > confidenceThreshold &&
                    ringMcpPoint.confidence > confidenceThreshold &&
                    pinkyTipPoint.confidence > confidenceThreshold &&
                    pinkyDipPoint.confidence > confidenceThreshold &&
                    pinkyPipPoint.confidence > confidenceThreshold &&
                    pinkyMcpPoint.confidence > confidenceThreshold &&
                    wristPoint.confidence > confidenceThreshold else {
                cameraView.showPoints([])
                return
            }
            
            // convert points from Vision coordinates to AVFoundation coordinates.
            thumbTip = CGPoint(x: thumbTipPoint.location.x, y: 1 - thumbTipPoint.location.y)
            thumbIp = CGPoint(x: thumbIpPoint.location.x, y: 1 - thumbIpPoint.location.y)
            thumbMp = CGPoint(x: thumbMpPoint.location.x, y: 1 - thumbMpPoint.location.y)
            thumbCmc = CGPoint(x: thumbCmcPoint.location.x, y: 1 - thumbCmcPoint.location.y)
            indexTip = CGPoint(x: indexTipPoint.location.x, y: 1 - indexTipPoint.location.y)
            indexDip = CGPoint(x: indexDipPoint.location.x, y: 1 - indexDipPoint.location.y)
            indexPip = CGPoint(x: indexPipPoint.location.x, y: 1 - indexPipPoint.location.y)
            indexMcp = CGPoint(x: indexMcpPoint.location.x, y: 1 - indexMcpPoint.location.y)
            middleTip = CGPoint(x: middleTipPoint.location.x, y: 1 - middleTipPoint.location.y)
            middleDip = CGPoint(x: middleDipPoint.location.x, y: 1 - middleDipPoint.location.y)
            middlePip = CGPoint(x: middlePipPoint.location.x, y: 1 - middlePipPoint.location.y)
            middleMcp = CGPoint(x: middleMcpPoint.location.x, y: 1 - middleMcpPoint.location.y)
            ringTip = CGPoint(x: ringTipPoint.location.x, y: 1 - ringTipPoint.location.y)
            ringDip = CGPoint(x: ringDipPoint.location.x, y: 1 - ringDipPoint.location.y)
            ringPip = CGPoint(x: ringPipPoint.location.x, y: 1 - ringPipPoint.location.y)
            ringMcp = CGPoint(x: ringMcpPoint.location.x, y: 1 - ringMcpPoint.location.y)
            pinkyTip = CGPoint(x: pinkyTipPoint.location.x, y: 1 - pinkyTipPoint.location.y)
            pinkyDip = CGPoint(x: pinkyDipPoint.location.x, y: 1 - pinkyDipPoint.location.y)
            pinkyPip = CGPoint(x: pinkyPipPoint.location.x, y: 1 - pinkyPipPoint.location.y)
            pinkyMcp = CGPoint(x: pinkyMcpPoint.location.x, y: 1 - pinkyMcpPoint.location.y)
            wrist = CGPoint(x: wristPoint.location.x, y: 1 - wristPoint.location.y)
            
            DispatchQueue.main.async {
                self.processPoints([thumbTip, thumbIp, thumbMp, thumbCmc,
                                    indexTip, indexDip, indexPip, indexMcp,
                                    middleTip, middleDip, middlePip, middleMcp,
                                    ringTip, ringDip, ringPip, ringMcp,
                                    pinkyTip, pinkyDip, pinkyPip, pinkyMcp,
                                    wrist])
            }
        }
        catch {
            cameraFeedSession?.stopRunning()
            let error = AppError.visionError(error: error)
            DispatchQueue.main.async {
                error.displayInViewController(self)
        }
        }
    }
}


// MARK: - CGPoint helpers

extension CGPoint {
    
    func distance(from point: CGPoint) -> CGFloat {
        return hypot(point.x - x, point.y - y)
    }
    
    static func percentDifference(_ v1: CGFloat,_ v2: CGFloat) -> CGFloat {
        return (v1 / v2) * 100
    }
}

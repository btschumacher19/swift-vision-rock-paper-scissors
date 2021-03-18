import UIKit
import AVFoundation

class CameraView: UIView {

    //overlay for points to show on
    private var overlayLayer = CAShapeLayer()
    private var path = UIBezierPath()

    var previewLayer: AVCaptureVideoPreviewLayer {
        return layer as! AVCaptureVideoPreviewLayer
    }

    override class var layerClass: AnyClass {
        return AVCaptureVideoPreviewLayer.self
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupOverlay()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupOverlay()
    }
    
    override func layoutSublayers(of layer: CALayer) {
        super.layoutSublayers(of: layer)
        if layer == previewLayer {
            overlayLayer.frame = layer.bounds
        }
    }

    private func setupOverlay() {
        previewLayer.addSublayer(overlayLayer)
    }
    
    func showPoints(_ points: [CGPoint]) {
        path.removeAllPoints()

        let overlay = overlayLayer
        let wrist = points.last

        //if hand is off screen/not found, overlay will be overwritten without any points
        if wrist != nil {
            
        for point in points {
            path.move(to: point)
            path.addArc(withCenter: point, radius: 3, startAngle: 0, endAngle: 2 * .pi, clockwise: true)
        }
        
        let x = [
            [0, 1, 2, 3, 4],
            [4, 5, 6, 7, 8],
            [8, 9, 10, 11, 12],
            [12, 13, 14, 15, 16],
            [16, 17, 18, 19, 20]
        ]

        //add lines to each finger
        for y in x {
            path.move(to: points[y[0]])
            path.addLine(to: points[y[1]])
            path.move(to: points[y[1]])
            path.addLine(to: points[y[2]])
            path.move(to: points[y[2]])
            path.addLine(to: points[y[3]])
            path.move(to: points[y[3]])
            path.addLine(to: wrist!)

        }
    
        overlay.fillColor = UIColor.green.cgColor
        overlay.strokeColor = UIColor.green.cgColor
        overlay.lineWidth = 3.0
        overlay.lineCap = .round
        }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        overlay.path = path.cgPath
        CATransaction.commit()
    }

}

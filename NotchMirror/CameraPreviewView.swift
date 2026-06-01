import SwiftUI
import AVFoundation
import AppKit

/// NSView wrapper that hosts an AVCaptureVideoPreviewLayer.
/// The video is horizontally mirrored so it acts like a real mirror.
struct CameraPreviewView: NSViewRepresentable {
    let session: AVCaptureSession

    func makeNSView(context: Context) -> PreviewNSView {
        let view = PreviewNSView()
        view.session = session
        return view
    }

    func updateNSView(_ nsView: PreviewNSView, context: Context) {
        nsView.session = session
    }
}

class PreviewNSView: NSView {
    var session: AVCaptureSession? {
        didSet { updateSession() }
    }

    private var previewLayer: AVCaptureVideoPreviewLayer?

    override func layout() {
        super.layout()
        previewLayer?.frame = bounds
    }

    private func updateSession() {
        guard let session else { return }

        previewLayer?.removeFromSuperlayer()

        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        // Mirror horizontally — true mirror behaviour
        layer.connection?.automaticallyAdjustsVideoMirroring = false
        layer.connection?.isVideoMirrored = true
        layer.frame = bounds
        wantsLayer = true
        self.layer?.addSublayer(layer)
        self.previewLayer = layer
    }
}

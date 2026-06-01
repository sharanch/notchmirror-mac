import AVFoundation
import AppKit
import Combine

class CameraManager: NSObject, ObservableObject {
    @Published var isRunning = false
    @Published var permissionDenied = false

    let session = AVCaptureSession()
    private var deviceInput: AVCaptureDeviceInput?

    override init() {
        super.init()
    }

    func startSession() {
        guard !session.isRunning else { return }

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }

            self.session.beginConfiguration()
            self.session.sessionPreset = .high

            // Always remove old inputs before adding — fixes "only works once" bug
            for input in self.session.inputs {
                self.session.removeInput(input)
            }
            self.deviceInput = nil

            if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
               let input = try? AVCaptureDeviceInput(device: device),
               self.session.canAddInput(input) {
                self.session.addInput(input)
                self.deviceInput = input
            }

            self.session.commitConfiguration()
            self.session.startRunning()

            DispatchQueue.main.async { self.isRunning = true }
        }
    }

    func stopSession() {
        guard session.isRunning else { return }

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            self.session.stopRunning()

            // Clean up inputs so next startSession() gets a fresh slate
            self.session.beginConfiguration()
            for input in self.session.inputs {
                self.session.removeInput(input)
            }
            self.deviceInput = nil
            self.session.commitConfiguration()

            DispatchQueue.main.async { self.isRunning = false }
        }
    }
}

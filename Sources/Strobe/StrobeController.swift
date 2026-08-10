import AVFoundation
import Combine

/// Drives the device flashlight on and off at a chosen frequency to produce a
/// strobe effect.
///
/// All torch hardware access is serialized on a dedicated background queue
/// via `DispatchSourceTimer`, which jitters far less than a main-run-loop
/// `Timer`. `@Published` state that SwiftUI observes is only ever mutated on
/// the main thread.
///
/// - Important: Sustained high-frequency strobing keeps the LED driven near
///   its duty-cycle limit and can noticeably warm up the device. This is not
///   mitigated in code (no thermal throttling logic) — just something to be
///   aware of if this is ever extended with a "duration" limit.
final class StrobeController: ObservableObject {
    /// Whether the strobe loop is currently running.
    @Published private(set) var isStrobing = false

    /// Selected strobe frequency in Hz (1...50). Locked while `isStrobing`.
    @Published var frequencyHz: Int = 33

    /// Whether this device exposes a torch at all (false on Simulator, iPad, etc).
    @Published private(set) var isTorchAvailable: Bool

    /// User-facing message for the most recent torch failure, if any.
    @Published private(set) var errorMessage: String?

    private let device: AVCaptureDevice?
    private let queue = DispatchQueue(label: "com.gyarcom.Strobe.torchQueue", qos: .userInteractive)
    private var timer: DispatchSourceTimer?
    private var torchIsOn = false

    init() {
        let device = AVCaptureDevice.default(for: .video)
        self.device = device
        self.isTorchAvailable = device?.hasTorch ?? false
    }

    /// Starts toggling the torch at `frequencyHz` full on/off cycles per second.
    ///
    /// No-op if already strobing or if the device has no torch. Above roughly
    /// 10–15 Hz, `AVCaptureDevice.torchMode` switching is best-effort: API and
    /// hardware latency mean the actual on-device flicker rate can drift from
    /// the requested value. This deliberately does not claim precise timing
    /// in the UI.
    func start() {
        guard !isStrobing else { return }
        guard let device, device.hasTorch else {
            errorMessage = "Torch is not available on this device."
            return
        }

        errorMessage = nil
        isStrobing = true

        let clampedHz = max(1, min(50, frequencyHz))
        let interval = 1.0 / (Double(clampedHz) * 2.0)

        queue.async { [weak self] in
            guard let self else { return }
            self.torchIsOn = false

            let timer = DispatchSource.makeTimerSource(queue: self.queue)
            timer.schedule(deadline: .now(), repeating: interval, leeway: .milliseconds(1))
            timer.setEventHandler { [weak self] in
                self?.toggleTorchOnQueue()
            }
            self.timer = timer
            timer.resume()
        }
    }

    /// Stops the strobe loop and guarantees the torch is switched off.
    ///
    /// Safe to call repeatedly, when not strobing, from `deinit`, or when the
    /// app moves to the background.
    func stop() {
        guard isStrobing else { return }
        isStrobing = false

        queue.async { [weak self] in
            guard let self else { return }
            self.timer?.cancel()
            self.timer = nil
            self.torchIsOn = false
            self.setTorch(on: false)
        }
    }

    /// Flips the torch state. Runs on `queue`.
    private func toggleTorchOnQueue() {
        torchIsOn.toggle()
        setTorch(on: torchIsOn)
    }

    /// Applies a torch on/off state to the hardware. Runs on `queue`.
    private func setTorch(on: Bool) {
        guard let device, device.hasTorch, device.isTorchModeSupported(on ? .on : .off) else { return }
        do {
            try device.lockForConfiguration()
            device.torchMode = on ? .on : .off
            device.unlockForConfiguration()
        } catch {
            let message = "Unable to control the flashlight: \(error.localizedDescription)"
            DispatchQueue.main.async { [weak self] in
                self?.errorMessage = message
            }
        }
    }

    deinit {
        timer?.cancel()
        timer = nil
        guard let device, device.hasTorch, device.isTorchModeSupported(.off) else { return }
        try? device.lockForConfiguration()
        device.torchMode = .off
        device.unlockForConfiguration()
    }
}

import SwiftUI
import UIKit
import WebKit
import AVFoundation
import Speech
#if canImport(Translation)
import Translation
#endif

/// The page-side behaviour behind the phone's page tools: darkening a page,
/// hiding cookie banners, and reading back what a page actually is (its address
/// bar name, its filter, its banner count, its title and its text). Kept in one
/// place, the way `PageTools` keeps find/reader/site information.
enum PageEnhancements {
    /// What every browser asks for when it requests the desktop version of a
    /// page: the Macintosh name of the same browser family. One string, no second
    /// copy of the app's version to drift.
    static let desktopUserAgent =
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 "
        + "(KHTML, like Gecko) Version/18.0 Safari/605.1.15"

    /// Turns the page dark without touching the app's own appearance. The filter
    /// inverts the page and inverts pictures back, which is the long-standing
    /// recipe browser extensions use; it leaves the site's layout alone.
    static func darkModeJS(_ on: Bool) -> String {
        """
        (function(on){
          var id = "brows-dark-pages";
          var el = document.getElementById(id);
          if (!on) { if (el) { el.remove(); } return "off"; }
          if (!el) {
            el = document.createElement("style");
            el.id = id;
            el.textContent = "html{filter:invert(1) hue-rotate(180deg) !important;background:#fff !important}"
              + "img,video,picture,canvas,svg{filter:invert(1) hue-rotate(180deg) !important}";
            (document.head || document.documentElement).appendChild(el);
          }
          return "on";
        })(\(on ? "true" : "false"));
        """
    }

    /// Hides the consent banners sites put over their own content. The ids and
    /// classes are the ones the large consent vendors ship (OneTrust, Cookiebot,
    /// Quantcast, the common WordPress plugins); generic cookie/consent banner
    /// patterns catch the rest.
    static let cookieBannerJS = """
    (function(){
      var selectors = [
        "#onetrust-banner-sdk", "#onetrust-consent-sdk", "#CybotCookiebotDialog",
        ".qc-cmp2-container", ".cc-window", ".cookie-consent", ".cookie-banner",
        "#cookie-banner", "#cookie-notice", "[class*=\"cookie-banner\" i]",
        "[id*=\"cookie-banner\" i]", "[class*=\"consent-banner\" i]",
        "[id*=\"consent-banner\" i]"
      ];
      var hidden = 0;
      selectors.forEach(function(selector){
        try {
          document.querySelectorAll(selector).forEach(function(el){
            el.style.setProperty("display", "none", "important");
            hidden += 1;
          });
        } catch (e) {}
      });
      return hidden;
    })();
    """

    /// The same report, posted to the browser when the document is ready. A call
    /// made from the navigation callback raced the load and came back empty, so
    /// the page pushes its state instead.
    static var probePostJS: String {
        let call = probeJS.hasSuffix(";") ? String(probeJS.dropLast()) : probeJS
        return "try { window.webkit.messageHandlers.browsProbe.postMessage(\(call)); } catch (e) {}"
    }

    /// What the app reads back after a page loads or a tool changes something.
    static let probeJS = """
    (function(){
      function banners(){
        var selectors = [
          "#onetrust-banner-sdk", "#onetrust-consent-sdk", "#CybotCookiebotDialog",
          ".qc-cmp2-container", ".cc-window", ".cookie-consent", ".cookie-banner",
          "#cookie-banner", "#cookie-notice", "[class*=\"cookie-banner\" i]",
          "[id*=\"cookie-banner\" i]", "[class*=\"consent-banner\" i]",
          "[id*=\"consent-banner\" i]"
        ];
        var count = 0;
        selectors.forEach(function(selector){
          try {
            document.querySelectorAll(selector).forEach(function(el){
              var style = getComputedStyle(el);
              if (style.display !== "none" && style.visibility !== "hidden" && el.offsetParent !== null) {
                count += 1;
              }
            });
          } catch (e) {}
        });
        return count;
      }
      return JSON.stringify({
        ua: navigator.userAgent || "",
        filter: getComputedStyle(document.documentElement).filter || "",
        banners: banners(),
        title: document.title || "",
        text: (document.body ? (document.body.innerText || "") : "").slice(0, 4000)
      });
    })();
    """
}

/// The state one page reports about itself, published for the hidden probes the
/// tests read and for the translate card's text.
struct PageProbe: Equatable {
    var userAgent = ""
    var filter = ""
    var banners = 0
    var title = ""
    var text = ""

    var isDesktopSite: Bool { userAgent.contains("Macintosh") }
    var isDark: Bool { filter.contains("invert") }

    /// A single accessibility label: desktop/mobile | dark/light | banners | title.
    var label: String {
        "\(isDesktopSite ? "desktop" : "mobile")|\(isDark ? "dark" : "light")|\(banners)|\(title)"
    }
}

/// A refresh control that runs a closure, so the model can hand each web view
/// its own reload without an `@objc` target dance.
final class ClosureRefreshControl: UIRefreshControl {
    var action: (() -> Void)?
    init(action: @escaping () -> Void) {
        self.action = action
        super.init(frame: .zero)
        addTarget(self, action: #selector(fire), for: .valueChanged)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    @objc private func fire() { action?() }
}

/// Dictation for the address field. The microphone is the phone's own speech
/// recogniser; the transcript is handed to the model as it arrives.
final class Dictation {
    var onStatus: ((String) -> Void)?
    var onTranscript: ((String) -> Void)?
    private(set) var listening = false
    private(set) var transcript = ""

    private let recogniser = SFSpeechRecognizer()
    private let engine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var started = false

    func start() {
        transcript = ""
        say("Preparing the microphone…")
        SFSpeechRecognizer.requestAuthorization { status in
            DispatchQueue.main.async {
                guard status == .authorized else {
                    self.say("Speech recognition is not allowed. Turn it on in Settings.")
                    return
                }
                AVAudioSession.sharedInstance().requestRecordPermission { granted in
                    DispatchQueue.main.async {
                        guard granted else {
                            self.say("The microphone is not allowed. Turn it on in Settings.")
                            return
                        }
                        self.listen()
                    }
                }
            }
        }
    }

    private func say(_ text: String) {
        onStatus?(text)
    }

    private func listen() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .measurement, options: .duckOthers)
            try session.setActive(true, options: .notifyOthersOnDeactivation)

            let request = SFSpeechAudioBufferRecognitionRequest()
            request.shouldReportPartialResults = true
            self.request = request

            let input = engine.inputNode
            let format = input.outputFormat(forBus: 0)
            input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
                request.append(buffer)
            }
            engine.prepare()
            try engine.start()
            started = true
            listening = true
            say("Listening…")

            task = recogniser?.recognitionTask(with: request) { [weak self] result, error in
                guard let self else { return }
                if let result {
                    let text = result.bestTranscription.formattedString
                    DispatchQueue.main.async {
                        self.transcript = text
                        self.onTranscript?(text)
                    }
                    if result.isFinal { DispatchQueue.main.async { self.finish() } }
                }
                if error != nil { DispatchQueue.main.async { self.finish() } }
            }
        } catch {
            say("The microphone could not start: \(error.localizedDescription)")
            finish()
        }
    }

    func finish() {
        if started {
            engine.stop()
            engine.inputNode.removeTap(onBus: 0)
            started = false
        }
        request?.endAudio()
        task?.cancel()
        request = nil
        task = nil
        listening = false
        if !transcript.isEmpty { say("Heard: \(transcript)") }
    }
}

/// The camera preview for the code scanner. A phone always has a camera; the
/// simulator never does, which is the one part of this feature the test machine
/// cannot prove.
struct CodeScannerPreview: UIViewRepresentable {
    let onCode: (String) -> Void

    final class Coordinator: NSObject, AVCaptureMetadataOutputObjectsDelegate {
        let onCode: (String) -> Void
        var preview: AVCaptureVideoPreviewLayer?
        init(onCode: @escaping (String) -> Void) { self.onCode = onCode }
        func metadataOutput(_ output: AVCaptureMetadataOutput,
                            didOutput metadataObjects: [AVMetadataObject],
                            from connection: AVCaptureConnection) {
            guard let object = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
                  let value = object.stringValue else { return }
            onCode(value)
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(onCode: onCode) }

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .black
        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device) else { return view }
        let session = AVCaptureSession()
        session.sessionPreset = .photo
        guard session.canAddInput(input) else { return view }
        session.addInput(input)

        let output = AVCaptureMetadataOutput()
        guard session.canAddOutput(output) else { return view }
        session.addOutput(output)
        output.setMetadataObjectsDelegate(context.coordinator, queue: .main)
        output.metadataObjectTypes = [.qr, .ean8, .ean13, .code128, .pdf417, .aztec]

        let preview = AVCaptureVideoPreviewLayer(session: session)
        preview.videoGravity = .resizeAspectFill
        preview.frame = view.bounds
        view.layer.addSublayer(preview)
        context.coordinator.preview = preview

        DispatchQueue.global(qos: .userInitiated).async { session.startRunning() }
        return view
    }

    func updateUIView(_ view: UIView, context: Context) {
        context.coordinator.preview?.frame = view.bounds
    }

    static func dismantleUIView(_ view: UIView, coordinator: Coordinator) {
        coordinator.preview?.session?.stopRunning()
    }
}

/// Scan a QR code or barcode and open it. On a phone the camera fills the card;
/// with no camera the card says so instead of pretending to scan.
struct CodeScannerSheet: View {
    @EnvironmentObject var model: BrowserModel
    @Environment(\.dismiss) private var dismiss
    @State private var found = ""
    @State private var message = "Point the camera at a code."

    private var hasCamera: Bool { AVCaptureDevice.default(for: .video) != nil }

    var body: some View {
        VStack(spacing: 0) {
            PanelBar(title: "Scan a code") {
                Button("Done") { dismiss() }
            }
            ZStack {
                GlassPane(cornerRadius: 0, plate: true)
                    .ignoresSafeArea()
                VStack(spacing: 16) {
                    if !found.isEmpty {
                        Text(found)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(Theme.plateInk)
                            .multilineTextAlignment(.center)
                            .accessibilityIdentifier("scan.result")
                        Button("Open") {
                            dismiss()
                            model.navigate(to: found)
                        }
                        .accessibilityIdentifier("scan.open")
                    } else if hasCamera {
                        CodeScannerPreview { code in
                            guard found.isEmpty else { return }
                            found = code
                            message = "Code found."
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .frame(height: 320)
                        Text(message)
                            .font(.system(size: 14))
                            .foregroundColor(Theme.plateMuted)
                    } else {
                        Text("This device has no camera, so a code cannot be scanned here.")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(Theme.plateInk)
                            .multilineTextAlignment(.center)
                            .accessibilityIdentifier("scan.unavailable")
                    }
                    Spacer(minLength: 0)
                }
                .padding(24)
            }
        }
    }
}

/// Translate the page's text. Apple's own on-device translator does the work;
/// the language pack has to be on the device, which is the part a test machine
/// cannot guarantee.
struct TranslateSheet: View {
    @EnvironmentObject var model: BrowserModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            PanelBar(title: "Translate page") {
                Button("Done") { dismiss() }
            }
            ZStack {
                GlassPane(cornerRadius: 0, plate: true)
                    .ignoresSafeArea()
                if #available(iOS 18.0, *) {
                    TranslatePanel(text: model.pageProbe.text)
                } else {
                    Text("Translating a page needs iOS 18 or newer on this device.")
                        .font(.system(size: 15))
                        .foregroundColor(Theme.plateInk)
                        .multilineTextAlignment(.center)
                        .padding(24)
                        .accessibilityIdentifier("translate.output")
                }
            }
        }
    }
}

/// Apple's on-device translator. Everything that names its types lives behind
/// the availability check above, so the app still builds for older systems.
@available(iOS 18.0, *)
private struct TranslatePanel: View {
    let text: String
    @State private var output = ""
    @State private var status = "Translate the page's text into English."
    @State private var configuration: TranslationSession.Configuration?

    var body: some View {
        VStack(spacing: 14) {
            ScrollView {
                Text(output.isEmpty ? status : output)
                    .font(.system(size: 15))
                    .foregroundColor(Theme.plateInk)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityIdentifier("translate.output")
            }
            Button("Translate to English") {
                status = "Translating…"
                configuration = TranslationSession.Configuration(
                    target: Locale.Language(identifier: "en")
                )
            }
            .accessibilityIdentifier("translate.run")
            .disabled(text.isEmpty)
            if text.isEmpty {
                Text("This page has no text to translate.")
                    .font(.system(size: 13))
                    .foregroundColor(Theme.plateMuted)
            }
        }
        .padding(24)
        .translationTask(configuration) { session in
            do {
                try await session.prepareTranslation()
                let response = try await session.translate(text)
                output = response.targetText
                status = ""
            } catch {
                status = "This device could not translate the page: \(error.localizedDescription)"
            }
        }
    }
}

/// The card the voice search shows while the microphone is open.
struct VoiceSearchCard: View {
    @EnvironmentObject var model: BrowserModel

    var body: some View {
        VStack(spacing: 12) {
            Text("Voice search")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(Theme.plateInk)
            Text(model.voiceStatus)
                .font(.system(size: 14))
                .foregroundColor(Theme.plateMuted)
                .multilineTextAlignment(.center)
                .accessibilityIdentifier("voice.status")
            if !model.voiceTranscript.isEmpty {
                Text(model.voiceTranscript)
                    .font(.system(size: 15))
                    .foregroundColor(Theme.plateInk)
                    .multilineTextAlignment(.center)
                    .accessibilityIdentifier("voice.transcript")
            }
            HStack(spacing: 10) {
                Button("Cancel") {
                    model.stopVoiceSearch()
                }
                .accessibilityIdentifier("voice.cancel")
                Button("Use it") {
                    model.useDictation()
                }
                .accessibilityIdentifier("voice.use")
                .disabled(model.voiceTranscript.isEmpty)
            }
            .buttonStyle(.plain)
            .font(.system(size: 15, weight: .semibold))
            .foregroundColor(Theme.panelInk)
        }
        .padding(18)
        .frame(maxWidth: 300)
        .background(
            GlassPane(cornerRadius: 16, plate: true, backdrop: model.panelBackdrop)
        )
        .padding(24)
    }
}

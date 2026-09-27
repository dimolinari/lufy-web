import AVFoundation
import Foundation
import MediaPlayer
import AprendeCore

@MainActor
@Observable
final class LessonPlayer {
    private(set) var isPlaying = false
    private(set) var elapsed: TimeInterval = 0
    private(set) var duration: TimeInterval = 0
    private(set) var usingDeviceVoice = false
    private(set) var finished = false
    private(set) var lessonID: String?
    private(set) var lessonTitle = ""
    var statusMessage: String?

    private var artist = ""
    private var script = ""
    private var speed: Double = 1
    private var player: AVPlayer?
    private var timeObserver: Any?
    private var endObserver: NSObjectProtocol?
    private var synthesizer: AVSpeechSynthesizer?
    private var speechDelegate: SpeechDelegate?
    private var timeline: SpeechTimeline?
    private var speechOffset: TimeInterval = 0
    private var speechAnchor: Date?
    private var ticker: Timer?
    private var speechToken = 0
    private var remoteConfigured = false
    private let bridge = PlayerBridge()

    init() {
        bridge.owner = self
    }

    func load(lesson: Lesson, brandName: String, speed: Double) {
        teardownPlayback()
        lessonID = lesson.id
        lessonTitle = lesson.title
        artist = brandName
        script = lesson.script
        self.speed = LearnerSettings.nearest(speed)
        finished = false
        elapsed = 0
        let audioURL = LessonAudio.bundledURL(lessonID: lesson.id)
        if let audioURL {
            usingDeviceVoice = false
            statusMessage = nil
            prepareFile(url: audioURL)
        } else {
            usingDeviceVoice = true
            timeline = SpeechTimeline.build(script: script, speed: self.speed)
            duration = timeline?.duration ?? 0
            if SpanishVoice.available() {
                statusMessage = "Esta lección usa la voz en español del dispositivo."
            } else {
                statusMessage = "No hay una voz en español instalada. Descárgala en Ajustes del sistema, o genera el MP3."
            }
        }
        activateSession()
        configureRemoteCommands()
        publishNowPlaying()
    }

    func toggle() {
        isPlaying ? pause() : play()
    }

    func play() {
        activateSession()
        if usingDeviceVoice {
            speak(from: elapsed)
        } else {
            player?.defaultRate = Float(speed)
            player?.playImmediately(atRate: Float(speed))
            isPlaying = true
            finished = false
        }
        publishNowPlaying()
    }

    func pause() {
        if usingDeviceVoice {
            captureSpeechElapsed()
            speechToken += 1
            synthesizer?.stopSpeaking(at: .immediate)
            stopTicker()
        } else {
            player?.pause()
        }
        isPlaying = false
        publishNowPlaying()
    }

    func skip(by delta: TimeInterval) {
        let target = min(max(0, elapsed + delta), max(duration, 0))
        seek(to: target)
    }

    func seek(to time: TimeInterval) {
        let target = min(max(0, time), max(duration, 0))
        finished = false
        if usingDeviceVoice {
            elapsed = target
            if isPlaying {
                speak(from: target)
            }
        } else {
            let cmTime = CMTime(seconds: target, preferredTimescale: 600)
            player?.seek(to: cmTime, toleranceBefore: .zero, toleranceAfter: .zero)
            elapsed = target
        }
        publishNowPlaying()
    }

    func setSpeed(_ newSpeed: Double) {
        let next = LearnerSettings.nearest(newSpeed)
        guard next != speed else { return }
        if usingDeviceVoice {
            let fraction = duration > 0 ? elapsed / duration : 0
            speed = next
            timeline = SpeechTimeline.build(script: script, speed: speed)
            duration = timeline?.duration ?? 0
            elapsed = fraction * duration
            if isPlaying {
                speak(from: elapsed)
            }
        } else {
            speed = next
            player?.defaultRate = Float(speed)
            if isPlaying {
                player?.rate = Float(speed)
            }
        }
        publishNowPlaying()
    }

    func stop() {
        teardownPlayback()
        isPlaying = false
        elapsed = 0
        finished = false
        lessonID = nil
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }

    private func prepareFile(url: URL) {
        let item = AVPlayerItem(url: url)
        item.audioTimePitchAlgorithm = .timeDomain
        let player = AVPlayer(playerItem: item)
        player.defaultRate = Float(speed)
        self.player = player
        let bridge = bridge
        timeObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.5, preferredTimescale: 600),
            queue: .main
        ) { time in
            let seconds = time.seconds
            Task { @MainActor in
                bridge.owner?.applyFileTime(seconds)
            }
        }
        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { _ in
            Task { @MainActor in
                bridge.owner?.finish()
            }
        }
        Task { [weak self] in
            if let loaded = try? await item.asset.load(.duration), loaded.seconds.isFinite {
                await MainActor.run {
                    self?.duration = loaded.seconds
                    self?.publishNowPlaying()
                }
            }
        }
    }

    private func speak(from time: TimeInterval) {
        guard let timeline else { return }
        let text = timeline.text(from: time)
        guard !text.isEmpty else {
            finish()
            return
        }
        let synth = synthesizer ?? AVSpeechSynthesizer()
        synthesizer = synth
        if speechDelegate == nil {
            let delegate = SpeechDelegate()
            speechDelegate = delegate
            synth.delegate = delegate
        }
        speechToken += 1
        speechDelegate?.setOnFinish(nil)
        if synth.isSpeaking {
            synth.stopSpeaking(at: .immediate)
        }
        speechToken += 1
        let token = speechToken
        let bridge = bridge
        speechDelegate?.setOnFinish {
            Task { @MainActor in
                guard bridge.owner?.speechToken == token else { return }
                bridge.owner?.finish()
            }
        }
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = SpanishVoice.pick()
        let base = AVSpeechUtteranceDefaultSpeechRate
        utterance.rate = min(
            AVSpeechUtteranceMaximumSpeechRate,
            max(AVSpeechUtteranceMinimumSpeechRate, base * Float(speed))
        )
        speechOffset = timeline.offset(at: time)
        speechAnchor = Date()
        isPlaying = true
        finished = false
        synth.speak(utterance)
        startTicker()
    }

    private func applyFileTime(_ seconds: TimeInterval) {
        guard seconds.isFinite else { return }
        elapsed = seconds
        publishNowPlaying()
    }

    private func captureSpeechElapsed() {
        guard usingDeviceVoice, let anchor = speechAnchor else { return }
        let advanced = Date().timeIntervalSince(anchor) * speed
        elapsed = min(max(duration, 0), speechOffset + advanced)
    }

    private func startTicker() {
        ticker?.invalidate()
        let bridge = bridge
        let timer = Timer(timeInterval: 0.4, repeats: true) { _ in
            Task { @MainActor in
                bridge.owner?.captureSpeechElapsed()
                bridge.owner?.publishNowPlaying()
            }
        }
        ticker = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func stopTicker() {
        ticker?.invalidate()
        ticker = nil
        speechAnchor = nil
    }

    private func finish() {
        isPlaying = false
        finished = true
        if duration > 0 {
            elapsed = duration
        }
        stopTicker()
        publishNowPlaying()
    }

    private func teardownPlayback() {
        speechToken += 1
        stopTicker()
        synthesizer?.stopSpeaking(at: .immediate)
        if let timeObserver, let player {
            player.removeTimeObserver(timeObserver)
        }
        timeObserver = nil
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
        }
        endObserver = nil
        player?.pause()
        player = nil
    }

    private func activateSession() {
        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .spokenAudio, options: [])
        try? session.setActive(true)
        #endif
    }

    private func configureRemoteCommands() {
        guard !remoteConfigured else { return }
        remoteConfigured = true
        let center = MPRemoteCommandCenter.shared()
        center.playCommand.isEnabled = true
        center.pauseCommand.isEnabled = true
        center.togglePlayPauseCommand.isEnabled = true
        center.skipForwardCommand.isEnabled = true
        center.skipBackwardCommand.isEnabled = true
        center.skipForwardCommand.preferredIntervals = [15]
        center.skipBackwardCommand.preferredIntervals = [15]
        center.changePlaybackRateCommand.isEnabled = true
        center.changePlaybackRateCommand.supportedPlaybackRates = LearnerSettings.speeds.map { NSNumber(value: $0) }
        let bridge = bridge
        center.playCommand.addTarget { _ in
            Task { @MainActor in bridge.owner?.play() }
            return .success
        }
        center.pauseCommand.addTarget { _ in
            Task { @MainActor in bridge.owner?.pause() }
            return .success
        }
        center.togglePlayPauseCommand.addTarget { _ in
            Task { @MainActor in bridge.owner?.toggle() }
            return .success
        }
        center.skipForwardCommand.addTarget { _ in
            Task { @MainActor in bridge.owner?.skip(by: 15) }
            return .success
        }
        center.skipBackwardCommand.addTarget { _ in
            Task { @MainActor in bridge.owner?.skip(by: -15) }
            return .success
        }
        center.changePlaybackRateCommand.addTarget { event in
            guard let event = event as? MPChangePlaybackRateCommandEvent else { return .commandFailed }
            let rate = Double(event.playbackRate)
            Task { @MainActor in bridge.owner?.setSpeed(rate) }
            return .success
        }
    }

    fileprivate func publishNowPlaying() {
        guard lessonID != nil else { return }
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: lessonTitle,
            MPMediaItemPropertyArtist: artist,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: elapsed,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? speed : 0,
        ]
        if duration.isFinite, duration > 0 {
            info[MPMediaItemPropertyPlaybackDuration] = duration
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }
}

private final class PlayerBridge: @unchecked Sendable {
    weak var owner: LessonPlayer?
}

private final class SpeechDelegate: NSObject, AVSpeechSynthesizerDelegate, @unchecked Sendable {
    private let lock = NSLock()
    private var onFinish: (@Sendable () -> Void)?

    func setOnFinish(_ callback: (@Sendable () -> Void)?) {
        lock.lock()
        onFinish = callback
        lock.unlock()
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        lock.lock()
        let callback = onFinish
        lock.unlock()
        callback?()
    }
}

private enum SpanishVoice {
    static func pick() -> AVSpeechSynthesisVoice? {
        let voices = AVSpeechSynthesisVoice.speechVoices()
        let preferred = ["es-MX", "es-419", "es-US", "es-ES", "es-AR", "es-CO", "es-CL"]
        for code in preferred {
            if let voice = voices.first(where: { $0.language == code }) {
                return voice
            }
        }
        return voices.first { $0.language.hasPrefix("es") } ?? AVSpeechSynthesisVoice(language: "es-MX")
    }

    static func available() -> Bool {
        AVSpeechSynthesisVoice.speechVoices().contains { $0.language.hasPrefix("es") }
    }
}

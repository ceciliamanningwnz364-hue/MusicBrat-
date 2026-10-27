import AVFoundation
import MediaPlayer
import ActivityKit
import Combine

@MainActor
final class AudioPlayerManager: ObservableObject {
    static let shared = AudioPlayerManager()
    
    @Published var currentTrack: URL?
    @Published var isPlaying = false
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var trackTitle = ""
    
    private var player: AVAudioPlayer?
    private var timer: Timer?
    private var liveActivity: Activity<MusicLiveActivityAttributes>?
    
    private init() {
        setupAudioSession()
        setupRemoteCommands()
    }
    
    private func setupAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.allowAirPlay, .allowBluetoothA2DP])
            try session.setActive(true)
        } catch {
            print("Audio session error: \(error)")
        }
    }
    
    func play(url: URL) {
        do {
            player = try AVAudioPlayer(contentsOf: url)
            player?.delegate = self
            player?.prepareToPlay()
            player?.play()
            
            currentTrack = url
            isPlaying = true
            duration = player?.duration ?? 0
            trackTitle = url.deletingPathExtension().lastPathComponent
            
            startTimer()
            updateNowPlaying()
            startLiveActivity()
        } catch {
            print("Playback error: \(error)")
        }
    }
    
    func togglePlayPause() {
        guard let player = player else { return }
        if player.isPlaying {
            player.pause()
            isPlaying = false
        } else {
            player.play()
            isPlaying = true
        }
        updateNowPlaying()
        updateLiveActivity()
        if isPlaying { startTimer() } else { stopTimer() }
    }
    
    func seek(to time: TimeInterval) {
        player?.currentTime = time
        currentTime = time
        updateNowPlaying()
        updateLiveActivity()
    }
    
    private func startTimer() {
        stopTimer()
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self, let player = self.player else { return }
                self.currentTime = player.currentTime
            }
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    private func updateNowPlaying() {
        guard let player = player else { return }
        let info: [String: Any] = [
            MPMediaItemPropertyTitle: trackTitle,
            MPMediaItemPropertyPlaybackDuration: player.duration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: player.currentTime,
            MPNowPlayingInfoPropertyPlaybackRate: player.isPlaying ? 1.0 : 0.0
        ]
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }
    
    private func setupRemoteCommands() {
        let center = MPRemoteCommandCenter.shared()
        center.playCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.togglePlayPause() }
            return .success
        }
        center.pauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.togglePlayPause() }
            return .success
        }
        center.togglePlayPauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.togglePlayPause() }
            return .success
        }
    }
    
    private func startLiveActivity() {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let attributes = MusicLiveActivityAttributes(title: trackTitle)
        let state = MusicLiveActivityAttributes.ContentState(isPlaying: isPlaying, elapsed: currentTime, duration: duration)
        do {
            liveActivity = try Activity.request(attributes: attributes, content: .init(state: state, staleDate: nil))
        } catch {
            print("Live Activity error: \(error)")
        }
    }
    
    private func updateLiveActivity() {
        guard let activity = liveActivity else { return }
        let state = MusicLiveActivityAttributes.ContentState(isPlaying: isPlaying, elapsed: currentTime, duration: duration)
        Task { await activity.update(.init(state: state, staleDate: nil)) }
    }
}

extension AudioPlayerManager: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            self.isPlaying = false
            self.stopTimer()
            self.updateNowPlaying()
            self.updateLiveActivity()
            await self.liveActivity?.end(nil, dismissalPolicy: .immediate)
        }
    }
}

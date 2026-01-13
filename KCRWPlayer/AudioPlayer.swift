import AVFoundation
import Combine

enum KCRWStream: String, CaseIterable, Identifiable {
    case simulcast = "https://streams.kcrw.com/kcrw_mp3"
    case eclectic24 = "https://streams.kcrw.com/e24_mp3"
    case news24 = "https://streams.kcrw.com/news24_mp3"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .simulcast: return "KCRW 89.9"
        case .eclectic24: return "Eclectic24"
        case .news24: return "News24"
        }
    }
}

class AudioPlayer: ObservableObject {
    @Published var isPlaying = false
    @Published var currentStream: KCRWStream = .simulcast

    private var player: AVPlayer?
    private var playerItem: AVPlayerItem?

    init() {
        setupAudioSession()
    }

    private func setupAudioSession() {
        // Enable AirPlay for this app's audio
        player?.allowsExternalPlayback = true
    }

    func play() {
        guard let url = URL(string: currentStream.rawValue) else { return }

        playerItem = AVPlayerItem(url: url)
        player = AVPlayer(playerItem: playerItem)
        player?.allowsExternalPlayback = true
        player?.play()
        isPlaying = true
    }

    func pause() {
        player?.pause()
        isPlaying = false
    }

    func toggle() {
        if isPlaying {
            pause()
        } else {
            play()
        }
    }

    func switchStream(_ stream: KCRWStream) {
        let wasPlaying = isPlaying
        if isPlaying {
            pause()
        }
        currentStream = stream
        if wasPlaying {
            play()
        }
    }
}

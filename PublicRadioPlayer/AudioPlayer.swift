import AVFoundation
import Combine

struct RadioStream: Identifiable, Equatable {
    let name: String
    let url: String
    var id: String { url }
}

enum Station: String, CaseIterable, Identifiable {
    case kcrw = "KCRW"
    case wnyc = "WNYC"

    var id: String { rawValue }

    var streams: [RadioStream] {
        switch self {
        case .kcrw:
            return [
                RadioStream(name: "KCRW 89.9", url: "https://streams.kcrw.com/kcrw_mp3"),
                RadioStream(name: "Eclectic24", url: "https://streams.kcrw.com/e24_mp3"),
                RadioStream(name: "News24", url: "https://streams.kcrw.com/news24_mp3"),
            ]
        case .wnyc:
            return [
                RadioStream(name: "WNYC FM 93.9", url: "https://fm939.wnyc.org/wnycfm"),
                RadioStream(name: "WNYC AM 820", url: "https://am820.wnyc.org/wnycam"),
                RadioStream(name: "New Sounds", url: "https://q2stream.wqxr.org/q2"),
            ]
        }
    }
}

class AudioPlayer: ObservableObject {
    @Published var isPlaying = false
    @Published var currentStream: RadioStream

    private var player: AVPlayer?
    private var playerItem: AVPlayerItem?

    init() {
        currentStream = Station.kcrw.streams[0]
    }

    func play() {
        guard let url = URL(string: currentStream.url) else { return }

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

    func switchStream(_ stream: RadioStream) {
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

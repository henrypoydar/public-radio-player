import AVFoundation
import Combine

struct RadioStream: Identifiable, Equatable {
    let name: String
    let url: String
    // radio-browser station UUID. When set, the current stream URL is resolved
    // at launch — BBC rotates its CDN pool numbers, so the hardcoded `url` above
    // is only a fallback.
    var resolverUUID: String? = nil
    var id: String { name }
}

enum Station: String, CaseIterable, Identifiable {
    case kcrw = "KCRW"
    case wnyc = "WNYC"
    case radioFrance = "Radio France"
    case bbc = "BBC"

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
        case .radioFrance:
            return [
                RadioStream(name: "FIP", url: "https://icecast.radiofrance.fr/fip-midfi.mp3"),
                RadioStream(name: "RFI", url: "https://rfimonde64k.ice.infomaniak.ch/rfimonde-64.mp3"),
            ]
        case .bbc:
            return [
                RadioStream(name: "World Service", url: "https://a.files.bbci.co.uk/media/live/manifesto/audio/simulcast/hls/nonuk/sbr_low/ak/bbc_world_service.m3u8", resolverUUID: "14b6c684-bb7c-4926-b2a3-fd5a02bf7867"),
                RadioStream(name: "Radio 6 Music", url: "https://as-hls-ww-live.akamaized.net/pool_81827798/live/ww/bbc_6music/bbc_6music.isml/bbc_6music-audio=320000.norewind.m3u8", resolverUUID: "1c6dcd6f-88c6-4fd4-8191-078435168e85"),
            ]
        }
    }

    // Stations and channels, alphabetized for display (menu and CLI).
    static var sorted: [Station] {
        allCases.sorted { $0.rawValue.localizedCaseInsensitiveCompare($1.rawValue) == .orderedAscending }
    }

    var sortedStreams: [RadioStream] {
        streams.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
}

class AudioPlayer: ObservableObject {
    @Published var isPlaying = false
    @Published var currentStream: RadioStream

    private var player: AVPlayer?
    private var playerItem: AVPlayerItem?

    // URLs resolved at launch, keyed by stream id. Overrides the hardcoded
    // fallback in RadioStream when present.
    private var resolvedURLs: [String: String] = [:]

    init() {
        currentStream = Station.kcrw.streams[0]
        resolveStreams()
    }

    private func playbackURL(for stream: RadioStream) -> String {
        resolvedURLs[stream.id] ?? stream.url
    }

    private func resolveStreams() {
        for stream in Station.allCases.flatMap({ $0.streams }) {
            guard let uuid = stream.resolverUUID else { continue }
            resolve(stream: stream, uuid: uuid)
        }
    }

    private func resolve(stream: RadioStream, uuid: String) {
        guard let api = URL(string: "https://de1.api.radio-browser.info/json/stations/byuuid/\(uuid)") else { return }
        var request = URLRequest(url: api)
        request.setValue("PublicRadioPlayer/1.0", forHTTPHeaderField: "User-Agent")
        URLSession.shared.dataTask(with: request) { [weak self] data, _, _ in
            guard let self = self,
                  let data = data,
                  let stations = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]],
                  let resolved = stations.first?["url_resolved"] as? String,
                  !resolved.isEmpty else { return }
            let secure = resolved.replacingOccurrences(of: "http://", with: "https://")
            DispatchQueue.main.async {
                let wasURL = self.playbackURL(for: stream)
                self.resolvedURLs[stream.id] = secure
                // If this stream is playing on the now-stale URL, restart it.
                if self.isPlaying, self.currentStream.id == stream.id, wasURL != secure {
                    self.play()
                }
            }
        }.resume()
    }

    func play() {
        guard let url = URL(string: playbackURL(for: currentStream)) else { return }

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

    // Lookups used by the control server / CLI.
    func stream(withID id: String) -> RadioStream? {
        let target = id.lowercased()
        return Station.allCases.flatMap { $0.streams }.first { $0.id.lowercased() == target }
    }

    func station(for stream: RadioStream) -> Station? {
        Station.allCases.first { station in station.streams.contains { $0.id == stream.id } }
    }
}

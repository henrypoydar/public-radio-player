import AVFoundation
import Combine

struct RadioStream: Identifiable, Equatable {
    let name: String
    let url: String
    // radio-browser station UUID. When set, the current stream URL is resolved
    // at launch — BBC rotates its CDN pool numbers, so the hardcoded `url` above
    // is only a fallback.
    var resolverUUID: String? = nil
    // BBC media-selector vpid (e.g. "bbc_world_service"). When set, the current
    // HLS URL is resolved at launch from the same API BBC Sounds uses, which
    // tracks pool, CDN GUID, and profile changes — so the hardcoded `url` is
    // only a fallback.
    var bbcVPID: String? = nil
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
                // World Service is resolved at launch from BBC's media-selector
                // (bbcVPID); the hardcoded ms6 master is only a fallback for when
                // that lookup fails. (The legacy "manifesto" URL that radio-browser
                // still returns is dead, so it does not use resolverUUID.)
                RadioStream(name: "World Service", url: "https://a.files.bbci.co.uk/ms6/live/3441A116-B12E-4D2F-ACA8-C1984642FA4B/audio/simulcast/hls/nonuk/pc_hd_abr_v2/aks/bbc_world_service.m3u8", bbcVPID: "bbc_world_service"),
                // 6 Music has no non-UK ms6 master, so it's a direct pool URL kept current
                // at launch via radio-browser.
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
            if let vpid = stream.bbcVPID {
                resolveBBC(stream: stream, vpid: vpid)
            } else if let uuid = stream.resolverUUID {
                resolve(stream: stream, uuid: uuid)
            }
        }
    }

    // Resolve a BBC stream from its media-selector — the canonical source that
    // BBC Sounds itself queries. Returns the current HLS URL regardless of pool,
    // CDN GUID, or profile-version changes. Prefers the HTTPS Akamai supplier.
    private func resolveBBC(stream: RadioStream, vpid: String) {
        let endpoint = "https://open.live.bbc.co.uk/mediaselector/6/select/version/2.0/mediaset/pc/vpid/\(vpid)/format/json"
        guard let api = URL(string: endpoint) else { return }
        var request = URLRequest(url: api)
        request.setValue("PublicRadioPlayer/1.0", forHTTPHeaderField: "User-Agent")
        URLSession.shared.dataTask(with: request) { [weak self] data, _, _ in
            guard let self = self,
                  let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let media = json["media"] as? [[String: Any]] else { return }
            let hrefs = media
                .flatMap { ($0["connection"] as? [[String: Any]]) ?? [] }
                .compactMap { $0["href"] as? String }
                .filter { $0.hasPrefix("https://") && $0.contains(".m3u8") }
            guard let resolved = hrefs.first(where: { $0.contains("/aks/") }) ?? hrefs.first else { return }
            DispatchQueue.main.async {
                let wasURL = self.playbackURL(for: stream)
                self.resolvedURLs[stream.id] = resolved
                if self.isPlaying, self.currentStream.id == stream.id, wasURL != resolved {
                    self.play()
                }
            }
        }.resume()
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

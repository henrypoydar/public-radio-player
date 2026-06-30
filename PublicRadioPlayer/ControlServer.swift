import Foundation
import Network

/// A minimal localhost-only HTTP server that exposes the player to the `prp` CLI.
/// Endpoints: GET /status, GET /channels, /play, /pause, /toggle, /switch?stream=<name>
final class ControlServer {
    static let port: NWEndpoint.Port = 7997

    private let player: AudioPlayer
    private var listener: NWListener?
    private let queue = DispatchQueue(label: "com.local.publicradioplayer.control")

    init(player: AudioPlayer) {
        self.player = player
    }

    func start() {
        do {
            let params = NWParameters.tcp
            params.allowLocalEndpointReuse = true
            params.requiredLocalEndpoint = .hostPort(host: "127.0.0.1", port: ControlServer.port)
            let listener = try NWListener(using: params)
            listener.newConnectionHandler = { [weak self] connection in
                self?.handle(connection)
            }
            listener.start(queue: queue)
            self.listener = listener
        } catch {
            NSLog("ControlServer failed to start: \(error)")
        }
    }

    private func handle(_ connection: NWConnection) {
        connection.start(queue: queue)
        connection.receive(minimumIncompleteLength: 1, maximumLength: 8192) { [weak self] data, _, _, _ in
            guard let self = self, let data = data,
                  let request = String(data: data, encoding: .utf8) else {
                connection.cancel()
                return
            }
            let body = self.route(request)
            self.respond(body, over: connection)
        }
    }

    private func respond(_ body: String, over connection: NWConnection) {
        let response = """
        HTTP/1.1 200 OK\r
        Content-Type: application/json\r
        Content-Length: \(body.utf8.count)\r
        Connection: close\r
        \r
        \(body)
        """
        connection.send(content: response.data(using: .utf8), completion: .contentProcessed { _ in
            connection.cancel()
        })
    }

    // MARK: - Routing

    private func route(_ request: String) -> String {
        guard let requestLine = request.split(separator: "\r\n", maxSplits: 1).first else {
            return json(["error": "bad request"])
        }
        let fields = requestLine.split(separator: " ")
        guard fields.count >= 2 else { return json(["error": "bad request"]) }

        let target = fields[1].split(separator: "?", maxSplits: 1)
        let path = String(target[0])
        let params = parseQuery(target.count > 1 ? String(target[1]) : "")

        switch path {
        case "/status":
            return onMain { _ in }
        case "/channels":
            return channelsJSON()
        case "/play":
            return onMain { $0.play() }
        case "/pause":
            return onMain { $0.pause() }
        case "/toggle":
            return onMain { $0.toggle() }
        case "/switch":
            guard let id = params["stream"] else { return json(["error": "missing stream"]) }
            return onMain { player in
                guard let stream = player.stream(withID: id) else { return }
                player.switchStream(stream)
            }
        default:
            return json(["error": "not found"])
        }
    }

    /// Runs a player action on the main thread and returns the resulting status.
    private func onMain(_ action: @escaping (AudioPlayer) -> Void) -> String {
        var result = ""
        DispatchQueue.main.sync {
            action(player)
            result = statusJSON()
        }
        return result
    }

    // MARK: - Responses

    private func statusJSON() -> String {
        let stream = player.currentStream
        return json([
            "playing": player.isPlaying,
            "station": player.station(for: stream)?.rawValue ?? "",
            "stream": stream.name,
        ])
    }

    private func channelsJSON() -> String {
        let stations = Station.sorted.map { station -> [String: Any] in
            [
                "station": station.rawValue,
                "streams": station.sortedStreams.map { ["id": $0.id, "name": $0.name] },
            ]
        }
        return json(["stations": stations])
    }

    // MARK: - Helpers

    private func parseQuery(_ query: String) -> [String: String] {
        var result: [String: String] = [:]
        for pair in query.split(separator: "&") {
            let kv = pair.split(separator: "=", maxSplits: 1)
            // In query strings, '+' means a space; decode it before percent-decoding.
            guard let key = kv.first?.replacingOccurrences(of: "+", with: " ").removingPercentEncoding else { continue }
            let value = kv.count > 1
                ? (kv[1].replacingOccurrences(of: "+", with: " ").removingPercentEncoding ?? "")
                : ""
            result[key] = value
        }
        return result
    }

    private func json(_ object: Any) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: object),
              let string = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return string
    }
}

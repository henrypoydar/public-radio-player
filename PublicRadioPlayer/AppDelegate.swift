import AppKit
import AVKit
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private let audioPlayer = AudioPlayer()

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        setupPopover()
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            updateStatusIcon()
            button.action = #selector(togglePopover)
            button.target = self
        }
    }

    private func setupPopover() {
        popover = NSPopover()
        popover.contentSize = NSSize(width: 220, height: 320)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(
            rootView: MenuContentView(
                audioPlayer: audioPlayer,
                onIconUpdate: { [weak self] in self?.updateStatusIcon() }
            )
        )
    }

    private func updateStatusIcon() {
        if let button = statusItem.button {
            let iconName = audioPlayer.isPlaying ? "speaker.wave.2.fill" : "radio"
            button.image = NSImage(systemSymbolName: iconName, accessibilityDescription: "Public Radio Player")
        }
    }

    @objc private func togglePopover() {
        if let button = statusItem.button {
            if popover.isShown {
                popover.performClose(nil)
            } else {
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
                popover.contentViewController?.view.window?.makeKey()
            }
        }
    }
}

struct MenuContentView: View {
    @ObservedObject var audioPlayer: AudioPlayer
    var onIconUpdate: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                Text("Public Radio")
                    .font(.headline)
                Spacer()
                AirPlayButton()
                    .frame(width: 24, height: 24)
            }

            Divider()

            // Stations and streams
            ForEach(Station.allCases) { station in
                Text(station.rawValue)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.top, 2)

                ForEach(station.streams) { stream in
                    Button(action: {
                        audioPlayer.switchStream(stream)
                        onIconUpdate()
                    }) {
                        HStack {
                            Image(systemName: audioPlayer.currentStream == stream ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(audioPlayer.currentStream == stream ? .accentColor : .secondary)
                            Text(stream.name)
                            Spacer()
                        }
                    }
                    .buttonStyle(.plain)
                }
            }

            Divider()

            // Play/Pause button
            Button(action: {
                audioPlayer.toggle()
                onIconUpdate()
            }) {
                HStack {
                    Image(systemName: audioPlayer.isPlaying ? "pause.fill" : "play.fill")
                    Text(audioPlayer.isPlaying ? "Pause" : "Play")
                    Spacer()
                }
            }
            .buttonStyle(.plain)

            Divider()

            // Quit button
            Button(action: {
                NSApplication.shared.terminate(nil)
            }) {
                HStack {
                    Image(systemName: "xmark.circle")
                    Text("Quit")
                    Spacer()
                }
            }
            .buttonStyle(.plain)
        }
        .padding()
        .frame(width: 200)
    }
}

struct AirPlayButton: NSViewRepresentable {
    func makeNSView(context: Context) -> AVRoutePickerView {
        let picker = AVRoutePickerView()
        picker.isRoutePickerButtonBordered = false
        picker.setRoutePickerButtonColor(.labelColor, for: .normal)
        return picker
    }

    func updateNSView(_ nsView: AVRoutePickerView, context: Context) {}
}

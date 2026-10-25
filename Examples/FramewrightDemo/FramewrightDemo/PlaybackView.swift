import AVKit
import FramewrightAnalytics
import SwiftUI

struct PlaybackView: View {
    @StateObject private var model = PlaybackModel()
    @Environment(\.scenePhase) private var scenePhase
    @State private var stream = ""
    @State private var document: SessionDocument?
    @State private var exporting = false
    @State private var preparingExport = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VideoPlayer(player: model.player)
                        .aspectRatio(16 / 9, contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    controls
                    media
                    diagnostics
                }
                .padding()
            }
            .navigationTitle("Framewright")
            .task {
                await model.connect()
                if model.player.currentItem == nil { loadBundled("TestPattern") }
                while !Task.isCancelled {
                    model.refresh()
                    do { try await Task.sleep(for: .milliseconds(300)) } catch { break }
                }
                await model.disconnect()
            }
            .onChange(of: scenePhase) { phase in
                if phase != .active { model.pause() }
            }
            .fileExporter(
                isPresented: $exporting, document: document, contentType: .json, defaultFilename: "framewright-session"
            ) { result in
                if case .failure = result { model.message = "Unable to save the session export." }
            }
        }
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(model.playbackStatus).font(.headline).accessibilityIdentifier("playbackStatus")
                Spacer()
                Text(
                    "\(model.position.formatted(.number.precision(.fractionLength(0)))) / \(model.duration.formatted(.number.precision(.fractionLength(0)))) s"
                ).monospacedDigit()
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), alignment: .leading)], alignment: .leading) {
                playbackButtons
            }
            .buttonStyle(.bordered)
            .disabled(!model.connected || model.isSeeking)
        }
    }

    @ViewBuilder private var playbackButtons: some View {
        Button(action: model.play) { Label("Play", systemImage: "play.fill") }
        Button(action: model.pause) { Label("Pause", systemImage: "pause.fill") }
        Button("−5 s") { model.seek(by: -5) }
        Button("+5 s") { model.seek(by: 5) }
        Button("Replay", action: model.replay)
    }

    private var media: some View {
        GroupBox("Media") {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Button("Test pattern") { loadBundled("TestPattern") }
                    Button("Color bars") { loadBundled("ColorBars") }
                }
                TextField("HTTPS video or HLS URL", text: $stream)
                    .keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
                    .textFieldStyle(.roundedBorder).accessibilityIdentifier("streamURL")
                Button("Load stream") { model.loadStream(stream) }
                    .disabled(stream.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }.frame(maxWidth: .infinity, alignment: .leading)
        }.disabled(!model.connected)
    }

    private var diagnostics: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Diagnostics").font(.title2.bold())
            Text("First-frame timing is unavailable with this player view.")
                .font(.footnote).foregroundStyle(.secondary)
            if let message = model.message {
                Text(message).foregroundStyle(.red).textSelection(.enabled)
            }
            if model.diagnosticsIncomplete {
                Label(
                    "Diagnostics incomplete. Restart the app before a new validation run.",
                    systemImage: "exclamationmark.triangle"
                )
                .foregroundStyle(.orange)
            }
            if !model.sessions.isEmpty {
                Picker("Session", selection: $model.selectedSession) {
                    ForEach(model.sessions, id: \.self) { id in
                        Text(String(id.prefix(8))).tag(id)
                    }
                }.pickerStyle(.menu)
                Button(preparingExport ? "Preparing export…" : "Export session JSON") {
                    let id = model.selectedSession
                    preparingExport = true
                    Task {
                        defer { preparingExport = false }
                        do {
                            document = SessionDocument(text: try await model.exportSession(id))
                            exporting = true
                        } catch { model.message = "Unable to export this session." }
                    }
                }.disabled(preparingExport || model.selectedSession.isEmpty)
            }
            Text("Latest 200 events · Last 10 sessions").font(.caption).foregroundStyle(.secondary)
            LazyVStack(alignment: .leading, spacing: 10) {
                ForEach(model.events.filter { $0.sessionId == model.selectedSession }.reversed(), id: \.eventId) {
                    event in
                    DisclosureGroup(event.type.rawValue) {
                        Text(eventJSON(event)).font(.caption.monospaced()).textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
    }

    private func loadBundled(_ name: String) {
        guard let url = Bundle.main.url(forResource: name, withExtension: "mp4") else {
            model.message = "Bundled media is missing."
            return
        }
        model.load(url)
    }

    private func eventJSON(_ event: DiagnosticEvent) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(event) else { return event.type.rawValue }
        return String(decoding: data, as: UTF8.self)
    }
}

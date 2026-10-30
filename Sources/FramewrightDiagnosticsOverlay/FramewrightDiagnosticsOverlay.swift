import FramewrightAnalytics
import SwiftUI
import UniformTypeIdentifiers

@MainActor
public struct FramewrightDiagnosticsOverlay: View {
    private let pipeline: DiagnosticEventPipeline
    private let sessionID: String
    private let incomplete: Bool
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var model = DiagnosticsModel()
    @State private var expanded = false
    @State private var exporting = false
    @State private var document: DiagnosticsDocument?
    @State private var exportError: String?

    public init(pipeline: DiagnosticEventPipeline, sessionID: String, incomplete: Bool = false) {
        self.pipeline = pipeline
        self.sessionID = sessionID
        self.incomplete = incomplete
    }

    public var body: some View {
        Button {
            expanded = true
        } label: {
            Label("Diagnostics · \(model.state?.status ?? "Waiting")", systemImage: "waveform.path.ecg")
                .font(.subheadline.weight(.medium))
                .padding(12)
                .frame(minHeight: 44)
                .background(.regularMaterial, in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityHint("Opens session metrics and event history")
        .task(
            id: ObservationKey(
                pipeline: ObjectIdentifier(pipeline), sessionID: sessionID, active: scenePhase == .active)
        ) {
            guard scenePhase == .active else { return }
            await model.observe(pipeline: pipeline, sessionID: sessionID)
        }
        .sheet(isPresented: $expanded) { details }
    }

    private var details: some View {
        NavigationStack {
            List {
                if incomplete { Text("Some diagnostics could not be recorded.").foregroundStyle(.orange) }
                if let error = model.errorMessage { Text(error).foregroundStyle(.orange) }
                if let state = model.state {
                    Section("Session") {
                        row("Status", state.status)
                        row("Device", state.deviceName)
                        row("Hardware identifier", state.deviceModel)
                        Text(state.snapshot.sessionId).font(.caption).textSelection(.enabled)
                        if state.snapshot.truncated {
                            Text("Partial history: older events were removed.").foregroundStyle(.orange)
                        }
                    }
                    Section {
                        row("First frame", state.summary.timeToFirstFrameMs.map { "\($0) ms" } ?? "Unavailable")
                        row(
                            "Rebuffers",
                            state.summary.timeToFirstFrameMs == nil ? "Unavailable" : "\(state.summary.rebufferCount)")
                        row("Dropped frames", state.droppedFrames.map(String.init) ?? "Unavailable")
                    } header: {
                        Text("Metrics")
                    } footer: {
                        Text(
                            "Metrics reflect retained events. Unavailable measurements require additional instrumentation."
                        )
                    }
                    Section("Events (\(state.snapshot.events.count))") {
                        ForEach(Array(state.snapshot.events.enumerated()), id: \.offset) { _, event in
                            DiagnosticEventRow(event: event)
                                .id(event.eventId)
                        }
                    }
                } else {
                    Text("Waiting for session diagnostics.")
                }
                if let exportError { Text(exportError).foregroundStyle(.orange) }
            }
            .navigationTitle("Diagnostics")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { expanded = false } }
                ToolbarItem(placement: .automatic) {
                    Button {
                        export()
                    } label: {
                        Label("Export JSON", systemImage: "square.and.arrow.up")
                    }
                    .disabled(model.state == nil)
                }
            }
            .fileExporter(
                isPresented: $exporting, document: document, contentType: .json,
                defaultFilename: "framewright-session"
            ) { result in
                if case .failure = result { exportError = "Unable to save the session export." }
            }
        }
    }

    private func row(_ title: String, _ value: String) -> some View {
        LabeledContent(title) { Text(value).textSelection(.enabled) }
    }

    private func export() {
        guard let state = model.state else { return }
        do {
            document = DiagnosticsDocument(json: try DiagnosticEventJSONCodec().encodeSession(state.snapshot))
            exportError = nil
            exporting = true
        } catch { exportError = "Unable to export the session." }
    }
}

private struct ObservationKey: Equatable {
    let pipeline: ObjectIdentifier
    let sessionID: String
    let active: Bool
}

private struct DiagnosticsDocument: FileDocument {
    static let readableContentTypes: [UTType] = [.json]
    let json: String
    init(json: String) { self.json = json }
    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else { throw CocoaError(.fileReadCorruptFile) }
        json = String(decoding: data, as: UTF8.self)
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data(json.utf8))
    }
}

private struct DiagnosticEventRow: View {
    let event: DiagnosticEvent
    @State private var expanded = false

    var body: some View {
        DisclosureGroup(isExpanded: $expanded) {
            if expanded {
                Text((try? DiagnosticEventJSONCodec().encodeEvent(event)) ?? "Unable to encode event.")
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
            }
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(event.type.rawValue.replacingOccurrences(of: "_", with: " ").capitalized)
                Text(Date(timeIntervalSince1970: Double(event.metadata.timestampMs) / 1000), style: .time)
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}

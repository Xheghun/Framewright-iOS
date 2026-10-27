import AVKit
import FramewrightDiagnosticsOverlay
import SwiftUI

struct PlaybackView: View {
    @StateObject private var model = PlaybackModel()
    @Environment(\.scenePhase) private var scenePhase
    @State private var stream = ""
    @State private var mediaName = "Big Buck Bunny"
    @State private var mediaKind = "Short film trailer"
    @State private var showingMedia = false
    @State private var showingPoster = true
    @State private var posterURL = URL(string: "https://media.w3.org/2010/05/bunny/poster.png")
    @State private var sourceError: String?

    private let accent = Color(red: 0.46, green: 0.82, blue: 0.84)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    player
                    nowPlaying
                    if let pipeline = model.pipeline {
                        FramewrightDiagnosticsOverlay(
                            pipeline: pipeline, sessionID: model.selectedSession,
                            incomplete: model.diagnosticsIncomplete)
                    }
                    if let message = model.message {
                        Label(message, systemImage: "exclamationmark.circle")
                            .font(.footnote).foregroundStyle(.orange).textSelection(.enabled)
                    }
                    if model.sessions.count > 1 {
                        Picker("Diagnostic session", selection: $model.selectedSession) {
                            ForEach(model.sessions, id: \.self) { id in
                                Text(String(id.prefix(8))).tag(id)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                    Button {
                        showingMedia = true
                    } label: {
                        Label("Choose video", systemImage: "rectangle.stack.badge.plus")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: 48)
                    }
                    .buttonStyle(.bordered)
                    .disabled(!model.connected)
                }
                .frame(maxWidth: 760)
                .padding(.horizontal, 24)
                .padding(.vertical, 32)
                .frame(maxWidth: .infinity)
            }
            .background(Color(red: 0.055, green: 0.065, blue: 0.08))
            .navigationTitle("Framewright")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .navigationBarTrailing) { playbackMenu } }
            .sheet(isPresented: $showingMedia) { mediaPicker }
        }
        .tint(accent)
        .preferredColorScheme(.dark)
        .task {
            await model.connect()
            if model.player.currentItem == nil { loadFilm("Big Buck Bunny", path: "bunny") }
            while !Task.isCancelled {
                model.refresh()
                do { try await Task.sleep(for: .milliseconds(300)) } catch { break }
            }
            await model.disconnect()
        }
        .onChange(of: model.playbackStatus) { status in
            if status == "Playing" { showingPoster = false }
        }
        .onChange(of: scenePhase) { phase in
            if phase != .active { model.pause() }
        }
    }

    private var player: some View {
        VideoPlayer(player: model.player)
            .aspectRatio(16 / 9, contentMode: .fit)
            .background(.black)
            .overlay {
                if showingPoster, let posterURL {
                    GeometryReader { geometry in
                        AsyncImage(url: posterURL) { image in
                            image.resizable().scaledToFill()
                        } placeholder: {
                            Color.black
                        }
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .clipped()
                    }
                    .overlay {
                        Button {
                            showingPoster = false
                            model.play()
                        } label: {
                            Image(systemName: "play.fill")
                                .font(.title2).foregroundStyle(.white)
                                .frame(width: 60, height: 60)
                                .background(.ultraThinMaterial, in: Circle())
                        }
                        .accessibilityLabel("Play \(mediaName)")
                        .disabled(!model.connected)
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay {
                RoundedRectangle(cornerRadius: 20).strokeBorder(.white.opacity(0.08))
                    .allowsHitTesting(false)
            }
    }

    private var nowPlaying: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("NOW PLAYING")
                .font(.caption2.weight(.semibold)).tracking(2).foregroundStyle(accent)
            Text(mediaName).font(.title2.weight(.semibold))
            ViewThatFits(in: .horizontal) {
                HStack {
                    playbackStatus
                    Spacer()
                    Text(mediaKind).foregroundStyle(.secondary)
                }
                VStack(alignment: .leading, spacing: 8) {
                    playbackStatus
                    Text(mediaKind).foregroundStyle(.secondary)
                }
            }
            .font(.subheadline)
        }
    }

    private var playbackStatus: some View {
        Label {
            Text(model.playbackStatus).accessibilityIdentifier("playbackStatus")
        } icon: {
            Circle().fill(model.playbackStatus == "Playing" ? accent : .secondary).frame(width: 6, height: 6)
        }
    }

    private var playbackMenu: some View {
        Menu {
            Button(action: model.play) { Label("Play", systemImage: "play") }
            Button(action: model.pause) { Label("Pause", systemImage: "pause") }
            Divider()
            Button {
                model.seek(by: -5)
            } label: {
                Label("Back 5 seconds", systemImage: "gobackward.5")
            }
            .disabled(model.isSeeking)
            Button {
                model.seek(by: 5)
            } label: {
                Label("Forward 5 seconds", systemImage: "goforward.5")
            }
            .disabled(model.isSeeking)
            Button(action: model.replay) { Label("Replay as new session", systemImage: "arrow.counterclockwise") }
                .disabled(model.isSeeking)
        } label: {
            Image(systemName: "ellipsis.circle").frame(minWidth: 44, minHeight: 44)
        }
        .accessibilityLabel("Playback actions")
        .disabled(!model.connected)
    }

    private var mediaPicker: some View {
        NavigationStack {
            Form {
                Section {
                    filmOption("Big Buck Bunny", detail: "Blender Foundation · 2008", path: "bunny")
                    filmOption("Sintel", detail: "Blender Foundation · 2010", path: "sintel")
                } header: {
                    Text("Sample films")
                } footer: {
                    Text("Trailers stream over the internet. Choose an offline test video when disconnected.")
                }
                Section("Offline test videos") {
                    mediaOption(
                        "Test pattern", detail: "Motion and color · 12 seconds", resource: "TestPattern",
                        icon: "play.rectangle")
                    mediaOption(
                        "Color bars", detail: "Static color reference · 12 seconds", resource: "ColorBars",
                        icon: "rectangle.split.3x1")
                }
                Section {
                    TextField("https://example.com/video.m3u8", text: $stream)
                        .keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
                        .accessibilityLabel("Stream URL").accessibilityIdentifier("streamURL")
                    Button("Open stream") {
                        guard let url = PlaybackModel.streamURL(stream) else {
                            sourceError = "Enter an HTTPS media URL without embedded credentials."
                            return
                        }
                        model.load(url)
                        showingPoster = false
                        posterURL = nil
                        mediaName = url.host ?? "Stream"
                        mediaKind = "Online video"
                        sourceError = nil
                        showingMedia = false
                    }.disabled(stream.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    if let sourceError { Text(sourceError).font(.footnote).foregroundStyle(.orange) }
                } header: {
                    Text("Your stream")
                } footer: {
                    Text("Open an HTTPS video or HLS stream.")
                }
                Section("Credits") {
                    creditLink("Big Buck Bunny — © 2008 Blender Foundation", url: "https://peach.blender.org/about/")
                    creditLink("Sintel — © 2010 Blender Foundation", url: "https://durian.blender.org/about/")
                    creditLink("Creative Commons Attribution 3.0", url: "https://creativecommons.org/licenses/by/3.0/")
                    Text("Unmodified trailers and posters hosted by W3C.").font(.caption).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Choose video")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { showingMedia = false } }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    @ViewBuilder private func creditLink(_ title: String, url: String) -> some View {
        if let destination = URL(string: url) { Link(title, destination: destination) }
    }

    private func filmOption(_ title: String, detail: String, path: String) -> some View {
        Button {
            loadFilm(title, path: path)
            showingMedia = false
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "film").font(.title3).frame(width: 28)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).foregroundStyle(.primary)
                    Text(detail).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                if mediaName == title { Image(systemName: "checkmark.circle.fill") }
            }
            .padding(.vertical, 6)
        }
    }

    private func loadFilm(_ title: String, path: String) {
        guard let url = URL(string: "https://media.w3.org/2010/05/\(path)/trailer.mp4") else { return }
        model.load(url)
        posterURL = URL(string: "https://media.w3.org/2010/05/\(path)/poster.png")
        showingPoster = true
        mediaName = title
        mediaKind = "Short film trailer"
    }

    private func mediaOption(_ title: String, detail: String, resource: String, icon: String) -> some View {
        Button {
            loadBundled(resource, title: title)
            showingMedia = false
        } label: {
            HStack(spacing: 12) {
                Image(systemName: icon).font(.title3).frame(width: 28)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).foregroundStyle(.primary)
                    Text(detail).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                if mediaName == title { Image(systemName: "checkmark.circle.fill") }
            }
            .padding(.vertical, 6)
        }
    }

    private func loadBundled(_ name: String, title: String) {
        guard let url = Bundle.main.url(forResource: name, withExtension: "mp4") else {
            model.message = "Bundled media is missing."
            return
        }
        model.load(url)
        showingPoster = false
        posterURL = nil
        mediaName = title
        mediaKind = "Bundled video"
    }

}

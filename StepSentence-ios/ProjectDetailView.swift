import SwiftUI
import SwiftData
import AVFoundation

struct ProjectDetailView: View {
    @Bindable var project: Project
    
    // Sequential playback state
    @State private var isSequentialPlaying = false
    @State private var playbackList: [Sentence] = []
    @State private var playbackIndex: Int = 0
    @State private var currentPlayingSentenceID: Sentence.ID?

    // Segment (source audio) playback
    @State private var segmentPlayer: SegmentPlayer = SegmentPlayer()
    @State private var isTimedProject: Bool = false
    @State private var appearT0: Date = .now
    @State private var didLogFirstRowAppear = false
    @State private var sortedSentences: [Sentence] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text(project.title)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                ProgressView(value: Double(project.completedCount), total: Double(project.totalCount)) {
                    HStack {
                        Text("录制进度")
                        Spacer()
                        Text("\(project.completedCount)/\(project.totalCount)")
                    }
                }
                .tint(.green)
            }
            .padding(.horizontal)

            // Playback control (single capsule-style toggle)
            HStack(spacing: 16) {
                Button(action: {
                    if isSequentialPlaying {
                        stopSequentialPlayback()
                    } else {
                        startSequentialPlayback()
                    }
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: isSequentialPlaying ? "stop.fill" : "play.fill")
                            .font(.title3.weight(.semibold))
                        Text(isSequentialPlaying ? "停止播放" : "播放已录制")
                            .font(.subheadline)
                    }
                    .foregroundColor(.white)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 14)
                    .background(
                        Capsule().fill(isSequentialPlaying ? Color.red : Color.accentColor)
                    )
                    .shadow(color: .black.opacity(0.08), radius: 3, x: 0, y: 1)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isSequentialPlaying ? "停止播放" : "播放已录制")
                Spacer()
            }
            .padding(.horizontal)
            .padding(.bottom, 4)

            ScrollViewReader { proxy in
                List {
                    let nextUnlockId = sortedSentences.first(where: { $0.status == .notStarted })?.id

                    ForEach(sortedSentences) { sentence in
                        let isUnlocked = sentence.status != .notStarted || sentence.id == nextUnlockId
                        let isPlayingThis = sentence.id == currentPlayingSentenceID

                        Group {
                            if isUnlocked {
                                NavigationLink(value: sentence) {
                                    rowView(for: sentence)
                                }
                            } else {
                                rowView(for: sentence)
                                    .opacity(0.6)
                            }
                        }
                        .listRowSeparator(.hidden)
                        .listRowBackground(isPlayingThis ? Color.accentColor.opacity(0.12) : Color.clear)
                        .id(sentence.id)
                        .onAppear {
                            if !didLogFirstRowAppear {
                                didLogFirstRowAppear = true
                                let dt = Date().timeIntervalSince(appearT0)
                                print("[ProjectDetailView] First row appeared after \(String(format: "%.3f", dt))s. rows=\(sortedSentences.count) timed=\(isTimedProject)")
                            }
                        }
                    }
                }
                .listStyle(.plain)
                .navigationDestination(for: Sentence.self) { sentence in
                    PracticeView(sentence: sentence, project: project, sortedSentences: sortedSentences, segmentPlayer: segmentPlayer)
                }
                .onChange(of: currentPlayingSentenceID) { _, newValue in
                    guard let id = newValue else { return }
                    withAnimation(.easeInOut) {
                        proxy.scrollTo(id, anchor: .center)
                    }
                }
            }
        }
        // No navigation title on this page per request
        .toolbar {
            if project.sourceAudioFileName == nil, project.completedCount == project.totalCount && project.totalCount > 0 {
                ToolbarItem(placement: .primaryAction) {
                    NavigationLink(destination: SynthesisView(project: project)) {
                        Text("合成作品")
                    }
                }
            }
        }
        .onAppear {
            appearT0 = Date()
            didLogFirstRowAppear = false
            print("[ProjectDetailView] onAppear start. title=\(project.title) sentences=\(project.sentences.count)")
            
            // Setup lightweight things immediately
            segmentPlayer.onSegmentEnd = { id in
                DispatchQueue.main.async { currentPlayingSentenceID = nil }
            }

            // Perform heavy operations asynchronously
            Task {
                let t0 = Date()
                let sorted = project.sentences.sorted(by: { $0.order < $1.order })
                let timed = project.sourceAudioURL != nil && sorted.contains(where: { $0.hasTiming })
                let dt = Date().timeIntervalSince(t0)
                print("[ProjectDetailView] Background preparation took \(String(format: "%.3f", dt))s")
                
                await MainActor.run {
                    sortedSentences = sorted
                    isTimedProject = timed
                    if let url = project.sourceAudioURL, timed {
                        segmentPlayer.ensureLoaded(url: url)
                    }
                    print("[ProjectDetailView] Updated UI with sorted sentences.")
                }
            }
        }
        .onDisappear {
            stopSequentialPlayback()
            segmentPlayer.stop()
        }
    }

    @ViewBuilder
    private func rowView(for sentence: Sentence) -> some View {
        HStack {
            Text(sentence.text)
            Spacer()
            Circle()
                .frame(width: 12, height: 12)
                .foregroundStyle(colorForStatus(sentence.status))
        }
        .padding(.vertical, 4)
    }

    private func colorForStatus(_ status: SentenceStatus) -> Color {
        switch status {
        case .notStarted:
            return .gray.opacity(0.5)
        case .recorded, .needsReview:
            return .orange
        case .approved:
            return .green
        }
    }
}

// MARK: - Sequential Playback Logic
extension ProjectDetailView {
    private func startSequentialPlayback() {
        // Build ordered playback list until first missing recording
        var contiguous: [Sentence] = []
        for s in sortedSentences {
            if let url = s.audioURL, FileManager.default.fileExists(atPath: url.path) {
                contiguous.append(s)
            } else {
                break
            }
        }
        guard !contiguous.isEmpty else { return }

        playbackList = contiguous
        playbackIndex = 0
        isSequentialPlaying = true
        currentPlayingSentenceID = nil
        playNextIfPossible()
    }

    private func playNextIfPossible() {
        guard isSequentialPlaying else { return }
        guard playbackIndex < playbackList.count else {
            isSequentialPlaying = false
            return
        }

        let sentence = playbackList[playbackIndex]
        guard let url = sentence.audioURL, FileManager.default.fileExists(atPath: url.path) else {
            // Stop at the first missing recording; do not skip
            isSequentialPlaying = false
            currentPlayingSentenceID = nil
            return
        }

        currentPlayingSentenceID = sentence.id
        do {
            try AudioPlayback.shared.play(url: url) {
                // Proceed to next when current finishes
                DispatchQueue.main.async {
                    playbackIndex += 1
                    playNextIfPossible()
                }
            }
        } catch {
            // Stop on error
            isSequentialPlaying = false
            currentPlayingSentenceID = nil
        }
    }

    private func stopSequentialPlayback() {
        isSequentialPlaying = false
        AudioPlayback.shared.stop()
        currentPlayingSentenceID = nil
    }

    // Seeking removed per request (no dragging)

    // Timed playback
    private func playTimedSentence(_ sentence: Sentence) {
        guard let start = sentence.startTimeSec, let end = sentence.endTimeSec, end > start else { return }
        if let url = project.sourceAudioURL {
            let exists = FileManager.default.fileExists(atPath: url.path)
            var sizeStr = "unknown"
            if let attrs = try? FileManager.default.attributesOfItem(atPath: url.path), let size = attrs[.size] as? NSNumber {
                let mb = Double(truncating: size) / (1024*1024)
                sizeStr = String(format: "%.2f MB", mb)
            }
            print("[ProjectDetailView] playTimedSentence ensureLoaded url=\(url.lastPathComponent) exists=\(exists) size=\(sizeStr)")
            segmentPlayer.ensureLoaded(url: url)
        }
        currentPlayingSentenceID = sentence.id
        segmentPlayer.playSegment(id: sentence.id.uuidString, start: start, end: end)
    }
}

#Preview {
    let project: Project = Project(title: "测试项目", fullText: "这是一个测试句子。")
    project.sentences = [Sentence(order: 0, text: "这是一个测试句子。", project: project)]
    
    return NavigationStack {
        ProjectDetailView(project: project)
            .modelContainer(for: [Project.self, Sentence.self], inMemory: true)
    }
}

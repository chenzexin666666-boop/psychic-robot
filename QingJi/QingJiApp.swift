import SwiftUI
import Speech
import AVFoundation
import PhotosUI
import UIKit

struct DiaryItem: Codable, Identifiable {
    var id = UUID()
    var timestamp = Date()
    var text: String
    var imageName: String?
}
@MainActor
final class DiaryModel: ObservableObject {
    @Published var items: [DiaryItem] = []
    @Published var listening = false
    @Published var presented = false
    @Published var text = ""
    @Published var status = "按下开始记录"
    @Published var showPhotoPicker = false
    @Published var selectedPhoto: PhotosPickerItem?
    private var lastVoiceTime = Date()
    private var checkTask: Task<Void, Never>?
    private var dismissTask: Task<Void, Never>?
    private var engine: AVAudioEngine?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var recordingID: UUID?
    private var photoRequested = false
    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "zh_CN"))
    private var base: URL { FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0] }
    private var dataFile: URL { base.appendingPathComponent("journal.json") }

    init() { load() }
    func load() {
        if let bytes = try? Data(contentsOf: dataFile),
           let data = try? JSONDecoder().decode([DiaryItem].self, from: bytes) {
            items = data
        }
    }
    private func save() {
        if let data = try? JSONEncoder().encode(items) {
            try? data.write(to: dataFile, options: .atomic)
        }
    }
    func begin() {
        guard !listening else { return }
        dismissTask?.cancel()
        presented = true
        text = ""
        status = "准备识别…"
        photoRequested = false
        recordingID = UUID()
        Task {
            let authorized = await withCheckedContinuation { (c: CheckedContinuation<Bool, Never>) in
                SFSpeechRecognizer.requestAuthorization { c.resume(returning: $0 == .authorized) }
            }
            guard authorized, await AVAudioApplication.requestRecordPermission() else {
                status = "请在系统设置里允许麦克风和语音识别"
                return
            }
            startEngine()
        }
    }
    private func startEngine() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.record, mode: .measurement)
            try session.setActive(true)
            let engine = AVAudioEngine()
            let input = engine.inputNode
            let fmt = input.outputFormat(forBus: 0)
            let req = SFSpeechAudioBufferRecognitionRequest()
            req.shouldReportPartialResults = true
            if recognizer?.supportsOnDeviceRecognition == true {
                req.requiresOnDeviceRecognition = true
            }
            input.installTap(onBus: 0, bufferSize: 1024, format: fmt) { buffer, _ in
                req.append(buffer)
                if let first = buffer.floatChannelData?.pointee {
                    let count = Int(buffer.frameLength)
                    var sum: Float = 0
                    for i in stride(from: 0, to: count, by: 32) {
                        sum += abs(first[i])
                    }
                    let level = sum / Float(max(1, (count + 31) / 32))
                    if level > 0.009 {
                        Task { @MainActor in self.lastVoiceTime = Date() }
                    }
                }
            }
            self.engine = engine
            self.request = req
            lastVoiceTime = Date()
            try engine.start()
            listening = true
            status = "正在听你说"
            task = recognizer?.recognitionTask(with: req) { [weak self] result, error in
                Task { @MainActor in
                    guard let self else { return }
                    if let result {
                        self.text = result.bestTranscription.formattedString
                        self.lastVoiceTime = Date()
                        self.persistCurrent()
                    }
                    if error != nil && self.listening { self.finish() }
                }
            }
            checkTask = Task { [weak self] in
                while let self, self.listening, !Task.isCancelled {
                    try? await Task.sleep(for: .milliseconds(400))
                    guard !Task.isCancelled else { return }
                    if Date().timeIntervalSince(self.lastVoiceTime) >= 5 {
                        self.finish()
                        return
                    }
                }
            }
        } catch { status = "无法启动麦克风：\\(error.localizedDescription)" }
    }
    private func persistCurrent() {
        guard let id = recordingID, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        if let i = items.firstIndex(where: { $0.id == id }) { items[i].text = text }
        else { items.insert(DiaryItem(id: id, text: text), at: 0) }
        save()
    }
    func finish() {
        guard listening else { return }
        listening = false
        checkTask?.cancel()
        engine?.inputNode.removeTap(onBus: 0)
        engine?.stop()
        request?.endAudio()
        task?.cancel()
        engine = nil
        request = nil
        task = nil
        persistCurrent()
        status = "已保存"
        if !photoRequested { grace() }
    }
    private func grace() {
        dismissTask?.cancel()
        dismissTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            self?.presented = false
        }
    }
    func startPhoto() {
        photoRequested = true
        dismissTask?.cancel()
        if listening { finish() }
        showPhotoPicker = true
    }
    func photoFinished() {
        photoRequested = false
        grace()
    }
    func savePhoto(_ item: PhotosPickerItem) async {
        defer { photoFinished() }
        guard let bytes = try? await item.loadTransferable(type: Data.self) else { return }
        let id = recordingID ?? UUID()
        recordingID = id
        let filename = "\\(id.uuidString).jpg"
        guard let image = UIImage(data: bytes),
              let jpeg = image.jpegData(compressionQuality: 0.85) else { return }
        do {
            try jpeg.write(to: base.appendingPathComponent(filename), options: .atomic)
            if let idx = items.firstIndex(where: { $0.id == id }) {
                items[idx].imageName = filename
            } else { items.insert(DiaryItem(id: id, text: "", imageName: filename), at: 0) }
            save()
        } catch { status = "照片保存失败" }
    }
}

@main
struct QingJiApp: App {
    @StateObject private var model = DiaryModel()
    var body: some Scene {
        WindowGroup {
            NavigationStack {
                VStack(spacing: 20) {
                    Text("轻记").font(.system(size: 38, weight: .semibold))
                    Text("一按即记，开口即存").foregroundStyle(.secondary)
                    Button("开始语音速记") { model.begin() }.buttonStyle(.borderedProminent)
                    List(model.items) { item in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(item.timestamp.formatted(date: .abbreviated, time: .standard)).font(.caption).foregroundStyle(.secondary)
                            if !item.text.isEmpty { Text(item.text) }
                            if let name = item.imageName,
                               let image = UIImage(contentsOfFile: FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent(name).path) {
                                Image(uiImage: image).resizable().scaledToFit().frame(maxHeight: 180)
                            }
                        }
                    }
                }
                .padding(.top, 20)
            }
            .onOpenURL { url in
                if url.scheme == "qingji" && url.host == "capture" { model.begin() }
            }
            .fullScreenCover(isPresented: $model.presented) {
                VStack(spacing: 20) {
                    HStack { Text(model.status); Spacer(); Button("关闭") { model.finish(); model.presented = false } }
                    Text(Date().formatted(date: .abbreviated, time: .shortened))
                        .font(.title)
                    ScrollView {
                        Text(model.text.isEmpty ? "你说的话会出现在这里…" : model.text)
                            .font(.title3).frame(maxWidth: .infinity, alignment: .leading)
                    }
                    PhotosPicker(selection: $model.selectedPhoto, matching: .images) {
                        Label("添加照片", systemImage: "photo")
                            .frame(maxWidth: .infinity).padding()
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                    }
                }
                .padding(24)
                .onChange(of: model.selectedPhoto) { _, value in
                    if let value {
                        model.startPhoto()
                        Task { await model.savePhoto(value) }
                    } else { model.photoFinished() }
                }
            }
        }
    }
}

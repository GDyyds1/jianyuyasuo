//
//  JianyuApp.swift
//  笺语压缩 iOS —— 手机单文件版（SwiftUI + .jianyu/zip/tar/gz 内核）
//
//  这是把工程里 8 个 Swift 文件合并成一整份，方便在手机浏览器上
//  一次性粘贴到 GitHub 的“新建文件”里。
//

// ======================== \(path) ========================
import SwiftUI

// 与安卓 / Windows 版同一套色值
enum Palette {
    static let bg = Color(hex: 0xF1F5F2)
    static let card = Color.white
    static let primary = Color(hex: 0x0E6B5C)
    static let primarySoft = Color(hex: 0xE6F1EC)
    static let textMain = Color(hex: 0x16211D)
    static let textSub = Color(hex: 0x8B968F)
    static let fieldBg = Color(hex: 0xF4F6F5)
    static let line = Color(hex: 0xE3EAE6)
}

extension Color {
    init(hex: UInt32) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: 1)
    }
}

struct CardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(18)
            .background(Palette.card)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 4)
    }
}

extension View {
    func card() -> some View { modifier(CardModifier()) }

    func primaryButton() -> some View {
        self.font(.system(size: 17, weight: .bold))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(Palette.primary)
            .clipShape(Capsule())
    }

    func softButton() -> some View {
        self.font(.system(size: 17, weight: .medium))
            .foregroundColor(Palette.textMain)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(Palette.primarySoft)
            .clipShape(Capsule())
    }
}

struct Pill: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.system(size: 14, weight: .medium))
            .foregroundColor(Palette.primary)
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(Palette.primarySoft)
            .clipShape(Capsule())
    }
}

struct FieldLabel: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.system(size: 15))
            .foregroundColor(Palette.textSub)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct FakeField: View {
    let text: String
    let placeholder: Bool
    var height: CGFloat = 76
    var body: some View {
        Text(text)
            .font(.system(size: 16))
            .foregroundColor(placeholder ? Palette.textSub : Palette.textMain)
            .lineLimit(3)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .frame(height: height, alignment: .center)
            .background(Palette.fieldBg)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

// ======================== \(path) ========================
import SwiftUI
import UniformTypeIdentifiers

@main
struct JianyuApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.light)
        }
    }
}

enum Mode: String, CaseIterable {
    case compress = "压缩"
    case extract = "解压"
}

struct ContentView: View {
    @State private var mode: Mode = .compress
    @State private var format: ArchiveFormat = .jianyu
    @State private var pickedFiles: [SourceFile] = []
    @State private var pickedFolderName: String?
    @State private var archive: URL?
    @State private var running = false
    @State private var progress: Double = 0
    @State private var progressText = ""
    @State private var logs: [String] = []
    @State private var showFileImporter = false
    @State private var showFolderImporter = false
    @State private var showArchiveImporter = false
    @State private var alertText: String?
    @State private var cancelFlag = false

    var body: some View {
        ZStack {
            Palette.bg.ignoresSafeArea()
            VStack(spacing: 0) {
                header
                ScrollView {
                    VStack(spacing: 18) {
                        if mode == .compress { compressPage } else { extractPage }
                        resultCard
                        logCard
                    }
                    .padding(.horizontal, 18)
                    .padding(.bottom, 12)
                }
                bottomTabs
            }
        }
        .fileImporter(isPresented: $showFileImporter,
                      allowedContentTypes: [.item],
                      allowsMultipleSelection: true) { result in
            if case .success(let urls) = result {
                pickedFiles = urls.map { url in
                    url.startAccessingSecurityScopedResource()
                    return SourceFile(url: url, name: url.lastPathComponent)
                }
            }
        }
        .fileImporter(isPresented: $showFolderImporter,
                      allowedContentTypes: [.folder],
                      allowsMultipleSelection: false) { result in
            if case .success(let urls) = result, let folder = urls.first {
                pickedFolderName = folder.lastPathComponent
                var list: [SourceFile] = []
                collect(folder, prefix: "", into: &list)
                pickedFiles = list
            }
        }
        .fileImporter(isPresented: $showArchiveImporter,
                      allowedContentTypes: [.item],
                      allowsMultipleSelection: false) { result in
            if case .success(let urls) = result {
                archive = urls.first
                logs.append("已选择：\(urls.first?.lastPathComponent ?? "")")
            }
        }
        .alert(item: Binding(get: { alertText.map(AlertText.init) }, set: { _ in alertText = nil })) { item in
            Alert(title: Text("提示"), message: Text(item.text), dismissButton: .default(Text("好")))
        }
    }

    // MARK: - 头部

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top) {
                Text("笺语压缩")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundColor(Palette.textMain)
                Spacer()
                Pill(text: "v1.0")
            }
            Text("自有 .jianyu 格式 · zip / tar / tar.gz / gz，一本通吃")
                .font(.system(size: 15))
                .foregroundColor(Palette.textSub)
        }
        .padding(.horizontal, 18)
        .padding(.top, 12)
        .padding(.bottom, 16)
    }

    // MARK: - 压缩页

    private var compressPage: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(mode == .compress ? "压缩设置" : "解压设置")
                .font(.system(size: 19, weight: .bold))
                .foregroundColor(Palette.textMain)
                .padding(.horizontal, 2)

            VStack(alignment: .leading, spacing: 12) {
                FieldLabel(text: "待压缩内容")
                FakeField(text: summaryText, placeholder: pickedFiles.isEmpty)
                Pill(text: formatSummary)

                HStack(spacing: 12) {
                    Button("添加文件") { showFileImporter = true }.softButton()
                    Button("添加文件夹") { showFolderImporter = true }.softButton()
                }

                HStack(spacing: 12) {
                    Menu {
                        ForEach(ArchiveFormat.allCases) { f in
                            Button(f.label) { format = f }
                        }
                    } label: {
                        HStack {
                            Text(format.ext)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(Palette.textMain)
                            Spacer()
                            Image(systemName: "chevron.down")
                                .foregroundColor(Palette.textSub)
                        }
                        .padding(.horizontal, 14)
                        .frame(height: 48)
                        .background(Palette.fieldBg)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                }

                Button(action: startCompress) {
                    Text(running ? "正在压缩…" : "开始压缩").primaryButton()
                }
                .disabled(running || pickedFiles.isEmpty)
                .opacity(running || pickedFiles.isEmpty ? 0.5 : 1)
            }
            .card()
        }
    }

    private var summaryText: String {
        if pickedFiles.isEmpty { return "选择文件或整个文件夹，支持多个一起打包" }
        let total = pickedFiles.reduce(Int64(0)) { $0 + $1.size }
        if let folder = pickedFolderName { return "\(folder)（\(pickedFiles.count) 个文件，\(bytes(total))）" }
        if pickedFiles.count == 1 { return pickedFiles[0].name }
        return "已选 \(pickedFiles.count) 个文件，共 \(bytes(total))"
    }

    private var formatSummary: String {
        if format == .gz { return "提示：.gz 只能压一个文件" }
        if format == .jianyu { return "提示：.jianyu 只有本工具能解，三端互通" }
        return "提示：\(format.ext) 通用工具也能解"
    }

    // MARK: - 解压页

    private var extractPage: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("解压设置")
                .font(.system(size: 19, weight: .bold))
                .foregroundColor(Palette.textMain)
                .padding(.horizontal, 2)

            VStack(alignment: .leading, spacing: 12) {
                FieldLabel(text: "压缩包")
                FakeField(text: archive?.lastPathComponent ?? "选择 .jianyu / .zip / .tar / .tar.gz / .gz",
                          placeholder: archive == nil)
                Pill(text: archive.map { ArchiveFormat.detect($0.lastPathComponent)?.ext ?? "未知格式" }
                        ?? "自动识别格式")

                Button("选择压缩包") { showArchiveImporter = true }.softButton()

                Button(action: startExtract) {
                    Text(running ? "正在解压…" : "开始解压").primaryButton()
                }
                .disabled(running || archive == nil)
                .opacity(running || archive == nil ? 0.5 : 1)
            }
            .card()
        }
    }

    // MARK: - 进度 / 日志

    private var resultCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("处理进度").font(.system(size: 17, weight: .bold))
                    .foregroundColor(Palette.textMain)
                Spacer()
                Text("\(Int(progress * 100))%")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Palette.primary)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Palette.fieldBg)
                    Capsule().fill(Palette.primary)
                        .frame(width: max(0, geo.size.width * progress))
                }
            }
            .frame(height: 8)
            Text(progressText.isEmpty ? "还没有开始" : progressText)
                .font(.system(size: 14))
                .foregroundColor(Palette.textSub)
                .lineLimit(1)
        }
        .card()
    }

    private var logCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("日志").font(.system(size: 15, weight: .bold))
                .foregroundColor(Palette.textMain)
            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(logs.suffix(30).enumerated()), id: \.offset) { _, line in
                        Text(line)
                            .font(.system(size: 13, design: .monospaced))
                            .foregroundColor(Palette.textSub)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .frame(height: 120)
        }
        .padding(18)
        .background(Palette.card)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    // MARK: - 底部标签

    private var bottomTabs: some View {
        HStack(spacing: 0) {
            tabButton(.compress)
            tabButton(.extract)
        }
        .padding(.top, 8)
        .background(Palette.card.shadow(color: Color.black.opacity(0.06), radius: 12, x: 0, y: -2))
    }

    private func tabButton(_ m: Mode) -> some View {
        Button {
            mode = m
        } label: {
            VStack(spacing: 8) {
                Image(systemName: m == .compress ? "archivebox" : "tray.and.arrow.down")
                    .font(.system(size: 18, weight: .semibold))
                Text(m.rawValue)
                    .font(.system(size: 15, weight: mode == m ? .semibold : .regular))
                Rectangle()
                    .fill(mode == m ? Palette.primary : Color.clear)
                    .frame(width: 26, height: 3)
            }
            .foregroundColor(mode == m ? Palette.primary : Palette.textSub)
            .frame(maxWidth: .infinity)
            .padding(.top, 6)
            .padding(.bottom, 6)
        }
    }

    // MARK: - 业务

    private func documentsURL() -> URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs
    }

    private func collect(_ dir: URL, prefix: String, into list: inout [SourceFile]) {
        let scoped = dir.startAccessingSecurityScopedResource()
        defer { if scoped { dir.stopAccessingSecurityScopedResource() } }
        guard let items = try? FileManager.default.contentsOfDirectory(
            at: dir, includingPropertiesForKeys: [.isDirectoryKey]) else { return }
        for item in items.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
            let isDir = (try? item.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
            if isDir {
                collect(item, prefix: prefix + item.lastPathComponent + "/", into: &list)
            } else {
                list.append(SourceFile(url: item, name: prefix + item.lastPathComponent))
            }
        }
    }

    private func startCompress() {
        guard !running, !pickedFiles.isEmpty else { return }
        running = true
        cancelFlag = false
        progress = 0
        progressText = "准备中…"
        let baseName = pickedFolderName ?? (pickedFiles.count == 1
            ? (pickedFiles[0].name as NSString).deletingPathExtension
            : "笺语压缩")
        let target = Engine.uniqueURL(in: documentsURL(), name: baseName + format.ext)
        let fmt = format
        let items = pickedFiles
        logs.append("开始压缩 \(items.count) 个文件 → \(target.lastPathComponent)")

        DispatchQueue.global(qos: .userInitiated).async {
            let options = EngineOptions(progress: { done, total, name in
                DispatchQueue.main.async {
                    if total > 0 { progress = min(1, Double(done) / Double(total)) }
                    progressText = "\(bytes(done)) / \(bytes(total)) · \(name)"
                }
            }, cancelled: { cancelFlag })

            do {
                try Engine.compress(format: fmt, items: items, to: target, options: options)
                DispatchQueue.main.async {
                    progress = 1
                    progressText = "完成：已保存到「文件 App → 笺语压缩」"
                    logs.append("✅ 完成：\(target.lastPathComponent)（\(bytesOf(target))）")
                    running = false
                }
            } catch {
                DispatchQueue.main.async {
                    logs.append("❌ 失败：\(error.localizedDescription)")
                    alertText = error.localizedDescription
                    running = false
                    progress = 0
                }
            }
        }
    }

    private func startExtract() {
        guard !running, let archive = archive else { return }
        running = true
        cancelFlag = false
        progress = 0
        progressText = "准备中…"
        let name = (archive.lastPathComponent as NSString).deletingPathExtension
        let outDir = Engine.uniqueURL(in: documentsURL(), name: name, isDirectory: true)
        logs.append("开始解压 \(archive.lastPathComponent) → \(outDir.lastPathComponent)/")

        DispatchQueue.global(qos: .userInitiated).async {
            let options = EngineOptions(progress: { done, total, name in
                DispatchQueue.main.async {
                    if total > 0 { progress = min(1, Double(done) / Double(total)) }
                    progressText = "\(bytes(done)) / \(bytes(total)) · \(name)"
                }
            }, cancelled: { cancelFlag })

            do {
                try Engine.extract(archive: archive, to: outDir, options: options)
                DispatchQueue.main.async {
                    progress = 1
                    progressText = "完成：已解压到「文件 App → 笺语压缩」"
                    logs.append("✅ 解压完成：\(outDir.lastPathComponent)/")
                    running = false
                }
            } catch {
                DispatchQueue.main.async {
                    logs.append("❌ 失败：\(error.localizedDescription)")
                    alertText = error.localizedDescription
                    running = false
                    progress = 0
                }
            }
        }
    }

    private func bytes(_ value: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: value, countStyle: .file)
    }

    private func bytesOf(_ url: URL) -> String {
        let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        return bytes(Int64(size))
    }
}

struct AlertText: Identifiable {
    let text: String
    var id: String { text }
}

// ======================== \(path) ========================
import Foundation

public struct SourceFile {
    public let url: URL
    /// 包内相对路径，统一用 "/" 分隔
    public let name: String
    public let size: Int64

    public init(url: URL, name: String) {
        self.url = url
        self.name = name
        let values = try? url.resourceValues(forKeys: [.fileSizeKey])
        self.size = Int64(values?.fileSize ?? 0)
    }
}

public enum ArchiveFormat: String, CaseIterable, Identifiable {
    case jianyu, zip, tar, tgz, gz

    public var id: String { rawValue }

    public var ext: String {
        switch self {
        case .jianyu: return ".jianyu"
        case .zip: return ".zip"
        case .tar: return ".tar"
        case .tgz: return ".tar.gz"
        case .gz: return ".gz"
        }
    }

    public var label: String {
        switch self {
        case .jianyu: return ".jianyu（本工具专用）"
        case .zip: return ".zip（通用）"
        case .tar: return ".tar（只打包）"
        case .tgz: return ".tar.gz（Linux 常用）"
        case .gz: return ".gz（仅单文件）"
        }
    }

    public static func detect(_ fileName: String) -> ArchiveFormat? {
        let n = fileName.lowercased()
        if n.hasSuffix(".jianyu") { return .jianyu }
        if n.hasSuffix(".tar.gz") || n.hasSuffix(".tgz") { return .tgz }
        if n.hasSuffix(".tar") { return .tar }
        if n.hasSuffix(".gz") { return .gz }
        if n.hasSuffix(".zip") || n.hasSuffix(".jar") || n.hasSuffix(".apk")
            || n.hasSuffix(".docx") || n.hasSuffix(".xlsx") || n.hasSuffix(".pptx")
            || n.hasSuffix(".epub") || n.hasSuffix(".cbz") { return .zip }
        return nil
    }
}

public struct EngineOptions {
    public var progress: (Int64, Int64, String) -> Void
    public var cancelled: () -> Bool

    public init(progress: @escaping (Int64, Int64, String) -> Void,
                cancelled: @escaping () -> Bool = { false }) {
        self.progress = progress
        self.cancelled = cancelled
    }
}

public enum Engine {
    // MARK: - 压缩

    public static func compress(format: ArchiveFormat, items: [SourceFile], to url: URL,
                                options: EngineOptions) throws {
        guard !items.isEmpty else { throw EngineError.noFiles }
        if format == .gz && items.count != 1 { throw EngineError.gzNeedsSingleFile }

        let data: Data
        switch format {
        case .jianyu:
            data = try JianyuFormat.pack(items: items, options: options)
        case .tar:
            data = try TarFormat.write(items: items, options: options)
        case .tgz:
            data = try GzipFormat.wrap(try TarFormat.write(items: items, options: options), name: url.lastPathComponent)
        case .gz:
            data = try GzipFormat.wrap(readData(of: items[0].url, budget: nil), name: items[0].name)
        case .zip:
            data = try ZipFormat.pack(items: items, options: options)
        }
        try data.write(to: url, options: .atomic)
        options.progress(-1, -1, "")
    }

    // MARK: - 解压

    public static func extract(archive: URL, to dir: URL, options: EngineOptions) throws {
        guard let format = ArchiveFormat.detect(archive.lastPathComponent) else {
            throw EngineError.unknownFormat
        }
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let data = try Data(contentsOf: archive)

        switch format {
        case .jianyu:
            try JianyuFormat.extract(data: data, to: dir, options: options)
        case .tar:
            try TarFormat.read(data: data, to: dir, options: options)
        case .tgz:
            let inner = try GzipFormat.unwrap(data)
            try TarFormat.read(data: inner, to: dir, options: options)
        case .gz:
            try GzipFormat.extractSingle(data: data, archiveName: archive.lastPathComponent,
                                         to: dir, options: options)
        case .zip:
            try ZipFormat.extract(data: data, to: dir, options: options)
        }
        options.progress(-1, -1, "")
    }

    // MARK: - 公共工具

    static func readData(of url: URL, budget: Int64?) throws -> Data {
        #if os(iOS)
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        #endif
        return try Data(contentsOf: url)
    }

    public static func sanitize(_ entry: String) -> String {
        var s = entry.replacingOccurrences(of: "\\", with: "/")
        while s.hasPrefix("/") { s.removeFirst() }
        if s.count >= 2, s[s.index(s.startIndex, offsetBy: 1)] == ":" { s.removeFirst(2) }
        while s.hasPrefix("/") { s.removeFirst() }
        var keep: [String] = []
        for part in s.split(separator: "/", omittingEmptySubsequences: true) {
            if part == "." { continue }
            if part == ".." { if !keep.isEmpty { keep.removeLast() }; continue }
            keep.append(String(part))
        }
        let joined = keep.joined(separator: "/")
        return joined.isEmpty ? "unnamed" : joined
    }

    public static func uniqueURL(in dir: URL, name: String, isDirectory: Bool = false) -> URL {
        let target = dir.appendingPathComponent(name)
        if !FileManager.default.fileExists(atPath: target.path) { return target }
        let ext = isDirectory ? "" : (name as NSString).pathExtension
        let stem = isDirectory ? name : (name as NSString).deletingPathExtension
        for i in 1...9999 {
            let candidate = ext.isEmpty ? "\(stem)(\(i))" : "\(stem)(\(i)).\(ext)"
            let url = dir.appendingPathComponent(candidate)
            if !FileManager.default.fileExists(atPath: url.path) { return url }
        }
        return dir.appendingPathComponent("\(stem)-\(UUID().uuidString.prefix(8))")
    }

    static func write(_ data: Data, to url: URL) throws {
        let parent = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
        try data.write(to: url, options: .atomic)
    }

    /// 把 "<dir>/<entry>" 落盘（自动建父目录、自动避免覆盖）
    static func writeEntry(_ data: Data, entry: String, in dir: URL) throws -> URL {
        let safe = sanitize(entry)
        if safe == "unnamed" { throw EngineError.badEntry }
        let parts = safe.split(separator: "/").map(String.init)
        guard let lastName = parts.last else { throw EngineError.badEntry }
        var parent = dir
        for p in parts.dropLast() { parent.appendPathComponent(p) }
        try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
        let target = uniqueURL(in: parent, name: lastName)
        try write(data, to: target)
        return target
    }

    static func makeDirectory(entry: String, in dir: URL) throws {
        let safe = sanitize(entry)
        if safe == "unnamed" { return }
        try FileManager.default.createDirectory(at: dir.appendingPathComponent(safe),
                                                withIntermediateDirectories: true)
    }
}

public enum EngineError: LocalizedError {
    case noFiles
    case gzNeedsSingleFile
    case unknownFormat
    case notJianyu
    case unsupportedVersion(Int)
    case encrypted
    case badHeader
    case badEntry
    case crcMismatch(String)

    public var errorDescription: String? {
        switch self {
        case .noFiles: return "没有待压缩的文件"
        case .gzNeedsSingleFile: return ".gz 只能压缩单个文件"
        case .unknownFormat: return "识别不了这个格式"
        case .notJianyu: return "不是 .jianyu 文件：魔数不符"
        case .unsupportedVersion(let v): return "不支持的 .jianyu 版本：\(v)"
        case .encrypted: return "这个包用了 AES 加密，本工具暂不支持"
        case .badHeader: return "文件头已损坏"
        case .badEntry: return "归档里有非法路径"
        case .crcMismatch(let n): return "CRC 校验失败：\(n)"
        }
    }
}

// MARK: - 小端读写工具

extension Data {
    mutating func appendU16(_ v: UInt16) {
        append(contentsOf: [UInt8(v & 0xFF), UInt8((v >> 8) & 0xFF)])
    }

    mutating func appendU32(_ v: UInt32) {
        append(contentsOf: (0..<4).map { UInt8((v >> (8 * UInt32($0))) & 0xFF) })
    }

    mutating func appendU64(_ v: UInt64) {
        append(contentsOf: (0..<8).map { UInt8((v >> (8 * UInt64($0))) & 0xFF) })
    }

    func u16(at offset: Int) -> UInt16 {
        guard offset + 2 <= count else { return 0 }
        let b0 = UInt16(self[index(startIndex, offsetBy: offset)])
        let b1 = UInt16(self[index(startIndex, offsetBy: offset + 1)])
        return b0 | (b1 << 8)
    }

    func u32(at offset: Int) -> UInt32 {
        guard offset + 4 <= count else { return 0 }
        var v: UInt32 = 0
        for i in 0..<4 {
            v |= UInt32(self[index(startIndex, offsetBy: offset + i)]) << (8 * UInt32(i))
        }
        return v
    }

    func u64(at offset: Int) -> UInt64 {
        guard offset + 8 <= count else { return 0 }
        var v: UInt64 = 0
        for i in 0..<8 {
            v |= UInt64(self[index(startIndex, offsetBy: offset + i)]) << (8 * UInt64(i))
        }
        return v
    }

    func slice(_ offset: Int, _ length: Int) -> Data {
        guard offset >= 0, length >= 0, offset + length <= count else { return Data() }
        let start = index(startIndex, offsetBy: offset)
        let end = index(startIndex, offsetBy: offset + length)
        return self[start..<end]
    }

    mutating func setU64(at offset: Int, _ v: UInt64) {
        guard offset + 8 <= count else { return }
        for i in 0..<8 {
            self[index(startIndex, offsetBy: offset + i)] = UInt8((v >> (8 * UInt64(i))) & 0xFF)
        }
    }
}

// ======================== \(path) ========================
import Foundation

#if canImport(JianyuCZlib)
import JianyuCZlib
#endif
// iOS 上同样的 jy_crc32 / zlib 符号由 BridgingHeader.h 暴露

enum ZlibError: LocalizedError {
    case initFailed(Int32)
    case inflateFailed(Int32)
    case truncated

    var errorDescription: String? {
        switch self {
        case .initFailed(let c): return "zlib 初始化失败（code \(c)）"
        case .inflateFailed(let c): return "zlib 解压失败（code \(c)）"
        case .truncated: return "数据被截断"
        }
    }
}

/// 只用 raw DEFLATE（windowBits = -15），与 JDK 的 Deflater(nowrap=true)、
/// .NET 的 DeflateStream 完全一致，这样 .jianyu 才能在三个平台互通。
enum RawZlib {
    static func deflate(_ input: Data, level: Int32 = Z_DEFAULT_COMPRESSION) throws -> Data {
        var stream = z_stream()
        let initResult = deflateInit2_(&stream, level, Z_DEFLATED, -15, 8, Z_DEFAULT_STRATEGY,
                                       ZLIB_VERSION, Int32(MemoryLayout<z_stream>.size))
        guard initResult == Z_OK else { throw ZlibError.initFailed(initResult) }
        defer { deflateEnd(&stream) }

        var output = Data()
        let chunk = 32768
        var outBuffer = [UInt8](repeating: 0, count: chunk)

        try input.withUnsafeBytes { (raw: UnsafeRawBufferPointer) in
            guard let base = raw.baseAddress else { return }
            stream.next_in = UnsafeMutablePointer<UInt8>(mutating: base.assumingMemoryBound(to: UInt8.self))
            stream.avail_in = UInt32(input.count)

            repeat {
                let produced: Int = outBuffer.withUnsafeMutableBytes { buf -> Int in
                    stream.next_out = buf.baseAddress!.assumingMemoryBound(to: UInt8.self)
                    stream.avail_out = UInt32(chunk)
                    let rc = jy_deflate(&stream, Z_FINISH)
                    if rc != Z_OK && rc != Z_STREAM_END && rc != Z_BUF_ERROR {
                        return -1
                    }
                    return chunk - Int(stream.avail_out)
                }
                if produced < 0 { throw ZlibError.initFailed(-1) }
                if produced > 0 { output.append(outBuffer, count: produced) }
                if stream.avail_out != 0 { break }
            } while true
        }
        if output.isEmpty {
            // 空输入：补一个合法的空块，否则 Java/安卓侧 InflaterInputStream 会报 EOF
            output.append(contentsOf: [0x03, 0x00])
        }
        return output
    }

    static func inflate(_ input: Data, expectedSize: Int? = nil) throws -> Data {
        var stream = z_stream()
        let initResult = inflateInit2_(&stream, -15, ZLIB_VERSION, Int32(MemoryLayout<z_stream>.size))
        guard initResult == Z_OK else { throw ZlibError.initFailed(initResult) }
        defer { inflateEnd(&stream) }

        var output = Data()
        if let expected = expectedSize { output.reserveCapacity(expected) }
        let chunk = 32768
        var outBuffer = [UInt8](repeating: 0, count: chunk)

        try input.withUnsafeBytes { (raw: UnsafeRawBufferPointer) in
            guard let base = raw.baseAddress else { throw ZlibError.truncated }
            stream.next_in = UnsafeMutablePointer<UInt8>(mutating: base.assumingMemoryBound(to: UInt8.self))
            stream.avail_in = UInt32(input.count)

            while true {
                let produced: Int = outBuffer.withUnsafeMutableBytes { buf -> Int in
                    stream.next_out = buf.baseAddress!.assumingMemoryBound(to: UInt8.self)
                    stream.avail_out = UInt32(chunk)
                    let rc = jy_inflate(&stream, Z_NO_FLUSH)
                    if rc == Z_STREAM_END || rc == Z_OK || rc == Z_BUF_ERROR {
                        return chunk - Int(stream.avail_out)
                    }
                    return -1
                }
                if produced < 0 { throw ZlibError.inflateFailed(stream.msg == nil ? -1 : -2) }
                if produced > 0 { output.append(outBuffer, count: produced) }
                if stream.avail_out != 0 && (stream.avail_in == 0 || produced == 0) { break }
            }
        }
        if let expected = expectedSize, output.count < expected {
            throw ZlibError.truncated
        }
        return output
    }

    static func crc32(_ input: Data) -> UInt32 {
        var out: UInt32 = 0
        input.withUnsafeBytes { raw in
            if let base = raw.baseAddress {
                out = jy_crc32(0, base.assumingMemoryBound(to: UInt8.self), UInt32(input.count))
            }
        }
        return out
    }
}

// ======================== \(path) ========================
import Foundation

/// `.jianyu` v1.1 读写：与安卓版 / Windows 版完全同一套二进制格式
///
/// 头部 32 字节（小端序）
///  0..5   magic "jianyu"
///  6      version = 1
///  7      flags   bit0 压缩 / bit1 AES / bit2 CRC
///  8..11  fileCount u32
///  12..19 tocOffset u64（回填）
///  20..27 tocSize   u64（回填）
///  28     compressMethod 0=STORE 1=DEFLATE(raw)
///  29..31 reserved
/// 目录表：nameLen u16 + name(utf8) + rawSize u64 + packSize u64 + dataOffset u64 + crc32 u32
enum JianyuFormat {
    static let magic: [UInt8] = [0x6A, 0x69, 0x61, 0x6E, 0x79, 0x75]
    static let version: UInt8 = 1
    static let headerSize = 32
    static let methodDeflate: UInt8 = 1

    static func pack(items: [SourceFile], options: EngineOptions) throws -> Data {
        let total = items.reduce(Int64(0)) { $0 + $1.size }
        var done: Int64 = 0

        var out = Data()
        out.append(contentsOf: magic)
        out.append(version)
        out.append(0x05)                     // 压缩 + CRC
        out.appendU32(UInt32(items.count))
        out.appendU64(0)                     // tocOffset 占位
        out.appendU64(0)                     // tocSize 占位
        out.append(methodDeflate)
        out.append(contentsOf: [0, 0, 0])    // reserved

        var offsets: [UInt64] = []
        var rawSizes: [UInt64] = []
        var packSizes: [UInt64] = []
        var crcs: [UInt32] = []

        for item in items {
            if options.cancelled() { throw CancelledError() }
            offsets.append(UInt64(out.count))
            let data = try Engine.readData(of: item.url, budget: nil)
            let packed = try RawZlib.deflate(data)
            out.append(packed)
            rawSizes.append(UInt64(data.count))
            packSizes.append(UInt64(packed.count))
            crcs.append(RawZlib.crc32(data))
            done += Int64(data.count)
            options.progress(done, total, item.name)
        }

        let tocOffset = UInt64(out.count)
        for (i, item) in items.enumerated() {
            let nameBytes = Array(item.name.utf8)
            out.appendU16(UInt16(nameBytes.count))
            out.append(contentsOf: nameBytes)
            out.appendU64(rawSizes[i])
            out.appendU64(packSizes[i])
            out.appendU64(offsets[i])
            out.appendU32(crcs[i])
        }
        let tocSize = UInt64(out.count) - tocOffset
        out.setU64(at: 12, tocOffset)
        out.setU64(at: 20, tocSize)
        return out
    }

    static func extract(data: Data, to dir: URL, options: EngineOptions) throws {
        guard data.count >= headerSize else { throw EngineError.badHeader }
        guard Array(data.prefix(6)) == magic else { throw EngineError.notJianyu }
        let ver = Int(data[data.startIndex + 6])
        guard ver == 1 else { throw EngineError.unsupportedVersion(ver) }
        let flags = data[data.startIndex + 7]
        if flags & 0x02 != 0 { throw EngineError.encrypted }
        let count = Int(data.u32(at: 8))
        let tocOffset = Int(data.u64(at: 12))
        let tocSize = Int(data.u64(at: 20))
        let method = data[data.startIndex + 28]

        guard tocOffset > 0, tocOffset <= data.count, tocOffset + tocSize <= data.count else {
            throw EngineError.badHeader
        }

        struct Entry {
            let name: String
            let rawSize: Int
            let packSize: Int
            let offset: Int
            let crc: UInt32
        }

        var entries: [Entry] = []
        var p = tocOffset
        for _ in 0..<count {
            guard p + 2 <= data.count else { throw EngineError.badHeader }
            let nameLen = Int(data.u16(at: p)); p += 2
            guard p + nameLen <= data.count else { throw EngineError.badHeader }
            let name = String(data: data.slice(p, nameLen), encoding: .utf8) ?? "unnamed"
            p += nameLen
            guard p + 28 <= data.count else { throw EngineError.badHeader }
            let rawSize = Int(data.u64(at: p)); p += 8
            let packSize = Int(data.u64(at: p)); p += 8
            let offset = Int(data.u64(at: p)); p += 8
            let crc = data.u32(at: p); p += 4
            entries.append(Entry(name: name, rawSize: rawSize, packSize: packSize,
                                 offset: offset, crc: crc))
        }

        let total = Int64(entries.reduce(0) { $0 + $1.rawSize })
        var done: Int64 = 0

        for entry in entries {
            if options.cancelled() { throw CancelledError() }
            if entry.name.hasSuffix("/") {
                try Engine.makeDirectory(entry: entry.name, in: dir)
                continue
            }
            guard entry.offset >= 0, entry.offset + entry.packSize <= data.count else {
                throw EngineError.badHeader
            }
            let packed = data.slice(entry.offset, entry.packSize)
            let raw: Data
            if method == methodDeflate {
                raw = try RawZlib.inflate(packed, expectedSize: entry.rawSize)
            } else {
                raw = packed
            }
            if flags & 0x04 != 0, RawZlib.crc32(raw) != entry.crc {
                throw EngineError.crcMismatch(entry.name)
            }
            _ = try Engine.writeEntry(raw, entry: entry.name, in: dir)
            done += Int64(raw.count)
            options.progress(done, total, entry.name)
        }
    }
}

struct CancelledError: LocalizedError {
    var errorDescription: String? { "已取消" }
}

// ======================== \(path) ========================
import Foundation

/// TAR：ustar + GNU LongLink（与 Windows / 安卓版一致，GNU tar 可直接读）
enum TarFormat {
    static let block = 512

    static func write(items: [SourceFile], options: EngineOptions) throws -> Data {
        let total = items.reduce(Int64(0)) { $0 + $1.size }
        var done: Int64 = 0
        var out = Data()

        for item in items {
            if options.cancelled() { throw CancelledError() }
            let nameBytes = Array(item.name.utf8)

            // 名字超过 100 字节 → GNU LongLink 记录
            if nameBytes.count >= 100 {
                out.append(header(name: "././@LongLink", size: nameBytes.count, type: "L"))
                out.append(contentsOf: nameBytes)
                out.appendPadding(toMultipleOf: block)
            }

            let data = try Engine.readData(of: item.url, budget: nil)
            let shortName = nameBytes.count >= 100
                ? String(data: Data(nameBytes.prefix(96)), encoding: .utf8) ?? "longname"
                : item.name
            out.append(header(name: shortName, size: data.count, type: "0"))
            out.append(data)
            out.appendPadding(toMultipleOf: block)

            done += Int64(data.count)
            options.progress(done, total, item.name)
        }

        out.append(contentsOf: [UInt8](repeating: 0, count: block * 2))
        return out
    }

    static func read(data: Data, to dir: URL, options: EngineOptions) throws {
        var p = 0
        var pendingLongName: String?

        while p + block <= data.count {
            if options.cancelled() { throw CancelledError() }
            let header = data.slice(p, block)
            p += block
            if header.allSatisfy({ $0 == 0 }) { break }

            let name = readName(header)
            let size = Int(readOctal(header, 124, 12))
            let type = header.count > 156 ? header[header.startIndex + 156] : 0x30

            if type == 0x4C { // 'L' GNU LongLink
                let body = data.slice(p, min(size, data.count - p))
                p += size
                p += padding(for: size)
                pendingLongName = String(data: body, encoding: .utf8)?
                    .trimmingCharacters(in: CharacterSet(charactersIn: "\0")) ?? name
                continue
            }

            if type == 0x78 || type == 0x67 { // 'x' / 'g' PAX
                let body = data.slice(p, min(size, data.count - p))
                p += size
                p += padding(for: size)
                if let text = String(data: body, encoding: .utf8),
                   let range = text.range(of: "path=") {
                    var value = String(text[range.upperBound...])
                    if let nl = value.firstIndex(of: "\n") { value = String(value[..<nl]) }
                    pendingLongName = value
                }
                continue
            }

            let entryName = pendingLongName ?? name
            pendingLongName = nil

            if type == 0x35 { // '5' 目录
                try Engine.makeDirectory(entry: entryName, in: dir)
                continue
            }

            let body = data.slice(p, min(size, data.count - p))
            p += size
            p += padding(for: size)

            _ = try Engine.writeEntry(body, entry: entryName, in: dir)
            options.progress(min(Int64(p), Int64(data.count)), Int64(data.count), entryName)
        }
    }

    // MARK: - 头部

    static func header(name: String, size: Int, type: Character) -> Data {
        var h = Data(repeating: 0, count: block)
        writeString(&h, 0, 100, name)
        writeOctal(&h, 100, 8, 420)      // 0644
        writeOctal(&h, 108, 8, 0)
        writeOctal(&h, 116, 8, 0)
        writeOctal(&h, 124, 12, size)
        writeOctal(&h, 136, 12, Int(Date().timeIntervalSince1970))
        h[h.startIndex + 156] = UInt8(type.unicodeScalars.first!.value)
        writeString(&h, 257, 6, "ustar")
        h[h.startIndex + 263] = 0x30
        h[h.startIndex + 264] = 0x30
        writeString(&h, 265, 32, "jianyu")
        writeString(&h, 297, 32, "jianyu")

        // 校验和：字段按 8 个空格参与累加（GNU 约定）
        for i in 148..<156 { h[h.startIndex + i] = 0x20 }
        let sum = h.reduce(0) { $0 + Int($1) }
        let sumText = String(format: "%06o", sum)   // 恰好 6 位八进制
        for (i, ch) in sumText.utf8.enumerated() where i < 6 {
            h[h.startIndex + 148 + i] = ch
        }
        h[h.startIndex + 154] = 0
        h[h.startIndex + 155] = 0x20
        return h
    }

    static func writeString(_ h: inout Data, _ offset: Int, _ length: Int, _ value: String) {
        let bytes = Array(value.utf8)
        let n = min(bytes.count, length - 1)
        for i in 0..<n { h[h.startIndex + offset + i] = bytes[i] }
    }

    static func writeOctal(_ h: inout Data, _ offset: Int, _ length: Int, _ value: Int) {
        let s = String(format: "%0\(length - 1)o", value)
        writeString(&h, offset, length, s)
    }

    static func readOctal(_ h: Data, _ offset: Int, _ length: Int) -> Int {
        var value = 0
        for i in 0..<length {
            let c = h[h.startIndex + offset + i]
            if c == 0 { break }
            if c == 0x20 { continue }
            guard c >= 0x30, c <= 0x37 else { continue }
            value = value * 8 + Int(c - 0x30)
        }
        return value
    }

    static func readString(_ h: Data, _ offset: Int, _ length: Int) -> String {
        var end = length
        for i in 0..<length where h[h.startIndex + offset + i] == 0 { end = i; break }
        if end == 0 { return "" }
        return String(data: h.slice(offset, end), encoding: .utf8)?
            .trimmingCharacters(in: .whitespaces) ?? ""
    }

    static func readName(_ h: Data) -> String {
        var name = readString(h, 0, 100)
        let prefix = readString(h, 345, 155)
        if !prefix.isEmpty { name = prefix + "/" + name }
        return name.replacingOccurrences(of: "\\", with: "/")
    }
}

extension Data {
    mutating func appendPadding(toMultipleOf n: Int) {
        let pad = (n - (count % n)) % n
        if pad > 0 { append(contentsOf: [UInt8](repeating: 0, count: pad)) }
    }
}

func padding(for size: Int) -> Int {
    (TarFormat.block - (size % TarFormat.block)) % TarFormat.block
}

// ======================== \(path) ========================
import Foundation

/// ZIP 读写：只做 deflate(8) 与 store(0)，UTF-8 文件名标记，Windows/手机都能打开
enum ZipFormat {
    static func pack(items: [SourceFile], options: EngineOptions) throws -> Data {
        let total = items.reduce(Int64(0)) { $0 + $1.size }
        var done: Int64 = 0
        var out = Data()
        var central = Data()

        let dosTime: UInt16 = 0
        let dosDate: UInt16 = 0x21  // 1980-01-01，避免依赖本地时间

        for item in items {
            if options.cancelled() { throw CancelledError() }
            let data = try Engine.readData(of: item.url, budget: nil)
            let packed = try RawZlib.deflate(data)
            let crc = RawZlib.crc32(data)
            let nameBytes = Array(item.name.utf8)
            let localOffset = UInt32(out.count)

            out.appendU32(0x04034b50)
            out.appendU16(20)                 // version needed
            out.appendU16(0x0800)             // UTF-8 名字
            out.appendU16(8)                  // deflate
            out.appendU16(dosTime)
            out.appendU16(dosDate)
            out.appendU32(crc)
            out.appendU32(UInt32(packed.count))
            out.appendU32(UInt32(data.count))
            out.appendU16(UInt16(nameBytes.count))
            out.appendU16(0)                  // extra len
            out.append(contentsOf: nameBytes)
            out.append(packed)

            central.appendU32(0x02014b50)
            central.appendU16(20)             // version made by
            central.appendU16(20)             // version needed
            central.appendU16(0x0800)
            central.appendU16(8)
            central.appendU16(dosTime)
            central.appendU16(dosDate)
            central.appendU32(crc)
            central.appendU32(UInt32(packed.count))
            central.appendU32(UInt32(data.count))
            central.appendU16(UInt16(nameBytes.count))
            central.appendU16(0)              // extra
            central.appendU16(0)              // comment
            central.appendU16(0)              // disk
            central.appendU16(0)              // internal attr
            central.appendU32(0)              // external attr
            central.appendU32(localOffset)
            central.append(contentsOf: nameBytes)

            done += Int64(data.count)
            options.progress(done, total, item.name)
        }

        let centralOffset = UInt32(out.count)
        out.append(central)
        out.appendU32(0x06054b50)
        out.appendU16(0)
        out.appendU16(0)
        out.appendU16(UInt16(items.count))
        out.appendU16(UInt16(items.count))
        out.appendU32(UInt32(central.count))
        out.appendU32(centralOffset)
        out.appendU16(0)
        return out
    }

    static func extract(data: Data, to dir: URL, options: EngineOptions) throws {
        let count = data.count
        guard count > 22 else { throw EngineError.badHeader }

        // 从尾部找 EOCD
        var eocd = -1
        let lowerBound = max(0, count - 22 - 65535)
        var i = count - 22
        while i >= lowerBound {
            if data.u32(at: i) == 0x06054b50 { eocd = i; break }
            i -= 1
        }
        guard eocd >= 0 else { throw EngineError.badHeader }

        let entriesCount = Int(data.u16(at: eocd + 10))
        let centralOffset = Int(data.u32(at: eocd + 16))
        guard centralOffset > 0, centralOffset < count else { throw EngineError.badHeader }

        var p = centralOffset
        var total: Int64 = 0
        struct Entry {
            let name: String
            let method: UInt16
            let crc: UInt32
            let compSize: Int
            let rawSize: Int
            let localOffset: Int
        }
        var entries: [Entry] = []

        for _ in 0..<entriesCount {
            guard p + 46 <= count, data.u32(at: p) == 0x02014b50 else { throw EngineError.badHeader }
            let method = data.u16(at: p + 10)
            let crc = data.u32(at: p + 16)
            let compSize = Int(data.u32(at: p + 20))
            let rawSize = Int(data.u32(at: p + 24))
            let nameLen = Int(data.u16(at: p + 28))
            let extraLen = Int(data.u16(at: p + 30))
            let commentLen = Int(data.u16(at: p + 32))
            let localOffset = Int(data.u32(at: p + 42))
            let name = String(data: data.slice(p + 46, nameLen), encoding: .utf8) ?? "unnamed"
            entries.append(Entry(name: name, method: method, crc: crc,
                                 compSize: compSize, rawSize: rawSize, localOffset: localOffset))
            p += 46 + nameLen + extraLen + commentLen
            total += Int64(rawSize)
        }

        var done: Int64 = 0
        for entry in entries {
            if options.cancelled() { throw CancelledError() }
            if entry.name.hasSuffix("/") {
                try Engine.makeDirectory(entry: entry.name, in: dir)
                continue
            }
            guard entry.localOffset + 30 <= count, data.u32(at: entry.localOffset) == 0x04034b50 else {
                throw EngineError.badHeader
            }
            let lNameLen = Int(data.u16(at: entry.localOffset + 26))
            let lExtraLen = Int(data.u16(at: entry.localOffset + 28))
            let dataStart = entry.localOffset + 30 + lNameLen + lExtraLen
            guard dataStart + entry.compSize <= count else { throw EngineError.badHeader }
            let packed = data.slice(dataStart, entry.compSize)

            let raw: Data
            switch entry.method {
            case 0: raw = packed
            case 8: raw = try RawZlib.inflate(packed, expectedSize: entry.rawSize)
            default: throw EngineError.badHeader
            }
            if RawZlib.crc32(raw) != entry.crc { throw EngineError.crcMismatch(entry.name) }

            _ = try Engine.writeEntry(raw, entry: entry.name, in: dir)
            done += Int64(raw.count)
            options.progress(done, total, entry.name)
        }
    }
}

// ======================== \(path) ========================
import Foundation

/// GZip：自己拼头和尾，中间用 raw DEFLATE，跟 JDK / .NET 的 gzip 完全兼容
enum GzipFormat {
    static func wrap(_ payload: Data, name: String) throws -> Data {
        var out = Data()
        out.append(contentsOf: [0x1F, 0x8B, 0x08, 0x00])   // magic + deflate + 无 flag
        out.appendU32(UInt32(Date().timeIntervalSince1970)) // mtime
        out.append(contentsOf: [0x02, 0xFF])               // XFL=2（最高压缩）、OS=255
        out.append(try RawZlib.deflate(payload, level: 9))
        out.appendU32(RawZlib.crc32(payload))
        out.appendU32(UInt32(payload.count))
        return out
    }

    static func unwrap(_ data: Data) throws -> Data {
        guard data.count > 18 else { throw EngineError.badHeader }
        guard data[data.startIndex] == 0x1F, data[data.startIndex + 1] == 0x8B else {
            throw EngineError.badHeader
        }
        let flags = data[data.startIndex + 3]
        var p = 10

        if flags & 0x04 != 0 {           // FEXTRA
            let xlen = Int(data.u16(at: p)); p += 2 + xlen
        }
        if flags & 0x08 != 0 {           // FNAME
            while p < data.count, data[data.startIndex + p] != 0 { p += 1 }
            p += 1
        }
        if flags & 0x10 != 0 {           // FCOMMENT
            while p < data.count, data[data.startIndex + p] != 0 { p += 1 }
            p += 1
        }
        if flags & 0x02 != 0 { p += 2 }  // FHCRC
        guard p < data.count - 8 else { throw EngineError.badHeader }

        let body = data.slice(p, data.count - p - 8)
        let raw = try RawZlib.inflate(body)
        let crc = data.u32(at: data.count - 8)
        if RawZlib.crc32(raw) != crc { throw EngineError.crcMismatch("gzip") }
        return raw
    }

    static func extractSingle(data: Data, archiveName: String, to dir: URL,
                              options: EngineOptions) throws {
        let raw = try unwrap(data)
        var name = archiveName
        if name.lowercased().hasSuffix(".gz") { name = String(name.dropLast(3)) }
        if name.isEmpty { name = "output" }
        let target = Engine.uniqueURL(in: dir, name: name)
        try Engine.write(raw, to: target)
        options.progress(Int64(raw.count), Int64(raw.count), name)
    }
}


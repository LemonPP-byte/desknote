// DeskNote —— 悬浮在桌面上的极简信息分流小工具（原生 SwiftUI 版）
//
// 只做一件事：给"趁热"型信息一个零摩擦出口，让它在眼皮底下变旧变红，逼你趁热动手。
//
// 三条泳道：
//   🔥 趁热  —— 行动窗口型（趁热问人 / 趁热做动作），置顶，显示已放多久，越放越红
//   ✅ 待办  —— 紧急 + 重要不紧急，该做就做
//   💡 想学  —— 知识囤积，没压力，有空再翻
//
// 用法：输入框敲字回车 = 扔进「待办」。每条右侧按钮升 / 降 / 勾掉。
//
// 编译：swiftc -O ~/.desknote/DeskNote.swift -o ~/.desknote/desknote
// 运行：~/.desknote/desknote

import SwiftUI
import AppKit

// MARK: - 数据模型

enum Lane: String, Codable, CaseIterable {
    case hot, todo, learn
    var label: String {
        switch self {
        case .hot:   return "🔥 趁热"
        case .todo:  return "✅ 待办"
        case .learn: return "💡 想学"
        }
    }
}

struct Item: Identifiable, Codable {
    var id: Int
    var text: String
    var lane: Lane
    var created: Double   // Unix 秒
}

// MARK: - 存储

final class Store: ObservableObject {
    @Published var items: [Item] = []
    private var nextID = 1

    private static var dir: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".desknote")
    }
    private static var file: URL { dir.appendingPathComponent("notes.json") }

    struct Persisted: Codable { var items: [Item]; var geometry: String? }
    private(set) var geometry: String?

    init() { load() }

    func load() {
        guard let data = try? Data(contentsOf: Self.file) else { return }
        // 兼容 Python 版写出的结构（items + geometry）
        if let p = try? JSONDecoder().decode(Persisted.self, from: data) {
            items = p.items
            geometry = p.geometry
        }
        nextID = (items.map { $0.id }.max() ?? 0) + 1
    }

    func save() {
        try? FileManager.default.createDirectory(at: Self.dir, withIntermediateDirectories: true)
        let p = Persisted(items: items, geometry: geometry)
        if let data = try? JSONEncoder().encode(p) {
            try? data.write(to: Self.file, options: .atomic)
        }
    }

    func add(_ text: String) {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        items.append(Item(id: nextID, text: t, lane: .todo, created: Date().timeIntervalSince1970))
        nextID += 1
        save()
    }

    func move(_ id: Int, to lane: Lane) {
        guard let i = items.firstIndex(where: { $0.id == id }) else { return }
        items[i].lane = lane
        if lane == .hot { items[i].created = Date().timeIntervalSince1970 } // 升到趁热=从现在开始烧
        save()
    }

    func done(_ id: Int) {
        items.removeAll { $0.id == id }
        save()
    }

    func saveGeometry(_ g: String) { geometry = g; save() }
}

// MARK: - 年龄与颜色

func fmtAge(_ created: Double) -> String {
    let s = Int(Date().timeIntervalSince1970 - created)
    if s < 300 { return "刚记" }
    if s < 3600 { return "\(s / 60)分钟前" }
    if s < 86400 { return "\(s / 3600)小时前" }
    return "\(s / 86400)天前"
}

// 🔥 栏文字颜色随年龄由橙转深红，约 4 小时到最红
func hotColor(_ created: Double) -> Color {
    let h = (Date().timeIntervalSince1970 - created) / 3600.0
    let t = min(h / 4.0, 1.0)
    let r = (255.0 + (192 - 255) * t) / 255.0
    let g = (140.0 + (19 - 140) * t) / 255.0
    let b = (66.0  + (46 - 66) * t) / 255.0
    return Color(red: r, green: g, blue: b)
}

// MARK: - 视图

struct ContentView: View {
    @ObservedObject var store: Store
    @State private var draft = ""
    // 每 30 秒触发一次刷新，让年龄/颜色更新
    @State private var ticker = Date()
    private let timer = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

    private let ink = Color(red: 0x3A/255, green: 0x3A/255, blue: 0x3A/255)
    private let paper = Color(red: 0xFB/255, green: 0xF3/255, blue: 0xD5/255)
    private let muted = Color(red: 0x9A/255, green: 0x8F/255, blue: 0x73/255)

    var body: some View {
        VStack(spacing: 0) {
            // 输入区
            HStack(spacing: 6) {
                TextField("记一笔…", text: $draft, onCommit: submit)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 13))
                Button("记下", action: submit)
                    .buttonStyle(.borderedProminent)
                    .tint(Color(red: 0xD8/255, green: 0xA6/255, blue: 0x57/255))
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)

            // 列表
            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(Lane.allCases, id: \.self) { lane in
                        laneSection(lane)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.top, 8)
                .padding(.bottom, 8)
            }
        }
        .background(paper)
        .onReceive(timer) { ticker = $0 }
    }

    private func submit() {
        store.add(draft)
        draft = ""
    }

    @ViewBuilder
    private func laneSection(_ lane: Lane) -> some View {
        let items = sortedItems(lane)
        // 无标题：靠颜色与位置区分。组间留一点空隙。
        if !items.isEmpty {
            Spacer().frame(height: lane == .hot ? 0 : 6)
            ForEach(items) { it in
                row(it, lane: lane)
            }
        }
    }

    private func sortedItems(_ lane: Lane) -> [Item] {
        let xs = store.items.filter { $0.lane == lane }
        // 趁热：最旧最上（最扎眼）；其余：最新最上
        return lane == .hot ? xs.sorted { $0.created < $1.created }
                            : xs.sorted { $0.created > $1.created }
    }

    @ViewBuilder
    private func row(_ it: Item, lane: Lane) -> some View {
        let bg: Color = {
            switch lane {
            case .hot:   return Color(red: 0xFF/255, green: 0xF0/255, blue: 0xE6/255)
            case .todo:  return paper
            case .learn: return Color(red: 0xEE/255, green: 0xF3/255, blue: 0xEE/255)
            }
        }()

        HStack(alignment: .top, spacing: 6) {
            VStack(alignment: .leading, spacing: 2) {
                if lane == .hot {
                    Text(fmtAge(it.created))
                        .font(.system(size: 10))
                        .foregroundColor(hotColor(it.created))
                }
                Text(it.text)
                    .font(.system(size: 13))
                    .foregroundColor(ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 4)

            HStack(spacing: 2) {
                switch lane {
                case .hot:
                    iconBtn("↓") { store.move(it.id, to: .todo) }
                case .todo:
                    iconBtn("🔥") { store.move(it.id, to: .hot) }
                    iconBtn("💡") { store.move(it.id, to: .learn) }
                case .learn:
                    iconBtn("↑") { store.move(it.id, to: .todo) }
                }
                iconBtn("✓") { store.done(it.id) }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(bg)
        .overlay(RoundedRectangle(cornerRadius: 4)
            .stroke(Color(red: 0xEA/255, green: 0xE0/255, blue: 0xC0/255), lineWidth: 1))
        .padding(.vertical, 2)
    }

    private func iconBtn(_ label: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label).font(.system(size: 14))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 3)
    }
}

// MARK: - 悬浮窗口

final class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!
    let store = Store()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory) // 不占 Dock，纯悬浮小工具

        let content = ContentView(store: store)
        let hosting = NSHostingView(rootView: content)

        let win = NSWindow(
            contentRect: NSRect(x: 80, y: 80, width: 340, height: 560),
            styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
            backing: .buffered, defer: false)
        win.title = "桌签"
        win.titlebarAppearsTransparent = true
        win.isMovableByWindowBackground = true
        win.level = .floating                       // 永远置顶
        win.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        win.contentView = hosting
        win.isReleasedWhenClosed = false
        win.setFrameAutosaveName("DeskNoteWindow")  // 位置自动记住

        // 恢复上次几何（若有）
        if let g = store.geometry { win.setFrame(from: g) }

        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        self.window = win
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    func applicationWillTerminate(_ notification: Notification) {
        if let w = window { store.saveGeometry(w.frameDescriptor) }
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()

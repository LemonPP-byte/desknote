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
import CoreText

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

// MARK: - 视图

// 像素字体名（Fusion Pixel 简中版）。取不到则回退等宽系统字。
let PIXEL_FONT = "Fusion-Pixel-12px-Prop-zh_hans-Regular"

func px(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
    if NSFont(name: PIXEL_FONT, size: size) != nil {
        return .custom(PIXEL_FONT, fixedSize: size)
    }
    return .system(size: size, weight: weight, design: .monospaced)
}

// MARK: - Minecraft 草地风配色
enum MC {
    static let grass     = Color(red: 0x7A/255, green: 0xB6/255, blue: 0x4F/255) // 草地绿（窗口底）
    static let grassDark = Color(red: 0x5C/255, green: 0x8D/255, blue: 0x3A/255) // 草深绿描边
    static let dirt      = Color(red: 0x8B/255, green: 0x5A/255, blue: 0x2B/255) // 泥土棕
    static let dirtDark  = Color(red: 0x5E/255, green: 0x3A/255, blue: 0x18/255) // 泥土深棕描边
    static let redstone  = Color(red: 0xC0/255, green: 0x2E/255, blue: 0x26/255) // 红石红（趁热）
    static let wood      = Color(red: 0xB5/255, green: 0x83/255, blue: 0x4E/255) // 木箱棕（想学）
    static let panel     = Color(red: 0xF3/255, green: 0xEC/255, blue: 0xD8/255) // 面板浅底（羊皮纸）
    static let ink       = Color(red: 0x2B/255, green: 0x22/255, blue: 0x16/255) // 深棕黑字
    static let dim       = Color(red: 0x2B/255, green: 0x22/255, blue: 0x16/255).opacity(0.55)
    static let softBtn   = Color(red: 0x3A/255, green: 0x2A/255, blue: 0x14/255).opacity(0.4)
}

struct ContentView: View {
    @ObservedObject var store: Store
    @State private var draft = ""
    @State private var ticker = Date()
    private let timer = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 0) {
            // 输入区：像素方块输入框 + 方块 ＋ 按钮
            HStack(spacing: 6) {
                TextField("", text: $draft, onCommit: submit)
                    .textFieldStyle(.plain)
                    .font(px(13))
                    .foregroundColor(MC.ink)
                    .padding(.horizontal, 8).padding(.vertical, 6)
                    .background(MC.panel)
                    .overlay(pixelBorder(MC.dirtDark))
                Button(action: submit) {
                    Text("＋")
                        .font(px(18, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 32, height: 32)
                        .background(MC.grass)
                        .overlay(pixelBorder(MC.grassDark))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 10)
            .padding(.top, 10)

            // 列表：每类一个方块面板。弹性填充，把地面带推到最底。
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Lane.allCases, id: \.self) { lane in
                        laneSection(lane)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.top, 10)
                .padding(.bottom, 6)
            }

            Spacer(minLength: 0)  // 列表短时，把地面带压到窗口最底边

            GroundStrip()          // 底部地面装饰带：小精灵站在草线上，填满底部空白
        }
        .background(MC.grass)
        .onReceive(timer) { ticker = $0 }
    }

    private func submit() {
        store.add(draft)
        draft = ""
    }

    @ViewBuilder
    private func laneSection(_ lane: Lane) -> some View {
        let items = sortedItems(lane)
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.element.id) { idx, it in
                    if idx > 0 {
                        Rectangle().fill(MC.ink.opacity(0.12)).frame(height: 1)
                            .padding(.leading, 10)
                    }
                    row(it, lane: lane)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(MC.panel)
            .overlay(
                // 左侧一条粗色带标明类别（红石/草/木）
                HStack {
                    Rectangle().fill(laneAccent(lane)).frame(width: 5)
                    Spacer()
                }
            )
            .overlay(pixelBorder(laneAccent(lane)))
        }
    }

    // 类别强调色（左色带 + 描边）
    private func laneAccent(_ lane: Lane) -> Color {
        switch lane {
        case .hot:   return MC.redstone
        case .todo:  return MC.grassDark
        case .learn: return MC.wood
        }
    }

    private func sortedItems(_ lane: Lane) -> [Item] {
        let xs = store.items.filter { $0.lane == lane }
        return lane == .hot ? xs.sorted { $0.created < $1.created }
                            : xs.sorted { $0.created > $1.created }
    }

    @ViewBuilder
    private func row(_ it: Item, lane: Lane) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Text(it.text)
                .font(px(13))
                .foregroundColor(lane == .hot ? MC.ink : MC.dim)  // 趁热黑字，其余约 55%
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 4)

            HStack(spacing: 4) {
                switch lane {
                case .hot:
                    iconBtn("↓") { store.move(it.id, to: .todo) }
                case .todo:
                    iconBtn("↑") { store.move(it.id, to: .hot) }
                    iconBtn("↓") { store.move(it.id, to: .learn) }
                case .learn:
                    iconBtn("↑") { store.move(it.id, to: .todo) }
                }
                iconBtn("✓") { store.done(it.id) }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .padding(.leading, 4)  // 给左色带让位
    }

    private func iconBtn(_ label: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label).font(px(13))
        }
        .buttonStyle(.plain)
        .foregroundColor(MC.softBtn)
        .padding(.horizontal, 2)
    }
}

// MARK: - 像素描边（MC 方块那种硬边）
func pixelBorder(_ color: Color) -> some View {
    Rectangle().stroke(color, lineWidth: 2)
}

// MARK: - 手绘像素小点缀（用小方块拼）
enum PixelArt {
    // 用 3~4 色的 8x8 网格拼一个小图，单元格 2pt
    static func grid(_ rows: [String], _ map: [Character: Color], cell: CGFloat = 2) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, line in
                HStack(spacing: 0) {
                    ForEach(Array(line.enumerated()), id: \.offset) { _, ch in
                        Rectangle()
                            .fill(map[ch] ?? .clear)
                            .frame(width: cell, height: cell)
                    }
                }
            }
        }
    }

    // 苦力怕脸
    static var creeper: some View {
        let g = Color(red: 0x5C/255, green: 0x8D/255, blue: 0x3A/255)
        let d = Color.black
        return grid([
            "gggggggg",
            "gggggggg",
            "gddggddg",
            "gddggddg",
            "ggggddgg",
            "ggdddddg",
            "ggddgddg",
            "ggddgddg",
        ], ["g": g, "d": d])
    }

    // 爱心
    static var heart: some View {
        let r = Color(red: 0xD1/255, green: 0x2E/255, blue: 0x2E/255)
        let h = Color(red: 0xF2/255, green: 0x7A/255, blue: 0x7A/255)
        return grid([
            ".rr..rr.",
            "rhhrrhhr",
            "rhhhhhhr",
            "rhhhhhhr",
            ".rhhhhr.",
            "..rhhr..",
            "...rr...",
            "........",
        ], ["r": r, "h": h, ".": .clear])
    }

    // 草方块（顶层草绿，下面泥土棕）
    static var grassBlock: some View {
        let g = Color(red: 0x7A/255, green: 0xB6/255, blue: 0x4F/255)
        let d = Color(red: 0x8B/255, green: 0x5A/255, blue: 0x2B/255)
        return grid([
            "gggggggg",
            "gggggggg",
            "gdggggdg",
            "dddddddd",
            "dddddddd",
            "ddddgddd",
            "dddddddd",
            "dddddddd",
        ], ["g": g, "d": d])
    }
}

// MARK: - 底部地面装饰带
// 一条贴着窗口底边的草地+泥土，小精灵站在草线上，把底部空白变成一小幅 MC 风景。
struct GroundStrip: View {
    private let grassTop  = Color(red: 0x7A/255, green: 0xB6/255, blue: 0x4F/255)
    private let grassEdge = Color(red: 0x5C/255, green: 0x8D/255, blue: 0x3A/255)
    private let dirt      = Color(red: 0x8B/255, green: 0x5A/255, blue: 0x2B/255)
    private let dirtDark  = Color(red: 0x6E/255, green: 0x45/255, blue: 0x20/255)

    var body: some View {
        ZStack(alignment: .bottom) {
            // 泥土层 + 草皮线
            VStack(spacing: 0) {
                grassTop.frame(height: 4)                     // 顶部草皮亮线
                grassEdge.frame(height: 2)                    // 草土交界
                ZStack {
                    dirt
                    // 泥土上零星几粒深色像素，做出颗粒感
                    HStack(spacing: 14) {
                        ForEach(0..<8, id: \.self) { i in
                            Rectangle().fill(dirtDark)
                                .frame(width: 3, height: 3)
                                .offset(y: CGFloat(i % 2 == 0 ? 4 : -3))
                        }
                    }
                }
                .frame(height: 20)
            }
            // 小精灵站在草线上
            HStack(spacing: 12) {
                Spacer()
                PixelArt.creeper
                PixelArt.heart
                PixelArt.grassBlock
                Spacer().frame(width: 4)
            }
            .padding(.bottom, 14)   // 抬到草皮之上，像站在地面上
        }
        .frame(height: 26)
    }
}

// MARK: - 悬浮窗口

final class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!
    let store = Store()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory) // 不占 Dock，纯桌面小工具
        registerBundledFont()

        let content = ContentView(store: store)
        let hosting = NSHostingView(rootView: content)

        let win = NSWindow(
            contentRect: NSRect(x: 80, y: 80, width: 340, height: 560),
            styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
            backing: .buffered, defer: false)
        win.title = "工作桌签"
        win.titlebarAppearsTransparent = true
        win.isMovableByWindowBackground = true
        // 像苹果便签：安静待在桌面某处，不永远置顶、不跨所有桌面
        win.level = .normal
        win.contentView = hosting
        win.isReleasedWhenClosed = false
        win.contentMinSize = NSSize(width: 300, height: 360)  // 兜底：再也拖不到看不见
        win.setFrameAutosaveName("DeskNoteWindow")  // 位置自动记住

        // 恢复上次几何（若有），但尺寸过小则忽略、用默认，避免"缩到看不见"
        if let g = store.geometry {
            win.setFrame(from: g)
            if win.frame.width < 300 || win.frame.height < 360 {
                win.setContentSize(NSSize(width: 340, height: 560))
                win.center()
            }
        }

        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        self.window = win
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    func applicationWillTerminate(_ notification: Notification) {
        if let w = window { store.saveGeometry(w.frameDescriptor) }
    }

    // 主动注册用户字体目录里的像素字体，避免字体缓存未刷新时读不到
    private func registerBundledFont() {
        let path = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Fonts/fusion-pixel-12px-proportional-zh_hans.ttf")
        guard FileManager.default.fileExists(atPath: path.path) else { return }
        CTFontManagerRegisterFontsForURL(path as CFURL, .process, nil)
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()

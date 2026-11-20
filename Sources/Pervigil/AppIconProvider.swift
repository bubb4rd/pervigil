import AppKit
import SwiftUI
import UniformTypeIdentifiers
import PervigilCore

/// What a ``TriggerSource`` draws as. App and file icons are the ones macOS
/// itself draws, read at runtime, so Pervigil never bundles another company's
/// logo and the icon always matches what the user recognizes.
enum ResolvedIcon {
    /// A full-color icon from the system (an app, a file type).
    case image(NSImage)
    /// An agent mark from `AgentBrands.xcassets`, drawn as a template.
    case agentMark(String)
    /// Claude without the Claude app installed: the orange tile drawn in code.
    case claudeTile
    /// An SF Symbol.
    case symbol(String)
}

/// Resolves trigger sources to icons and names, the chain the design notes
/// describe: running process, then bundle id, then bundle path, then agent
/// mark, then file type, then the trigger's symbol. Results are cached; none
/// of this touches the network or needs a permission.
@MainActor
final class AppIconProvider {
    static let shared = AppIconProvider()

    private var icons: [TriggerSource: ResolvedIcon] = [:]
    private var names: [TriggerSource: String] = [:]
    /// Process ids are reused, so pid-keyed entries live only this long.
    private var pidEntries: [TriggerSource: Date] = [:]
    private static let pidLifetime: TimeInterval = 30

    static let claudeAppBundleID = "com.anthropic.claudefordesktop"

    func icon(for source: TriggerSource) -> ResolvedIcon {
        if let cached = icons[source], !isStale(source) { return cached }
        let resolved = resolveIcon(source)
        icons[source] = resolved
        if case .app(_, _, let pid?) = source, pid > 0 { pidEntries[source] = Date() }
        return resolved
    }

    /// The app's own name ("Zoom", "Google Chrome"), or `nil` for anything
    /// that is not an app.
    func name(for source: TriggerSource) -> String? {
        if let cached = names[source], !isStale(source) { return cached }
        guard let url = appURL(for: source) else { return nil }
        let name = Bundle(url: url)?.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? Bundle(url: url)?.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? FileManager.default.displayName(atPath: url.path).replacingOccurrences(of: ".app", with: "")
        names[source] = name
        return name
    }

    private func isStale(_ source: TriggerSource) -> Bool {
        guard let stamp = pidEntries[source] else { return false }
        return Date().timeIntervalSince(stamp) > Self.pidLifetime
    }

    private func resolveIcon(_ source: TriggerSource) -> ResolvedIcon {
        switch source {
        case .app:
            if let url = appURL(for: source) { return .image(NSWorkspace.shared.icon(forFile: url.path)) }
            return .symbol("app")
        case .agent(let agent):
            let id = agent.lowercased()
            if id == "claude" {
                if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: Self.claudeAppBundleID) {
                    return .image(NSWorkspace.shared.icon(forFile: url.path))
                }
                return .claudeTile
            }
            if let asset = Self.agentAsset[id] { return .agentMark(asset) }
            return .symbol("sparkle")
        case .file(let url):
            if FileManager.default.fileExists(atPath: url.path) {
                return .image(NSWorkspace.shared.icon(forFile: url.path))
            }
            if let type = UTType(filenameExtension: url.pathExtension) {
                return .image(NSWorkspace.shared.icon(for: type))
            }
            return .symbol("doc")
        case .symbol(let name):
            return .symbol(name)
        }
    }

    /// The `.app` bundle behind an app source: the running process first (so a
    /// side-by-side install resolves to the copy actually in use), then the
    /// bundle id through LaunchServices, then the saved path.
    func appURL(for source: TriggerSource) -> URL? {
        guard case .app(let bundleID, let bundlePath, let pid) = source else { return nil }
        if let pid, pid > 0, let app = NSRunningApplication(processIdentifier: pid),
           let url = app.bundleURL ?? app.executableURL {
            return Self.outermostApp(containing: url) ?? url
        }
        if let bundleID, let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            return url
        }
        if let bundlePath, FileManager.default.fileExists(atPath: bundlePath) {
            return URL(fileURLWithPath: bundlePath)
        }
        return nil
    }

    /// Helper processes (Electron renderers, XPC services) live inside their
    /// app's bundle. The outermost `.app` in the path is the app the user knows.
    static func outermostApp(containing url: URL) -> URL? {
        let parts = url.standardizedFileURL.pathComponents
        guard let index = parts.firstIndex(where: { $0.hasSuffix(".app") }) else { return nil }
        return URL(fileURLWithPath: NSString.path(withComponents: Array(parts[...index])))
    }

    /// Agent ids to their marks in `AgentBrands.xcassets`.
    static let agentAsset: [String: String] = [
        "codex": "brand_codex", "cursor": "brand_cursor", "cursor-agent": "brand_cursor",
        "agy": "brand_antigravity", "antigravity": "brand_antigravity", "gemini": "brand_gemini",
        "grok": "brand_grok", "omp": "brand_omp", "hermes": "brand_hermes", "qwen": "brand_qwen",
        "devin": "brand_devin", "kimi": "brand_kimi", "cline": "brand_cline", "kilo": "brand_kilo",
        "opencode": "brand_opencode", "opencode2": "brand_opencode", "muse": "brand_muse", "dsh": "brand_dsh",
    ]

    /// Brand tints for agent marks drawn as templates. Monochrome marks use
    /// the label color, like the rest of the panel.
    static func agentTint(_ agent: String) -> Color? {
        switch agent.lowercased() {
        case "gemini": return Color(red: 0.43, green: 0.56, blue: 0.97)
        default: return nil
        }
    }
}

/// Draws a resolved icon at a square size. App and file icons fill the frame
/// (they carry their own shape); marks and symbols are inset.
struct SourceIcon: View {
    let source: TriggerSource
    var size: CGFloat = 20

    var body: some View {
        switch AppIconProvider.shared.icon(for: source) {
        case .image(let image):
            Image(nsImage: image).resizable().interpolation(.high).frame(width: size, height: size)
        case .claudeTile:
            ClaudeTile().frame(width: size, height: size)
        case .agentMark(let asset):
            Image(asset).renderingMode(.template).resizable().scaledToFit()
                .frame(width: size * 0.82, height: size * 0.82)
                .foregroundStyle(agentTint ?? Color.primary)
                .frame(width: size, height: size)
        case .symbol(let name):
            Image(systemName: name).font(.system(size: size * 0.72, weight: .medium))
                .frame(width: size, height: size)
        }
    }

    private var agentTint: Color? {
        if case .agent(let agent) = source { return AppIconProvider.agentTint(agent) }
        return nil
    }
}

/// Claude's mark on its orange tile, for Macs without the Claude app: the
/// same look the app icon has, drawn in code so nothing is bundled.
struct ClaudeTile: View {
    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            ZStack {
                RoundedRectangle(cornerRadius: side * 0.225, style: .continuous)
                    .fill(Color(red: 0.851, green: 0.467, blue: 0.341))
                ClaudeBurst().fill(Color.white).frame(width: side * 0.66, height: side * 0.66)
            }
            .frame(width: side, height: side)
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

/// Eight rounded spokes around a center, the burst on Claude's tile.
private struct ClaudeBurst: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let length = min(rect.width, rect.height) / 2
        let width = length * 0.24
        for index in 0..<8 {
            let angle = Double(index) * .pi / 4
            let spoke = Path(roundedRect: CGRect(x: -width / 2, y: -length, width: width, height: length * 0.78),
                             cornerRadius: width / 2)
            path.addPath(spoke, transform: CGAffineTransform(rotationAngle: angle)
                .concatenating(CGAffineTransform(translationX: center.x, y: center.y)))
        }
        path.addEllipse(in: CGRect(x: center.x - width * 0.9, y: center.y - width * 0.9, width: width * 1.8, height: width * 1.8))
        return path
    }
}

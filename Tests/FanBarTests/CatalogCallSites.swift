import Foundation

/// Scans `Sources` for `fanBarText` / `fanBarFormat` calls, the only source of
/// UI copy, so each translation catalog can be checked against them.
enum CatalogCallSites {
    struct CallSite {
        let english: String
        let isFormat: Bool
        let location: String
    }

    static func scan() throws -> [CallSite] {
        let sources = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources", isDirectory: true)
        let literal = #""((?:[^"\\]|\\.)*)""#
        let regex = try NSRegularExpression(
            pattern: #"fanBar(Text|Format)\(\s*"# + literal + #"\s*,\s*"# + literal
        )
        var sites: [CallSite] = []
        let files = FileManager.default.enumerator(at: sources, includingPropertiesForKeys: nil)
        while let file = files?.nextObject() as? URL {
            guard file.pathExtension == "swift" else { continue }
            let text = try String(contentsOf: file, encoding: .utf8)
            let range = NSRange(text.startIndex..., in: text)
            for match in regex.matches(in: text, range: range) {
                guard let kind = Range(match.range(at: 1), in: text),
                      let english = Range(match.range(at: 3), in: text) else { continue }
                sites.append(CallSite(
                    english: unescape(String(text[english])),
                    isFormat: text[kind] == "Format",
                    location: file.lastPathComponent
                ))
            }
        }
        return sites
    }

    /// `String(format:)` pairs arguments by position, so a translated template
    /// must carry the same specifiers in the same order as the English one.
    static func specifiers(in template: String) -> [String] {
        let pattern = #"%(?:\d+\$)?[-+ #0]*\d*(?:\.\d+)?(?:ll|l|h)?[@dDiuUxXoOfFeEgGcCsSaAp%]"#
        let regex = try! NSRegularExpression(pattern: pattern)
        let range = NSRange(template.startIndex..., in: template)
        return regex.matches(in: template, range: range).compactMap {
            Range($0.range, in: template).map { String(template[$0]) }
        }
    }

    /// Source literals are escaped; the runtime key is the unescaped string.
    private static func unescape(_ literal: String) -> String {
        literal
            .replacingOccurrences(of: #"\""#, with: "\"")
            .replacingOccurrences(of: #"\\"#, with: "\\")
    }
}

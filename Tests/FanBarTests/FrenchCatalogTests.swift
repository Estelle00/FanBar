import Foundation
import XCTest
@testable import FanBarShared

/// Keeps the French catalog in step with the `fanBarText` / `fanBarFormat`
/// call sites, which are the only source of UI copy.
final class FrenchCatalogTests: XCTestCase {
    func testFrenchPreferenceUpdatesTextAndFormats() {
        let saved = UserDefaults.standard.object(forKey: FanBarLanguage.preferenceKey)
        defer {
            if let saved {
                UserDefaults.standard.set(saved, forKey: FanBarLanguage.preferenceKey)
            } else {
                UserDefaults.standard.removeObject(forKey: FanBarLanguage.preferenceKey)
            }
        }

        UserDefaults.standard.set(FanBarLanguage.french.rawValue, forKey: FanBarLanguage.preferenceKey)
        XCTAssertEqual(FanBarLanguage.current, .french)
        XCTAssertEqual(FanBarLanguage.french.title, "Français")
        XCTAssertEqual(FanBarLanguage.french.localizationIdentifier, "fr")
        XCTAssertEqual(fanBarText("设置", "Settings"), "Réglages")
        XCTAssertEqual(fanBarFormat("风扇 %d", "Fan %d", 2), "Ventilateur 2")

        UserDefaults.standard.set(FanBarLanguage.english.rawValue, forKey: FanBarLanguage.preferenceKey)
        XCTAssertEqual(fanBarText("设置", "Settings"), "Settings")
    }

    func testFrenchWidgetStringsMatchEnglishKeysAndFormats() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let resources = root.appendingPathComponent("WidgetExtension/Resources")
        func strings(_ language: String) throws -> [String: String] {
            let data = try Data(contentsOf: resources.appendingPathComponent("\(language).lproj/Localizable.strings"))
            return try XCTUnwrap(
                PropertyListSerialization.propertyList(from: data, format: nil) as? [String: String]
            )
        }
        let english = try strings("en")
        let french = try strings("fr")
        XCTAssertEqual(Set(french.keys), Set(english.keys))
        for (key, value) in english {
            let translated = try XCTUnwrap(french[key])
            XCTAssertFalse(translated.isEmpty, key)
            XCTAssertEqual(
                try CatalogCallSites.specifiers(in: translated), try CatalogCallSites.specifiers(in: value), key
            )
        }
    }

    func testEveryCallSiteHasFrench() throws {
        let sites = try CatalogCallSites.scan()
        XCTAssertGreaterThan(sites.count, 200, "call-site scan found too little; check the pattern")
        for site in sites where FrenchCatalog.text(for: site.english) == nil {
            XCTFail("No French for \"\(site.english)\" (\(site.location))")
        }
    }

    func testCatalogHasNoStaleEntries() throws {
        let used = Set(try CatalogCallSites.scan().map(\.english))
        for key in FrenchCatalog.strings.keys where !used.contains(key) {
            XCTFail("Catalog entry no longer used: \"\(key)\"")
        }
    }

    func testFormatSpecifiersMatchEnglish() throws {
        for site in try CatalogCallSites.scan() where site.isFormat {
            guard let translated = FrenchCatalog.text(for: site.english) else { continue }
            XCTAssertEqual(
                try CatalogCallSites.specifiers(in: translated), try CatalogCallSites.specifiers(in: site.english),
                "Specifiers differ for \"\(site.english)\" (\(site.location))"
            )
        }
    }
}

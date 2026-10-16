import Foundation
import XCTest
@testable import FanBarShared

/// Keeps the Russian catalog in step with the `fanBarText` / `fanBarFormat`
/// call sites, which are the only source of UI copy.
final class RussianCatalogTests: XCTestCase {
    func testEveryCallSiteHasRussian() throws {
        let sites = try CatalogCallSites.scan()
        XCTAssertGreaterThan(sites.count, 200, "call-site scan found too little; check the pattern")
        for site in sites where RussianCatalog.text(for: site.english) == nil {
            XCTFail("No Russian for \"\(site.english)\" (\(site.location))")
        }
    }

    func testCatalogHasNoStaleEntries() throws {
        let used = Set(try CatalogCallSites.scan().map(\.english))
        for key in RussianCatalog.strings.keys where !used.contains(key) {
            XCTFail("Catalog entry no longer used: \"\(key)\"")
        }
    }

    func testFormatSpecifiersMatchEnglish() throws {
        for site in try CatalogCallSites.scan() where site.isFormat {
            guard let translated = RussianCatalog.text(for: site.english) else { continue }
            XCTAssertEqual(
                CatalogCallSites.specifiers(in: translated), CatalogCallSites.specifiers(in: site.english),
                "Specifiers differ for \"\(site.english)\" (\(site.location))"
            )
        }
    }
}

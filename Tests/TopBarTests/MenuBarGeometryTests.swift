import XCTest
@testable import TopBar

final class MenuBarGeometryTests: XCTestCase {
    private let screen = CGRect(x: 0, y: 0, width: 1710, height: 1112)

    func testPointInMenuBarStrip() {
        XCTAssertTrue(MenuBarGeometry.isInMenuBar(CGPoint(x: 800, y: 1100), screenFrame: screen, menuBarHeight: 38))
        XCTAssertFalse(MenuBarGeometry.isInMenuBar(CGPoint(x: 800, y: 1000), screenFrame: screen, menuBarHeight: 38))
    }

    func testEmptyArea() {
        let occupied: [ClosedRange<CGFloat>] = [1200...1230, 1240...1260]
        XCTAssertTrue(MenuBarGeometry.isEmptyArea(x: 900, appMenusMaxX: 400, occupied: occupied))
        XCTAssertFalse(MenuBarGeometry.isEmptyArea(x: 1210, appMenusMaxX: 400, occupied: occupied), "on an item")
        XCTAssertFalse(MenuBarGeometry.isEmptyArea(x: 300, appMenusMaxX: 400, occupied: occupied), "on app menus")
    }
}

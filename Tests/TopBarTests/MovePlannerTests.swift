import XCTest
@testable import TopBar

final class MovePlannerTests: XCTestCase {
    // [always-hidden] |300-312| [hidden] |500-512| [visible]
    private let separators = SeparatorFrames(hidden: 500...512, alwaysHidden: 300...312)

    private func item(_ bundleID: String, x: CGFloat) -> MenuBarItem {
        MenuBarItem(pid: 1, bundleID: bundleID, appName: bundleID,
                    frame: CGRect(x: x, y: 0, width: 20, height: 24))
    }

    func testSectionClassification() {
        XCTAssertEqual(MovePlanner.section(ofX: 600, separators: separators), .visible)
        XCTAssertEqual(MovePlanner.section(ofX: 400, separators: separators), .hidden)
        XCTAssertEqual(MovePlanner.section(ofX: 100, separators: separators), .alwaysHidden)
    }

    func testItemsAlreadyInPlaceOrUnlistedProduceNoMoves() {
        let items = [item("obs", x: 400), item("other", x: 600)]
        XCTAssertEqual(MovePlanner.moves(items: items, separators: separators, desired: ["obs": .hidden]), [])
    }

    func testVisibleToHiddenDropsLeftOfHiddenSeparator() {
        let obs = item("obs", x: 600)
        let moves = MovePlanner.moves(items: [obs], separators: separators, desired: ["obs": .hidden])
        XCTAssertEqual(moves, [Move(item: obs, destinationX: 498)])
    }

    func testHiddenToVisibleDropsRightOfHiddenSeparator() {
        let obs = item("obs", x: 400)
        let moves = MovePlanner.moves(items: [obs], separators: separators, desired: ["obs": .visible])
        XCTAssertEqual(moves, [Move(item: obs, destinationX: 514)])
    }

    func testToAlwaysHiddenDropsLeftOfAlwaysHiddenSeparator() {
        let obs = item("obs", x: 600)
        let moves = MovePlanner.moves(items: [obs], separators: separators, desired: ["obs": .alwaysHidden])
        XCTAssertEqual(moves, [Move(item: obs, destinationX: 298)])
    }
}

final class AllowedBundlesTests: XCTestCase {
    private let sections: [String: MenuBarSection] = ["obs": .hidden, "secret": .alwaysHidden, "keep": .visible]
    private let running = ["obs", "secret", "keep", "unmanaged", "unmanaged"]

    func testCollapsedHidesBothHiddenSections() {
        XCTAssertEqual(MenuBarSection.allowedBundles(running: running, sections: sections,
                                                     blocking: [.hidden, .alwaysHidden]),
                       ["keep", "unmanaged"])
    }

    func testExpandedHidesOnlyAlwaysHidden() {
        XCTAssertEqual(MenuBarSection.allowedBundles(running: running, sections: sections, blocking: [.alwaysHidden]),
                       ["keep", "obs", "unmanaged"])
    }

    func testShowAllHasNoRestriction() {
        XCTAssertNil(MenuBarSection.allowedBundles(running: running, sections: sections, blocking: []))
    }
}

final class ChevronMoveTests: XCTestCase {
    private func item(x: CGFloat) -> MenuBarItem {
        MenuBarItem(pid: 1, bundleID: "a", appName: "a", frame: CGRect(x: x, y: 7, width: 24, height: 24))
    }
    private let icon = CGRect(x: 1248, y: 1074, width: 26, height: 38)

    func testAlreadyLeftmostNeedsNoMove() {
        XCTAssertNil(MovePlanner.chevronLeftmostMove(icon: icon, shownItems: [item(x: 1300), item(x: 1400)]))
        XCTAssertNil(MovePlanner.chevronLeftmostMove(icon: icon, shownItems: []))
    }

    func testIconLeftOfChevronMovesChevronToItsEdge() {
        let move = MovePlanner.chevronLeftmostMove(icon: icon, shownItems: [item(x: 1300), item(x: 1200)])
        XCTAssertEqual(move?.destinationX, 1201)
        XCTAssertEqual(move?.item.frame, CGRect(x: 1248, y: 7, width: 26, height: 24))
    }
}

final class RevealedItemMoveTests: XCTestCase {
    private func item(_ id: String, x: CGFloat) -> MenuBarItem {
        MenuBarItem(pid: 1, bundleID: id, appName: id, frame: CGRect(x: x, y: 7, width: 24, height: 24))
    }
    private let icon = CGRect(x: 1200, y: 1074, width: 26, height: 38)
    private let sections: [String: MenuBarSection] = ["obs": .hidden, "ollama": .hidden, "keep": .visible]

    func testMovesLeftmostHiddenItemRightOfChevronFirst() {
        let items = [item("keep", x: 1240), item("ollama", x: 1300), item("obs", x: 1270)]
        let move = MovePlanner.revealedItemMove(icon: icon, shownItems: items, sections: sections)
        XCTAssertEqual(move?.item.bundleID, "obs")
        XCTAssertEqual(move?.destinationX, 1201)
    }

    func testNothingToDoWhenHiddenItemsAreLeftOfChevron() {
        let items = [item("obs", x: 1150), item("keep", x: 1240), item("unmanaged", x: 1300)]
        XCTAssertNil(MovePlanner.revealedItemMove(icon: icon, shownItems: items, sections: sections))
    }
}

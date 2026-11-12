import CoreGraphics

/// Moves a status item by synthesizing the Cmd-drag a user would do by hand.
@MainActor
enum MenuBarItemMover {
    static func perform(_ move: Move) async {
        let start = CGPoint(x: move.item.frame.midX, y: move.item.frame.midY)
        let end = CGPoint(x: move.destinationX, y: start.y)
        let originalCursor = CGEvent(source: nil)?.location
        let source = CGEventSource(stateID: .hidSystemState)

        post(.leftMouseDown, at: start, source: source)
        await pause()
        let steps = 10
        for step in 1...steps {
            let x = start.x + (end.x - start.x) * CGFloat(step) / CGFloat(steps)
            post(.leftMouseDragged, at: CGPoint(x: x, y: start.y), source: source)
            await pause()
        }
        post(.leftMouseUp, at: end, source: source)

        if let originalCursor { CGWarpMouseCursorPosition(originalCursor) }
    }

    private static func post(_ type: CGEventType, at point: CGPoint, source: CGEventSource?) {
        let event = CGEvent(mouseEventSource: source, mouseType: type,
                            mouseCursorPosition: point, mouseButton: .left)
        event?.flags = .maskCommand
        event?.post(tap: .cghidEventTap)
    }

    private static func pause() async {
        try? await Task.sleep(for: .milliseconds(15))
    }
}

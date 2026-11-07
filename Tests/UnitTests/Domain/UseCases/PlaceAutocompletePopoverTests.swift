import XCTest
@testable import TrueRPCMini

/// Placement uses a top-left origin and a downward y axis. Every rectangle shares that space.
final class PlaceAutocompletePopoverTests: XCTestCase {
    func test_place_caretInTheUpperEditor_putsThePanelBelowTheLine() throws {
        let limits = EditorRect(x: 0, y: 0, width: 1200, height: 800)
        let editor = EditorRect(x: 100, y: 150, width: 480, height: 500)
        let caret = EditorRect(x: 120, y: 170, width: 1, height: 20)

        let placement = place(caret: caret, visibleEditor: editor, limits: limits, height: 72)

        XCTAssertEqual(placement?.side, .below)
        let frame = try XCTUnwrap(placement?.frame)
        XCTAssertEqual(frame.y, caret.maxY + PlaceAutocompletePopover.gap)
        XCTAssertEqual(frame.height, 72)
        XCTAssertEqual(frame.width, 240)
        XCTAssertEqual(frame.midX, caret.midX)
        XCTAssertFalse(frame.intersects(caret))
        XCTAssertTrue(limits.contains(frame))
    }

    func test_place_caretAtTheBottomEdge_putsThePanelAboveTheLine() throws {
        let editor = EditorRect(x: 100, y: 150, width: 480, height: 500)
        let caret = EditorRect(x: 140, y: 610, width: 1, height: 20)

        let placement = place(caret: caret, visibleEditor: editor, limits: editor, height: 200)

        XCTAssertEqual(placement?.side, .above)
        let frame = try XCTUnwrap(placement?.frame)
        XCTAssertEqual(frame.maxY, caret.minY - PlaceAutocompletePopover.gap)
        XCTAssertEqual(frame.height, 200)
        XCTAssertFalse(frame.intersects(caret))
        XCTAssertTrue(editor.contains(frame))
    }

    func test_place_tallListInTheMiddle_usesTheRoomierSideAndShrinks() throws {
        let editor = EditorRect(x: 100, y: 150, width: 480, height: 500)
        let caret = EditorRect(x: 200, y: 380, width: 1, height: 20)
        let roomBelow = editor.maxY - caret.maxY - PlaceAutocompletePopover.gap

        let placement = place(
            caret: caret,
            visibleEditor: editor,
            limits: editor,
            size: EditorSize(width: 260, height: 400))

        XCTAssertEqual(placement?.side, .below)
        let frame = try XCTUnwrap(placement?.frame)
        XCTAssertEqual(frame.y, caret.maxY + PlaceAutocompletePopover.gap)
        XCTAssertEqual(frame.height, roomBelow)
        XCTAssertLessThan(frame.height, 400)
        XCTAssertTrue(editor.contains(frame))
    }

    func test_place_shortWindowAndCaretNearTheTop_shrinksBelowTheLine() throws {
        let window = EditorRect(x: 0, y: 0, width: 400, height: 220)
        let caret = EditorRect(x: 20, y: 30, width: 1, height: 16)
        let roomBelow = window.maxY - caret.maxY - PlaceAutocompletePopover.gap

        let placement = place(caret: caret, visibleEditor: window, limits: window, height: 300)

        XCTAssertEqual(placement?.side, .below)
        let frame = try XCTUnwrap(placement?.frame)
        XCTAssertEqual(frame.height, roomBelow)
        XCTAssertEqual(frame.y, caret.maxY + PlaceAutocompletePopover.gap)
        XCTAssertTrue(window.contains(frame))
    }

    func test_place_windowAgainstTheDock_staysInsideTheVisibleScreen() throws {
        let screen = EditorRect(x: 0, y: 40, width: 1200, height: 660)
        let editor = EditorRect(x: 80, y: 100, width: 500, height: 620)
        let caret = EditorRect(x: 100, y: 664, width: 1, height: 16)

        let placement = place(caret: caret, visibleEditor: editor, limits: screen, height: 100)

        XCTAssertEqual(placement?.side, .above)
        let frame = try XCTUnwrap(placement?.frame)
        XCTAssertLessThanOrEqual(frame.maxY, screen.maxY)
        XCTAssertGreaterThanOrEqual(frame.minY, screen.minY)
        XCTAssertEqual(frame.maxY, caret.minY - PlaceAutocompletePopover.gap)
        XCTAssertFalse(frame.intersects(caret))
    }

    func test_place_caretAtTheLeftEdge_shiftsThePanelRightAndKeepsTheCaretInsideIt() throws {
        let limits = EditorRect(x: 0, y: 0, width: 1200, height: 800)
        let caret = EditorRect(x: 4, y: 100, width: 1, height: 20)

        let placement = place(caret: caret, visibleEditor: limits, limits: limits, height: 40)

        let frame = try XCTUnwrap(placement?.frame)
        XCTAssertEqual(frame.minX, limits.minX)
        XCTAssertGreaterThanOrEqual(caret.midX, frame.minX)
        XCTAssertLessThanOrEqual(caret.midX, frame.maxX)
        XCTAssertTrue(limits.contains(frame))
    }

    func test_place_caretAtTheRightEdge_shiftsThePanelLeftAndKeepsTheCaretInsideIt() throws {
        let limits = EditorRect(x: 0, y: 0, width: 1200, height: 800)
        let caret = EditorRect(x: 1180, y: 100, width: 1, height: 20)

        let placement = place(caret: caret, visibleEditor: limits, limits: limits, height: 40)

        let frame = try XCTUnwrap(placement?.frame)
        XCTAssertEqual(frame.maxX, limits.maxX)
        XCTAssertGreaterThanOrEqual(caret.midX, frame.minX)
        XCTAssertLessThanOrEqual(caret.midX, frame.maxX)
    }

    func test_place_caretOnAWrappedLine_anchorsToThatCaretNotTheLineStart() {
        let limits = EditorRect(x: 0, y: 0, width: 1200, height: 800)
        let lineStart = EditorRect(x: 16, y: 200, width: 1, height: 20)
        let caret = EditorRect(x: 220, y: 200, width: 1, height: 20)

        let placement = place(caret: caret, visibleEditor: limits, limits: limits, height: 40)

        XCTAssertEqual(placement?.frame.midX, caret.midX)
        XCTAssertNotEqual(placement?.frame.midX, lineStart.midX)
    }

    func test_place_scrolledCaretVisibleInTheViewport_anchorsToTheVisibleCaret() throws {
        let viewport = EditorRect(x: 100, y: 400, width: 480, height: 300)
        let caret = EditorRect(x: 120, y: 430, width: 1, height: 20)

        let placement = place(caret: caret, visibleEditor: viewport, limits: viewport, height: 48)

        XCTAssertEqual(placement?.side, .below)
        let frame = try XCTUnwrap(placement?.frame)
        XCTAssertEqual(frame.y, caret.maxY + PlaceAutocompletePopover.gap)
        XCTAssertGreaterThan(frame.y, viewport.minY)
        XCTAssertTrue(viewport.contains(frame))
    }

    func test_place_caretOutsideTheVisibleEditor_returnsNil() {
        let editor = EditorRect(x: 100, y: 150, width: 480, height: 500)

        XCTAssertNil(place(
            caret: EditorRect(x: 120, y: 10, width: 1, height: 20),
            visibleEditor: editor,
            limits: editor))
        XCTAssertNil(place(
            caret: EditorRect(x: 120, y: 800, width: 1, height: 20),
            visibleEditor: editor,
            limits: editor))
        XCTAssertNil(place(
            caret: EditorRect(x: 10, y: 200, width: 1, height: 20),
            visibleEditor: editor,
            limits: editor))
    }

    func test_place_shorterList_keepsTheCaretAndUsesTheFullHeight() {
        let limits = EditorRect(x: 0, y: 0, width: 1200, height: 800)
        let caret = EditorRect(x: 120, y: 170, width: 1, height: 20)

        let placement = place(caret: caret, visibleEditor: limits, limits: limits, height: 40)

        XCTAssertEqual(placement?.side, .below)
        XCTAssertEqual(placement?.frame.y, caret.maxY + PlaceAutocompletePopover.gap)
        XCTAssertEqual(placement?.frame.height, 40)
    }

    func test_place_tallerList_staysOnTheCaretAndShrinksToTheFreeRoom() throws {
        let limits = EditorRect(x: 0, y: 0, width: 1200, height: 800)
        let caret = EditorRect(x: 120, y: 170, width: 1, height: 20)
        let roomBelow = limits.maxY - caret.maxY - PlaceAutocompletePopover.gap

        let placement = place(caret: caret, visibleEditor: limits, limits: limits, height: 900)

        XCTAssertEqual(placement?.side, .below)
        XCTAssertEqual(placement?.frame.y, caret.maxY + PlaceAutocompletePopover.gap)
        XCTAssertEqual(placement?.frame.height, roomBelow)
        XCTAssertTrue(try limits.contains(XCTUnwrap(placement?.frame)))
    }

    func test_place_caretMovesToAnotherLine_followsTheNewCaret() throws {
        let limits = EditorRect(x: 0, y: 0, width: 1200, height: 800)
        let first = EditorRect(x: 120, y: 170, width: 1, height: 20)
        let second = EditorRect(x: 120, y: 300, width: 1, height: 20)

        let firstPanel = place(caret: first, visibleEditor: limits, limits: limits, height: 48)
        let secondPanel = place(caret: second, visibleEditor: limits, limits: limits, height: 48)

        XCTAssertEqual(firstPanel?.frame.y, first.maxY + PlaceAutocompletePopover.gap)
        XCTAssertEqual(secondPanel?.frame.y, second.maxY + PlaceAutocompletePopover.gap)
        XCTAssertEqual(try XCTUnwrap(secondPanel?.frame.y) - firstPanel!.frame.y, second.minY - first.minY)
    }

    func test_place_windowMoves_movesThePanelByTheSameAmount() throws {
        let limits = EditorRect(x: 0, y: 0, width: 1200, height: 800)
        let editor = EditorRect(x: 100, y: 150, width: 480, height: 500)
        let caret = EditorRect(x: 120, y: 170, width: 1, height: 20)
        let parked = place(caret: caret, visibleEditor: editor, limits: limits, height: 72)

        let shiftX = 30.0
        let shiftY = 80.0
        let moved = place(
            caret: caret.offset(x: shiftX, y: shiftY),
            visibleEditor: editor.offset(x: shiftX, y: shiftY),
            limits: limits.offset(x: shiftX, y: shiftY),
            height: 72)

        XCTAssertEqual(moved?.frame.x, try XCTUnwrap(parked?.frame.x) + shiftX)
        XCTAssertEqual(moved?.frame.y, try XCTUnwrap(parked?.frame.y) + shiftY)
        XCTAssertEqual(moved?.side, parked?.side)
    }

    func test_place_twoEditors_anchorsToTheEditorThatContainsTheCaret() throws {
        let limits = EditorRect(x: 0, y: 0, width: 1200, height: 800)
        let body = EditorRect(x: 0, y: 0, width: 400, height: 500)
        let metadata = EditorRect(x: 500, y: 0, width: 400, height: 500)
        let bodyCaret = EditorRect(x: 20, y: 40, width: 1, height: 18)
        let metadataCaret = EditorRect(x: 520, y: 80, width: 1, height: 18)

        let bodyPanel = place(caret: bodyCaret, visibleEditor: body, limits: limits, height: 48)
        let metadataPanel = place(caret: metadataCaret, visibleEditor: metadata, limits: limits, height: 48)

        XCTAssertEqual(bodyPanel?.frame.y, bodyCaret.maxY + PlaceAutocompletePopover.gap)
        XCTAssertEqual(metadataPanel?.frame.y, metadataCaret.maxY + PlaceAutocompletePopover.gap)
        XCTAssertNotEqual(bodyPanel?.frame.y, metadataPanel?.frame.y)
        XCTAssertGreaterThanOrEqual(bodyCaret.midX, try XCTUnwrap(bodyPanel?.frame.minX))
        XCTAssertLessThanOrEqual(bodyCaret.midX, try XCTUnwrap(bodyPanel?.frame.maxX))
        XCTAssertEqual(metadataPanel?.frame.midX, metadataCaret.midX)
    }

    func test_place_neitherSideFitsOneRow_returnsNil() {
        let limits = EditorRect(x: 0, y: 0, width: 200, height: 80)
        let caret = EditorRect(x: 10, y: 30, width: 1, height: 20)

        XCTAssertNil(place(caret: caret, visibleEditor: limits, limits: limits, height: 200))
    }

    func test_place_bothSidesFit_prefersBelow() {
        let limits = EditorRect(x: 0, y: 0, width: 1200, height: 800)
        let caret = EditorRect(x: 400, y: 390, width: 1, height: 20)

        let placement = place(caret: caret, visibleEditor: limits, limits: limits, height: 72)

        XCTAssertEqual(placement?.side, .below)
        XCTAssertEqual(placement?.frame.height, 72)
    }

    func test_place_panelWiderThanTheLimits_usesTheAvailableWidth() throws {
        let limits = EditorRect(x: 40, y: 0, width: 100, height: 400)
        let caret = EditorRect(x: 80, y: 40, width: 1, height: 20)

        let placement = place(
            caret: caret,
            visibleEditor: limits,
            limits: limits,
            size: EditorSize(width: 240, height: 40))

        let frame = try XCTUnwrap(placement?.frame)
        XCTAssertEqual(frame.width, limits.width)
        XCTAssertEqual(frame.minX, limits.minX)
        XCTAssertTrue(limits.contains(frame))
    }

    private func place(
        caret: EditorRect,
        visibleEditor: EditorRect,
        limits: EditorRect,
        height: Double = 72,
        size: EditorSize? = nil)
        -> AutocompletePopoverPlacement?
    {
        PlaceAutocompletePopover.place(
            caret: caret,
            visibleEditor: visibleEditor,
            limits: limits,
            contentSize: size ?? EditorSize(width: 240, height: height))
    }
}

private extension EditorRect {
    func offset(x: Double, y: Double) -> EditorRect {
        EditorRect(x: self.x + x, y: self.y + y, width: width, height: height)
    }
}

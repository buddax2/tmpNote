//
//  ResizeGripView.swift
//  tmpNote
//
//  An invisible resize handle for the bottom corners and bottom edge. NSPopover can't
//  be resized by the user, so the popover's content uses these to change its size.
//  They draw nothing; hovering shows the matching resize cursor and a tooltip.
//

import Cocoa

final class ResizeGripView: NSView {

    enum Edge {
        case bottomLeft, bottom, bottomRight

        /// How dragging right changes the width: the left corner grows when dragged left,
        /// the bottom edge only changes the height.
        var widthDirection: CGFloat {
            switch self {
            case .bottomLeft: return -1
            case .bottom: return 0
            case .bottomRight: return 1
            }
        }
    }

    let edge: Edge

    var onDragBegan: (() -> Void)?
    /// Mouse offset since the drag started, in screen points: right and down are positive.
    var onDrag: ((NSSize) -> Void)?
    var onDragEnded: (() -> Void)?

    private var dragStart: NSPoint?

    init(edge: Edge) {
        self.edge = edge
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        return true
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: cursor)
    }

    private var cursor: NSCursor {
        if #available(macOS 15, *) {
            switch edge {
            case .bottomLeft: return NSCursor.frameResize(position: .bottomLeft, directions: .all)
            case .bottom: return NSCursor.frameResize(position: .bottom, directions: .all)
            case .bottomRight: return NSCursor.frameResize(position: .bottomRight, directions: .all)
            }
        }
        return edge == .bottom ? .resizeUpDown : .crosshair
    }

    override func mouseDown(with event: NSEvent) {
        dragStart = NSEvent.mouseLocation
        onDragBegan?()
    }

    override func mouseDragged(with event: NSEvent) {
        guard let start = dragStart else { return }
        let location = NSEvent.mouseLocation
        // Screen coordinates grow upwards, so flip y to make "down" positive
        onDrag?(NSSize(width: location.x - start.x, height: start.y - location.y))
    }

    override func mouseUp(with event: NSEvent) {
        guard dragStart != nil else { return }
        dragStart = nil
        onDragEnded?()
    }
}

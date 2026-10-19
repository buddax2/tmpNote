//
//  NoteTextView.swift
//  tmpNote
//
//  Draws `- [ ] item` markdown tasks as clickable checkboxes. The note itself
//  stays plain markdown; MarkdownHighlighter tags the marker characters with
//  `.todoCheckbox` and hides them, and this view draws a checkbox over them.
//

import Cocoa
import Carbon.HIToolbox

class NoteTextView: NSTextView {

    private static let listPrefixRegex = try! NSRegularExpression(pattern: "^([ \\t]*)([-*+])([ \\t]+\\[[ xX]\\])?[ \\t]+")

    override func keyDown(with event: NSEvent) {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

        // ⌘S - Save content
        if flags == .command && event.keyCode == kVK_ANSI_S {
            DatasourceController.shared.save()
        }

        // ⌘⇧T - Turn the selected lines into to-do items and back
        if flags == [.command, .shift] && event.keyCode == kVK_ANSI_T && isEditable {
            toggleTodoLines()
            return
        }

        super.keyDown(with: event)
    }

    // MARK: Drawing

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        forEachCheckbox(in: dirtyRect) { rect, isChecked, _ in
            drawCheckbox(in: rect, isChecked: isChecked)
        }
    }

    private func drawCheckbox(in rect: NSRect, isChecked: Bool) {
        let side = min(rect.height, 16) * 0.95
        let box = NSRect(x: rect.midX - side / 2, y: rect.midY - side / 2, width: side, height: side).insetBy(dx: 0.5, dy: 0.5)
        let circle = NSBezierPath(ovalIn: box)

        guard isChecked else {
            NSColor.secondaryLabelColor.setStroke()
            circle.lineWidth = 1
            circle.stroke()
            return
        }

        NSColor.controlAccentColor.setFill()
        circle.fill()

        // The view is flipped, so y grows downwards
        let check = NSBezierPath()
        check.move(to: NSPoint(x: box.minX + side * 0.27, y: box.minY + side * 0.52))
        check.line(to: NSPoint(x: box.minX + side * 0.44, y: box.minY + side * 0.68))
        check.line(to: NSPoint(x: box.minX + side * 0.74, y: box.minY + side * 0.34))
        check.lineWidth = max(1.5, side * 0.11)
        check.lineCapStyle = .round
        check.lineJoinStyle = .round
        NSColor.white.setStroke()
        check.stroke()
    }

    /// Calls `body` with the view rect, state and character range of every checkbox intersecting `viewRect`.
    private func forEachCheckbox(in viewRect: NSRect, _ body: (NSRect, Bool, NSRange) -> Void) {
        guard let layoutManager = layoutManager, let textContainer = textContainer, let storage = textStorage else { return }

        let origin = textContainerOrigin
        let containerRect = viewRect.offsetBy(dx: -origin.x, dy: -origin.y)
        let glyphRange = layoutManager.glyphRange(forBoundingRect: containerRect, in: textContainer)
        let charRange = layoutManager.characterRange(forGlyphRange: glyphRange, actualGlyphRange: nil)

        storage.enumerateAttribute(.todoCheckbox, in: charRange, options: []) { value, range, _ in
            guard let isChecked = value as? Bool else { return }
            let markerGlyphs = layoutManager.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
            let rect = layoutManager.boundingRect(forGlyphRange: markerGlyphs, in: textContainer).offsetBy(dx: origin.x, dy: origin.y)
            body(rect, isChecked, range)
        }
    }

    private func checkbox(at viewPoint: NSPoint) -> NSRange? {
        var hit: NSRange?
        forEachCheckbox(in: NSRect(x: viewPoint.x - 1, y: viewPoint.y - 1, width: 2, height: 2)) { rect, _, range in
            if rect.contains(viewPoint) { hit = range }
        }
        return hit
    }

    // MARK: Clicking

    /// Called when a checkbox is clicked in the read-only preview, with the location
    /// of its `[ ]` state character in the note's markdown.
    var onPreviewTodoToggle: ((Int) -> Void)?

    /// In the editor every checkbox toggles; in the preview only the ones linked back to the note do.
    private func clickableCheckbox(at point: NSPoint) -> NSRange? {
        guard let marker = checkbox(at: point) else { return nil }
        if isEditable { return marker }
        return textStorage?.attribute(.todoSourceLocation, at: marker.location, effectiveRange: nil) != nil ? marker : nil
    }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        if let marker = clickableCheckbox(at: point) {
            if isEditable {
                toggleCheckbox(marker: marker)
            } else if let location = textStorage?.attribute(.todoSourceLocation, at: marker.location, effectiveRange: nil) as? Int {
                onPreviewTodoToggle?(location)
            }
            return
        }
        super.mouseDown(with: event)
    }

    override func mouseMoved(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        if clickableCheckbox(at: point) != nil {
            NSCursor.pointingHand.set()
            return
        }
        super.mouseMoved(with: event)
    }

    /// Flips `[ ]` ↔ `[x]` inside the `- [ ]` marker range.
    private func toggleCheckbox(marker: NSRange) {
        let markerText = (string as NSString).substring(with: marker) as NSString
        let bracket = markerText.range(of: "[")
        guard bracket.location != NSNotFound else { return }

        let stateRange = NSRange(location: marker.location + bracket.location + 1, length: 1)
        let newState = (string as NSString).substring(with: stateRange) == " " ? "x" : " "
        replace(stateRange, with: newState)
    }

    // MARK: Editing

    /// Return on a list or to-do line starts the next item; on an empty item it ends the list.
    /// Returns false when the line isn't a list item, so the newline is inserted as usual.
    func continueList() -> Bool {
        let text = string as NSString
        let selection = selectedRange()
        guard selection.length == 0 else { return false }

        let lineRange = text.lineRange(for: NSRange(location: selection.location, length: 0))
        let line = text.substring(with: lineRange).trimmingCharacters(in: .newlines) as NSString
        guard let match = Self.listPrefixRegex.firstMatch(in: line as String, range: NSRange(location: 0, length: line.length)) else { return false }

        let prefixEnd = lineRange.location + match.range.length
        guard selection.location >= prefixEnd else { return false }

        let content = line.substring(from: match.range.length).trimmingCharacters(in: .whitespaces)
        if content.isEmpty {
            replace(NSRange(location: lineRange.location, length: match.range.length), with: "")
            return true
        }

        let indent = line.substring(with: match.range(at: 1))
        let bullet = line.substring(with: match.range(at: 2))
        let isTask = match.range(at: 3).location != NSNotFound
        insertText("\n" + indent + bullet + (isTask ? " [ ] " : " "), replacementRange: selection)
        return true
    }

    /// Turns the selected lines into to-do items, or back into plain lines if they all are already.
    func toggleTodoLines() {
        let text = string as NSString
        let linesRange = text.lineRange(for: selectedRange())
        let block = text.substring(with: linesRange)
        let hasTrailingNewline = block.hasSuffix("\n")
        var lines = block.components(separatedBy: "\n")
        if hasTrailingNewline { lines.removeLast() }

        func isTask(_ line: String) -> Bool {
            return MarkdownHighlighter.taskRegex.firstMatch(in: line, range: NSRange(location: 0, length: (line as NSString).length)) != nil
        }

        let contentLines = lines.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        let removeTodos = !contentLines.isEmpty && contentLines.allSatisfy(isTask)

        let newLines: [String] = lines.map { line in
            let isBlank = line.trimmingCharacters(in: .whitespaces).isEmpty
            if isBlank && lines.count > 1 { return line }

            let ns = line as NSString
            let match = Self.listPrefixRegex.firstMatch(in: line, range: NSRange(location: 0, length: ns.length))
            let indent = match.map { ns.substring(with: $0.range(at: 1)) } ?? String(line.prefix { $0 == " " || $0 == "\t" })
            let content = match.map { ns.substring(from: $0.range.length) } ?? String(line.dropFirst(indent.count))

            if removeTodos { return indent + content }
            if isTask(line) { return line }
            return indent + "- [ ] " + content
        }

        let replacement = newLines.joined(separator: "\n")
        replace(linesRange, with: replacement + (hasTrailingNewline ? "\n" : ""))
        setSelectedRange(NSRange(location: linesRange.location + (replacement as NSString).length, length: 0))
    }

    /// Replaces text as a regular user edit: undoable and reported to the delegate, without moving the caret.
    private func replace(_ range: NSRange, with replacement: String) {
        guard shouldChangeText(in: range, replacementString: replacement) else { return }
        textStorage?.replaceCharacters(in: range, with: replacement)
        didChangeText()
    }
}

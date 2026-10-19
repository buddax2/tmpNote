//
//  MarkdownHighlighter.swift
//  tmpNote
//
//  Styles raw markdown in place: only attributes are changed, the text itself
//  (including the syntax markers) stays untouched and editable.
//

import Cocoa

extension NSAttributedString.Key {
    /// Marks the characters NoteTextView draws a checkbox over. The value is `true` when checked.
    static let todoCheckbox = NSAttributedString.Key("tmpNote.todoCheckbox")
    /// Preview only: where the checkbox's `[ ]` state character is in the note's markdown.
    static let todoSourceLocation = NSAttributedString.Key("tmpNote.todoSourceLocation")
}

final class MarkdownHighlighter: NSObject, NSTextStorageDelegate {

    var isEnabled = false
    var baseFontSize: CGFloat = CGFloat(TmpNoteViewController.defaultFontSize)

    private let markerColor = NSColor.tertiaryLabelColor
    private let codeBackground = NSColor.quaternaryLabelColor.withAlphaComponent(0.12)
    private let headingSizeDelta: [CGFloat] = [10, 8, 4, 0, -2, -4]

    private static func regex(_ pattern: String, _ options: NSRegularExpression.Options = [.anchorsMatchLines]) -> NSRegularExpression {
        return try! NSRegularExpression(pattern: pattern, options: options)
    }

    private static let headingRegex = regex("^(#{1,6})[ \\t]+.*$")
    private static let blockquoteRegex = regex("^([ \\t]*>[> \\t]*)(.*)$")
    private static let listMarkerRegex = regex("^[ \\t]*([-*+]|\\d+[.)])[ \\t]+")
    /// `- [ ] item`: group 1 is the marker drawn as a checkbox, group 2 the state, group 3 the item text.
    static let taskRegex = regex("^[ \\t]*([-*+][ \\t]+\\[([ xX])\\])(?:[ \\t]+(.*))?$")
    private static let ruleRegex = regex("^[ \\t]*([-*_])(?:[ \\t]*\\1){2,}[ \\t]*$")
    private static let boldRegex = regex("(\\*\\*|__)(?=\\S)(.+?)(?<=\\S)\\1")
    private static let italicRegex = regex("(?<![*_\\w])([*_])(?=[^\\s*_])(.+?)(?<=[^\\s*_])\\1(?![*_\\w])")
    private static let strikeRegex = regex("(~~)(?=\\S)(.+?)(?<=\\S)~~")
    private static let linkRegex = regex("(!?\\[)([^\\]\\n]+)(\\]\\([^)\\n]*\\))")
    private static let inlineCodeRegex = regex("(`+)([^`\\n]+?)\\1")
    private static let fencedCodeRegex = regex("^```.*?(?:^```[^\\n]*$|\\z)", [.anchorsMatchLines, .dotMatchesLineSeparators])

    // MARK: NSTextStorageDelegate

    func textStorage(_ textStorage: NSTextStorage, didProcessEditing editedMask: NSTextStorageEditActions, range editedRange: NSRange, changeInLength delta: Int) {
        guard isEnabled, editedMask.contains(.editedCharacters) else { return }
        // Notes are small, and fences/lists can span lines, so restyle everything.
        apply(to: textStorage)
    }

    // MARK: Public

    var baseAttributes: [NSAttributedString.Key: Any] {
        return [.font: NSFont.systemFont(ofSize: baseFontSize), .foregroundColor: NSColor.textColor]
    }

    func highlight(_ storage: NSTextStorage) {
        storage.beginEditing()
        apply(to: storage)
        storage.endEditing()
    }

    // MARK: Styling

    private func resetAttributes(_ storage: NSTextStorage, _ range: NSRange) {
        storage.removeAttribute(.backgroundColor, range: range)
        storage.removeAttribute(.strikethroughStyle, range: range)
        storage.removeAttribute(.underlineStyle, range: range)
        storage.removeAttribute(.todoCheckbox, range: range)
        storage.addAttributes(baseAttributes, range: range)
    }

    private func apply(to storage: NSTextStorage) {
        let string = storage.string
        let fullRange = NSRange(location: 0, length: storage.length)
        guard fullRange.length > 0 else { return }

        resetAttributes(storage, fullRange)

        func matches(_ regex: NSRegularExpression, _ body: (NSTextCheckingResult) -> Void) {
            regex.enumerateMatches(in: string, options: [], range: fullRange) { result, _, _ in
                if let result = result { body(result) }
            }
        }

        // Block-level
        matches(Self.headingRegex) { m in
            let level = m.range(at: 1).length
            let size = max(baseFontSize + headingSizeDelta[level - 1], 6)
            storage.addAttribute(.font, value: NSFontManager.shared.convert(NSFont.systemFont(ofSize: size), toHaveTrait: .boldFontMask), range: m.range)
            dim(storage, m.range(at: 1))
        }
        matches(Self.blockquoteRegex) { m in
            dim(storage, m.range(at: 1))
            storage.addAttribute(.foregroundColor, value: NSColor.secondaryLabelColor, range: m.range(at: 2))
        }
        matches(Self.listMarkerRegex) { m in
            storage.addAttribute(.foregroundColor, value: NSColor.controlAccentColor, range: m.range(at: 1))
        }
        matches(Self.taskRegex) { m in
            let isChecked = (string as NSString).substring(with: m.range(at: 2)) != " "
            // The marker text is hidden; NoteTextView draws a checkbox in its place.
            // Monospaced so `[ ]` and `[x]` take the same width and items stay aligned.
            storage.addAttributes([
                .todoCheckbox: isChecked,
                .foregroundColor: NSColor.clear,
                .font: NSFont.monospacedSystemFont(ofSize: baseFontSize * 0.8, weight: .regular),
            ], range: m.range(at: 1))
            let item = m.range(at: 3)
            if isChecked, item.location != NSNotFound, item.length > 0 {
                storage.addAttributes([
                    .strikethroughStyle: NSUnderlineStyle.single.rawValue,
                    .foregroundColor: NSColor.secondaryLabelColor,
                ], range: item)
            }
        }
        matches(Self.ruleRegex) { m in
            dim(storage, m.range)
        }

        // Inline
        matches(Self.boldRegex) { m in
            addTrait(.boldFontMask, storage, m.range(at: 2))
            dimDelimiters(storage, m, contentGroup: 2)
        }
        matches(Self.italicRegex) { m in
            addTrait(.italicFontMask, storage, m.range(at: 2))
            dimDelimiters(storage, m, contentGroup: 2)
        }
        matches(Self.strikeRegex) { m in
            storage.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: m.range(at: 2))
            dimDelimiters(storage, m, contentGroup: 2)
        }
        matches(Self.linkRegex) { m in
            storage.addAttribute(.foregroundColor, value: NSColor.linkColor, range: m.range(at: 2))
            dim(storage, m.range(at: 1))
            dim(storage, m.range(at: 3))
        }

        // Code last, so it overrides any styling matched inside it.
        matches(Self.inlineCodeRegex) { m in
            styleAsCode(storage, m.range)
            dimDelimiters(storage, m, contentGroup: 2)
        }
        matches(Self.fencedCodeRegex) { m in
            styleAsCode(storage, m.range)
            let text = string as NSString
            dim(storage, text.lineRange(for: NSRange(location: m.range.location, length: 0)))
            let lastLine = text.lineRange(for: NSRange(location: NSMaxRange(m.range) - 1, length: 0))
            if lastLine.location > m.range.location, text.substring(with: lastLine).hasPrefix("```") {
                dim(storage, lastLine)
            }
        }
    }

    private func dim(_ storage: NSTextStorage, _ range: NSRange) {
        guard range.location != NSNotFound, range.length > 0 else { return }
        storage.addAttribute(.foregroundColor, value: markerColor, range: range)
    }

    /// Dims everything in the match outside the content group (the opening and closing markers).
    private func dimDelimiters(_ storage: NSTextStorage, _ match: NSTextCheckingResult, contentGroup: Int) {
        let whole = match.range
        let content = match.range(at: contentGroup)
        dim(storage, NSRange(location: whole.location, length: content.location - whole.location))
        dim(storage, NSRange(location: NSMaxRange(content), length: NSMaxRange(whole) - NSMaxRange(content)))
    }

    private func addTrait(_ trait: NSFontTraitMask, _ storage: NSTextStorage, _ range: NSRange) {
        storage.enumerateAttribute(.font, in: range, options: []) { value, subrange, _ in
            let font = value as? NSFont ?? NSFont.systemFont(ofSize: baseFontSize)
            storage.addAttribute(.font, value: NSFontManager.shared.convert(font, toHaveTrait: trait), range: subrange)
        }
    }

    private func styleAsCode(_ storage: NSTextStorage, _ range: NSRange) {
        let size = (storage.attribute(.font, at: range.location, effectiveRange: nil) as? NSFont)?.pointSize ?? baseFontSize
        storage.removeAttribute(.strikethroughStyle, range: range)
        storage.removeAttribute(.todoCheckbox, range: range)
        storage.addAttributes([
            .font: NSFont.monospacedSystemFont(ofSize: size * 0.9, weight: .regular),
            .foregroundColor: NSColor.systemPink,
            .backgroundColor: codeBackground,
        ], range: range)
    }
}

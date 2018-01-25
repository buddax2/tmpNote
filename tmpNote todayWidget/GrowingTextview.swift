//
//  GrowingTextview.swift
//  tmpNote todayWidget
//
//  Created by BUDDAx2 on 11/19/17.
//  Copyright © 2017 BUDDAx2. All rights reserved.
//

import AppKit

protocol TextProtocol {
    func textDidChange(text: String?)
    func resizeParentViewToHeight(_ height:CGFloat)
}

class GrowingTextView: NSTextView {
    var textDelegate:TextProtocol!
    
    override init(frame: NSRect) {
        super.init(frame: frame)
    }
    
    required init(coder: NSCoder)  {
        super.init(coder: coder)!
    }
    
    override func keyDown(with theEvent: NSEvent) {
        switch theEvent.keyCode {
        case 36,76: //Enter and Return
            super.keyDown(with: theEvent)
            updateTextViewHeight()
        default:
            super.keyDown(with: theEvent)
        }
    }
    
    override func didChangeText() {
        updateTextViewHeight()
        setupDefaultView()
        textDelegate?.textDidChange(text: self.string)
    }
    
    func numberOfLines() -> Int {
        var numberOfLines = 0
        guard let numberOfGlyphs = layoutManager?.numberOfGlyphs else { return 1 }
        var lineRange = NSRange()
        var index = 0
        
        while index < numberOfGlyphs {
            layoutManager?.lineFragmentRect(forGlyphAt: index, effectiveRange: &lineRange)
            index = NSMaxRange(lineRange);
            numberOfLines += 1
        }
        
        return numberOfLines
    }
    
    func updateTextViewHeight() {
        
        let sizeThatFitsTextView = self.fittingSize// (CGSize(width: self.frame.size.width, height: CGFloat(MAXFLOAT)))
        let heightOfText = sizeThatFitsTextView.height
        
        let lines = numberOfLines()
        let fontSize = self.font?.pointSize ?? CGFloat(TodayViewController.defaultFontSize)
        let lineHeight = CGFloat(lines) * (fontSize + 4)
        let minLineHeight: CGFloat = 18
        textDelegate.resizeParentViewToHeight(CGFloat.maximum(lineHeight, minLineHeight))
        textDelegate.resizeParentViewToHeight(heightOfText)
    }
    
    func setupDefaultView() {
        
    }
    
}

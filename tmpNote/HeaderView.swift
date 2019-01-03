//
//  HeaderView.swift
//  tmpNote
//
//  Created by BUDDAx2 on 1/3/19.
//  Copyright © 2019 BUDDAx2. All rights reserved.
//

import Cocoa

class HeaderView: NSView {
    
    var onMouseEnteredClosure: (()->())?
    var onMouseExitedClosure: (()->())?
    
    override func awakeFromNib() {
        self.backgroundColor = .clear
        addTrackingArea(NSTrackingArea(rect: bounds, options: [.activeAlways, .mouseEnteredAndExited], owner: self, userInfo: nil))
    }
    
    override func layout() {
        super.layout()
        
        self.trackingAreas.forEach { [weak self] area in
            self?.removeTrackingArea(area)
        }
        
        addTrackingArea(NSTrackingArea(rect: bounds, options: [.activeAlways, .mouseEnteredAndExited], owner: self, userInfo: nil))
    }
    
    override func mouseEntered(with event: NSEvent) {
        onMouseEnteredClosure?()
    }
    
    override func mouseExited(with event: NSEvent) {
        onMouseExitedClosure?()
    }
    
}


extension NSView {
    
    var backgroundColor: NSColor? {
        
        get {
            if let colorRef = self.layer?.backgroundColor {
                return NSColor(cgColor: colorRef)
            } else {
                return nil
            }
        }
        
        set {
            self.wantsLayer = true
            self.layer?.backgroundColor = newValue?.cgColor
        }
    }
}

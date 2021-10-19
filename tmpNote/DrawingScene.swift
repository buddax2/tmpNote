//
//  DrawingScene.swift
//  tmpNote
//
//  Created by BUDDAx2 on 1/2/19.
//  Copyright © 2019 BUDDAx2. All rights reserved.
//

import SpriteKit
import Carbon.HIToolbox

class DrawingScene: SKScene {
    
    var storage: StorageDataSource?
    var firstPoint: CGPoint?
    weak var mainController: TmpNoteViewController!
    var lineNode = SKShapeNode()
    var pathToDraw: CGMutablePath?
    var redoArray = [SKShapeNode]()
    
    var contentDidChangeCallback: (()->Void)?
    
    override func mouseDown(with event: NSEvent) {
        firstPoint = event.location(in: self)
        pathToDraw = CGMutablePath()
    }
    
    override func mouseDragged(with event: NSEvent) {
        let positionInScene = event.location(in: self)
        
        lineNode.removeFromParent()
        if let fp = firstPoint {
            pathToDraw?.move(to: CGPoint(x: fp.x, y: fp.y))
        }
        pathToDraw?.addLine(to: CGPoint(x: positionInScene.x, y: positionInScene.y))
        lineNode.path = pathToDraw
        lineNode.strokeColor = .textColor
        addChild(lineNode)
        firstPoint = positionInScene
    }

    override func mouseUp(with event: NSEvent) {
        if let path = pathToDraw {
            lineNode.removeFromParent()
            let newLine = SKShapeNode(path: path)
            newLine.strokeColor = .textColor
            addChild(newLine)
            mainController.lines.append(newLine)
        }
        
        contentDidChangeCallback?()
    }
    
    func clear() {
        mainController.lines.forEach { line in
            line.removeFromParent()
        }
        mainController.lines.removeAll()
        pathToDraw = nil
    }
    
    func load() {
        pathToDraw = CGMutablePath()

        for line in mainController.lines {
            line.removeFromParent()
            addChild(line)
        }
    }
    
    func undo() {
        if let lastLine = mainController.lines.last {
            redoArray.append(lastLine)
            lastLine.removeFromParent()
            mainController.lines.removeLast()
        }
    }
    
    func redo() {
        if let lastLine = redoArray.last {
            addChild(lastLine)
            mainController.lines.append(lastLine)
            redoArray.removeLast()
        }
    }
}

extension DrawingScene {
    
    override func keyDown(with event: NSEvent) {
        
        // ⌘S - Save content
        if event.modifierFlags.contains(.command) && event.keyCode == kVK_ANSI_S {
            DatasourceController.shared.saveSketch(newSketch: mainController.lines)
        }

        if event.keyCode == kVK_ANSI_Z {
            // ⌘⇧Z - Redo
            if event.modifierFlags.contains(.command) && event.modifierFlags.contains(.shift) {
                redo()
            }
            // ⌘Z - Undo
            else if event.modifierFlags.contains(.command) {
                undo()
            }
        }

        super.keyDown(with: event)
    }
}

//
//  DrawingScene.swift
//  tmpNote
//
//  Created by BUDDAx2 on 1/2/19.
//  Copyright © 2019 BUDDAx2. All rights reserved.
//

import SpriteKit

class DrawingScene: SKScene {
    
    static let saveKey = "PreviousSessionSketch"
    
    var firstPoint: CGPoint?
    weak var mainController: TmpNoteViewController!
    var lineNode = SKShapeNode()
    var pathToDraw: CGMutablePath?
    
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
            addChild(line)
        }
    }
}

//
//  DrawingScene.swift
//  tmpNote
//
//  Created by BUDDAx2 on 1/2/19.
//  Copyright © 2019 BUDDAx2. All rights reserved.
//

import SpriteKit

class DrawingScene: SKScene {
    
    var firstPoint: CGPoint?
    var lines = [SKShapeNode]()
    var lineNode = SKShapeNode()
    var pathToDraw: CGMutablePath?
    
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
            lines.append(newLine)
        }
    }
    
    func clear() {
        lines.forEach { line in
            line.removeFromParent()
        }
        pathToDraw = nil
    }
}

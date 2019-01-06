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
        lines.removeAll()
        pathToDraw = nil
    }
    
    func save() {
        let paths:[CGPath] = lines.compactMap { $0.path }
        
        var encodedLines = [Data]()
        for path in paths {
            let bp = NSBezierPath()
            
            let points:[CGPoint] = path.getPathElementsPoints()
            if points.count > 0 {
                
                bp.move(to: points.first!)
                for i in 1..<points.count {
                    bp.line(to: points[i])
                }
                
                let arch = NSKeyedArchiver.archivedData(withRootObject: bp)
                encodedLines.append(arch)
            }
        }
        
        UserDefaults.standard.set(encodedLines, forKey: DrawingScene.saveKey)
    }
    
    func load() {
        if let encodedLines = UserDefaults.standard.value(forKey: DrawingScene.saveKey) as? [Data] {
            pathToDraw = CGMutablePath()
            for data in encodedLines {
                if let bp = NSKeyedUnarchiver.unarchiveObject(with: data) as? NSBezierPath {
                    let path = bp.cgPath
                    let newLine = SKShapeNode(path: path)
                    newLine.strokeColor = .textColor
                    addChild(newLine)
                    lines.append(newLine)
                }
            }
        }
    }
}

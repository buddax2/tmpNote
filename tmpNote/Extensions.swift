//
//  Extensions.swift
//  tmpNote
//
//  Created by BUDDAx2 on 1/6/19.
//  Copyright © 2019 BUDDAx2. All rights reserved.
//

import Cocoa

extension CGPath {
    func forEach( body: @escaping @convention(block) (CGPathElement) -> Void) {
        typealias Body = @convention(block) (CGPathElement) -> Void
        let callback: @convention(c) (UnsafeMutableRawPointer, UnsafePointer<CGPathElement>) -> Void = { (info, element) in
            let body = unsafeBitCast(info, to: Body.self)
            body(element.pointee)
        }

        let unsafeBody = unsafeBitCast(body, to: UnsafeMutableRawPointer.self)
        self.apply(info: unsafeBody, function: unsafeBitCast(callback, to: CGPathApplierFunction.self))
    }
    func getPathElementsPoints() -> [CGPoint] {
        var arrayPoints : [CGPoint]! = [CGPoint]()
        self.forEach { element in
            switch (element.type) {
            case CGPathElementType.moveToPoint:
                arrayPoints.append(element.points[0])
            case .addLineToPoint:
                arrayPoints.append(element.points[0])
            case .addQuadCurveToPoint:
                arrayPoints.append(element.points[0])
                arrayPoints.append(element.points[1])
            case .addCurveToPoint:
                arrayPoints.append(element.points[0])
                arrayPoints.append(element.points[1])
                arrayPoints.append(element.points[2])
            default: break
            }
        }
        return arrayPoints
    }
    func getPathElementsPointsAndTypes() -> ([CGPoint],[CGPathElementType]) {
        var arrayPoints : [CGPoint]! = [CGPoint]()
        var arrayTypes : [CGPathElementType]! = [CGPathElementType]()
        self.forEach { element in
            switch (element.type) {
            case CGPathElementType.moveToPoint:
                arrayPoints.append(element.points[0])
                arrayTypes.append(element.type)
            case .addLineToPoint:
                arrayPoints.append(element.points[0])
                arrayTypes.append(element.type)
            case .addQuadCurveToPoint:
                arrayPoints.append(element.points[0])
                arrayPoints.append(element.points[1])
                arrayTypes.append(element.type)
                arrayTypes.append(element.type)
            case .addCurveToPoint:
                arrayPoints.append(element.points[0])
                arrayPoints.append(element.points[1])
                arrayPoints.append(element.points[2])
                arrayTypes.append(element.type)
                arrayTypes.append(element.type)
                arrayTypes.append(element.type)
            default: break
            }
        }
        return (arrayPoints,arrayTypes)
    }
}

// Taken from here: https://gist.github.com/juliensagot/9749c3a1df28c38fb9f9
// But I removed forced closing NSBezierPath 
extension NSBezierPath {
    
    var cgPath: CGPath {
        get { return self.transformToCGPath() }
    }
    
    /// Transforms the NSBezierPath into a CGPath
    ///
    /// :returns: The transformed NSBezierPath
    private func transformToCGPath() -> CGPath {
        
        // Create path
        let path = CGMutablePath()
        let points = UnsafeMutablePointer<NSPoint>.allocate(capacity: 3)
        let numElements = self.elementCount
        
        if numElements > 0 {
            
            for index in 0..<numElements {
                
                let pathType = self.element(at: index, associatedPoints: points)
                
                switch pathType {
                case .moveToBezierPathElement:
                    path.move(to: CGPoint(x: points[0].x, y: points[0].y))
                case .lineToBezierPathElement:
                    path.addLine(to: CGPoint(x: points[0].x, y: points[0].y))
                case .curveToBezierPathElement:
                    path.addCurve(to: CGPoint(x: points[0].x, y: points[0].y), control1: CGPoint(x: points[1].x, y: points[1].y), control2: CGPoint(x: points[2].x, y: points[2].y))
                case .closePathBezierPathElement:
                    path.closeSubpath()
                }
            }
        }
        
        points.deallocate()
        return path
    }
}

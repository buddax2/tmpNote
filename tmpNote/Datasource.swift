//
//  Datasource.swift
//  tmpNote
//
//  Created by Oleksandr Yakubchyk on 10.10.2021.
//  Copyright © 2021 BUDDAx2. All rights reserved.
//

import Foundation
import Combine
import SpriteKit

protocol DatasourceDelegate {
    
}

class DatasourceController: ObservableObject {
    
    static let shared = DatasourceController()
    var context: NSManagedObjectContext {
        let ctx = (NSApplication.shared.delegate as! AppDelegate).persistentContainer.viewContext
        return ctx
    }
    
    var isLocked: Bool = UserDefaults.standard.bool(forKey: DatasourceKey.isLockedKey.rawValue)
    var currentViewIndex: Int = 0
    @Published var currentMode: Mode = .text
    @Published var content: String = ""
    @Published var lines = [SKShapeNode]()

    private var loadNoteSubscriber: AnyCancellable?
    private var loadSketchSubscriber: AnyCancellable?
    
    private lazy var loadNoteSubject = PassthroughSubject<String, Never>()
    lazy var doLoadNoteSubject = loadNoteSubject.eraseToAnyPublisher()

    private lazy var loadSketchSubject = PassthroughSubject<[SKShapeNode], Never>()
    lazy var doLoadSketchSubject = loadNoteSubject.eraseToAnyPublisher()

    
    func load() {
        let prevModeRaw = UserDefaults.standard.integer(forKey: DatasourceKey.previousSessionModeKey.rawValue)
        currentMode = Mode(rawValue: prevModeRaw) ?? .text
        currentViewIndex = UserDefaults.standard.integer(forKey: DatasourceKey.previousViewIndex.rawValue)
        isLocked = UserDefaults.standard.bool(forKey: DatasourceKey.isLockedKey.rawValue)
        
        load(index: currentViewIndex)
    }
    
    func save() {
        UserDefaults.standard.set(currentMode.rawValue, forKey: DatasourceKey.previousSessionModeKey.rawValue)
        UserDefaults.standard.set(currentViewIndex, forKey: DatasourceKey.previousViewIndex.rawValue)
        UserDefaults.standard.set(isLocked, forKey: DatasourceKey.isLockedKey.rawValue)
        

        save(index: currentViewIndex)
    }
    
    func load(index: Int) {
        
        currentViewIndex = index
        
        let request = NoteView.fetchRequest()
        request.predicate = NSPredicate(format: "id = %d", index)

        do {
            let ent = try context.fetch(request).first

            let text = ent?.note ?? ""
            self.content = text
            if let sketch = ent?.sketch {
                let lines = getSketch(sketch)
                self.lines = lines
            }
            else {
                self.lines = []
            }

        } catch {
            debugPrint(error)
        }
    }
    
    func save(index: Int) {
        let request = NoteView.fetchRequest()
        request.predicate = NSPredicate(format: "id = %d", index)

        do {
            let ent = try context.fetch(request).first
            
            ent?.note = content
            ent?.sketch = getData(lines)
            
            ent?.lastModified = Date()
            
            do {
                try context.save()
            } catch {
                debugPrint(error.localizedDescription)
            }

        } catch {
            debugPrint(error.localizedDescription)
        }
    }
    
    func getData(_ lines: [SKShapeNode]) -> Data? {
        let paths:[CGPath] = lines.compactMap { $0.path }
        guard !paths.isEmpty else { return nil }
        
        var encodedLines = [Data]()
        for path in paths {
            let bp = NSBezierPath()
            
            let points:[CGPoint] = path.getPathElementsPoints()
            if points.count > 0 {
                
                bp.move(to: points.first!)
                for i in 1..<points.count {
                    bp.line(to: points[i])
                }
                
                if let arch = try? NSKeyedArchiver.archivedData(withRootObject: bp, requiringSecureCoding: true) {
                    encodedLines.append(arch)
                }
            }
        }
        
        let resultData = try? NSKeyedArchiver.archivedData(withRootObject: encodedLines, requiringSecureCoding: true)

        return resultData
    }
    
    func getSketch(_ data: Data) -> [SKShapeNode] {
        guard let nsArray = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSArray.self, from: data as Data) else {
            return []
        }
                      
        guard let encodedLines = nsArray as? Array<Data> else {
            return []
        }
        
        var lines = [SKShapeNode]()

        for data in encodedLines {
            if let bp = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSBezierPath.self, from: data) {
                let path = bp.cgPath
                let newLine = SKShapeNode(path: path)
                newLine.strokeColor = .textColor
                lines.append(newLine)
            }
        }

        return lines
    }
}


enum StorageError: Error {
    case failedToReadFile
    case encoding
    case defaultError(_ message: String)
}


enum DatasourceKey: String {
    case previousSessionModeKey = "PreviousMode"
    case previousViewIndex = "SelectedViewIndex"
    case isLockedKey = "locked"
}

enum Mode: Int {
    case text
    case markdown
    case sketch
}

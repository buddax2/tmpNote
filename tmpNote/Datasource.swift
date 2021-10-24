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
    
    let datasource = Datasource()
    
    var isLocked: Bool = UserDefaults.standard.bool(forKey: DatasourceKey.isLockedKey.rawValue)
    @Published var currentViewIndex: Int = 0
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
        
        loadNote()
        loadSketch()
    }
    
    func save() {
        UserDefaults.standard.set(currentMode.rawValue, forKey: DatasourceKey.previousSessionModeKey.rawValue)
        UserDefaults.standard.set(currentViewIndex, forKey: DatasourceKey.previousViewIndex.rawValue)
        UserDefaults.standard.set(isLocked, forKey: DatasourceKey.isLockedKey.rawValue)
        
        saveText()
        saveSketch()
    }
    
    func loadNote() {
        loadNoteSubscriber = datasource.loadText(viewIndex: currentViewIndex)
            .receive(on: DispatchQueue.main)
            .sink { _ in } receiveValue: { [weak self] savedText in
                self?.content = savedText
                self?.loadNoteSubject.send(savedText)
            }
    }
    
    func loadSketch() {
        loadSketchSubscriber = datasource.loadSketch()
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { _ in }, receiveValue: { [weak self] savedLines in
                self?.lines = savedLines
                self?.loadSketchSubject.send(savedLines)
            })
    }
    
    func saveText(newContent: String? = nil) {
        
        let contentToSave: String = newContent ?? content
        
        _ = datasource.saveText(content: contentToSave, viewIndex: currentViewIndex).sink { result in
            switch result {
            case .finished:
                debugPrint("Saved text")
            case .failure(let err):
                debugPrint(err.localizedDescription)
            }
        } receiveValue: { isSaved in
            debugPrint("Saved text: \(isSaved)")
        }
    }
    
    func saveSketch(newSketch: [SKShapeNode]? = nil) {
        let sketchToSave: [SKShapeNode] = newSketch ?? lines
        
        _ = datasource.saveSketch(lines: sketchToSave).sink(receiveCompletion: { result in
            switch result {
            case .finished:
                debugPrint("Saved sketch")
            case .failure(let err):
                debugPrint(err.localizedDescription)
            }
        }, receiveValue: { isSaved in
            debugPrint("Saved sketch: \(isSaved)")
        })
    }
}

class Datasource {
    
    static var containerUrl: URL? {
        return FileManager.default.url(forUbiquityContainerIdentifier: nil)?.appendingPathComponent("Documents")
    }

    static func localFileURL(name: String, extensionStr: String) -> URL? {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths.first?.appendingPathComponent(name).appendingPathExtension(extensionStr)
    }

    static func remoteFileURL(name: String, extensionStr: String) -> URL? {
        return Self.containerUrl?.appendingPathComponent(name).appendingPathExtension(extensionStr)
    }
    
    static func defaultTextFileURL(viewIndex: Int) -> URL? {
        let fileName = "defaultContainer_\(viewIndex)"
        let fileExtension = "txt"
        
        if UserDefaults.standard.bool(forKey: "SynchronizeContent") == true {
            if let url = Self.remoteFileURL(name: fileName, extensionStr: fileExtension) {
                return url
            }
        }
        
        return Self.localFileURL(name: fileName, extensionStr: fileExtension)
    }

    static var defaultSketchFileURL: URL? {
        let fileName = "defaultSketch"
        let fileExtension = "tmpSketch"
        
        if UserDefaults.standard.bool(forKey: "SynchronizeContent") == true {
            if let url = Self.remoteFileURL(name: fileName, extensionStr: fileExtension) {
                return url
            }
        }
        
        return Self.localFileURL(name: fileName, extensionStr: fileExtension)
    }
}
protocol StorageDataSource {
    func saveText(content: String, viewIndex: Int) -> Future<Bool, Error>
    func saveSketch(lines: [SKShapeNode]) -> Future<Bool, Error>
    func loadText(viewIndex: Int) -> AnyPublisher<String, Error>
    func loadSketch() -> AnyPublisher<[SKShapeNode], Error>
}

enum StorageError: Error {
    case failedToReadFile
    case encoding
    case defaultError(_ message: String)
}

extension Datasource: StorageDataSource {
    func loadText(viewIndex: Int) -> AnyPublisher<String, Error> {
        Future<String, Error> { promise in
            
            if let url = Self.defaultTextFileURL(viewIndex: viewIndex), let txt = try? String(contentsOf: url) {
                promise(.success(txt))
            }
            else {
                promise(.failure(StorageError.failedToReadFile))
            }
        }.eraseToAnyPublisher()
    }
    
    func loadSketch() -> AnyPublisher<[SKShapeNode], Error> {
        Future<[SKShapeNode], Error> { promise in
            if let url = Self.defaultSketchFileURL, let data = try? Data(contentsOf: url) {
                
                guard let nsArray = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSArray.self, from: data as Data) else {
                    return promise(.failure(StorageError.encoding))
                }
                              
                guard let encodedLines = nsArray as? Array<Data> else {
                    return promise(.failure(StorageError.encoding))
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
                
                promise(.success(lines))
            }
            else {
                promise(.failure(StorageError.failedToReadFile))
            }
        }.eraseToAnyPublisher()
    }
    
    func saveText(content: String, viewIndex: Int) -> Future<Bool, Error> {
        Future<Bool, Error> { promise in
            _ = self.loadText(viewIndex: viewIndex).sink { result in
                switch result {
                    case .finished:
                        print("OK")
                    case .failure(let err):
                        return promise(.failure(err))
                }
            } receiveValue: { savedText in
                if savedText == content {
                    return promise(.success(false))
                }

                guard let url = Self.defaultTextFileURL(viewIndex: viewIndex) else {
                    return promise(.failure(StorageError.defaultError("Failed to read file")))
                }

                do {
                    try content.write(to: url, atomically: true, encoding: .utf8)
                    promise(.success(true))
                } catch {
                    return promise(.failure(StorageError.defaultError("Failed to write to file")))
                }
            }
        }
    }
    
    func saveSketch(lines: [SKShapeNode]) -> Future<Bool, Error> {
        Future<Bool, Error> { promise in
            _ = self.loadSketch().sink(receiveCompletion: { result in
                switch result {
                    case .finished:
                        print("OK")
                    case .failure(let err):
                        return promise(.failure(err))
                }
            }, receiveValue: { savedLines in
                let paths:[CGPath] = lines.compactMap { $0.path }
                
                if paths == savedLines.compactMap({ $0.path }) {
                    return promise(.success(false))
                }
                
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
                
                if let url = Self.defaultSketchFileURL, let resultData = try? NSKeyedArchiver.archivedData(withRootObject: encodedLines, requiringSecureCoding: true) {

                    do {
                        try resultData.write(to: url)
                        promise(.success(true))
                    }
                    catch {
                        promise(.failure(StorageError.defaultError("Failed to write file")))
                    }
                }
                else {
                    promise(.failure(StorageError.encoding))
                }


            })
        }
    }
    
//    func load() {
////        loadSubstitutions()
//
//        Self.loadText(viewIndex: currentViewIndex) { [weak self] (savedText) in
//            content = savedText
//        }
//
//        Self.loadSketch() { [weak self] savedLines in
//            self?.lines = savedLines
//        }
//
////        setupViewButtons()
//    }
//
//    func save() {
//        Self.saveTextIfChanged(note: content, viewIndex: currentViewIndex, completion: nil)
//        Self.saveSketchIfChanged(lines: lines, completion: nil)
//
//        UserDefaults.standard.set(currentMode.rawValue, forKey: DatasourceKey.previousSessionModeKey.rawValue)
//
////        saveSubstitutions()
//    }
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

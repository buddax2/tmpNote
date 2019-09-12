//
//  List.swift
//  tmpNote
//
//  Created by Oleksandr Yakubchyk on 9/10/19.
//  Copyright © 2019 BUDDAx2. All rights reserved.
//

import Foundation

class List : NSObject, Codable {
    @objc dynamic var title:String
    var note:String
    var id = 0
    
    convenience required init(id: Int, title: String, note: String) {
        self.init()
        
        self.id = id
        self.note = note
        self.title = title
    }
    
    func copy(with zone: NSZone? = nil) -> Any {
        return type(of:self).init(id: self.id, title: self.title, note: self.note)
    }
    
    override init() {
        title = "title"
        note = "note"
        super.init()
    }
}

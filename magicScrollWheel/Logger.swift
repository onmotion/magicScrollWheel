//
//  Logger.swift
//  magicScrollWheel
//
//  Created by Aleksandr Kozhevnikov on 29/09/2019.
//  Copyright © 2019 Aleksandr Kozhevnikov. All rights reserved.
//

import Foundation

public func print(_ items: String..., filename: String = #file, function : String = #function, line: Int = #line, separator: String = " ", terminator: String = "\n") {
    Logger.log(items)
}
public func print(_ items: Any..., filename: String = #file, function : String = #function, line: Int = #line, separator: String = " ", terminator: String = "\n") {
    Logger.log(items)
}
public func print(_ items: Any...) {
    Logger.log(items)
}
public func print(_ items: Any..., separator: String = " ", terminator: String = "\n") {
    Logger.log(items)
}

/// Disable print() in production mode
class Logger {
    
    static let enabled = { () -> Bool in
        #if DEBUG
            return true
        #else
            return false
        #endif
    }()
    
    public static func log(_ items: [Any]) {
        if self.enabled {
            let stringItem = items.map{"\($0)"}.joined(separator: ", ")
            Swift.print("\(stringItem)", terminator: "\n")
        }
    }
}

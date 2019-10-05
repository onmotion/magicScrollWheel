//
//  EventMonitorDelegate.swift
//  magicScrollWheel
//
//  Created by Aleksandr Kozhevnikov on 05/10/2019.
//  Copyright © 2019 Aleksandr Kozhevnikov. All rights reserved.
//

import Foundation

protocol EventMonitorDelegate {
    func systemScrollEventHandler(event: CGEvent)
    func mouseMoveEventHandler(event: CGEvent)
}

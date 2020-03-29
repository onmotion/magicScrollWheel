//
//  DecimalNumberFormatter.swift
//  magicScrollWheel
//
//  Created by Aleksandr Kozhevnikov on 15.03.2020.
//  Copyright © 2020 Aleksandr Kozhevnikov. All rights reserved.
//

import Cocoa

class DecimalNumberFormatter: NumberFormatter {
   
    required init?(coder aDecoder: NSCoder) {
       super.init(coder: aDecoder)
    }
    
    override func awakeFromNib() {
       super.awakeFromNib()
        self.decimalSeparator = "."
       //custom logic goes here
    }
}

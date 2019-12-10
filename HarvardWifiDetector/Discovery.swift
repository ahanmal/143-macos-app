//
//  Discovery.swift
//  HarvardWifiDetector
//
//  Created by Ahan Malhotra on 12/4/19.
//  Copyright © 2019 Random Widgets Inc. All rights reserved.
//

import Foundation
import CoreWLAN

class Discovery {

    var currentInterface: CWInterface
    var interfacesNames: [String] = []
    var networks: Set<CWNetwork> = []

    // Failable init using default interface
    init?() {
        if let defaultInterface = CWWiFiClient.shared().interface(),
            let name = defaultInterface.interfaceName {
            self.currentInterface = defaultInterface
            self.interfacesNames.append(name)
            self.findNetworks()
        } else {
            return nil
        }
    }

    // Fetch detectable WIFI networks
   func findNetworks() {
        do {
            self.networks = try currentInterface.scanForNetworks(withSSID: nil)
        } catch let error as NSError {
            print("Error: \(error.localizedDescription)")
        }
    }

}

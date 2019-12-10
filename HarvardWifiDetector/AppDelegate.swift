//
//  AppDelegate.swift
//  HarvardWifiDetector
//
//  Created by Ahan Malhotra on 11/18/19.
//  Copyright © 2019 Random Widgets Inc. All rights reserved.
//

import Cocoa
import SwiftUI
import CoreWLAN
import CoreLocation
import Foundation
import SwiftyJSON
import Alamofire

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate, CLLocationManagerDelegate {
    
    var window: NSWindow!
    let locationManager = CLLocationManager()
    let statusItem = NSStatusBar.system.statusItem(withLength:NSStatusItem.squareLength)
    var ingestTimer: Timer?
    
    
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        
        handleIngest()
        
        ingestTimer = Timer.scheduledTimer(timeInterval: 300, target: self, selector: #selector(handleIngest), userInfo: nil, repeats: true)
        
        
        if let button = statusItem.button {
            button.title = "🐠"
        }
        
        let statusBarMenu = NSMenu(title: "Status Bar Menu")
        statusItem.menu = statusBarMenu
        
        statusBarMenu.addItem(
            withTitle: "Run",
            action: #selector(AppDelegate.handleIngest),
            keyEquivalent: "")
        
        statusBarMenu.addItem(
            withTitle: "Quit",
            action: #selector(AppDelegate.handleQuit),
            keyEquivalent: ""
        )
        
    }
    
    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }
    

    @objc func handleQuit() {
        NSApplication.shared.terminate(self)
    }
    
    @objc func handleIngest() {
        
        locationManager.requestAlwaysAuthorization()
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.startUpdatingLocation()
        
        guard let discovery = Discovery() else {
            print("Oops. Discovery is nil for some reason.")
            return
        }
        
        if discovery.currentInterface.ssid() != "Harvard Secure" {
            return
        }
        
        let (success, dlMbps, ulMbps) = runIperf()
        
        if !success {
            return
        }
        
        let body : [String : Any] = [
            "uuid": discovery.currentInterface.hardwareAddress() ?? "xyz",
            "ingest_time": ISO8601DateFormatter().string(from: Date()),
            "upload_speed": ulMbps,
            "download_speed": dlMbps,
            "tx_rate": discovery.currentInterface.transmitRate(),
            "lat": locationManager.location?.coordinate.latitude ?? 0.0,
            "lon": locationManager.location?.coordinate.longitude ?? 0.0,
            "bssid": discovery.currentInterface.bssid() ?? "",
            "noise_measure": discovery.currentInterface.noiseMeasurement(),
            "rssi": discovery.currentInterface.rssiValue()
        ]
        
        AF.request("https://flask-143.herokuapp.com/ingest",
                   method: .post,
                   parameters: body,
                   encoding: JSONEncoding.default)
            .responseJSON { response in
                print("Successfully Posted!")
        }
          
        
        locationManager.stopUpdatingLocation()
        
    }
    
    func runIperf() -> (Bool, Decimal, Decimal) {
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/local/bin/iperf3")
        process.arguments = ["-c", "speedtest.serverius.net", "-J", "-p", "5002", "-P", "10"]
        
        let outPipe = Pipe()
        process.standardOutput = outPipe
        
        do {
            try process.run()
        } catch let error {
            print("Something went wrong with running IPerf.")
            print(error.localizedDescription)
        }
        
        guard let output = String(data: outPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) else {
            print("No output from iper3")
            return (false, 0, 0)
        }
        
        if output.contains("error") {
            print("Iperf Server Busy")
            return (false, 0, 0)
        }
        
        let json = JSON(parseJSON: output)
        
        let downloadBandwith = json["end"]["sum_sent"]["bits_per_second"].numberValue
        let uploadBandwith = json["end"]["sum_received"]["bits_per_second"].numberValue
        
        let downloadMbps = downloadBandwith.decimalValue / pow(10, 6)
        let uploadMbps = uploadBandwith.decimalValue / pow(10, 6)
        
        return (true, downloadMbps, uploadMbps)
    }
    
    
    
    
}


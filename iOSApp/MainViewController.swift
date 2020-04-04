/*
    Copyright (C) 2016 Apple Inc. All Rights Reserved.
    See LICENSE.txt for this sample’s licensing information
    
    Abstract:
    A view controller for testing SimplePing on iOS.
 */

import UIKit

class MainViewController: UITableViewController, SimplePingDelegate {

    let hostName = "www.apple.com"
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = self.hostName
    }

    var pinger: SimplePing?
    var sendTimer: NSTimer?
    
    /// Called by the table view selection delegate callback to start the ping.
    
    func start(forceIPv4 forceIPv4: Bool, forceIPv6: Bool) {
        self.pingerWillStart()

        NSLog("start")

        let pinger = SimplePing(hostName: self.hostName)
        self.pinger = pinger

        // By default we use the first IP address we get back from host resolution (.Any) 
        // but these flags let the user override that.
            
        if (forceIPv4 && !forceIPv6) {
            pinger.addressStyle = .ICMPv4
        } else if (forceIPv6 && !forceIPv4) {
            pinger.addressStyle = .ICMPv6
        }

        pinger.delegate = self
        pinger.start()
    }

    /// Called by the table view selection delegate callback to stop the ping.
    
    func stop() {
        NSLog("stop")
        self.pinger?.stop()
        self.pinger = nil

        self.sendTimer?.invalidate()
        self.sendTimer = nil
        
        self.pingerDidStop()
    }

    /// Sends a ping.
    ///
    /// Called to send a ping, both directly (as soon as the SimplePing object starts up) and 
    /// via a timer (to continue sending pings periodically).
    
    func sendPing() {
        self.pinger!.sendPingWithData(nil)
    }

    // MARK: pinger delegate callback
    
    func simplePing(pinger: SimplePing, didStartWithAddress address: NSData) {
        NSLog("pinging %@", MainViewController.displayAddressForAddress(address))
        
        // Send the first ping straight away.
        
        self.sendPing()

        // And start a timer to send the subsequent pings.
        
        assert(self.sendTimer == nil)
        self.sendTimer = NSTimer.scheduledTimerWithTimeInterval(1.0, target: self, selector: #selector(MainViewController.sendPing), userInfo: nil, repeats: true)
    }
    
    func simplePing(pinger: SimplePing, didFailWithError error: NSError) {
        NSLog("failed: %@", MainViewController.shortErrorFromError(error))
        
        self.stop()
    }
    
    func simplePing(pinger: SimplePing, didSendPacket packet: NSData, sequenceNumber: UInt16) {
        NSLog("#%u sent", sequenceNumber)
    }
    
    func simplePing(pinger: SimplePing, didFailToSendPacket packet: NSData, sequenceNumber: UInt16, error: NSError) {
        NSLog("#%u send failed: %@", sequenceNumber, MainViewController.shortErrorFromError(error))
    }
    
    func simplePing(pinger: SimplePing, didReceivePingResponsePacket packet: NSData, sequenceNumber: UInt16) {
        NSLog("#%u received, size=%zu", sequenceNumber, packet.length)
    }
    
    func simplePing(pinger: SimplePing, didReceiveUnexpectedPacket packet: NSData) {
        NSLog("unexpected packet, size=%zu", packet.length)
    }
    
    // MARK: utilities
    
    /// Returns the string representation of the supplied address.
    ///
    /// - parameter address: Contains a `(struct sockaddr)` with the address to render.
    ///
    /// - returns: A string representation of that address.

    static func displayAddressForAddress(address: NSData) -> String {
        var hostStr = [Int8](count: Int(NI_MAXHOST), repeatedValue: 0)
        
        let success = getnameinfo(
            UnsafePointer(address.bytes), 
            socklen_t(address.length), 
            &hostStr, 
            socklen_t(hostStr.count), 
            nil, 
            0, 
            NI_NUMERICHOST
        ) == 0
        let result: String
        if success {
            result = String.fromCString(hostStr)!
        } else {
            result = "?"
        }
        return result
    }

    /// Returns a short error string for the supplied error.
    ///
    /// - parameter error: The error to render.
    ///
    /// - returns: A short string representing that error.

    static func shortErrorFromError(error: NSError) -> String {
        if error.domain == kCFErrorDomainCFNetwork as String && error.code == Int(CFNetworkErrors.CFHostErrorUnknown.rawValue) {
            if let failureObj = error.userInfo[kCFGetAddrInfoFailureKey] {
                if let failureNum = failureObj as? NSNumber {
                    if failureNum.intValue != 0 {
                        let f = gai_strerror(failureNum.intValue)
                        if f != nil {
                            return String.fromCString(f)!
                        }
                    }
                }
            }
        }
        if let result = error.localizedFailureReason {
            return result
        }
        return error.localizedDescription
    }
    
    // MARK: table view delegate callback
    
    @IBOutlet var forceIPv4Cell: UITableViewCell!
    @IBOutlet var forceIPv6Cell: UITableViewCell!
    @IBOutlet var startStopCell: UITableViewCell!

    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        let cell = self.tableView.cellForRowAtIndexPath(indexPath)!
        switch cell {
        case forceIPv4Cell, forceIPv6Cell:
            cell.accessoryType = cell.accessoryType == .None ? .Checkmark : .None
        case startStopCell:
            if self.pinger == nil {
                let forceIPv4 = self.forceIPv4Cell.accessoryType != .None
                let forceIPv6 = self.forceIPv6Cell.accessoryType != .None
                self.start(forceIPv4: forceIPv4, forceIPv6: forceIPv6)
            } else {
                self.stop()
            }
        default:
            fatalError()
        }
        self.tableView.deselectRowAtIndexPath(indexPath, animated: true)
    }

    func pingerWillStart() {
        self.startStopCell.textLabel!.text = "Stop…"
    }
    
    func pingerDidStop() {
        self.startStopCell.textLabel!.text = "Start…"
    }
}

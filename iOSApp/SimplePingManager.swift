//
//  SimplePingManager.swift
//  iOSApp
//
//  Created by Robert Ryan on 4/4/20.
//

import Foundation

class SimplePingManager: NSObject {
    enum SimplePingResponse {
        case start(String)
        case sendFailed(Data, UInt16, Error)
        case sent(Data, UInt16)
        case received(Data, UInt16)
        case unexpectedPacket(Data)
        case failed(Error)
    }

    typealias SimplePingHandler = (SimplePingResponse) -> Void

    private var pinger: SimplePing?
    private var handler: SimplePingHandler?
    private weak var sendTimer: Timer?

    var isStarted: Bool { return pinger != nil }
    var nextSequenceNumber: Int? { (pinger?.nextSequenceNumber).flatMap { Int($0) } }
}

// MARK: Public interface

extension SimplePingManager {
    /// Called by the table view selection delegate callback to start the ping.

    func start(hostName: String, forceIPv4: Bool = false, forceIPv6: Bool = false, handler: @escaping SimplePingHandler) {
        self.handler = handler
        pinger = SimplePing(hostName: hostName)

        // By default we use the first IP address we get back from host resolution (.Any)
        // but these flags let the user override that.

        if (forceIPv4 && !forceIPv6) {
            pinger?.addressStyle = .icmPv4
        } else if (forceIPv6 && !forceIPv4) {
            pinger?.addressStyle = .icmPv6
        }

        pinger?.delegate = self
        pinger?.start()
    }

    /// Called by the table view selection delegate callback to stop the ping.

    func stop() {
        pinger?.stop()
        pinger = nil

        sendTimer?.invalidate()

        handler = nil
    }
}

// MARK: - private utility methods

private extension SimplePingManager {
    /// Sends a ping.
    ///
    /// Called to send a ping, both directly (as soon as the SimplePing object starts up) and
    /// via a timer (to continue sending pings periodically).

    func sendPing() {
        pinger!.send(with: nil)
    }

    func startTimer() {
        sendTimer?.invalidate()
        sendTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] timer in
            if self == nil {
                timer.invalidate()
            } else {
                self?.sendPing()
            }
        }
        sendTimer?.fire()
    }

    /// Returns the string representation of the supplied address.
    ///
    /// - parameter address: Contains a `(struct sockaddr)` with the address to render.
    ///
    /// - returns: A string representation of that address.

    func stringRepresentation(forAddress address: Data) -> String {
        var hostStr = [Int8](repeating: 0, count: Int(NI_MAXHOST))

        let result = address.withUnsafeBytes { pointer in
            getnameinfo(
                pointer.baseAddress?.assumingMemoryBound(to: sockaddr.self),
                socklen_t(address.count),
                &hostStr,
                socklen_t(hostStr.count),
                nil,
                0,
                NI_NUMERICHOST
            )
        }
        return result == 0 ? String(cString: hostStr) : "?"
    }

    /// Returns a short error string for the supplied error.
    ///
    /// - parameter error: The error to render.
    ///
    /// - returns: A short string representing that error.

    func shortErrorFromError(error: Error) -> String {
        let error = error as NSError
        if error.domain == kCFErrorDomainCFNetwork as String && error.code == Int(CFNetworkErrors.cfHostErrorUnknown.rawValue) {
            if let failureObj = error.userInfo[kCFGetAddrInfoFailureKey as String] {
                if let failureNum = failureObj as? NSNumber {
                    if failureNum.intValue != 0 {
                        if let f = gai_strerror(failureNum.int32Value) {
                            return String(cString: f)
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
}

// MARK: pinger delegate callback

extension SimplePingManager: SimplePingDelegate {
    func simplePing(_ pinger: SimplePing, didStartWithAddress address: Data) {
        handler?(.start(stringRepresentation(forAddress: address)))
        startTimer()
    }

    func simplePing(_ pinger: SimplePing, didFailWithError error: Error) {
        handler?(.failed(error))
        stop()
    }

    func simplePing(_ pinger: SimplePing, didSendPacket packet: Data, sequenceNumber: UInt16) {
        handler?(.sent(packet, sequenceNumber))
    }

    func simplePing(_ pinger: SimplePing, didFailToSendPacket packet: Data, sequenceNumber: UInt16, error: Error) {
        handler?(.sendFailed(packet, sequenceNumber, error))
    }

    func simplePing(_ pinger: SimplePing, didReceivePingResponsePacket packet: Data, sequenceNumber: UInt16) {
        handler?(.received(packet, sequenceNumber))
    }

    func simplePing(_ pinger: SimplePing, didReceiveUnexpectedPacket packet: Data) {
        handler?(.unexpectedPacket(packet))
    }
}

/*
    Copyright (C) 2016 Apple Inc. All Rights Reserved.
    See LICENSE.txt for this sample’s licensing information

    Abstract:
    A view controller for testing SimplePing on iOS.
 */

import UIKit

class MainViewController: UITableViewController {
    let hostName = "www.apple.com"

    let pingManager = SimplePingManager()

    @IBOutlet var forceIPv4Cell: UITableViewCell!
    @IBOutlet var forceIPv6Cell: UITableViewCell!
    @IBOutlet var startStopCell: UITableViewCell!

    override func viewDidLoad() {
        super.viewDidLoad()
        title = hostName
    }
}

// MARK: UITableViewDelegate

extension MainViewController {
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let cell = tableView.cellForRow(at: indexPath)!

        switch cell {
        case forceIPv4Cell, forceIPv6Cell:
            cell.accessoryType = cell.accessoryType == .none ? .checkmark : .none

        case startStopCell:
            if pingManager.isStarted {
                stop()
            } else {
                let forceIPv4 = forceIPv4Cell.accessoryType != .none
                let forceIPv6 = forceIPv6Cell.accessoryType != .none
                start(forceIPv4: forceIPv4, forceIPv6: forceIPv6)
            }

        default:
            fatalError()
        }

        tableView.deselectRow(at: indexPath, animated: true)
    }
}

// MARK: - Private utility methods

private extension MainViewController {
    /// Called by the table view selection delegate callback to start the ping.

    func start(forceIPv4: Bool, forceIPv6: Bool) {
        pingerWillStart()

        pingManager.start(hostName: hostName, forceIPv4: forceIPv4, forceIPv6: forceIPv6) { result in
            print(result)
        }
    }

    /// Called by the table view selection delegate callback to stop the ping.

    func stop() {
        pingManager.stop()
        pingerDidStop()
    }

    func pingerWillStart() {
        startStopCell.textLabel!.text = "Stop…"
    }

    func pingerDidStop() {
        startStopCell.textLabel!.text = "Start…"
    }
}

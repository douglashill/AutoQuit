// Douglas Hill, December 2023

import AppKit
import os.log

let logger = Logger()

// TODO: Run without dock icon
// TODO: Open at login (I could set this up manually)

@main class AppDelegate: NSObject, NSApplicationDelegate {
    var frontmostAppObservation: NSKeyValueObservation?

    func applicationDidFinishLaunching(_ notification: Notification) {
        frontmostAppObservation = NSWorkspace.shared.observe(\.frontmostApplication, options: [.old], changeHandler: { _, change in
            guard let maybeApp = change.oldValue, let app = maybeApp else {
                return
            }
            AppDelegate.terminateAppsIfTheyHaveNoWindows(apps: [app])
        })

        AppDelegate.terminateAppsIfTheyHaveNoWindows(apps: NSWorkspace.shared.runningApplications)
    }

    private static func terminateAppsIfTheyHaveNoWindows(apps: [NSRunningApplication]) {
        let exemptAppBundleIDs: Set<String> = ["com.apple.finder"]

        let eligibleApps = apps.filter {
            $0.activationPolicy == .regular && $0.isActive == false && $0 != NSRunningApplication.current && exemptAppBundleIDs.contains($0.bundleIdentifier ?? "") == false
        }
        if eligibleApps.isEmpty {
            return
        }

        var appsToQuitByPID: [pid_t: NSRunningApplication] = [:]
        for app in eligibleApps {
            appsToQuitByPID[app.processIdentifier] = app
        }

        for window in CGWindowListCopyWindowInfo([.excludeDesktopElements], kCGNullWindowID) as! [[String: AnyObject]] {
            let bounds = window[kCGWindowBounds as String] as! [String: Double]
            // Menu bar. Actual height is 37 on my 2021 MacBook Pro.
            // Also GitUp has a window that’s 68 points high.
            if bounds["Height"]! < 100 {
                continue
            }

            // Not sure what this is, but apps often have this window.
            if bounds["Width"]! == 500 && bounds["Height"]! == 500 {
                continue
            }

            // Not sure if this check does anything useful.
            let layer = window[kCGWindowLayer as String] as! Int
            if layer != 0 {
                continue
            }

            let pid = window[kCGWindowOwnerPID as String] as! pid_t

            guard let app = appsToQuitByPID[pid] else {
                continue
            }

            appsToQuitByPID.removeValue(forKey: pid)
            logger.debug("Not terminating \(app.localizedName ?? "UNKNOWN APP") because it has at least one window.")

            // Avoid unnecessary work.
            if appsToQuitByPID.isEmpty {
                break
            }
        }

        for (_, app) in appsToQuitByPID {
            let success = app.terminate()
            if success {
                logger.debug("Terminated \(app.localizedName ?? "UNKNOWN APP")")
            } else {
                logger.error("Couldn’t terminate \(app.localizedName ?? "UNKNOWN APP")")
            }
        }
    }
}

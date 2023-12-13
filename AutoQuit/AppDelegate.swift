// Douglas Hill, December 2023

import AppKit

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

        var appsByPID: [pid_t: NSRunningApplication] = [:]
        for app in eligibleApps {
            appsByPID[app.processIdentifier] = app
        }

        let windows = CGWindowListCopyWindowInfo([.excludeDesktopElements], kCGNullWindowID) as! [[String: AnyObject]]

        var windowsByApp: [NSRunningApplication: [[String: AnyObject]]] = [:]
        var windowsForOtherApps: [[String: AnyObject]] = []

        for window in windows {
            let bounds = window[kCGWindowBounds as String] as! [String: Double]
            // Menu bar. Actual height is 37 on my 2021 MacBook Pro.
            // Also GitUp has a window that’s 68 points high.
            if bounds["Height"]! < 100 {
                continue
            }
            if bounds["Width"]! == 500 && bounds["Height"]! == 500 {
                continue
            }

            let layer = window[kCGWindowLayer as String] as! Int
            if layer != 0 {
                continue
            }

            let pid = window[kCGWindowOwnerPID as String] as! pid_t

            guard let app = appsByPID[pid] else {
                windowsForOtherApps.append(window)
                continue
            }

            var windowsForThisApp = windowsByApp[app] ?? []
            windowsForThisApp.append(window)
            windowsByApp[app] = windowsForThisApp
        }

        for app in eligibleApps {
            let count = windowsByApp[app]?.count ?? 0
            if count == 0 {
                let success = app.terminate()
                if success {
                    print("Terminated \(app.localizedName ?? "UNKNOWN APP")")
                } else {
                    print("Couldn’t terminate \(app.localizedName ?? "UNKNOWN APP")")
                }
            } else {
                print("Not terminating \(app.localizedName ?? "UNKNOWN APP") because there are \(count) windows.")
            }
        }
    }
}

// Douglas Hill, December 2023

import AppKit
import Combine

// TODO: Run without dock icon
// TODO: Open at login (I could set this up manually)

@main class AppDelegate: NSObject, NSApplicationDelegate {
    var frontmostAppObservation: AnyCancellable?

    func applicationDidFinishLaunching(_ notification: Notification) {
        frontmostAppObservation = NSWorkspace.shared.publisher(for: \.frontmostApplication, options: [.initial]).sink { _ in
            AppDelegate.terminateAppsWithNoWindows()
        }
    }

    private static func terminateAppsWithNoWindows() {
        let exemptAppBundleIDs: Set<String> = ["com.apple.finder"]

        let apps = NSWorkspace.shared.runningApplications.filter {
            $0.activationPolicy == .regular && $0.isActive == false && $0 != NSRunningApplication.current && exemptAppBundleIDs.contains($0.bundleIdentifier ?? "") == false
        }

        var appsByPID: [pid_t: NSRunningApplication] = [:]
        for app in apps {
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

        for app in apps {
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

// Douglas Hill, December 2023

import AppKit

// TODO: Observe changes to the frontmost app
// TODO: Run without dock icon
// TODO: Open at login (I could set this up manually)

@main class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {

        let exemptAppBundleIDs: Set<String> = ["com.apple.finder"]

        let apps = NSWorkspace.shared.runningApplications.filter {
            $0.activationPolicy == .regular && $0.isActive == false && $0 != NSRunningApplication.current && exemptAppBundleIDs.contains($0.bundleIdentifier ?? "") == false
        }

        var appsByPID: [pid_t: NSRunningApplication] = [:]
        for app in apps {
            appsByPID[app.processIdentifier] = app
        }

        // These options need experimenting with.
        // No options gives way too many windows for each app.
        // The options below give too few. E.g. maybe not including hidden windows.

        // .optionOnScreenOnly, is way too restrictive. Removes hidden windows and windows in other spaces.

        let windows = CGWindowListCopyWindowInfo([.excludeDesktopElements], kCGNullWindowID) as! [[String: AnyObject]]

        // This could be simpler.
        // Could make var appsToTerminate = apps
        // then enumerate windows and remove apps from appsToTerminate when finding them.

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

//        let sortedApps = windowsByApp.keys.sorted { $0.processIdentifier < $1.processIdentifier }
//        for app in sortedApps {
//            print("\n\n## \(app.localizedName!) ##")
//            for window in windowsByApp[app]! {
//                print(describeWindow(window))
//            }
//        }
//        print("\n - - - - - - - -\n")
//        print(windowsForOtherApps)

        for app in apps {
            let count = windowsByApp[app]?.count ?? 0
            if count == 0 {
                let success = app.terminate()
                if success {
                    print("Terminated \(app.localizedName ?? "UNKNOWN APP")")
                } else {
                    print("Couldn’t terminate \(app.localizedName ?? "UNKNOWN APP")")
                }
//                print("Would terminate \(app.localizedName ?? "APP").")
            } else {
                print("Not terminating \(app.localizedName ?? "UNKNOWN APP") because there are \(count) windows.")
            }
        }

        // Then work out if I can observe changes to the window list.

//        let owners = goodWindows.map {
//            $0[kCGWindowOwnerName as String]!
//        }
//
//        print(owners)
    }
}

func describeWindow(_ window: [String: AnyObject]) -> String {
    window.keys.sorted().map { key in
        let value = window[key]!
        return "\(key): \(value)"
    }.joined(separator: ", ")
}

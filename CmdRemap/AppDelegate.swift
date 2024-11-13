//
//  AppDelegate.swift
//  CmdRemap
//
//  Created by digitalpochi on 2024/08/15.
//

import Cocoa
import ServiceManagement

@main
class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem = NSStatusBar.system.statusItem(withLength: CGFloat(NSStatusItem.variableLength))
    let keyRemapper = KeyRemapper()
    var pauseMenu: NSMenuItem!
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        launchAtStartup(true)
        
        let menu = NSMenu()
        pauseMenu = NSMenuItem(title: "Disable", action: #selector(self.pause), keyEquivalent: "")
        menu.addItem(pauseMenu)
        menu.addItem(withTitle: "Quit", action: #selector(self.quit), keyEquivalent: "")

        statusItem.button?.title = "CR"
        statusItem.menu = menu
        
        keyRemapper.authRequest()
        keyRemapper.waitForReady { [weak self] in
            self?.keyRemapper.start()
        }
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }

    @objc
    func quit() {
        exit(EXIT_SUCCESS)
    }

    @objc
    func pause() {
        keyRemapper.pause = !keyRemapper.pause
        if keyRemapper.pause {
            pauseMenu.title = "Enable"
        } else {
            pauseMenu.title = "Disable"
        }
    }

}

func launchAtStartup(_ enable: Bool) {
    if SMAppService.mainApp.status == .enabled {
        return
    }
    
    do {
        if enable {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    } catch {
        print(error)
    }
}

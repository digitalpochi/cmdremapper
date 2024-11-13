//
//  KeyRemapper.swift
//  CmdRemap
//
//  Created by digitalpochi on 2024/08/15.
//

import Cocoa

class KeyRemapper {
    enum ActiveCommand {
        case left, right, none
    }

    var pause: Bool = false
    var leftCmd = ShortPressDetector {
        postEng()
    }
    var rightCmd = ShortPressDetector {
        postKana()
    }

    @discardableResult
    func authRequest() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue(): true] as CFDictionary
        let isTrusted = AXIsProcessTrustedWithOptions(options)

        return isTrusted
    }
    
    func waitForReady(completion: @escaping (() -> Void)) {
        if !AXIsProcessTrusted() {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
                self?.waitForReady(completion: completion)
            }
            return
        }
        completion()
    }
    
    func start() {
        let eventType: [CGEventType] = [.keyUp, .keyDown, .flagsChanged]
        var eventMask = 0
        for type in eventType {
            eventMask |= 1 << type.rawValue
        }
        
        let userInfo = UnsafeMutableRawPointer(Unmanaged.passRetained(self).toOpaque())
        guard let port = CGEvent.tapCreate(tap: .cgSessionEventTap,
                                           place: .headInsertEventTap,
                                           options: .defaultTap,
                                           eventsOfInterest: CGEventMask(eventMask),
                                           callback: ExecRemap,
                                           userInfo: userInfo) else {
            return
        }
        
        let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, port, 0)
        
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: port, enable: true)
        CFRunLoopRun()
    }
  
    private static func postKana() {
        postKey(keyCode: 104, isDown: true)
        postKey(keyCode: 104, isDown: false)
    }
    
    private static func postEng() {
        postKey(keyCode: 102, isDown: true)
        postKey(keyCode: 102, isDown: false)
    }

    private static func postKey(keyCode: CGKeyCode, isDown: Bool) {
        let loc = CGEventTapLocation.cghidEventTap
        let keyEvent = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: isDown)!
        keyEvent.flags = CGEventFlags()
        keyEvent.post(tap: loc)
    }
}

fileprivate func ExecRemap(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent, pointer: UnsafeMutableRawPointer?) -> Unmanaged<CGEvent>? {
    guard let pointer else {
        return Unmanaged.passUnretained(event)
    }
    
    let uinfo = Unmanaged<KeyRemapper>.fromOpaque(pointer).takeUnretainedValue()
    
//    print("type: \(type.rawValue) code: \(event.getIntegerValueField(.keyboardEventKeycode)) flag: \(event.flags.rawValue)")
    
    guard type == .flagsChanged else {
        return Unmanaged.passUnretained(event)
    }
    
    if event.flags.contains(.maskCommand) {
        uinfo.rightCmd.reset()
        uinfo.leftCmd.reset()
    }
    
    let code = event.getIntegerValueField(.keyboardEventKeycode)
    if code == 54 { // right cmd
        uinfo.rightCmd.tryExec(with: event.timestamp)
    } else if code == 55 { // left cmd
        uinfo.leftCmd.tryExec(with: event.timestamp)
    }

    return Unmanaged.passUnretained(event)
}

struct ShortPressDetector {
    private var threshold: Int
    private var timestamp: CGEventTimestamp = 0
    private var execCmd: (() -> Void)
    
    init(threshold: Int = 3, execCmd: @escaping () -> Void) {
        self.threshold = threshold
        self.execCmd = execCmd
    }
    
    mutating func tryExec(with timestamp: CGEventTimestamp) {
        if self.timestamp != 0 {
            let th = (timestamp - self.timestamp) / 100_000_000
            if th <= threshold {
                execCmd()
            }
            reset()
        } else {
            self.timestamp = timestamp
        }
    }
    
    mutating func reset() {
        timestamp = 0
    }
}

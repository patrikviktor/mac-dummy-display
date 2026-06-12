import Cocoa
import CoreGraphics
import CoreVideo

// Disable buffering to flush stdout immediately for log capture
setbuf(stdout, nil)

class DummyDisplayApp: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var virtualDisplay: CGVirtualDisplay?
    var displayLink: CVDisplayLink?
    var statusTimer: Timer?
    
    // Menu items
    var toggleItem: NSMenuItem!
    var statusItemMenu: NSMenuItem!
    
    var toggleSunshineItem: NSMenuItem!
    var statusSunshineMenu: NSMenuItem!
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Create status bar item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem.button {
            if #available(macOS 11.0, *) {
                button.image = NSImage(systemSymbolName: "display", accessibilityDescription: "Dummy Display")
            } else {
                button.title = "🖥️"
            }
        }
        
        // Dynamically generate the LaunchAgent plist for the current user
        ensureLaunchAgentExists()
        
        setupMenu()
        
        // Start a timer to monitor Sunshine status every 1.5 seconds
        statusTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            self?.updateSunshineMenuStatus()
        }
    }
    
    func setupMenu() {
        let menu = NSMenu()
        
        // Virtual Display Section
        statusItemMenu = NSMenuItem(title: "Display: Inactive", action: nil, keyEquivalent: "")
        statusItemMenu.isEnabled = false
        menu.addItem(statusItemMenu)
        
        toggleItem = NSMenuItem(title: "Enable Virtual Display", action: #selector(toggleDisplay), keyEquivalent: "t")
        toggleItem.target = self
        menu.addItem(toggleItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Sunshine Section
        statusSunshineMenu = NSMenuItem(title: "Sunshine: Stopped", action: nil, keyEquivalent: "")
        statusSunshineMenu.isEnabled = false
        menu.addItem(statusSunshineMenu)
        
        toggleSunshineItem = NSMenuItem(title: "Start Sunshine", action: #selector(toggleSunshine), keyEquivalent: "s")
        toggleSunshineItem.target = self
        menu.addItem(toggleSunshineItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Quit
        let quitItem = NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        
        statusItem.menu = menu
    }
    
    @objc func toggleDisplay() {
        if virtualDisplay == nil {
            startDisplay()
        } else {
            stopDisplay()
        }
    }
    
    @objc func toggleSunshine() {
        if isSunshineRunning() {
            stopSunshine()
        } else {
            startSunshine()
        }
    }
    
    func startDisplay() {
        print("Initializing virtual display descriptor...")
        let descriptor = CGVirtualDisplayDescriptor()
        descriptor.name = "Dummy Retina Display"
        
        descriptor.maxPixelsWide = 5120
        descriptor.maxPixelsHigh = 3200
        
        descriptor.vendorID = 0xABCD
        descriptor.productID = 0x1234
        descriptor.serialNum = 42
        
        descriptor.sizeInMillimeters = CGSize(width: 340, height: 212)
        descriptor.queue = DispatchQueue.main
        
        descriptor.terminationHandler = { display in
            print("Virtual display termination handler triggered.")
        }
        
        let display = CGVirtualDisplay(descriptor: descriptor)
        virtualDisplay = display
        let displayID = display.displayID
        print("Virtual display created with Display ID: \(displayID)")
        
        let resolutions: [(UInt32, UInt32)] = [
            (1440, 900),
            (1680, 1050),
            (1920, 1200),
            (2560, 1600),
            (2880, 1800),
            (3360, 2100),
            (3840, 2400),
            (5120, 3200)
        ]
        
        var modes: [CGVirtualDisplayMode] = []
        let refreshRates: [Double] = [60.0, 90.0, 120.0]
        for res in resolutions {
            for rate in refreshRates {
                let mode = CGVirtualDisplayMode(width: res.0, height: res.1, refreshRate: rate)
                modes.append(mode)
            }
        }
        
        let settings = CGVirtualDisplaySettings()
        settings.modes = modes
        settings.hiDPI = 1
        
        if display.apply(settings) {
            startDisplayLink(displayID: displayID)
            toggleItem.title = "Disable Virtual Display"
            statusItemMenu.title = "Display: Active (ID: \(displayID))"
            print("Display settings applied successfully. Display ID: \(displayID)")
            
            // Automatically update Sunshine configuration file with new Display ID
            updateSunshineConfig(displayID: displayID)
            
            // If Sunshine is already running, restart it to apply the new display ID
            if isSunshineRunning() {
                print("Sunshine is running. Restarting to apply new Display ID...")
                stopSunshine()
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
                    self?.startSunshine()
                }
            }
        } else {
            virtualDisplay = nil
            print("Failed to apply virtual display settings.")
        }
    }
    
    func stopDisplay() {
        stopDisplayLink()
        virtualDisplay = nil
        toggleItem.title = "Enable Virtual Display"
        statusItemMenu.title = "Display: Inactive"
        print("Display stopped.")
    }
    
    func startDisplayLink(displayID: CGDirectDisplayID) {
        var link: CVDisplayLink?
        let result = CVDisplayLinkCreateWithCGDisplay(displayID, &link)
        
        guard result == kCVReturnSuccess, let activeLink = link else {
            print("Warning: Failed to create CVDisplayLink.")
            return
        }
        
        let status = CVDisplayLinkSetOutputCallback(activeLink, { (displayLink, inNow, inOutputTime, flagsIn, flagsOut, displayLinkContext) -> CVReturn in
            return kCVReturnSuccess
        }, nil)
        
        if status == kCVReturnSuccess {
            CVDisplayLinkStart(activeLink)
            displayLink = activeLink
            print("CVDisplayLink started for Display ID: \(displayID)")
        } else {
            print("Warning: Failed to set CVDisplayLink output callback.")
        }
    }
    
    func stopDisplayLink() {
        if let link = displayLink {
            CVDisplayLinkStop(link)
            displayLink = nil
            print("CVDisplayLink stopped.")
        }
    }
    
    func getSunshineConfigPath() -> String {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        return homeDir.appendingPathComponent(".config/sunshine/sunshine.conf").path
    }
    
    func getLaunchAgentPlistPath() -> String {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        return homeDir.appendingPathComponent("Library/LaunchAgents/com.patrikviktor.sunshine.plist").path
    }
    
    func ensureLaunchAgentExists() {
        let fileManager = FileManager.default
        let homeDir = fileManager.homeDirectoryForCurrentUser
        let launchAgentsDir = homeDir.appendingPathComponent("Library/LaunchAgents")
        let plistPath = getLaunchAgentPlistPath()
        
        let plistContent = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>Label</key>
            <string>com.patrikviktor.sunshine</string>
            <key>ProgramArguments</key>
            <array>
                <string>/opt/homebrew/bin/sunshine</string>
            </array>
            <key>RunAtLoad</key>
            <true/>
            <key>KeepAlive</key>
            <false/>
            <key>StandardOutPath</key>
            <string>\(homeDir.path)/.config/sunshine/sunshine_launch.log</string>
            <key>StandardErrorPath</key>
            <string>\(homeDir.path)/.config/sunshine/sunshine_launch.log</string>
        </dict>
        </plist>
        """
        
        do {
            try fileManager.createDirectory(at: launchAgentsDir, withIntermediateDirectories: true, attributes: nil)
            try plistContent.write(toFile: plistPath, atomically: true, encoding: .utf8)
            print("LaunchAgent plist verified/written at: \(plistPath)")
        } catch {
            print("Failed to write LaunchAgent plist: \(error)")
        }
    }
    
    func updateSunshineConfig(displayID: CGDirectDisplayID) {
        let fileManager = FileManager.default
        let configPath = getSunshineConfigPath()
        
        do {
            var configContent = ""
            if fileManager.fileExists(atPath: configPath) {
                configContent = try String(contentsOfFile: configPath, encoding: .utf8)
            }
            
            let lines = configContent.components(separatedBy: .newlines)
            var newLines: [String] = []
            var outputNameFound = false
            
            for line in lines {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.hasPrefix("output_name") {
                    newLines.append("output_name = \(displayID)")
                    outputNameFound = true
                } else {
                    newLines.append(line)
                }
            }
            
            if !outputNameFound {
                newLines.append("output_name = \(displayID)")
            }
            
            let newContent = newLines.joined(separator: "\n")
            try newContent.write(toFile: configPath, atomically: true, encoding: .utf8)
            print("Updated sunshine.conf with output_name = \(displayID)")
        } catch {
            print("Error updating sunshine.conf: \(error)")
        }
    }
    
    func isSunshineRunning() -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep")
        process.arguments = ["-x", "sunshine"]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }
    
    func updateSunshineMenuStatus() {
        let running = isSunshineRunning()
        if running {
            toggleSunshineItem.title = "Stop Sunshine"
            statusSunshineMenu.title = "Sunshine: Running"
        } else {
            toggleSunshineItem.title = "Start Sunshine"
            statusSunshineMenu.title = "Sunshine: Stopped"
        }
    }
    
    func startSunshine() {
        guard !isSunshineRunning() else { return }
        
        // Decouple Sunshine from DummyDisplay's process tree and TCC permissions context
        // by launching it via macOS launchd (launchctl load) with the dynamically generated plist.
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = ["load", getLaunchAgentPlistPath()]
        
        do {
            try process.run()
            process.waitUntilExit()
            print("Sunshine started via launchctl load.")
            
            // Give it a brief moment to start and let the UI update
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
                self?.updateSunshineMenuStatus()
            }
        } catch {
            print("Failed to start Sunshine via launchctl: \(error)")
        }
    }
    
    func stopSunshine() {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = ["unload", getLaunchAgentPlistPath()]
        
        do {
            try process.run()
            process.waitUntilExit()
            print("Sunshine stopped via launchctl unload.")
            
            // Just in case, kill any lingering processes
            let killProcess = Process()
            killProcess.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
            killProcess.arguments = ["sunshine"]
            try? killProcess.run()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
                self?.updateSunshineMenuStatus()
            }
        } catch {
            print("Failed to stop Sunshine via launchctl: \(error)")
        }
    }
    
    @objc func quit() {
        stopDisplay()
        stopSunshine()
        statusTimer?.invalidate()
        NSApplication.shared.terminate(self)
    }
}

// Application Entry Point
let app = NSApplication.shared
let delegate = DummyDisplayApp()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()

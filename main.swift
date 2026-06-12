import Foundation
import CoreGraphics
import CoreVideo

// Disable buffering to flush stdout immediately for log capture
setbuf(stdout, nil)

// Global references to keep the virtual display and display link alive
var virtualDisplay: CGVirtualDisplay?
var displayLink: CVDisplayLink?

func startDisplayLink(displayID: CGDirectDisplayID) {
    print("Setting up CVDisplayLink to prevent frame drops...")
    var link: CVDisplayLink?
    let result = CVDisplayLinkCreateWithCGDisplay(displayID, &link)
    
    guard result == kCVReturnSuccess, let activeLink = link else {
        print("Warning: Failed to create CVDisplayLink.")
        return
    }
    
    // Set a C-compatible no-op callback. This callback is triggered by the window server
    // at the display's refresh rate (60Hz), forcing constant VSync rendering on this headless display.
    let status = CVDisplayLinkSetOutputCallback(activeLink, { (displayLink, inNow, inOutputTime, flagsIn, flagsOut, displayLinkContext) -> CVReturn in
        return kCVReturnSuccess
    }, nil)
    
    if status == kCVReturnSuccess {
        CVDisplayLinkStart(activeLink)
        displayLink = activeLink
        print("CVDisplayLink successfully started for Display ID: \(displayID)")
        print("Displej je teraz chránený pred sekaním (Frame Throttling) zo strany macOS.")
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

func createVirtualDisplay() {
    print("Initializing virtual display descriptor...")
    let descriptor = CGVirtualDisplayDescriptor()
    descriptor.name = "Dummy Retina Display"
    
    // Set maximum resolution bounds to support our maximum backing store size (5120x3200)
    descriptor.maxPixelsWide = 5120
    descriptor.maxPixelsHigh = 3200
    
    descriptor.vendorID = 0xABCD
    descriptor.productID = 0x1234
    descriptor.serialNum = 42 // Constant to ensure stable Display ID in Sunshine
    
    descriptor.sizeInMillimeters = CGSize(width: 340, height: 212)
    descriptor.queue = DispatchQueue.main
    
    descriptor.terminationHandler = { display in
        print("Virtual display termination handler triggered.")
    }
    
    print("Instantiating CGVirtualDisplay...")
    let display = CGVirtualDisplay(descriptor: descriptor)
    virtualDisplay = display
    
    let displayID = display.displayID
    print("Virtual display created with Display ID: \(displayID)")
    
    print("Configuring display modes...")
    // To support scaled HiDPI (Retina) resolutions in System Settings, we register
    // both the logical sizes and their 2x physical backing counterparts.
    let resolutions: [(UInt32, UInt32)] = [
        (1440, 900),   // Logical 1x (standard MacBook)
        (1680, 1050),  // Logical 1x
        (1920, 1200),  // Logical 1x
        (2560, 1600),  // Target logical & Backing for 1280x800 @ 2x
        (2880, 1800),  // Backing for 1440x900 @ 2x
        (3360, 2100),  // Backing for 1680x1050 @ 2x
        (3840, 2400),  // Backing for 1920x1200 @ 2x
        (5120, 3200)   // Backing for 2560x1600 @ 2x
    ]
    
    var modes: [CGVirtualDisplayMode] = []
    for res in resolutions {
        let mode = CGVirtualDisplayMode(width: res.0, height: res.1, refreshRate: 60.0)
        modes.append(mode)
    }
    
    let settings = CGVirtualDisplaySettings()
    settings.modes = modes
    settings.hiDPI = 1 // Enable Retina scaling
    
    print("Applying settings...")
    if display.apply(settings) {
        print("Successfully applied settings to virtual display.")
        print("Displej je teraz aktívny s HiDPI škálovaním na frekvencii 60Hz.")
        print("Môžete si vybrať menšie Retina rozlíšenia v: System Settings -> Displays")
        
        // Start the display link to lock the window server frame updates to 60Hz
        startDisplayLink(displayID: displayID)
    } else {
        print("Error: Failed to apply settings.")
        virtualDisplay = nil
        exit(1)
    }
}

func setupSignalHandlers() {
    // Register standard C signal handlers. C-convention closures can access global variables/functions.
    signal(SIGINT) { _ in
        print("\nPrerušenie prijaté (SIGINT). Odstraňujem displej...")
        stopDisplayLink()
        virtualDisplay = nil
        exit(0)
    }

    signal(SIGTERM) { _ in
        print("\nUkončenie prijaté (SIGTERM). Odstraňujem displej...")
        stopDisplayLink()
        virtualDisplay = nil
        exit(0)
    }
}

// Main execution
setupSignalHandlers()
createVirtualDisplay()

print("Spúšťam RunLoop. Pre ukončenie stlačte Ctrl+C...")
RunLoop.main.run()

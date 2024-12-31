// ∅ 2025 lil org

import Cocoa
import WalletCore

struct Images {
    
    static var statusBarIcon: NSImage { named("Status") }
    static var zorb: NSImage { named("zorb") }
    static var multicoinWalletPreferences: NSImage { systemName("ellipsis.rectangle") }
    static var network: NSImage { systemName("network") }
    static var circleFill: NSImage { systemName("circle.fill") }
    
    private static func named(_ name: String) -> NSImage {
        return NSImage(named: name)!
    }
    
    private static func systemName(_ systemName: String) -> NSImage {
        return NSImage(systemSymbolName: systemName, accessibilityDescription: nil)!
    }
    
}

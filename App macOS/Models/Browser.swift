// ∅ 2025 lil org

import Foundation

enum Browser: String, CaseIterable {
    case safari = "com.apple.Safari"
    case chrome = "com.google.Chrome"
    case tor = "org.torproject.torbrowser"
    case opera = "com.operasoftware.Opera"
    case edge = "com.microsoft.edgemac"
    case brave = "com.brave.Browser"
    case firefox = "org.mozilla.firefox"
    case vivaldi = "com.vivaldi.Vivaldi"
    case unknown = "com.unknown.browser.stub"
    
    static let allBundleIds = Set(Browser.allCases.map { $0.rawValue })
}

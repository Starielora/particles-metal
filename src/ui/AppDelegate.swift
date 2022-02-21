#if os(macOS)
import AppKit
import Foundation

class AppDelegate : NSObject, NSApplicationDelegate
{
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true;
    }
}
#endif

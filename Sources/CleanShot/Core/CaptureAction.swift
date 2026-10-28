import Carbon

/// Actions supported by CleanShot X global shortcuts and menu items.
public enum CaptureAction: UInt32, CaseIterable, Sendable {
    case captureArea = 1001
    case captureWindow = 1002
    case captureFullscreen = 1003
    case capturePreviousArea = 1004
    case scrollingCapture = 1005
    case selfTimer = 1006
    case recognizeText = 1007
    case recordScreen = 1008

    public var title: String {
        switch self {
        case .captureArea: return "Capture Area"
        case .captureWindow: return "Capture Window"
        case .captureFullscreen: return "Capture Fullscreen"
        case .capturePreviousArea: return "Capture Previous Area"
        case .scrollingCapture: return "Scrolling Capture"
        case .selfTimer: return "Self-Timer Capture"
        case .recognizeText: return "Recognize Text (OCR)"
        case .recordScreen: return "Record Screen"
        }
    }

    public var shortcutDisplayString: String {
        switch self {
        case .captureArea: return "⌘⇧4"
        case .captureWindow: return "⌘⇧5"
        case .captureFullscreen: return "⌘⇧3"
        case .capturePreviousArea: return "⌘⇧6"
        case .scrollingCapture: return "⌘⇧7"
        case .selfTimer: return "⌘⇧8"
        case .recognizeText: return "⌘⇧2"
        case .recordScreen: return "⌘⇧9"
        }
    }

    /// Carbon virtual key code.
    public var defaultKeyCode: UInt32 {
        switch self {
        case .captureArea: return 21           // kVK_ANSI_4
        case .captureWindow: return 23         // kVK_ANSI_5
        case .captureFullscreen: return 20     // kVK_ANSI_3
        case .capturePreviousArea: return 22   // kVK_ANSI_6
        case .scrollingCapture: return 26      // kVK_ANSI_7
        case .selfTimer: return 28             // kVK_ANSI_8
        case .recognizeText: return 19         // kVK_ANSI_2
        case .recordScreen: return 25          // kVK_ANSI_9
        }
    }

    /// Carbon modifier flags: Cmd + Shift
    public var defaultModifiers: UInt32 {
        return UInt32(cmdKey | shiftKey)
    }
}

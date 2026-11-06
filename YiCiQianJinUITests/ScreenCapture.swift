import UIKit
import XCTest

/// Screenshot of the display that is actually lit. On iPhone Duo, `XCUIScreen.main` is the outer
/// display even while the device is open (when it's black), so pick the brightest screen instead.
enum ScreenCapture {
    static func active() -> XCUIScreenshot {
        let shots = XCUIScreen.screens.map { $0.screenshot() }
        return shots.max { brightness($0.image) < brightness($1.image) } ?? XCUIScreen.main.screenshot()
    }

    private static func brightness(_ image: UIImage) -> CGFloat {
        let size = CGSize(width: 8, height: 8)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let small = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        guard let data = small.cgImage?.dataProvider?.data, let bytes = CFDataGetBytePtr(data) else { return 0 }
        var total = 0
        for i in stride(from: 0, to: CFDataGetLength(data), by: 4) {
            total += Int(bytes[i]) + Int(bytes[i + 1]) + Int(bytes[i + 2])
        }
        return CGFloat(total)
    }

    static func save(_ shot: XCUIScreenshot, name: String, in testCase: XCTestCase) {
        let attachment = XCTAttachment(screenshot: shot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        testCase.add(attachment)
        if let dir = ProcessInfo.processInfo.environment["SCREENSHOT_DIR"] {
            try? shot.pngRepresentation.write(to: URL(fileURLWithPath: dir).appendingPathComponent("\(name).png"))
        }
    }
}

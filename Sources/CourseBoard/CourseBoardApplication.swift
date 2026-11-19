import AppKit

@main
struct CourseBoardApplication {
    @MainActor
    private static var applicationDelegate: AppDelegate?

    @MainActor
    static func main() {
        let application = NSApplication.shared
        application.setActivationPolicy(.accessory)

        let delegate = AppDelegate()
        applicationDelegate = delegate

        application.delegate = delegate
        application.run()
    }
}

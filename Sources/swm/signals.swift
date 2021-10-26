import AppKit

func handleSigInt(_: Int32) {
    print("received sigint - terminating...")
    NSApplication.shared.terminate(nil)
}

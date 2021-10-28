import AppKit

func handleSigInt(_: Int32) {
    print("received SIGINT - terminating...")
    CFRunLoopStop(CFRunLoopGetCurrent())
}

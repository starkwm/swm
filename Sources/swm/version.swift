import Foundation

let majorVersion = 0
let minorVersion = 0
let patchVersion = 1

func printVersion() -> Int32 {
    print("swm version \(majorVersion).\(minorVersion).\(patchVersion)")
    return EXIT_SUCCESS
}

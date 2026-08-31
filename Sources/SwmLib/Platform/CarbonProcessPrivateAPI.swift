import Carbon

// Private system functions imported from Carbon.

/// Advance to the next running process.
// swift-format-ignore: AlwaysUseLowerCamelCase
@_silgen_name("GetNextProcess") @discardableResult
func GetNextProcess(_ psn: inout ProcessSerialNumber) -> OSStatus

/// Return process information for the given process serial number.
// swift-format-ignore: AlwaysUseLowerCamelCase
@_silgen_name("GetProcessInformation") @discardableResult
func GetProcessInformation(_ psn: inout ProcessSerialNumber, _ info: inout ProcessInfoRec)
  -> OSStatus

/// Return the process ID for the given process serial number.
// swift-format-ignore: AlwaysUseLowerCamelCase
@_silgen_name("GetProcessPID") @discardableResult
func GetProcessPID(_ psn: inout ProcessSerialNumber, _ pid: inout pid_t) -> OSStatus

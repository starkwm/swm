// Private and Swift-unavailable functions from the HIServices framework.
//
// These are declared in C so Swift calls them with the C calling convention, the real
// integer widths, and nullable, ownership-annotated results. ApplicationServices, which
// SwmLib already links, provides the symbols.

#ifndef SWM_HISERVICES_H
#define SWM_HISERVICES_H

#include <ApplicationServices/ApplicationServices.h>

CF_ASSUME_NONNULL_BEGIN

/// Return the window ID for the given accessibility UI element.
extern AXError _AXUIElementGetWindow(AXUIElementRef element, CGWindowID *identifier);

/// Create an accessibility element from a remote token, or return NULL when none matches.
extern AXUIElementRef _Nullable _AXUIElementCreateWithRemoteToken(CFDataRef token)
  CF_RETURNS_RETAINED;

// The Process Manager functions below are public but deprecated, and Swift refuses to import
// APIs deprecated as early as macOS 10.9. These declarations bind new names to the same
// symbols.

/// Advance to the next running process.
extern OSErr SWMGetNextProcess(ProcessSerialNumber *psn) __asm("_GetNextProcess");

/// Return process information for the given process serial number.
extern OSErr SWMGetProcessInformation(const ProcessSerialNumber *psn, ProcessInfoRec *info)
  __asm("_GetProcessInformation");

/// Return the process ID for the given process serial number.
extern OSStatus SWMGetProcessPID(const ProcessSerialNumber *psn, pid_t *pid)
  __asm("_GetProcessPID");

CF_ASSUME_NONNULL_END

#endif

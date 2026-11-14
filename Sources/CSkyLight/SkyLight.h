// Private system functions imported from SkyLight.
//
// These are declared in C so Swift calls them with the C calling convention, the real
// integer widths, and nullable results. SwmLib links the framework itself.

#ifndef SWM_SKYLIGHT_H
#define SWM_SKYLIGHT_H

#include <ApplicationServices/ApplicationServices.h>
#include <stdbool.h>
#include <stdint.h>

CF_ASSUME_NONNULL_BEGIN

/// Return the main connection ID.
extern int SLSMainConnectionID(void);

/// Return the connection ID for the given process serial number.
extern CGError SLSGetConnectionIDForPSN(
  int connectionID,
  ProcessSerialNumber *psn,
  int *processConnectionID
);

/// Return the process serial number that owns a connection.
extern CGError SLSGetConnectionPSN(int connectionID, ProcessSerialNumber *psn);

/// Return the frontmost window and its owner at a screen point.
extern OSStatus SLSFindWindowAndOwner(
  int connectionID,
  int windowID,
  int options,
  int relativeWindowID,
  CGPoint *screenPoint,
  CGPoint *windowPoint,
  uint32_t *foundWindowID,
  int *foundWindowConnectionID
);

/// Return windows on the given spaces, or NULL when WindowServer has no answer.
extern CFArrayRef _Nullable SLSCopyWindowsWithOptionsAndTags(
  int connectionID,
  uint32_t owner,
  CFArrayRef spaces,
  uint32_t options,
  uint64_t *setTags,
  uint64_t *clearTags
) CF_RETURNS_RETAINED;

/// Query the given windows, or return NULL when the query cannot be created.
extern CFTypeRef _Nullable SLSWindowQueryWindows(
  int connectionID,
  CFArrayRef windows,
  int count
) CF_RETURNS_RETAINED;

/// Return the iterator for the given query, or NULL when it cannot be created.
extern CFTypeRef _Nullable SLSWindowQueryResultCopyWindows(CFTypeRef query) CF_RETURNS_RETAINED;

/// Advance the given query iterator.
extern bool SLSWindowIteratorAdvance(CFTypeRef iterator);

/// Return the window attributes for the given query iterator.
extern uint64_t SLSWindowIteratorGetAttributes(CFTypeRef iterator);

/// Return the parent ID for the given query iterator.
extern uint32_t SLSWindowIteratorGetParentID(CFTypeRef iterator);

/// Return the window level for the given query iterator.
extern int SLSWindowIteratorGetLevel(CFTypeRef iterator);

/// Return the tags for the given query iterator.
extern uint64_t SLSWindowIteratorGetTags(CFTypeRef iterator);

/// Return the window ID for the given query iterator.
extern uint32_t SLSWindowIteratorGetWindowID(CFTypeRef iterator);

/// Post a private process event record.
extern CGError SLPSPostEventRecordTo(ProcessSerialNumber *psn, uint8_t *bytes);

/// Return the frontmost process serial number.
extern OSStatus _SLPSGetFrontProcess(ProcessSerialNumber *psn);

/// Focus a process window using private WindowServer options.
extern CGError _SLPSSetFrontProcessWithOptions(
  ProcessSerialNumber *psn,
  uint32_t windowID,
  uint32_t options
);

CF_ASSUME_NONNULL_END

#endif

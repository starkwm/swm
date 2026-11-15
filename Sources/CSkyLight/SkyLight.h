#ifndef SWM_SKYLIGHT_H
#define SWM_SKYLIGHT_H

#include <ApplicationServices/ApplicationServices.h>
#include <stdbool.h>
#include <stdint.h>

CF_ASSUME_NONNULL_BEGIN

extern int SLSMainConnectionID(void);

extern CGError SLSGetConnectionIDForPSN(
  int connectionID,
  ProcessSerialNumber *psn,
  int *processConnectionID
);

extern CGError SLSGetConnectionPSN(int connectionID, ProcessSerialNumber *psn);

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

extern CFArrayRef _Nullable SLSCopyWindowsWithOptionsAndTags(
  int connectionID,
  uint32_t owner,
  CFArrayRef spaces,
  uint32_t options,
  uint64_t *setTags,
  uint64_t *clearTags
) CF_RETURNS_RETAINED;

extern CFTypeRef _Nullable SLSWindowQueryWindows(
  int connectionID,
  CFArrayRef windows,
  int count
) CF_RETURNS_RETAINED;

extern CFTypeRef _Nullable SLSWindowQueryResultCopyWindows(CFTypeRef query) CF_RETURNS_RETAINED;

extern bool SLSWindowIteratorAdvance(CFTypeRef iterator);

extern uint64_t SLSWindowIteratorGetAttributes(CFTypeRef iterator);

extern uint32_t SLSWindowIteratorGetParentID(CFTypeRef iterator);

extern int SLSWindowIteratorGetLevel(CFTypeRef iterator);

extern uint64_t SLSWindowIteratorGetTags(CFTypeRef iterator);

extern uint32_t SLSWindowIteratorGetWindowID(CFTypeRef iterator);

extern CGError SLPSPostEventRecordTo(ProcessSerialNumber *psn, uint8_t *bytes);

extern OSStatus _SLPSGetFrontProcess(ProcessSerialNumber *psn);

extern CGError _SLPSSetFrontProcessWithOptions(
  ProcessSerialNumber *psn,
  uint32_t windowID,
  uint32_t options
);

CF_ASSUME_NONNULL_END

#endif

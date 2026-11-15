#ifndef SWM_HISERVICES_H
#define SWM_HISERVICES_H

#include <ApplicationServices/ApplicationServices.h>

CF_ASSUME_NONNULL_BEGIN

extern AXError _AXUIElementGetWindow(AXUIElementRef element, CGWindowID *identifier);

extern AXUIElementRef _Nullable _AXUIElementCreateWithRemoteToken(CFDataRef token)
  CF_RETURNS_RETAINED;


extern OSErr SWMGetNextProcess(ProcessSerialNumber *psn) __asm("_GetNextProcess");

extern OSErr SWMGetProcessInformation(const ProcessSerialNumber *psn, ProcessInfoRec *info)
  __asm("_GetProcessInformation");

extern OSStatus SWMGetProcessPID(const ProcessSerialNumber *psn, pid_t *pid)
  __asm("_GetProcessPID");

CF_ASSUME_NONNULL_END

#endif

/*
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License
 * as published by the Free Software Foundation; either version 2
 * of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software Foundation,
 * Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.
 *
 * The Original Code is Copyright (C) 2001-2002 by NaN Holding BV.
 * All rights reserved.
 */

#include "GHOST_SystemUIKit.h"

#include "GHOST_DisplayManagerUIKit.h"
#include "GHOST_EventButton.h"
#include "GHOST_EventCursor.h"
#include "GHOST_EventDragnDrop.h"
#include "GHOST_EventKey.h"
#include "GHOST_EventString.h"
#include "GHOST_EventTrackpad.h"
#include "GHOST_EventWheel.h"
#include "GHOST_TimerManager.h"
#include "GHOST_TimerTask.h"
#include "GHOST_WindowUIKit.h"
#include "GHOST_WindowManager.h"

#if defined(WITH_GL_EGL)
#  include "GHOST_ContextEGL.h"
#else
#  include "GHOST_ContextCGL.h"
#endif

#ifdef WITH_INPUT_NDOF
#  include "GHOST_NDOFManagerCocoa.h"
#endif

#include "AssertMacros.h"

#import <UIKit/UIKit.h>

#include <sys/sysctl.h>
#include <sys/time.h>
#include <sys/types.h>

#include <mach/mach_time.h>

#pragma mark KeyMap, mouse converters

static GHOST_TButtonMask convertButton(int button)
{
  switch (button) {
    case 0:
      return GHOST_kButtonMaskLeft;
    case 1:
      return GHOST_kButtonMaskRight;
    case 2:
      return GHOST_kButtonMaskMiddle;
    case 3:
      return GHOST_kButtonMaskButton4;
    case 4:
      return GHOST_kButtonMaskButton5;
    case 5:
      return GHOST_kButtonMaskButton6;
    case 6:
      return GHOST_kButtonMaskButton7;
    default:
      return GHOST_kButtonMaskLeft;
  }
}

#pragma mark Utility functions

#define FIRSTFILEBUFLG 512
static bool g_hasFirstFile = false;
static char g_firstFileBuf[512];

// TODO: Need to investigate this.
// Function called too early in creator.c to have g_hasFirstFile == true
extern "C" int GHOST_HACK_getFirstFile(char buf[FIRSTFILEBUFLG])
{
  if (g_hasFirstFile) {
    strncpy(buf, g_firstFileBuf, FIRSTFILEBUFLG - 1);
    buf[FIRSTFILEBUFLG - 1] = '\0';
    return 1;
  }
  else {
    return 0;
  }
}

#pragma mark Cocoa objects

/**
 * GHOSTUIKitAppDelegate
 * 
 * This exists primarily to ensure window scenes are created with our default
 * scene delegate.
 */
@interface GHOSTUIKitAppDelegate : NSObject <UIApplicationDelegate>
{

  GHOST_SystemUIKit *systemUIKit;
}

- (GHOST_SystemUIKit *)systemUIKit;
- (void)setSystemUIKit:(GHOST_SystemUIKit *)sysUIKit;

- (UISceneConfiguration *)application:(UIApplication *) application
    configurationForConnectingSceneSession:(UISceneSession *) connectingSceneSession
    options:(UISceneConnectionOptions *) options;
@end

@implementation GHOSTUIKitAppDelegate : NSObject
- (GHOST_SystemUIKit *)systemUIKit {
  return systemUIKit;
};

- (void)setSystemUIKit:(GHOST_SystemUIKit *)sysUIKit
{
  systemUIKit = sysUIKit;
}

- (UISceneConfiguration *)application:(UIApplication *) application
  configurationForConnectingSceneSession:(UISceneSession *) connectingSceneSession
  options:(UISceneConnectionOptions *) options {

  UISceneConfiguration* sceneconfig =
    [[UISceneConfiguration alloc] initWithName:@"Blender"
      sessionRole:UIWindowSceneSessionRoleApplication];
  
  [sceneconfig setSceneClass: [UIWindowScene self]];
  [sceneconfig setDelegateClass: [GHOSTWindowSceneDelegate self]];
  
  return sceneconfig;
}

@end

#pragma mark initialization/finalization

GHOST_SystemUIKit::GHOST_SystemUIKit()
{
  int mib[2];
  struct timeval boottime;
  size_t len;
  char *rstring = NULL;

  m_modifierMask = 0;
  m_outsideLoopEventProcessed = false;
  m_needDelayedApplicationBecomeActiveEventProcessing = false;
  m_displayManager = new GHOST_DisplayManagerUIKit();
  GHOST_ASSERT(m_displayManager, "GHOST_SystemUIKit::GHOST_SystemUIKit(): m_displayManager==0\n");
  m_displayManager->initialize();

  // NSEvent timeStamp is given in system uptime, state start date is boot time
  mib[0] = CTL_KERN;
  mib[1] = KERN_BOOTTIME;
  len = sizeof(struct timeval);

  sysctl(mib, 2, &boottime, &len, NULL, 0);
  m_start_time = ((boottime.tv_sec * 1000) + (boottime.tv_usec / 1000));

  // Detect multitouch trackpad
  mib[0] = CTL_HW;
  mib[1] = HW_MODEL;
  sysctl(mib, 2, NULL, &len, NULL, 0);
  rstring = (char *)malloc(len);
  sysctl(mib, 2, rstring, &len, NULL, 0);

  free(rstring);
  rstring = NULL;

  m_ignoreWindowSizedMessages = false;
  m_ignoreMomentumScroll = false;
  m_multiTouchScroll = false;
  m_last_warp_timestamp = 0;
}

GHOST_SystemUIKit::~GHOST_SystemUIKit()
{
}

GHOST_TSuccess GHOST_SystemUIKit::init()
{
  GHOST_TSuccess success = GHOST_System::init();
  if (success) {

#ifdef WITH_INPUT_NDOF
    m_ndofManager = new GHOST_NDOFManagerCocoa(*this);
#endif

    @autoreleasepool {
      UIApplication* app = [UIApplication sharedApplication];  // initializes UIApplication

      if ([app delegate] == nil) {
        GHOSTUIKitAppDelegate *appDelegate = [[GHOSTUIKitAppDelegate alloc] init];
        [appDelegate setSystemUIKit:this];
        [app setDelegate:appDelegate];
      }
    }
  }
  return success;
}

#pragma mark window management

GHOST_TUns64 GHOST_SystemUIKit::getMilliSeconds() const
{
  struct timeval currentTime;

  gettimeofday(&currentTime, NULL);

  // Return timestamp of system uptime

  return ((currentTime.tv_sec * 1000) + (currentTime.tv_usec / 1000) - m_start_time);
}

GHOST_TUns8 GHOST_SystemUIKit::getNumDisplays() const
{
  // We do not support iPadOS auxiliary screens at the moment
  @autoreleasepool {
    return UIScreen.screens.count;
  }
}

void GHOST_SystemUIKit::getMainDisplayDimensions(GHOST_TUns32 &width, GHOST_TUns32 &height) const
{
  @autoreleasepool {
    // TODO: Does Blender want rotated or unrotated screen size?
    CGRect bounds = [[UIScreen mainScreen] nativeBounds];

    width = bounds.size.width;
    height = bounds.size.height;
  }
}

void GHOST_SystemUIKit::getAllDisplayDimensions(GHOST_TUns32 &width, GHOST_TUns32 &height) const
{
  /* TODO! */
  getMainDisplayDimensions(width, height);
}

GHOST_IWindow *GHOST_SystemUIKit::createWindow(const char *title,
                                               GHOST_TInt32 left,
                                               GHOST_TInt32 top,
                                               GHOST_TUns32 width,
                                               GHOST_TUns32 height,
                                               GHOST_TWindowState state,
                                               GHOST_TDrawingContextType type,
                                               GHOST_GLSettings glSettings,
                                               const bool exclusive,
                                               const bool is_dialog,
                                               const GHOST_IWindow *parentWindow)
{
  // TODO: We cannot (currently) programmatically create new windows
  // synchronously
  // fortunately blender is already single window enough
  return m_mainWindow;
}

/**
 * Create a new offscreen context.
 * Never explicitly delete the context, use #disposeContext() instead.
 * \return The new context (or 0 if creation failed).
 */
GHOST_IContext *GHOST_SystemUIKit::createOffscreenContext(GHOST_GLSettings glSettings)
{
  GHOST_Context *context = new GHOST_ContextCGL(false, NULL, NULL, NULL);
  if (context->initializeDrawingContext())
    return context;
  else
    delete context;

  return NULL;
}

/**
 * Dispose of a context.
 * \param context: Pointer to the context to be disposed.
 * \return Indication of success.
 */
GHOST_TSuccess GHOST_SystemUIKit::disposeContext(GHOST_IContext *context)
{
  delete context;

  return GHOST_kSuccess;
}

/**
 * \note : returns coordinates in Cocoa screen coordinates
 */
GHOST_TSuccess GHOST_SystemUIKit::getCursorPosition(GHOST_TInt32 &x, GHOST_TInt32 &y) const
{
  //TODO: Figure out how the hell you get mouse location in iPadOS
  x = (GHOST_TInt32)0;
  y = (GHOST_TInt32)0;
  return GHOST_kSuccess;
}

/**
 * \note : expect Cocoa screen coordinates
 */
GHOST_TSuccess GHOST_SystemUIKit::setCursorPosition(GHOST_TInt32 x, GHOST_TInt32 y)
{
  //TODO: Can you even *set* the cursor position on an iPad?!
  return GHOST_kSuccess;
}

GHOST_TSuccess GHOST_SystemUIKit::setMouseCursorPosition(GHOST_TInt32 x, GHOST_TInt32 y)
{
  //TODO: What's the difference between "cursor" and "mouse cursor" position!?
  return GHOST_kSuccess;
}

GHOST_TSuccess GHOST_SystemUIKit::getModifierKeys(GHOST_ModifierKeys &keys) const
{
  //TODO: How does one get the keyboard modifiers on iPadOS?
  return GHOST_kSuccess;
}

GHOST_TSuccess GHOST_SystemUIKit::getButtons(GHOST_Buttons &buttons) const
{
  //TODO: How does one get the mouse buttons on iPadOS?
  buttons.clear();
  return GHOST_kSuccess;
}

#pragma mark Event handlers

/**
 * The event queue polling function
 */
bool GHOST_SystemUIKit::processEvents(bool waitForEvent)
{
  //TODO: on iPadOS, you don't poll the event queue.
  //The event queue polls you.
  return false;
}

bool GHOST_SystemUIKit::hasDialogWindow()
{
  for (GHOST_IWindow *iwindow : m_windowManager->getWindows()) {
    GHOST_WindowUIKit *window = (GHOST_WindowUIKit *)iwindow;
    if (window->isDialog()) {
      return true;
    }
  }
  return false;
}

void GHOST_SystemUIKit::notifyExternalEventProcessed()
{
  m_outsideLoopEventProcessed = true;
}

// Note: called from UIWindowScene delegate
GHOST_TSuccess GHOST_SystemUIKit::handleWindowEvent(GHOST_TEventType eventType,
                                                    GHOST_WindowUIKit *window)
{
  if (!validWindow(window)) {
    return GHOST_kFailure;
  }
  switch (eventType) {
    case GHOST_kEventWindowClose:
      pushEvent(new GHOST_Event(getMilliSeconds(), GHOST_kEventWindowClose, window));
      break;
    case GHOST_kEventWindowActivate:
      m_windowManager->setActiveWindow(window);
      window->loadCursor(window->getCursorVisibility(), window->getCursorShape());
      pushEvent(new GHOST_Event(getMilliSeconds(), GHOST_kEventWindowActivate, window));
      break;
    case GHOST_kEventWindowDeactivate:
      m_windowManager->setWindowInactive(window);
      pushEvent(new GHOST_Event(getMilliSeconds(), GHOST_kEventWindowDeactivate, window));
      break;
    case GHOST_kEventWindowUpdate:
      if (m_nativePixel) {
        window->setNativePixelSize();
        pushEvent(new GHOST_Event(getMilliSeconds(), GHOST_kEventNativeResolutionChange, window));
      }
      pushEvent(new GHOST_Event(getMilliSeconds(), GHOST_kEventWindowUpdate, window));
      break;
    case GHOST_kEventWindowMove:
      pushEvent(new GHOST_Event(getMilliSeconds(), GHOST_kEventWindowMove, window));
      break;
    case GHOST_kEventWindowSize:
      if (!m_ignoreWindowSizedMessages) {
        // Enforce only one resize message per event loop
        // (coalescing all the live resize messages)
        window->updateDrawingContext();
        pushEvent(new GHOST_Event(getMilliSeconds(), GHOST_kEventWindowSize, window));
        // Mouse up event is trapped by the resizing event loop,
        // so send it anyway to the window manager.
        pushEvent(new GHOST_EventButton(getMilliSeconds(),
                                        GHOST_kEventButtonUp,
                                        window,
                                        GHOST_kButtonMaskLeft,
                                        GHOST_TABLET_DATA_NONE));
        // m_ignoreWindowSizedMessages = true;
      }
      break;
    case GHOST_kEventNativeResolutionChange:

      if (m_nativePixel) {
        window->setNativePixelSize();
        pushEvent(new GHOST_Event(getMilliSeconds(), GHOST_kEventNativeResolutionChange, window));
      }

    default:
      return GHOST_kFailure;
      break;
  }

  m_outsideLoopEventProcessed = true;
  return GHOST_kSuccess;
}

void GHOST_SystemUIKit::handleQuitRequest()
{
  GHOST_Window *window = (GHOST_Window *)m_windowManager->getActiveWindow();

  // Discard quit event if we are in cursor grab sequence
  if (window && window->getCursorGrabModeIsWarp())
    return;

  // Push the event to Blender so it can open a dialog if needed
  pushEvent(new GHOST_Event(getMilliSeconds(), GHOST_kEventQuitRequest, window));
  m_outsideLoopEventProcessed = true;
}

bool GHOST_SystemUIKit::handleOpenDocumentRequest(void *filepathStr)
{
  //TODO: Figure out how to do this on iPad.
  return NO;
}

GHOST_TSuccess GHOST_SystemUIKit::handleTabletEvent(void *eventPtr, short eventType)
{
  //TODO: handle Apple Pencil input
  return GHOST_kSuccess;
}

bool GHOST_SystemUIKit::handleTabletEvent(void *eventPtr)
{
  //TODO: handle Apple Pencil input
  return false;
}

GHOST_TSuccess GHOST_SystemUIKit::handleMouseEvent(void *eventPtr)
{
  //TODO: handle trackpad/mouse input
  return GHOST_kSuccess;
}

GHOST_TSuccess GHOST_SystemUIKit::handleKeyEvent(void *eventPtr)
{
  //TODO: handle keyboard input
  return GHOST_kSuccess;
}

#pragma mark Clipboard get/set

GHOST_TUns8 *GHOST_SystemUIKit::getClipboard(bool selection) const
{
  //TODO: handle iPadOS pastebin
  return NULL;
}

void GHOST_SystemUIKit::putClipboard(GHOST_TInt8 *buffer, bool selection) const
{
  //TODO: handle iPadOS pastebin writing
}

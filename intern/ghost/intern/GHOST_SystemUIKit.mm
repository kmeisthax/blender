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

/**
 * Converts Mac raw-key codes (same for Cocoa & Carbon)
 * into GHOST key codes
 * \param rawCode: The raw physical key code
 * \param recvChar: the character ignoring modifiers (except for shift)
 * \return Ghost key code
 */
static GHOST_TKey convertKey(int rawCode, unichar recvChar, UInt16 keyAction)
{
  // printf("\nrecvchar %c 0x%x",recvChar,recvChar);
  switch (rawCode) {
    /*Physical keycodes not used due to map changes in int'l keyboards
    case kVK_ANSI_A:    return GHOST_kKeyA;
    case kVK_ANSI_B:    return GHOST_kKeyB;
    case kVK_ANSI_C:    return GHOST_kKeyC;
    case kVK_ANSI_D:    return GHOST_kKeyD;
    case kVK_ANSI_E:    return GHOST_kKeyE;
    case kVK_ANSI_F:    return GHOST_kKeyF;
    case kVK_ANSI_G:    return GHOST_kKeyG;
    case kVK_ANSI_H:    return GHOST_kKeyH;
    case kVK_ANSI_I:    return GHOST_kKeyI;
    case kVK_ANSI_J:    return GHOST_kKeyJ;
    case kVK_ANSI_K:    return GHOST_kKeyK;
    case kVK_ANSI_L:    return GHOST_kKeyL;
    case kVK_ANSI_M:    return GHOST_kKeyM;
    case kVK_ANSI_N:    return GHOST_kKeyN;
    case kVK_ANSI_O:    return GHOST_kKeyO;
    case kVK_ANSI_P:    return GHOST_kKeyP;
    case kVK_ANSI_Q:    return GHOST_kKeyQ;
    case kVK_ANSI_R:    return GHOST_kKeyR;
    case kVK_ANSI_S:    return GHOST_kKeyS;
    case kVK_ANSI_T:    return GHOST_kKeyT;
    case kVK_ANSI_U:    return GHOST_kKeyU;
    case kVK_ANSI_V:    return GHOST_kKeyV;
    case kVK_ANSI_W:    return GHOST_kKeyW;
    case kVK_ANSI_X:    return GHOST_kKeyX;
    case kVK_ANSI_Y:    return GHOST_kKeyY;
    case kVK_ANSI_Z:    return GHOST_kKeyZ;*/

    /* Numbers keys mapped to handle some int'l keyboard (e.g. French)*/
    case kVK_ISO_Section:
      return GHOST_kKeyUnknown;
    case kVK_ANSI_1:
      return GHOST_kKey1;
    case kVK_ANSI_2:
      return GHOST_kKey2;
    case kVK_ANSI_3:
      return GHOST_kKey3;
    case kVK_ANSI_4:
      return GHOST_kKey4;
    case kVK_ANSI_5:
      return GHOST_kKey5;
    case kVK_ANSI_6:
      return GHOST_kKey6;
    case kVK_ANSI_7:
      return GHOST_kKey7;
    case kVK_ANSI_8:
      return GHOST_kKey8;
    case kVK_ANSI_9:
      return GHOST_kKey9;
    case kVK_ANSI_0:
      return GHOST_kKey0;

    case kVK_ANSI_Keypad0:
      return GHOST_kKeyNumpad0;
    case kVK_ANSI_Keypad1:
      return GHOST_kKeyNumpad1;
    case kVK_ANSI_Keypad2:
      return GHOST_kKeyNumpad2;
    case kVK_ANSI_Keypad3:
      return GHOST_kKeyNumpad3;
    case kVK_ANSI_Keypad4:
      return GHOST_kKeyNumpad4;
    case kVK_ANSI_Keypad5:
      return GHOST_kKeyNumpad5;
    case kVK_ANSI_Keypad6:
      return GHOST_kKeyNumpad6;
    case kVK_ANSI_Keypad7:
      return GHOST_kKeyNumpad7;
    case kVK_ANSI_Keypad8:
      return GHOST_kKeyNumpad8;
    case kVK_ANSI_Keypad9:
      return GHOST_kKeyNumpad9;
    case kVK_ANSI_KeypadDecimal:
      return GHOST_kKeyNumpadPeriod;
    case kVK_ANSI_KeypadEnter:
      return GHOST_kKeyNumpadEnter;
    case kVK_ANSI_KeypadPlus:
      return GHOST_kKeyNumpadPlus;
    case kVK_ANSI_KeypadMinus:
      return GHOST_kKeyNumpadMinus;
    case kVK_ANSI_KeypadMultiply:
      return GHOST_kKeyNumpadAsterisk;
    case kVK_ANSI_KeypadDivide:
      return GHOST_kKeyNumpadSlash;
    case kVK_ANSI_KeypadClear:
      return GHOST_kKeyUnknown;

    case kVK_F1:
      return GHOST_kKeyF1;
    case kVK_F2:
      return GHOST_kKeyF2;
    case kVK_F3:
      return GHOST_kKeyF3;
    case kVK_F4:
      return GHOST_kKeyF4;
    case kVK_F5:
      return GHOST_kKeyF5;
    case kVK_F6:
      return GHOST_kKeyF6;
    case kVK_F7:
      return GHOST_kKeyF7;
    case kVK_F8:
      return GHOST_kKeyF8;
    case kVK_F9:
      return GHOST_kKeyF9;
    case kVK_F10:
      return GHOST_kKeyF10;
    case kVK_F11:
      return GHOST_kKeyF11;
    case kVK_F12:
      return GHOST_kKeyF12;
    case kVK_F13:
      return GHOST_kKeyF13;
    case kVK_F14:
      return GHOST_kKeyF14;
    case kVK_F15:
      return GHOST_kKeyF15;
    case kVK_F16:
      return GHOST_kKeyF16;
    case kVK_F17:
      return GHOST_kKeyF17;
    case kVK_F18:
      return GHOST_kKeyF18;
    case kVK_F19:
      return GHOST_kKeyF19;
    case kVK_F20:
      return GHOST_kKeyF20;

    case kVK_UpArrow:
      return GHOST_kKeyUpArrow;
    case kVK_DownArrow:
      return GHOST_kKeyDownArrow;
    case kVK_LeftArrow:
      return GHOST_kKeyLeftArrow;
    case kVK_RightArrow:
      return GHOST_kKeyRightArrow;

    case kVK_Return:
      return GHOST_kKeyEnter;
    case kVK_Delete:
      return GHOST_kKeyBackSpace;
    case kVK_ForwardDelete:
      return GHOST_kKeyDelete;
    case kVK_Escape:
      return GHOST_kKeyEsc;
    case kVK_Tab:
      return GHOST_kKeyTab;
    case kVK_Space:
      return GHOST_kKeySpace;

    case kVK_Home:
      return GHOST_kKeyHome;
    case kVK_End:
      return GHOST_kKeyEnd;
    case kVK_PageUp:
      return GHOST_kKeyUpPage;
    case kVK_PageDown:
      return GHOST_kKeyDownPage;

      /*case kVK_ANSI_Minus:      return GHOST_kKeyMinus;
    case kVK_ANSI_Equal:        return GHOST_kKeyEqual;
    case kVK_ANSI_Comma:        return GHOST_kKeyComma;
    case kVK_ANSI_Period:       return GHOST_kKeyPeriod;
    case kVK_ANSI_Slash:        return GHOST_kKeySlash;
    case kVK_ANSI_Semicolon:    return GHOST_kKeySemicolon;
    case kVK_ANSI_Quote:        return GHOST_kKeyQuote;
    case kVK_ANSI_Backslash:    return GHOST_kKeyBackslash;
    case kVK_ANSI_LeftBracket:  return GHOST_kKeyLeftBracket;
    case kVK_ANSI_RightBracket: return GHOST_kKeyRightBracket;
    case kVK_ANSI_Grave:        return GHOST_kKeyAccentGrave;*/

    case kVK_VolumeUp:
    case kVK_VolumeDown:
    case kVK_Mute:
      return GHOST_kKeyUnknown;

    default: {
      /* alphanumerical or punctuation key that is remappable in int'l keyboards */
      if ((recvChar >= 'A') && (recvChar <= 'Z')) {
        return (GHOST_TKey)(recvChar - 'A' + GHOST_kKeyA);
      }
      else if ((recvChar >= 'a') && (recvChar <= 'z')) {
        return (GHOST_TKey)(recvChar - 'a' + GHOST_kKeyA);
      }
      else {
        /* Leopard and Snow Leopard 64bit compatible API*/
        CFDataRef uchrHandle; /*the keyboard layout*/
        TISInputSourceRef kbdTISHandle;

        kbdTISHandle = TISCopyCurrentKeyboardLayoutInputSource();
        uchrHandle = (CFDataRef)TISGetInputSourceProperty(kbdTISHandle,
                                                          kTISPropertyUnicodeKeyLayoutData);
        CFRelease(kbdTISHandle);

        /*get actual character value of the "remappable" keys in int'l keyboards,
        if keyboard layout is not correctly reported (e.g. some non Apple keyboards in Tiger),
        then fallback on using the received charactersIgnoringModifiers */
        if (uchrHandle) {
          UInt32 deadKeyState = 0;
          UniCharCount actualStrLength = 0;

          UCKeyTranslate((UCKeyboardLayout *)CFDataGetBytePtr(uchrHandle),
                         rawCode,
                         keyAction,
                         0,
                         LMGetKbdType(),
                         kUCKeyTranslateNoDeadKeysBit,
                         &deadKeyState,
                         1,
                         &actualStrLength,
                         &recvChar);
        }

        switch (recvChar) {
          case '-':
            return GHOST_kKeyMinus;
          case '+':
            return GHOST_kKeyPlus;
          case '=':
            return GHOST_kKeyEqual;
          case ',':
            return GHOST_kKeyComma;
          case '.':
            return GHOST_kKeyPeriod;
          case '/':
            return GHOST_kKeySlash;
          case ';':
            return GHOST_kKeySemicolon;
          case '\'':
            return GHOST_kKeyQuote;
          case '\\':
            return GHOST_kKeyBackslash;
          case '[':
            return GHOST_kKeyLeftBracket;
          case ']':
            return GHOST_kKeyRightBracket;
          case '`':
            return GHOST_kKeyAccentGrave;
          default:
            return GHOST_kKeyUnknown;
        }
      }
    }
  }
  return GHOST_kKeyUnknown;
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
  
  [sceneconfig setWindowClass: [UIWindowScene self]];
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

    width = bounds.width;
    height = bounds.height;
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
  NSPoint mouseLoc = [NSEvent mouseLocation];

  // Returns the mouse location in screen coordinates
  x = (GHOST_TInt32)mouseLoc.x;
  y = (GHOST_TInt32)mouseLoc.y;
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
  keys.set(GHOST_kModifierKeyOS, (m_modifierMask & NSEventModifierFlagCommand) ? true : false);
  keys.set(GHOST_kModifierKeyLeftAlt, (m_modifierMask & NSEventModifierFlagOption) ? true : false);
  keys.set(GHOST_kModifierKeyLeftShift,
           (m_modifierMask & NSEventModifierFlagShift) ? true : false);
  keys.set(GHOST_kModifierKeyLeftControl,
           (m_modifierMask & NSEventModifierFlagControl) ? true : false);

  return GHOST_kSuccess;
}

GHOST_TSuccess GHOST_SystemUIKit::getButtons(GHOST_Buttons &buttons) const
{
  UInt32 button_state = GetCurrentEventButtonState();

  buttons.clear();
  buttons.set(GHOST_kButtonMaskLeft, button_state & (1 << 0));
  buttons.set(GHOST_kButtonMaskRight, button_state & (1 << 1));
  buttons.set(GHOST_kButtonMaskMiddle, button_state & (1 << 2));
  buttons.set(GHOST_kButtonMaskButton4, button_state & (1 << 3));
  buttons.set(GHOST_kButtonMaskButton5, button_state & (1 << 4));
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

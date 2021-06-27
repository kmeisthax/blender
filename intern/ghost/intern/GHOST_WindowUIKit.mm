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

#include "GHOST_WindowUIKit.h"
#include "GHOST_ContextNone.h"
#include "GHOST_Debug.h"
#include "GHOST_SystemUIKit.h"

#if defined(WITH_GL_EGL)
#  include "GHOST_ContextEGL.h"
#else
#  include "GHOST_ContextEAGL.h"
#endif

#include <UIKit/UIKit.h>
#include <Metal/Metal.h>
#include <QuartzCore/QuartzCore.h>

#include <sys/sysctl.h>

#pragma mark UIKit window scene delegate object

@interface GHOSTWindowSceneDelegate : NSObject <UIWindowSceneDelegate>
{
  GHOST_SystemUIKit *systemUIKit;
  GHOST_WindowUIKit *associatedWindow;
}

- (id)init;

- (void)scene:(UIScene *)scene willConnectToSession:(UISceneSesssion *)session
                    options:(UISceneConnectionOptions *)connectionOptions;
- (void)windowScene:(UIWindowScene *) windowScene
    didUpdateCoordinateSpace:(id<UICoordinateSpace>) previousCoordinateSpace
    interfaceOrientation:(UIInterfaceOrientation) previousInterfaceOrientation
    traitCollection:(UITraitCollection *)previousTraitCollection;
- (void)sceneWillEnterForeground:(UIScene *)scene;
- (void)sceneDidBecomeActive:(UIScene *)scene;
- (void)sceneWillResignActive:(UIScene *)scene;
- (void)sceneDidDisconnect:(UIScene *)scene;
@end

@implementation GHOSTWindowSceneDelegate : NSObject
- (id)init {
    systemUIKit = [[[UIApplication sharedApplication] delegate] systemUIKit];
}

- (void)setSystemAndWindowUIKit:(GHOST_SystemUIKit *)sysUIKit
                    windowUIKit:(GHOST_WindowUIKit *)winUIKit
{
  systemUIKit = sysUIKit;
  associatedWindow = winUIKit;
}

- (void)scene:(UIScene *)scene willConnectToSession:(UISceneSesssion *)session
                    options:(UISceneConnectionOptions *)connectionOptions {
    UIWindow* window = [[scene windows] firstObject];
}

- (void)windowScene:(UIWindowScene *) windowScene
    didUpdateCoordinateSpace:(id<UICoordinateSpace>) previousCoordinateSpace
    interfaceOrientation:(UIInterfaceOrientation) previousInterfaceOrientation
    traitCollection:(UITraitCollection *)previousTraitCollection {
    systemUIKit->handleWindowEvent(GHOST_kEventWindowMove, associatedWindow);
    systemUIKit->handleWindowEvent(GHOST_kEventWindowSize, associatedWindow);
}

- (void)sceneWillEnterForeground:(UIScene *)scene {
    systemUIKit->handleWindowEvent(GHOST_kEventWindowUpdate, associatedWindow);
}

- (void)sceneDidBecomeActive:(UIScene *)scene {
    systemUIKit->handleWindowEvent(GHOST_kEventWindowActivate, associatedWindow);
}

- (void)sceneWillResignActive:(UIScene *)scene {
    systemUIKit->handleWindowEvent(GHOST_kEventWindowDeactivate, associatedWindow);
}

- (void)sceneDidDisconnect:(UIScene *)scene {
    systemUIKit->handleWindowEvent(GHOST_kEventWindowClose, associatedWindow);
}

@end

/* UIView for handling input and drawing. */
#define UI_VIEW_CLASS GHOSTOpenGLUIView
#define UI_VIEW_BASE_CLASS GLKView
#include "GHOST_WindowViewUIKit.h"
#undef UI_VIEW_CLASS
#undef UI_VIEW_BASE_CLASS

#define UI_VIEW_CLASS GHOSTMetalUIView
#define UI_VIEW_BASE_CLASS UIView
#include "GHOST_WindowViewUIKit.h"
#undef UI_VIEW_CLASS
#undef UI_VIEW_BASE_CLASS

#define UI_VIEW_CLASS GHOSTOpenGLUIViewController
#define UI_VIEW_BASE_CLASS GLKViewController
#include "GHOST_WindowViewControllerUIKit.h"
#undef UI_VIEW_CLASS
#undef UI_VIEW_BASE_CLASS

#define UI_VIEW_CLASS GHOSTMetalUIViewController
#define UI_VIEW_BASE_CLASS UIViewController
#include "GHOST_WindowViewControllerUIKit.h"
#undef UI_VIEW_CLASS
#undef UI_VIEW_BASE_CLASS

#pragma mark initialization / finalization

GHOST_WindowUIKit::GHOST_WindowUIKit(UIWindowScene *ui_windowscene,
                                     UIWindow *ui_window,
                                     GHOST_SystemUIKit *systemUIKit,
                                     const char *title,
                                     GHOST_TWindowState state,
                                     GHOST_TDrawingContextType type,
                                     const bool stereoVisual,
                                     bool is_debug,
                                     bool is_dialog)
    : GHOST_Window(0, 0, state, stereoVisual, false),
      m_windowScene(ui_windowscene),
      m_window(ui_window),
      m_openGLView(nil),
      m_metalView(nil),
      m_metalLayer(nil),
      m_systemUIKit(systemUIKit),
      m_customCursor(0),
      m_immediateDraw(false),
      m_debug_context(is_debug),
      m_is_dialog(is_dialog)
{
  m_fullScreen = false;

  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

  //TODO: Fix our width/height to match the window size somehow
  //or otherwise measure the window size appropriately

  // Create UIView inside the window
  id<MTLDevice> metalDevice = MTLCreateSystemDefaultDevice();
  UIView *view;
  UIViewController *controller;

  if (metalDevice) {
    // Create metal layer and view if supported
    m_metalLayer = [[CAMetalLayer alloc] init];
    [m_metalLayer setEdgeAntialiasingMask:0];
    [m_metalLayer setMasksToBounds:NO];
    [m_metalLayer setOpaque:YES];
    [m_metalLayer setFramebufferOnly:YES];
    [m_metalLayer setPresentsWithTransaction:NO];
    [m_metalLayer removeAllAnimations];
    [m_metalLayer setDevice:metalDevice];

    m_metalView = [[GHOSTMetalUIView alloc] initWithFrame:rect];
    [m_metalView setLayer:m_metalLayer];
    [m_metalView setSystemAndWindowUIKit:systemUIKit windowUIKit:this];
    view = m_metalView;

    m_metalViewController = [[GHOSTMetalUIViewController alloc] initWithView:m_metalView];
    controller = m_metalViewController;
  }
  else {
    // Fallback to OpenGL view if there is no Metal support
    m_openGLView = [[GHOSTOpenGLUIView alloc] initWithFrame:rect];
    [m_openGLView setSystemAndWindowUIKit:systemUIKit windowUIKit:this];
    view = m_openGLView;

    m_openGLViewController = [[GHOSTOpenGLViewController alloc] initWithView:m_openGLView];
    controller = m_openGLViewController;
  }

  [m_window setRootViewController:controller];

  setDrawingContextType(type);
  updateDrawingContext();
  activateDrawingContext();

  setTitle(title);

  m_tablet = GHOST_TABLET_DATA_NONE;

  GHOSTWindowSceneDelegate *windowDelegate = [m_windowscene delegate];
  [windowDelegate setSystemAndWindowUIKit:systemUIKit windowUIKit:this];

  if (state == GHOST_kWindowStateFullScreen)
    setState(GHOST_kWindowStateFullScreen);

  setNativePixelSize();

  [pool drain];
}

GHOST_WindowUIKit::~GHOST_WindowUIKit()
{
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

  if (m_customCursor) {
    [m_customCursor release];
    m_customCursor = nil;
  }

  releaseNativeHandles();

  if (m_openGLView) {
    [m_openGLView release];
    m_openGLView = nil;
  }
  if (m_openGLViewController) {
    [m_openGLViewController release];
    m_openGLViewController = nil;
  }
  if (m_metalView) {
    [m_metalView release];
    m_metalView = nil;
  }
  if (m_metalViewController) {
    [m_metalViewController release];
    m_metalViewController = nil;
  }
  if (m_metalLayer) {
    [m_metalLayer release];
    m_metalLayer = nil;
  }

  if (m_window) {
    [m_window close];
  }

  [pool drain];
}

#pragma mark accessors

bool GHOST_WindowUIKit::getValid() const
{
  NSView *view = (m_openGLView) ? m_openGLView : m_metalView;
  return GHOST_Window::getValid() && m_window != NULL && view != NULL;
}

void *GHOST_WindowUIKit::getOSWindow() const
{
  return (void *)m_window;
}

void GHOST_WindowUIKit::setTitle(const char *title)
{
  GHOST_ASSERT(getValid(), "GHOST_WindowUIKit::setTitle(): window invalid");
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

  NSString *windowTitle = [[NSString alloc] initWithCString:title encoding:NSUTF8StringEncoding];

  // Set associated file if applicable
  if (windowTitle && [windowTitle hasPrefix:@"Blender"]) {
    NSRange fileStrRange;
    NSString *associatedFileName;
    int len;

    fileStrRange.location = [windowTitle rangeOfString:@"["].location + 1;
    len = [windowTitle rangeOfString:@"]"].location - fileStrRange.location;

    if (len > 0) {
      fileStrRange.length = len;
      associatedFileName = [windowTitle substringWithRange:fileStrRange];
      [m_windowScene setTitle:[associatedFileName lastPathComponent]];
    }
    else {
      [m_windowScene setTitle:windowTitle];
    }
  }
  else {
    [m_windowScene setTitle:windowTitle];
  }

  [windowTitle release];
  [pool drain];
}

std::string GHOST_WindowUIKit::getTitle() const
{
  GHOST_ASSERT(getValid(), "GHOST_WindowUIKit::getTitle(): window invalid");

  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

  NSString *windowTitle = [m_windowScene title];

  std::string title;
  if (windowTitle != nil) {
    title = [windowTitle UTF8String];
  }

  [pool drain];

  return title;
}

void GHOST_WindowUIKit::getWindowBounds(GHOST_Rect &bounds) const
{
  NSRect rect;
  GHOST_ASSERT(getValid(), "GHOST_WindowUIKit::getWindowBounds(): window invalid");

  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

  NSRect screenSize = [[m_window screen] visibleFrame];

  rect = [m_window frame];

  bounds.m_b = screenSize.size.height - (rect.origin.y - screenSize.origin.y);
  bounds.m_l = rect.origin.x - screenSize.origin.x;
  bounds.m_r = rect.origin.x - screenSize.origin.x + rect.size.width;
  bounds.m_t = screenSize.size.height - (rect.origin.y + rect.size.height - screenSize.origin.y);

  [pool drain];
}

void GHOST_WindowUIKit::getClientBounds(GHOST_Rect &bounds) const
{
  NSRect rect;
  GHOST_ASSERT(getValid(), "GHOST_WindowUIKit::getClientBounds(): window invalid");

  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

  NSRect screenSize = [[m_window screen] visibleFrame];

  // Max window contents as screen size (excluding title bar...)
  NSRect contentRect = [CocoaWindow contentRectForFrameRect:screenSize
                                                  styleMask:[m_window styleMask]];

  rect = [m_window contentRectForFrameRect:[m_window frame]];

  bounds.m_b = contentRect.size.height - (rect.origin.y - contentRect.origin.y);
  bounds.m_l = rect.origin.x - contentRect.origin.x;
  bounds.m_r = rect.origin.x - contentRect.origin.x + rect.size.width;
  bounds.m_t = contentRect.size.height - (rect.origin.y + rect.size.height - contentRect.origin.y);
  [pool drain];
}

GHOST_TSuccess GHOST_WindowUIKit::setClientWidth(GHOST_TUns32 width)
{
  GHOST_ASSERT(getValid(), "GHOST_WindowUIKit::setClientWidth(): window invalid");
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
  GHOST_Rect cBnds, wBnds;
  getClientBounds(cBnds);
  if (((GHOST_TUns32)cBnds.getWidth()) != width) {
    NSSize size;
    size.width = width;
    size.height = cBnds.getHeight();
    [m_window setContentSize:size];
  }
  [pool drain];
  return GHOST_kSuccess;
}

GHOST_TSuccess GHOST_WindowUIKit::setClientHeight(GHOST_TUns32 height)
{
  GHOST_ASSERT(getValid(), "GHOST_WindowUIKit::setClientHeight(): window invalid");
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
  GHOST_Rect cBnds, wBnds;
  getClientBounds(cBnds);
  if (((GHOST_TUns32)cBnds.getHeight()) != height) {
    NSSize size;
    size.width = cBnds.getWidth();
    size.height = height;
    [m_window setContentSize:size];
  }
  [pool drain];
  return GHOST_kSuccess;
}

GHOST_TSuccess GHOST_WindowUIKit::setClientSize(GHOST_TUns32 width, GHOST_TUns32 height)
{
  GHOST_ASSERT(getValid(), "GHOST_WindowUIKit::setClientSize(): window invalid");
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
  GHOST_Rect cBnds, wBnds;
  getClientBounds(cBnds);
  if ((((GHOST_TUns32)cBnds.getWidth()) != width) ||
      (((GHOST_TUns32)cBnds.getHeight()) != height)) {
    NSSize size;
    size.width = width;
    size.height = height;
    [m_window setContentSize:size];
  }
  [pool drain];
  return GHOST_kSuccess;
}

GHOST_TWindowState GHOST_WindowUIKit::getState() const
{
  GHOST_ASSERT(getValid(), "GHOST_WindowUIKit::getState(): window invalid");
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
  GHOST_TWindowState state;

  NSUInteger masks = [m_window styleMask];

  if (masks & NSWindowStyleMaskFullScreen) {
    // Lion style fullscreen
    if (!m_immediateDraw) {
      state = GHOST_kWindowStateFullScreen;
    }
    else {
      state = GHOST_kWindowStateNormal;
    }
  }
  else if ([m_window isMiniaturized]) {
    state = GHOST_kWindowStateMinimized;
  }
  else if ([m_window isZoomed]) {
    state = GHOST_kWindowStateMaximized;
  }
  else {
    if (m_immediateDraw) {
      state = GHOST_kWindowStateFullScreen;
    }
    else {
      state = GHOST_kWindowStateNormal;
    }
  }
  [pool drain];
  return state;
}

void GHOST_WindowUIKit::screenToClient(GHOST_TInt32 inX,
                                       GHOST_TInt32 inY,
                                       GHOST_TInt32 &outX,
                                       GHOST_TInt32 &outY) const
{
  GHOST_ASSERT(getValid(), "GHOST_WindowUIKit::screenToClient(): window invalid");

  screenToClientIntern(inX, inY, outX, outY);

  /* switch y to match ghost convention */
  GHOST_Rect cBnds;
  getClientBounds(cBnds);
  outY = (cBnds.getHeight() - 1) - outY;
}

void GHOST_WindowUIKit::clientToScreen(GHOST_TInt32 inX,
                                       GHOST_TInt32 inY,
                                       GHOST_TInt32 &outX,
                                       GHOST_TInt32 &outY) const
{
  GHOST_ASSERT(getValid(), "GHOST_WindowUIKit::clientToScreen(): window invalid");

  /* switch y to match ghost convention */
  GHOST_Rect cBnds;
  getClientBounds(cBnds);
  inY = (cBnds.getHeight() - 1) - inY;

  clientToScreenIntern(inX, inY, outX, outY);
}

void GHOST_WindowUIKit::screenToClientIntern(GHOST_TInt32 inX,
                                             GHOST_TInt32 inY,
                                             GHOST_TInt32 &outX,
                                             GHOST_TInt32 &outY) const
{
  NSRect screenCoord;
  NSRect baseCoord;

  screenCoord.origin.x = inX;
  screenCoord.origin.y = inY;

  baseCoord = [m_window convertRectFromScreen:screenCoord];

  outX = baseCoord.origin.x;
  outY = baseCoord.origin.y;
}

void GHOST_WindowUIKit::clientToScreenIntern(GHOST_TInt32 inX,
                                             GHOST_TInt32 inY,
                                             GHOST_TInt32 &outX,
                                             GHOST_TInt32 &outY) const
{
  NSRect screenCoord;
  NSRect baseCoord;

  baseCoord.origin.x = inX;
  baseCoord.origin.y = inY;

  screenCoord = [m_window convertRectToScreen:baseCoord];

  outX = screenCoord.origin.x;
  outY = screenCoord.origin.y;
}

UIScreen *GHOST_WindowUIKit::getScreen()
{
  return [[m_window windowScene] screen];
}

/* called for event, when window leaves monitor to another */
void GHOST_WindowUIKit::setNativePixelSize(void)
{
  NSView *view = (m_openGLView) ? m_openGLView : m_metalView;
  NSRect backingBounds = [view convertRectToBacking:[view bounds]];

  GHOST_Rect rect;
  getClientBounds(rect);

  m_nativePixelSize = (float)backingBounds.size.width / (float)rect.getWidth();
}

/**
 * \note Fullscreen switch is not actual fullscreen with display capture.
 * As this capture removes all OS X window manager features.
 *
 * Instead, the menu bar and the dock are hidden, and the window is made border-less and enlarged.
 * Thus, process switch, exposé, spaces, ... still work in fullscreen mode
 */
GHOST_TSuccess GHOST_WindowUIKit::setState(GHOST_TWindowState state)
{
  GHOST_ASSERT(getValid(), "GHOST_WindowUIKit::setState(): window invalid");
  switch (state) {
    case GHOST_kWindowStateMinimized:
      [m_window miniaturize:nil];
      break;
    case GHOST_kWindowStateMaximized:
      [m_window zoom:nil];
      break;

    case GHOST_kWindowStateFullScreen: {
      NSUInteger masks = [m_window styleMask];

      if (!(masks & NSWindowStyleMaskFullScreen)) {
        [m_window toggleFullScreen:nil];
      }
      break;
    }
    case GHOST_kWindowStateNormal:
    default:
      NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
      NSUInteger masks = [m_window styleMask];

      if (masks & NSWindowStyleMaskFullScreen) {
        // Lion style fullscreen
        [m_window toggleFullScreen:nil];
      }
      else if ([m_window isMiniaturized])
        [m_window deminiaturize:nil];
      else if ([m_window isZoomed])
        [m_window zoom:nil];
      [pool drain];
      break;
  }

  return GHOST_kSuccess;
}

GHOST_TSuccess GHOST_WindowUIKit::setModifiedState(bool isUnsavedChanges)
{
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

  [m_window setDocumentEdited:isUnsavedChanges];

  [pool drain];
  return GHOST_Window::setModifiedState(isUnsavedChanges);
}

GHOST_TSuccess GHOST_WindowUIKit::setOrder(GHOST_TWindowOrder order)
{
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

  GHOST_ASSERT(getValid(), "GHOST_WindowUIKit::setOrder(): window invalid");
  if (order == GHOST_kWindowOrderTop) {
    [NSApp activateIgnoringOtherApps:YES];
    [m_window makeKeyAndOrderFront:nil];
  }
  else {
    NSArray *windowsList;

    [m_window orderBack:nil];

    // Check for other blender opened windows and make the frontmost key
    windowsList = [NSApp orderedWindows];
    if ([windowsList count]) {
      [[windowsList objectAtIndex:0] makeKeyAndOrderFront:nil];
    }
  }

  [pool drain];
  return GHOST_kSuccess;
}

#pragma mark Drawing context

GHOST_Context *GHOST_WindowUIKit::newDrawingContext(GHOST_TDrawingContextType type)
{
  if (type == GHOST_kDrawingContextTypeOpenGL) {

    GHOST_Context *context = new GHOST_ContextEAGL(
        m_wantStereoVisual, m_metalView, m_metalLayer, m_openGLView);

    if (context->initializeDrawingContext())
      return context;
    else
      delete context;
  }

  return NULL;
}

#pragma mark invalidate

GHOST_TSuccess GHOST_WindowUIKit::invalidate()
{
  GHOST_ASSERT(getValid(), "GHOST_WindowUIKit::invalidate(): window invalid");
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
  NSView *view = (m_openGLView) ? m_openGLView : m_metalView;
  [view setNeedsDisplay:YES];
  [pool drain];
  return GHOST_kSuccess;
}

#pragma mark Progress bar

GHOST_TSuccess GHOST_WindowUIKit::setProgressBar(float progress)
{
  //iPadOS does not have a concept of a progress bar.
  //TODO: Request background time?
  return GHOST_kSuccess;
}

GHOST_TSuccess GHOST_WindowUIKit::endProgressBar()
{
  //TODO: Send local push notification on task completion.
  return GHOST_kSuccess;
}

#pragma mark Cursor handling

void GHOST_WindowUIKit::loadCursor(bool visible, GHOST_TStandardCursor shape) const
{
  //TODO: iPadOS does not support arbitrary mouse cursors out of the box.
}

bool GHOST_WindowUIKit::isDialog() const
{
  return m_is_dialog;
}

GHOST_TSuccess GHOST_WindowUIKit::setWindowCursorVisibility(bool visible)
{
  //TODO: see above note on mouse cursors
  return GHOST_kSuccess;
}

GHOST_TSuccess GHOST_WindowUIKit::setWindowCursorGrab(GHOST_TGrabCursorMode mode)
{
  //TODO: later iPadOS does support cursor locking
  return GHOST_kSuccess;
}

GHOST_TSuccess GHOST_WindowUIKit::setWindowCursorShape(GHOST_TStandardCursor shape)
{
  //TODO: Cursors
  return GHOST_kSuccess;
}

GHOST_TSuccess GHOST_WindowUIKit::hasCursorShape(GHOST_TStandardCursor shape)
{
  //TODO: Cursors
  return GHOST_kSuccess;
}

GHOST_TSuccess GHOST_WindowUIKit::setWindowCustomCursorShape(GHOST_TUns8 *bitmap,
                                                             GHOST_TUns8 *mask,
                                                             int sizex,
                                                             int sizey,
                                                             int hotX,
                                                             int hotY,
                                                             bool canInvertColor)
{
  //TODO: Cursors
  return GHOST_kSuccess;
}

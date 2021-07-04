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
#include <GLKit/GLKit.h>
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

- (void)scene:(UIScene *)scene willConnectToSession:(UISceneSession *)session
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
    systemUIKit = (GHOST_SystemUIKit *)[[[UIApplication sharedApplication] delegate] systemUIKit];
}

- (void)setSystemAndWindowUIKit:(GHOST_SystemUIKit *)sysUIKit
                    windowUIKit:(GHOST_WindowUIKit *)winUIKit
{
  systemUIKit = sysUIKit;
  associatedWindow = winUIKit;
}

- (void)scene:(UIScene *)scene willConnectToSession:(UISceneSession *)session
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

  rect = [m_window bounds];

  bounds.m_b = rect.origin.y;
  bounds.m_l = rect.origin.x;
  bounds.m_r = rect.origin.x + rect.size.width;
  bounds.m_t = rect.origin.y + rect.size.height;

  [pool drain];
}

void GHOST_WindowUIKit::getClientBounds(GHOST_Rect &bounds) const
{
  NSRect rect;
  GHOST_ASSERT(getValid(), "GHOST_WindowUIKit::getClientBounds(): window invalid");

  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

  rect = [m_window bounds];

  bounds.m_b = rect.origin.y;
  bounds.m_l = rect.origin.x;
  bounds.m_r = rect.origin.x + rect.size.width;
  bounds.m_t = rect.origin.y + rect.size.height;
  [pool drain];
}

GHOST_TSuccess GHOST_WindowUIKit::setClientWidth(GHOST_TUns32 width)
{
  //iPadOS windows cannot be resized by the application
  return GHOST_kSuccess;
}

GHOST_TSuccess GHOST_WindowUIKit::setClientHeight(GHOST_TUns32 height)
{
  //iPadOS windows cannot be resized by the application
  return GHOST_kSuccess;
}

GHOST_TSuccess GHOST_WindowUIKit::setClientSize(GHOST_TUns32 width, GHOST_TUns32 height)
{
  //iPadOS windows cannot be resized by the application
  return GHOST_kSuccess;
}

GHOST_TWindowState GHOST_WindowUIKit::getState() const
{
  //iPadOS windows are always fullscreen or divided
  return GHOST_kWindowStateFullScreen;
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

  UIView *view = (m_openGLView) ? m_openGLView : m_metalView;
  screenCoord = [view convertRect:baseCoord fromCoordinateSpace:view.window.screen.coordinateSpace];

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

  UIView *view = (m_openGLView) ? m_openGLView : m_metalView;
  screenCoord = [view convertRect:baseCoord toCoordinateSpace:view.window.screen.coordinateSpace];

  outX = screenCoord.origin.x;
  outY = screenCoord.origin.y;
}

UIScreen *GHOST_WindowUIKit::getScreen()
{
  return [[m_window windowScene] screen];
}

void GHOST_WindowUIKit::setNativePixelSize(void)
{
  UIView *view = (m_openGLView) ? m_openGLView : m_metalView;
  m_nativePixelSize = [view contentScaleFactor];
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
  //iPadOS does not support application-driven window scene reordering
  return GHOST_kSuccess;
}

GHOST_TSuccess GHOST_WindowUIKit::setModifiedState(bool isUnsavedChanges)
{
  //iPadOS does not have a notion of "modified state" for windows
  return GHOST_Window::setModifiedState(isUnsavedChanges);
}

GHOST_TSuccess GHOST_WindowUIKit::setOrder(GHOST_TWindowOrder order)
{
  //iPadOS does not support application-driven window scene reordering
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

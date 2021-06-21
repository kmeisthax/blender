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

/* UIView subclass for drawing and handling input.
 *
 * UI_VIEW_BASE_CLASS will be either NSView or NSOpenGLView depending if
 * we use a Metal or OpenGL layer for drawing in the view. We use macros
 * to defined classes for each case, so we don't have to duplicate code as
 * Objective-C does not have multiple inheritance. */

// We need to subclass it in order to give UIKit the feeling key events are trapped
@interface UI_VIEW_CLASS : UI_VIEW_BASE_CLASS
{
  GHOST_SystemUIKit *systemUIKit;
  GHOST_WindowUIKit *associatedWindow;

  bool composing;
  NSString *composing_text;

  bool immediate_draw;
}
- (void)setSystemAndWindowUIKit:(GHOST_SystemUIKit *)sysUIKit
                    windowUIKit:(GHOST_WindowUIKit *)winUIKit;
@end

@implementation UI_VIEW_CLASS

- (void)setSystemAndWindowUIKit:(GHOST_SystemUIKit *)sysUIKit
                    windowUIKit:(GHOST_WindowUIKit *)winUIKit
{
  systemUIKit = sysUIKit;
  associatedWindow = winUIKit;

  composing = false;
  composing_text = nil;

  immediate_draw = false;
}

- (BOOL)canBecomeFirstResponder
{
  return YES;
}

- (void)keyDown:(NSEvent *)event
{
  systemUIKit->handleKeyEvent(event);

  /* Start or continue composing? */
  if ([[event characters] length] == 0 || [[event charactersIgnoringModifiers] length] == 0 ||
      composing) {
    composing = YES;

    // interpret event to call insertText
    NSMutableArray *events;
    events = [[NSMutableArray alloc] initWithCapacity:1];
    [events addObject:event];
    [self interpretKeyEvents:events];  // calls insertText
    [events removeObject:event];
    [events release];
    return;
  }
}

- (void)keyUp:(NSEvent *)event
{
  systemUIKit->handleKeyEvent(event);
}

- (void)flagsChanged:(NSEvent *)event
{
  systemUIKit->handleKeyEvent(event);
}

- (void)mouseDown:(NSEvent *)event
{
  systemUIKit->handleMouseEvent(event);
}

- (void)mouseUp:(NSEvent *)event
{
  systemUIKit->handleMouseEvent(event);
}

- (void)rightMouseDown:(NSEvent *)event
{
  systemUIKit->handleMouseEvent(event);
}

- (void)rightMouseUp:(NSEvent *)event
{
  systemUIKit->handleMouseEvent(event);
}

- (void)mouseMoved:(NSEvent *)event
{
  systemUIKit->handleMouseEvent(event);
}

- (void)mouseDragged:(NSEvent *)event
{
  systemUIKit->handleMouseEvent(event);
}

- (void)rightMouseDragged:(NSEvent *)event
{
  systemUIKit->handleMouseEvent(event);
}

- (void)scrollWheel:(NSEvent *)event
{
  systemUIKit->handleMouseEvent(event);
}

- (void)otherMouseDown:(NSEvent *)event
{
  systemUIKit->handleMouseEvent(event);
}

- (void)otherMouseUp:(NSEvent *)event
{
  systemUIKit->handleMouseEvent(event);
}

- (void)otherMouseDragged:(NSEvent *)event
{
  systemUIKit->handleMouseEvent(event);
}

- (void)magnifyWithEvent:(NSEvent *)event
{
  systemUIKit->handleMouseEvent(event);
}

- (void)smartMagnifyWithEvent:(NSEvent *)event
{
  systemUIKit->handleMouseEvent(event);
}

- (void)rotateWithEvent:(NSEvent *)event
{
  systemUIKit->handleMouseEvent(event);
}

- (void)tabletPoint:(NSEvent *)event
{
  systemUIKit->handleTabletEvent(event, [event type]);
}

- (void)tabletProximity:(NSEvent *)event
{
  systemUIKit->handleTabletEvent(event, [event type]);
}

- (BOOL)isOpaque
{
  return YES;
}

- (void)drawRect:(NSRect)rect
{
  if ([self inLiveResize]) {
    /* Don't redraw while in live resize */
  }
  else {
    [super drawRect:rect];
    systemUIKit->handleWindowEvent(GHOST_kEventWindowUpdate, associatedWindow);

    /* For some cases like entering fullscreen we need to redraw immediately
     * so our window does not show blank during the animation */
    if (associatedWindow->getImmediateDraw())
      systemUIKit->dispatchEvents();
  }
}

// Text input

- (void)composing_free
{
  composing = NO;

  if (composing_text) {
    [composing_text release];
    composing_text = nil;
  }
}

- (void)insertText:(id)chars
{
  [self composing_free];
}

- (void)setMarkedText:(id)chars selectedRange:(NSRange)range
{
  [self composing_free];
  if ([chars length] == 0)
    return;

  // start composing
  composing = YES;
  composing_text = [chars copy];

  // if empty, cancel
  if ([composing_text length] == 0)
    [self composing_free];
}

- (void)unmarkText
{
  [self composing_free];
}

- (BOOL)hasMarkedText
{
  return (composing) ? YES : NO;
}

- (void)doCommandBySelector:(SEL)selector
{
}

- (BOOL)isComposing
{
  return composing;
}

- (NSInteger)conversationIdentifier
{
  return (NSInteger)self;
}

- (NSAttributedString *)attributedSubstringFromRange:(NSRange)range
{
  return [[[NSAttributedString alloc] init] autorelease];
}

- (NSRange)markedRange
{
  unsigned int length = (composing_text) ? [composing_text length] : 0;

  if (composing)
    return NSMakeRange(0, length);

  return NSMakeRange(NSNotFound, 0);
}

- (NSRange)selectedRange
{
  unsigned int length = (composing_text) ? [composing_text length] : 0;
  return NSMakeRange(0, length);
}

- (NSRect)firstRectForCharacterRange:(NSRange)range
{
  return NSZeroRect;
}

- (NSUInteger)characterIndexForPoint:(NSPoint)point
{
  return NSNotFound;
}

- (NSArray *)validAttributesForMarkedText
{
  return [NSArray array];
}

@end

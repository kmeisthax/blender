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

/* UIViewController subclass for drawing and handling input.
 *
 * UI_VIEW_CONTROLLER_BASE_CLASS will be either UIViewController or
 * GLKViewController depending if we use a Metal or OpenGL layer for drawing in
 * the view. We use macros to defined classes for each case, so we don't have
 * to duplicate code as Objective-C does not have multiple inheritance. */

@interface UI_VIEW_CONTROLLER_CLASS : UI_VIEW_CONTROLLER_BASE_CLASS
{
  GHOST_SystemUIKit *systemUIKit;
  GHOST_WindowUIKit *associatedWindow;
}

- (void)initWithView:(UIView*)view;
- (void)setSystemAndWindowUIKit:(GHOST_SystemUIKit *)sysUIKit
                    windowUIKit:(GHOST_WindowUIKit *)winUIKit;
@end

@implementation UI_VIEW_CONTROLLER_CLASS

- (void)initWithView:(UIView*)view {
    [self setView:view];
}

- (void)setSystemAndWindowUIKit:(GHOST_SystemUIKit *)sysUIKit
                    windowUIKit:(GHOST_WindowUIKit *)winUIKit
{
  systemUIKit = sysUIKit;
  associatedWindow = winUIKit;

  composing = false;
  composing_text = nil;

  immediate_draw = false;
}

//TODO: basically all input handling

@end

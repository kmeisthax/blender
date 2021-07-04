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
          Damien Plisson  10/2009
 */

#include <UIKit/UIKit.h>

#include "GHOST_Debug.h"
#include "GHOST_DisplayManagerUIKit.h"

// We do not support multiple monitors at the moment

GHOST_DisplayManagerUIKit::GHOST_DisplayManagerUIKit(void)
{
}

GHOST_TSuccess GHOST_DisplayManagerUIKit::getNumDisplays(GHOST_TUns8 &numDisplays) const
{
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
  
  numDisplays = (GHOST_TUns8)[[UIScreen screens] count];

  [pool drain];
  return GHOST_kSuccess;
}

GHOST_TSuccess GHOST_DisplayManagerUIKit::getNumDisplaySettings(GHOST_TUns8 display,
                                                                GHOST_TInt32 &numSettings) const
{
  numSettings = (GHOST_TInt32)3;  // Width, Height, BitsPerPixel

  return GHOST_kSuccess;
}

GHOST_TSuccess GHOST_DisplayManagerUIKit::getDisplaySetting(GHOST_TUns8 display,
                                                            GHOST_TInt32 index,
                                                            GHOST_DisplaySetting &setting) const
{
  UIScreen *askedDisplay;

  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

  // Screen #0 IS always the main one (unlike AppKit)
  askedDisplay = [[UIScreen screens] objectAtIndex:display];
  if (askedDisplay == nil) {
    [pool drain];
    return GHOST_kFailure;
  }

  //TODO: Does Blender want rotated or unrotated screen size?
  CGRect frame = [askedDisplay nativeBounds];
  setting.xPixels = frame.size.width;
  setting.yPixels = frame.size.height;

  setting.bpp = 24; //UIKit does not appear to provide a way to get this

  setting.frequency = 0;  // No more CRT display...

#ifdef GHOST_DEBUG
  printf("display mode: width=%d, height=%d, bpp=%d, frequency=%d\n",
         setting.xPixels,
         setting.yPixels,
         setting.bpp,
         setting.frequency);
#endif  // GHOST_DEBUG

  [pool drain];
  return GHOST_kSuccess;
}

GHOST_TSuccess GHOST_DisplayManagerUIKit::getCurrentDisplaySetting(
    GHOST_TUns8 display, GHOST_DisplaySetting &setting) const
{
  UIScreen *askedDisplay;

  GHOST_ASSERT(
      (display == kMainDisplay),
      "GHOST_DisplayManagerUIKit::getCurrentDisplaySetting(): only main display is supported");

  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

  // Screen #0 IS always the main one (unlike AppKit)
  askedDisplay = [[UIScreen screens] objectAtIndex:display];
  if (askedDisplay == nil) {
    [pool drain];
    return GHOST_kFailure;
  }

  //TODO: Does Blender want rotated or unrotated screen size?
  CGRect frame = [askedDisplay nativeBounds];
  setting.xPixels = frame.size.width;
  setting.yPixels = frame.size.height;

  setting.bpp = 24; //UIKit does not appear to provide a way to get this

  setting.frequency = 0;  // No more CRT display...

#ifdef GHOST_DEBUG
  printf("current display mode: width=%d, height=%d, bpp=%d, frequency=%d\n",
         setting.xPixels,
         setting.yPixels,
         setting.bpp,
         setting.frequency);
#endif  // GHOST_DEBUG

  [pool drain];
  return GHOST_kSuccess;
}

GHOST_TSuccess GHOST_DisplayManagerUIKit::setCurrentDisplaySetting(
    GHOST_TUns8 display, const GHOST_DisplaySetting &setting)
{
  GHOST_ASSERT(
      (display == kMainDisplay),
      "GHOST_DisplayManagerUIKit::setCurrentDisplaySetting(): only main display is supported");

#ifdef GHOST_DEBUG
  printf("GHOST_DisplayManagerUIKit::setCurrentDisplaySetting(): requested settings:\n");
  printf("  setting.xPixels=%d\n", setting.xPixels);
  printf("  setting.yPixels=%d\n", setting.yPixels);
  printf("  setting.bpp=%d\n", setting.bpp);
  printf("  setting.frequency=%d\n", setting.frequency);
#endif  // GHOST_DEBUG

  // Display configuration was never available on iOS, fail silently
  return GHOST_kSuccess;
}

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
 * The Original Code is Copyright (C) 2013 Blender Foundation.
 * All rights reserved.
 */

/** \file
 * \ingroup GHOST
 *
 * Definition of GHOST_ContextEAGL class.
 */

#import <OpenGLES/ES2/gl.h>
#include "GHOST_ContextEAGL.h"

#include <CoreGraphics/CGGeometry.h>
#include <UIKit/UIKit.h>
#include <Metal/Metal.h>
#include <QuartzCore/QuartzCore.h>
#include <GLKit/GLKit.h>

#include <cassert>
#include <vector>

static void ghost_fatal_error_dialog(const char *msg)
{
  /* clang-format off */
  @autoreleasepool {
    /* clang-format on */
    NSString *message = [NSString stringWithFormat:@"Error opening window:\n%s", msg];

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Blender"
        message:message
        preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction *defaultAction = [UIAlertAction actionWithTitle:@"Quit"
        style:UIAlertActionStyleDefault
        handler:^(UIAlertAction *action) {exit(1);}];
    
    [alert addAction:defaultAction];

    //TODO: This code assumes all active scenes are going to be equally viable
    //to deliver alerts in.
    UIWindowScene* scene = (UIWindowScene *)[[[UIApplication sharedApplication] connectedScenes] anyObject];
    if (!scene) {
        exit(1); //can't do anything without a scene to connect this alert to
    }

    UIWindow* window = [[scene windows] firstObject];
    if (!window) {
        exit(1); //...or a window
    }

    UIViewController* controller = [window rootViewController];
    if (!controller) {
        exit(1); //...or a view controller
    }

    [controller presentViewController:alert animated:YES completion:nil];
  }

  exit(1);
}

EAGLContext *GHOST_ContextEAGL::s_sharedOpenGLContext = nil;
int GHOST_ContextEAGL::s_sharedCount = 0;

GHOST_ContextEAGL::GHOST_ContextEAGL(bool stereoVisual,
                                   UIView *metalView,
                                   CAMetalLayer *metalLayer,
                                   GLKView *openGLView)
    : GHOST_Context(stereoVisual),
      m_metalView(metalView),
      m_metalLayer(metalLayer),
      m_metalCmdQueue(nil),
      m_metalRenderPipeline(nil),
      m_openGLView(openGLView),
      m_openGLContext(nil),
      m_defaultFramebuffer(0),
      m_defaultFramebufferMetalTexture(nil),
      m_debug(false)
{
#if defined(WITH_GL_PROFILE_CORE)
  m_coreProfile = true;
#else
  m_coreProfile = false;
#endif

  if (m_metalView) {
    metalInit();
  }
}

GHOST_ContextEAGL::~GHOST_ContextEAGL()
{
  metalFree();

  if (m_openGLContext != nil) {
    if (m_openGLContext == [EAGLContext currentContext]) {
      //TODO: How do you clear the context off of GLKView?
    }

    if (m_openGLContext != s_sharedOpenGLContext || s_sharedCount == 1) {
      assert(s_sharedCount > 0);

      s_sharedCount--;

      if (s_sharedCount == 0)
        s_sharedOpenGLContext = nil;

      [m_openGLContext release];
    }
  }
}

GHOST_TSuccess GHOST_ContextEAGL::swapBuffers()
{
  if (m_openGLContext != nil) {
    if (m_metalView) {
      metalSwapBuffers();
    }
    else if (m_openGLView) {
      NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
      //TODO: how do flush buffers on iPad
      [pool drain];
    }
    return GHOST_kSuccess;
  }
  else {
    return GHOST_kFailure;
  }
}

GHOST_TSuccess GHOST_ContextEAGL::setSwapInterval(int interval)
{
  if (m_openGLContext != nil) {
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    //TODO: how do swap intervals on iPad
    //[m_openGLContext setValues:&interval forParameter:NSOpenGLCPSwapInterval];
    [pool drain];
    return GHOST_kSuccess;
  }
  else {
    return GHOST_kFailure;
  }
}

GHOST_TSuccess GHOST_ContextEAGL::getSwapInterval(int &intervalOut)
{
  if (m_openGLContext != nil) {
    GLint interval;

    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

    //TODO: how do swap intervals on ipad
    //[m_openGLContext getValues:&interval forParameter:NSOpenGLCPSwapInterval];

    [pool drain];

    intervalOut = static_cast<int>(interval);

    return GHOST_kSuccess;
  }
  else {
    return GHOST_kFailure;
  }
}

GHOST_TSuccess GHOST_ContextEAGL::activateDrawingContext()
{
  if (m_openGLContext != nil) {
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    [EAGLContext setCurrentContext:m_openGLContext];
    [pool drain];
    return GHOST_kSuccess;
  }
  else {
    return GHOST_kFailure;
  }
}

GHOST_TSuccess GHOST_ContextEAGL::releaseDrawingContext()
{
  if (m_openGLContext != nil) {
    //iPadOS does not allow setting a nil drawing context
    return GHOST_kSuccess;
  }
  else {
    return GHOST_kFailure;
  }
}

unsigned int GHOST_ContextEAGL::getDefaultFramebuffer()
{
  return m_defaultFramebuffer;
}

GHOST_TSuccess GHOST_ContextEAGL::updateDrawingContext()
{
  if (m_openGLContext != nil) {
    if (m_metalView) {
      metalUpdateFramebuffer();
    }
    else if (m_openGLView) {
      //the Cocoa version of this sends `update` but EAGLContext doesn't do that
    }

    return GHOST_kSuccess;
  }
  else {
    return GHOST_kFailure;
  }
}

GHOST_TSuccess GHOST_ContextEAGL::initializeDrawingContext()
{
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

#ifdef GHOST_OPENGL_ALPHA
  static const bool needAlpha = true;
#else
  static const bool needAlpha = false;
#endif

  //makeAttribList(attribs, m_coreProfile, m_stereoVisual, needAlpha, softwareGL);

  if (s_sharedOpenGLContext != nil) {
    m_openGLContext = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES3
      sharegroup:[s_sharedOpenGLContext sharegroup]];
  } else {
    m_openGLContext = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES3];
  }

  if (m_openGLContext == nil) {
    goto error;
  }

  [EAGLContext setCurrentContext:m_openGLContext];

  if (m_debug) {
    fprintf(stderr, "OpenGL ES version (something?)\n"); //TODO: Cannot get GLES version on iPadOS
    fprintf(stderr, "Renderer: %s\n", glGetString(GL_RENDERER));
  }

#ifdef GHOST_WAIT_FOR_VSYNC
  {
    GLint swapInt = 1;
    /* Wait for vertical-sync, to avoid tearing artifacts. */
    //TODO: How do you wait for vsync on iPadOS?
  }
#endif

  initContextGLEW();

  if (m_metalView) {
    if (m_defaultFramebuffer == 0) {
      // Create a virtual framebuffer
      [EAGLContext setCurrentContext:m_openGLContext];
      metalInitFramebuffer();
      initClearGL();
    }
  }
  else if (m_openGLView) {
    [m_openGLView setContext:m_openGLContext];
    initClearGL();
  }

  if (s_sharedCount == 0)
    s_sharedOpenGLContext = m_openGLContext;

  s_sharedCount++;

  [pool drain];

  return GHOST_kSuccess;

error:

  [pool drain];

  return GHOST_kFailure;
}

GHOST_TSuccess GHOST_ContextEAGL::releaseNativeHandles()
{
  m_openGLContext = nil;
  m_openGLView = nil;
  m_metalView = nil;

  return GHOST_kSuccess;
}

/* OpenGL on Metal
 *
 * Use Metal layer to avoid Viewport lagging on macOS, see T60043. */

static const MTLPixelFormat METAL_FRAMEBUFFERPIXEL_FORMAT = MTLPixelFormatBGRA8Unorm;
static const OSType METAL_CORE_VIDEO_PIXEL_FORMAT = kCVPixelFormatType_32BGRA;

void GHOST_ContextEAGL::metalInit()
{
  /* clang-format off */
  @autoreleasepool {
    /* clang-format on */
    id<MTLDevice> device = m_metalLayer.device;

    // Create a command queue for blit/present operation
    m_metalCmdQueue = (MTLCommandQueue *)[device newCommandQueue];
    [m_metalCmdQueue retain];

    // Create shaders for blit operation
    NSString *source = @R"msl(
      using namespace metal;

      struct Vertex {
        float4 position [[position]];
        float2 texCoord [[attribute(0)]];
      };

      vertex Vertex vertex_shader(uint v_id [[vertex_id]]) {
        Vertex vtx;

        vtx.position.x = float(v_id & 1) * 4.0 - 1.0;
        vtx.position.y = float(v_id >> 1) * 4.0 - 1.0;
        vtx.position.z = 0.0;
        vtx.position.w = 1.0;

        vtx.texCoord = vtx.position.xy * 0.5 + 0.5;

        return vtx;
      }

      constexpr sampler s {};

      fragment float4 fragment_shader(Vertex v [[stage_in]],
                      texture2d<float> t [[texture(0)]]) {
        return t.sample(s, v.texCoord);
      }

      )msl";

    MTLCompileOptions *options = [[[MTLCompileOptions alloc] init] autorelease];
    options.languageVersion = MTLLanguageVersion1_1;

    NSError *error = nil;
    id<MTLLibrary> library = [device newLibraryWithSource:source options:options error:&error];
    if (error) {
      ghost_fatal_error_dialog(
          "GHOST_ContextEAGL::metalInit: newLibraryWithSource:options:error: failed!");
    }

    // Create a render pipeline for blit operation
    MTLRenderPipelineDescriptor *desc = [[[MTLRenderPipelineDescriptor alloc] init] autorelease];

    desc.fragmentFunction = [library newFunctionWithName:@"fragment_shader"];
    desc.vertexFunction = [library newFunctionWithName:@"vertex_shader"];

    [desc.colorAttachments objectAtIndexedSubscript:0].pixelFormat = METAL_FRAMEBUFFERPIXEL_FORMAT;

    m_metalRenderPipeline = (MTLRenderPipelineState *)[device
        newRenderPipelineStateWithDescriptor:desc
                                       error:&error];
    if (error) {
      ghost_fatal_error_dialog(
          "GHOST_ContextEAGL::metalInit: newRenderPipelineStateWithDescriptor:error: failed!");
    }
  }
}

void GHOST_ContextEAGL::metalFree()
{
  if (m_metalCmdQueue) {
    [m_metalCmdQueue release];
  }
  if (m_metalRenderPipeline) {
    [m_metalRenderPipeline release];
  }
  if (m_defaultFramebufferMetalTexture) {
    [m_defaultFramebufferMetalTexture release];
  }
}

void GHOST_ContextEAGL::metalInitFramebuffer()
{
  glGenFramebuffers(1, &m_defaultFramebuffer);
  updateDrawingContext();
  glBindFramebuffer(GL_FRAMEBUFFER, m_defaultFramebuffer);
}

void GHOST_ContextEAGL::metalUpdateFramebuffer()
{
  assert(m_defaultFramebuffer != 0);

  CGRect bounds = [m_metalView bounds];
  CGSize backingSize = bounds.size; //TODO: Backing size?
  size_t width = (size_t)backingSize.width;
  size_t height = (size_t)backingSize.height;

  {
    /* Test if there is anything to update */
    id<MTLTexture> tex = (id<MTLTexture>)m_defaultFramebufferMetalTexture;
    if (tex && tex.width == width && tex.height == height) {
      return;
    }
  }

  activateDrawingContext();

  NSDictionary *cvPixelBufferProps = @{
    (__bridge NSString *)kCVPixelBufferOpenGLCompatibilityKey : @YES,
    (__bridge NSString *)kCVPixelBufferMetalCompatibilityKey : @YES,
  };
  CVPixelBufferRef cvPixelBuffer = nil;
  CVReturn cvret = CVPixelBufferCreate(kCFAllocatorDefault,
                                       width,
                                       height,
                                       METAL_CORE_VIDEO_PIXEL_FORMAT,
                                       (__bridge CFDictionaryRef)cvPixelBufferProps,
                                       &cvPixelBuffer);
  if (cvret != kCVReturnSuccess) {
    ghost_fatal_error_dialog(
        "GHOST_ContextEAGL::metalUpdateFramebuffer: CVPixelBufferCreate failed!");
  }

  // Create an OpenGL texture
  CVOpenGLESTextureCacheRef cvGLTexCache = nil;
  cvret = CVOpenGLESTextureCacheCreate(kCFAllocatorDefault,
                                     nil,
                                     m_openGLContext,
                                     nil,
                                     &cvGLTexCache);
  if (cvret != kCVReturnSuccess) {
    ghost_fatal_error_dialog(
        "GHOST_ContextEAGL::metalUpdateFramebuffer: CVOpenGLTextureCacheCreate failed!");
  }

  CVOpenGLESTextureRef cvGLTex = nil;
  cvret = CVOpenGLESTextureCacheCreateTextureFromImage(
      kCFAllocatorDefault, cvGLTexCache, cvPixelBuffer, nil,
      GL_TEXTURE_2D, GL_RGBA, width, height, GL_RGBA, GL_UNSIGNED_BYTE, 0,
      &cvGLTex);
  if (cvret != kCVReturnSuccess) {
    ghost_fatal_error_dialog(
        "GHOST_ContextEAGL::metalUpdateFramebuffer: "
        "CVOpenGLTextureCacheCreateTextureFromImage failed!");
  }

  unsigned int glTex;
  glTex = CVOpenGLESTextureGetName(cvGLTex);

  // Create a Metal texture
  CVMetalTextureCacheRef cvMetalTexCache = nil;
  cvret = CVMetalTextureCacheCreate(
      kCFAllocatorDefault, nil, m_metalLayer.device, nil, &cvMetalTexCache);
  if (cvret != kCVReturnSuccess) {
    ghost_fatal_error_dialog(
        "GHOST_ContextEAGL::metalUpdateFramebuffer: CVMetalTextureCacheCreate failed!");
  }

  CVMetalTextureRef cvMetalTex = nil;
  cvret = CVMetalTextureCacheCreateTextureFromImage(kCFAllocatorDefault,
                                                    cvMetalTexCache,
                                                    cvPixelBuffer,
                                                    nil,
                                                    METAL_FRAMEBUFFERPIXEL_FORMAT,
                                                    width,
                                                    height,
                                                    0,
                                                    &cvMetalTex);
  if (cvret != kCVReturnSuccess) {
    ghost_fatal_error_dialog(
        "GHOST_ContextEAGL::metalUpdateFramebuffer: "
        "CVMetalTextureCacheCreateTextureFromImage failed!");
  }

  MTLTexture *tex = (MTLTexture *)CVMetalTextureGetTexture(cvMetalTex);

  if (!tex) {
    ghost_fatal_error_dialog(
        "GHOST_ContextEAGL::metalUpdateFramebuffer: CVMetalTextureGetTexture failed!");
  }

  [m_defaultFramebufferMetalTexture release];
  m_defaultFramebufferMetalTexture = [tex retain];

  glBindFramebuffer(GL_FRAMEBUFFER, m_defaultFramebuffer);
  glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, glTex, 0);

  [m_metalLayer setDrawableSize:CGSizeMake((CGFloat)width, (CGFloat)height)];

  CVPixelBufferRelease(cvPixelBuffer);
  CFRelease(cvGLTexCache);
  CFRelease(cvGLTex);
  CFRelease(cvMetalTexCache);
  CFRelease(cvMetalTex);
}

void GHOST_ContextEAGL::metalSwapBuffers()
{
  /* clang-format off */
  @autoreleasepool {
    /* clang-format on */
    updateDrawingContext();
    glFlush();

    assert(m_defaultFramebufferMetalTexture != 0);

    id<CAMetalDrawable> drawable = [m_metalLayer nextDrawable];
    if (!drawable) {
      return;
    }

    id<MTLCommandBuffer> cmdBuffer = [m_metalCmdQueue commandBuffer];

    MTLRenderPassDescriptor *passDescriptor = [MTLRenderPassDescriptor renderPassDescriptor];
    {
      auto attachment = [passDescriptor.colorAttachments objectAtIndexedSubscript:0];
      attachment.texture = drawable.texture;
      attachment.loadAction = MTLLoadActionDontCare;
      attachment.storeAction = MTLStoreActionStore;
    }

    id<MTLTexture> srcTexture = (id<MTLTexture>)m_defaultFramebufferMetalTexture;

    {
      id<MTLRenderCommandEncoder> enc = [cmdBuffer
          renderCommandEncoderWithDescriptor:passDescriptor];

      [enc setRenderPipelineState:(id<MTLRenderPipelineState>)m_metalRenderPipeline];
      [enc setFragmentTexture:srcTexture atIndex:0];
      [enc drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:3];

      [enc endEncoding];
    }

    [cmdBuffer presentDrawable:drawable];

    [cmdBuffer commit];
  }
}

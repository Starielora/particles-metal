#pragma once

#import <MetalKit/MetalKit.h>
#include <TargetConditionals.h>

@interface RendererWrapper : NSObject
#if TARGET_OS_OSX
- (id) initWithDevice:(id<MTLDevice>)gpu view:(NSView*)view;
#else
- (id) initWithDevice:(id<MTLDevice>)gpu view:(UIView*)view;
#endif
- (void) draw:(MTKView*)view;
- (void) toggleShouldEmit;
- (void) setEmitPos:(double)x :(double)y;
- (void) setWindowSize:(float)w :(float)h;
#if TARGET_OS_OSX
- (void) forwardEventToImGui:(NSEvent*)event;
#else
- (void) forwardEventToImGui:(UIEvent*)event;
#endif
- (void) resize:(int)width :(int)height;
@end

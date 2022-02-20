#pragma once

#import <MetalKit/MetalKit.h>

@interface RendererWrapper : NSObject
- (id) initWithDevice:(id<MTLDevice>) gpu: (NSView*)view;
- (void) draw:(MTKView*) view;
- (void) toggleShouldEmit;
- (void) setEmitPos:(double)x: (double) y;
- (void) setWindowSize:(float)w: (float) h;
- (void) forwardEventToImGui:(NSEvent*)event;
- (void) resize:(int)width: (int) height;
@end

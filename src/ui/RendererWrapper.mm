#include "RendererWrapper.h"
#include "Renderer.h"

#include <TargetConditionals.h>

#include <memory>

@implementation RendererWrapper

std::unique_ptr<particles::metal::Renderer> renderer;

#if TARGET_OS_IPHONE
- (id) initWithDevice:(id<MTLDevice>)gpu view:(UIView*)view
#elif TARGET_OS_OSX
- (id) initWithDevice:(id<MTLDevice>)gpu view:(NSView*)view
#endif
{
    renderer = std::make_unique<particles::metal::Renderer>(view, gpu);
    return self;
}

- (void) draw:(MTKView*)view
{
    renderer->draw(view);
}

- (void) toggleShouldEmit
{
    renderer->toggleShouldEmit();
}

- (void) setEmitPos:(double)x :(double)y
{
    renderer->setEmitPos(x, y);
}

- (void) setWindowSize:(float)w :(float)h
{
    renderer->setWindowSize(w, h);
    renderer->resize(w, h); // TODO merge both
}

#if TARGET_OS_IPHONE
- (void) forwardEventToImGui:(UIEvent*)event
#elif TARGET_OS_OSX
- (void) forwardEventToImGui:(NSEvent*)event
#endif
{
    renderer->forwardEventToImgui(event);
}

- (void) resize:(int)width :(int)height
{
    renderer->resize(width, height);
}

@end

#include "RendererWrapper.h"
#include "Renderer.h"

#include <memory>

@implementation RendererWrapper

std::unique_ptr<particles::metal::Renderer> renderer;

- (id) initWithDevice:(id<MTLDevice>)gpu view:(UIView*)view;
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

- (void) forwardEventToImGui:(UIEvent*)event
{
    renderer->forwardEventToImgui(event);
}

- (void) resize:(int)width :(int)height
{
    renderer->resize(width, height);
}

@end

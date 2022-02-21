#pragma once

#include "Particle.h"
#include "Emitter.h"
#include "Camera.h"

#include <Metal/Metal.h>
#include <MetalKit/MetalKit.h>
#include <TargetConditionals.h>

#include <list>

namespace particles::metal
{
    class Renderer
    {
    public:

#if TARGET_OS_IPHONE
        Renderer(UIView*, id<MTLDevice>);
#elif TARGET_OS_OSX
        Renderer(NSView*, id<MTLDevice>);
#endif
        ~Renderer();

        void draw(MTKView*);

        void setEmitPos(double x, double y);
        void setWindowSize(float w, float h);

        // TODO toggling may spawn interesting bugs, related to state, later on
        void toggleShouldEmit() { _shouldEmit = !_shouldEmit; }

#if TARGET_OS_IPHONE
        void forwardEventToImgui(UIEvent*);
#elif TARGET_OS_OSX
        void forwardEventToImgui(NSEvent*);
#endif

        void resize(int width, int height);

    private:
        const id<MTLDevice> _gpu;
        const id<MTLCommandQueue> _commandQueue;
        const id<MTLLibrary> _shadersLibrary;

#if TARGET_OS_IPHONE
        UIView* const _view;
#elif TARGET_OS_OSX
        NSView* const _view;
#endif

        std::list<particles::metal::Emitter> _emitters;
        particles::metal::Emitter::Descriptor _emitterDescriptor;
        Camera camera;

        bool _shouldEmit = false;
        glm::vec2 _windowSize; // TODO initialize. Maybe in constructor?

        id<MTLTexture> _particlesTexture;
        id<MTLTexture> _blurTexture;
        id<MTLTexture> _bloomTexture;
        id<MTLTexture> _finalTexture;

    private:
        void processState();
        void initTextures(int width, int height);
    };
}


#pragma once

#include "Particle.h"
#include "Emitter.h"
#include "Camera.h"

#include <Metal/Metal.h>
#include <MetalKit/MetalKit.h>

#include <list>

namespace particles::metal
{
    class Renderer
    {
    public:
        Renderer(NSView*, id<MTLDevice>);
        ~Renderer();

        void draw(MTKView*);
//        void onClick(double x, double y);

        void setEmitPos(double x, double y);
        void setWindowSize(float w, float h);

        // TODO toggling may spawn interesting bugs later on
        void toggleShouldEmit() { _shouldEmit = !_shouldEmit; }

        void forwardEventToImgui(NSEvent*);

        void resize(int width, int height);

    private:
        const id<MTLDevice> _gpu;
        const id<MTLCommandQueue> _commandQueue;
        const id<MTLLibrary> _shadersLibrary;
        NSView* const _view;

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


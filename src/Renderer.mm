#include "Renderer.h"
#include "Particle.h"
#include "Emitter.h"
#include "Camera.h"
#include "ui/imgui.h"

#include <MetalPerformanceShaders/MetalPerformanceShaders.h>

#include <vector>
#include <chrono>

namespace particles::metal
{
    namespace
    {
        std::vector<float> FPS_VALUES(100, 0);
        int aliveParticles = 0;
        bool blur = true;
        bool bloom = true;
        float blurSigma = 9.0f;
        int bloomIterations = 1;
    }

#if TARGET_OS_IPHONE
    Renderer::Renderer(UIView* view, id<MTLDevice> gpu)
#elif TARGET_OS_OSX
    Renderer::Renderer(NSView* view, id<MTLDevice> gpu)
#endif
        : _gpu(gpu)
        , _commandQueue([_gpu newCommandQueue])
        , _shadersLibrary([_gpu newDefaultLibrary])
        , _view(view)
    {
#if TARGET_OS_IPHONE
        imgui::init(_gpu);
#elif TARGET_OS_OSX
        imgui::init(_view, _gpu);
#endif
        initTextures(_view.bounds.size.width, _view.bounds.size.height);
    }

    void Renderer::resize(int width, int height)
    {
        initTextures(width, height);
    }

    Renderer::~Renderer()
    {
        imgui::deinit();
    }

    void Renderer::initTextures(int width, int height)
    {
        @autoreleasepool {
            MTLTextureDescriptor* textureDescriptor = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatBGRA8Unorm width:width height:height mipmapped:false];
            textureDescriptor.usage = (MTLTextureUsageShaderRead | MTLTextureUsageShaderWrite | MTLTextureUsageRenderTarget);
            textureDescriptor.storageMode = MTLStorageModePrivate;

            _particlesTexture = [_gpu newTextureWithDescriptor:textureDescriptor];
            _blurTexture = [_gpu newTextureWithDescriptor:textureDescriptor];
            _bloomTexture = [_gpu newTextureWithDescriptor:textureDescriptor];
            _finalTexture = [_gpu newTextureWithDescriptor:textureDescriptor];
        }
    }

    void Renderer::draw(MTKView* view)
    {
        const auto drawable = [view currentDrawable];
        const auto rpd = [view currentRenderPassDescriptor];

        ImGuiIO& io = ImGui::GetIO();
        io.DisplaySize.x = view.bounds.size.width;
        io.DisplaySize.y = view.bounds.size.height;
        CGFloat framebufferScale = view.window.screen.scale ?: UIScreen.mainScreen.scale;
        io.DisplayFramebufferScale = ImVec2(framebufferScale, framebufferScale);

        static auto LAST_FRAME = std::chrono::steady_clock::now();
        const auto currentFrame = std::chrono::steady_clock::now();
        const auto deltaTimeMs = std::chrono::duration_cast<std::chrono::milliseconds>(currentFrame - LAST_FRAME).count();
        const auto deltaTime = float(deltaTimeMs) / 1000.f;
        LAST_FRAME = currentFrame;

        io.DeltaTime = deltaTime;

        FPS_VALUES.erase(FPS_VALUES.begin());
        FPS_VALUES.push_back(1.f / deltaTime);

        processState();

        @autoreleasepool {

            auto drawable = [view currentDrawable];
            MTLRenderPassDescriptor *rpd = [view currentRenderPassDescriptor];
            rpd.colorAttachments[0].texture = _particlesTexture;
            id<MTLCommandBuffer> commandBuffer = [_commandQueue commandBuffer];

            // Particles render pass
            {
                for (auto&& emitter : _emitters)
                {
                    emitter.update(commandBuffer);
                }

                id<MTLRenderCommandEncoder> encoder = [commandBuffer renderCommandEncoderWithDescriptor:rpd];
                for (auto emitter = _emitters.begin(); emitter != _emitters.end(); emitter++)
                {
                    if (emitter->isDead())
                    {
                        emitter = _emitters.erase(emitter);
                    }
                    else
                    {
                        emitter->draw(rpd, camera, encoder, _windowSize.x, _windowSize.y);
                        aliveParticles += emitter->descriptor().particlesCount;
                    }
                }

                // TODO yeet this to separate encoder
                [encoder endEncoding];
            }

            _finalTexture = _particlesTexture;

            // Particles blur pass
            {
                if (blur)
                {
                    MPSImageGaussianBlur* gaussianBlur = [[MPSImageGaussianBlur alloc] initWithDevice:_gpu sigma:blurSigma];
                    gaussianBlur.label = [NSString stringWithUTF8String:"MPS Gaussian blur"];
                    [gaussianBlur encodeToCommandBuffer:commandBuffer sourceTexture:_particlesTexture destinationTexture:_blurTexture];
                    _finalTexture = _blurTexture;
                }
            }

            // Particle blend pass
            {
                if (bloom)
                {
                    MPSImageAdd* add = [[MPSImageAdd alloc] initWithDevice:_gpu];
                    [add encodeToCommandBuffer:commandBuffer primaryTexture:_finalTexture secondaryTexture:_particlesTexture destinationTexture:_bloomTexture];
                    _finalTexture = _bloomTexture;
                }
            }

            rpd.colorAttachments[0].loadAction  = MTLLoadActionLoad;
            rpd.colorAttachments[0].texture = _finalTexture;
            id<MTLRenderCommandEncoder> imguiEncoder = [commandBuffer renderCommandEncoderWithDescriptor:rpd];
            particles::metal::imgui::newFrame(rpd);
            particles::imgui::drawCameraPane(camera);
            particles::imgui::drawFpsPlot(FPS_VALUES);
            particles::imgui::drawParticleSystemPane(_emitterDescriptor, aliveParticles, blur, bloom, blurSigma, bloomIterations);
            aliveParticles = 0;
            particles::metal::imgui::render(commandBuffer, imguiEncoder);
            [imguiEncoder endEncoding];

            id<MTLBlitCommandEncoder> blit = [commandBuffer blitCommandEncoder];
            [blit copyFromTexture:_finalTexture toTexture:drawable.texture];
            [blit endEncoding];

            [commandBuffer presentDrawable:drawable];
            [commandBuffer commit];
            [commandBuffer waitUntilCompleted];
        }
    }

    void Renderer::setEmitPos(double xpos, double ypos)
    {
        const auto xTrans = ((xpos / _windowSize.x) * 2 - 1);
        const auto yTrans = ((ypos / _windowSize.y) * 2 - 1);

        const auto invProjection = glm::inverse(camera.projection(_windowSize.x, _windowSize.y)); // go back to camera coordinates
        const auto offsetFromCamera = glm::vec3(invProjection * glm::vec4{ xTrans, -yTrans, 1, 1 });

        auto worldPos = camera.position() + offsetFromCamera;

        _emitterDescriptor.worldPos = simd_make_float3(worldPos.x, worldPos.y, worldPos.z);
    }

    void Renderer::setWindowSize(float w, float h)
    {
        _windowSize = glm::vec2(w / _view.window.screen.scale, h / _view.window.screen.scale);
    }

    void Renderer::processState()
    {
        if (_shouldEmit)
        {
            auto emitter = particles::metal::Emitter(_emitterDescriptor, _gpu, _shadersLibrary, _commandQueue);
            _emitters.push_back(emitter);
        }
    }

#if TARGET_OS_OSX
    void Renderer::forwardEventToImgui(NSEvent* event)
    {
        ImGui_ImplOSX_HandleEvent(event, _view);
    }
#elif TARGET_OS_IPHONE
    void Renderer::forwardEventToImgui(UIEvent* event)
    {
        UITouch *anyTouch = event.allTouches.anyObject;
        CGPoint touchLocation = [anyTouch locationInView:_view];
        ImGuiIO &io = ImGui::GetIO();
        io.AddMousePosEvent(touchLocation.x, touchLocation.y);

        BOOL hasActiveTouch = NO;
        for (UITouch *touch in event.allTouches)
        {
            if (touch.phase != UITouchPhaseEnded && touch.phase != UITouchPhaseCancelled)
            {
                hasActiveTouch = YES;
                break;
            }
        }
        io.AddMouseButtonEvent(0, hasActiveTouch);
    }
#endif
}

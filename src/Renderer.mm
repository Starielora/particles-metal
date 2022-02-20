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

    Renderer::Renderer(NSView* view, id<MTLDevice> gpu)
        : _gpu(gpu)
        , _commandQueue([_gpu newCommandQueue])
        , _shadersLibrary([_gpu newDefaultLibrary])
        , _view(view)
    {
        imgui::init(_view, _gpu);
        initTextures(view.bounds.size.width, view.bounds.size.height);
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
        const auto commandBuffer = [_commandQueue commandBuffer];

//        static auto LAST_FRAME = std::chrono::steady_clock::now();
//        const auto currentFrame = std::chrono::steady_clock::now();
//        const auto deltaTimeMs = std::chrono::duration_cast<std::chrono::milliseconds>(currentFrame - LAST_FRAME).count();
//        const auto deltaTime = float(deltaTimeMs) / 1000.f;
//        LAST_FRAME = currentFrame;

//        FPS_VALUES.erase(FPS_VALUES.begin());
//        FPS_VALUES.push_back(1.f / deltaTime);

        processState();

        @autoreleasepool {

            auto drawable = [view currentDrawable];
            MTLRenderPassDescriptor *rpd = [view currentRenderPassDescriptor];
            // pass.colorAttachments[0].clearColor = color;
//            particlesRenderPass.colorAttachments[0].loadAction  = MTLLoadActionClear;
//            particlesRenderPass.colorAttachments[0].storeAction = MTLStoreActionStore;
//            particlesRenderPass.colorAttachments[0].texture = drawable.texture;
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
            particles::metal::imgui::newFrame(rpd, _view);
            particles::imgui::drawCameraPane(camera);
//            particles::imgui::drawFpsPlot(FPS_VALUES); TODO something is very wrong with this on osx
            particles::imgui::drawParticleSystemPane(_emitterDescriptor, aliveParticles, blur, bloom, blurSigma, bloomIterations);
            aliveParticles = 0;
            particles::metal::imgui::render(commandBuffer, imguiEncoder);
            [imguiEncoder endEncoding];

            id<MTLBlitCommandEncoder> blit = [commandBuffer blitCommandEncoder];
            [blit copyFromTexture:_finalTexture toTexture:drawable.texture];
            [blit endEncoding];

            [commandBuffer presentDrawable:drawable];
            [commandBuffer commit];
        }
    }

    void Renderer::setEmitPos(double xpos, double ypos)
    {
        const auto xTrans = ((xpos / _windowSize.x) * 2 - 1);
        const auto yTrans = ((ypos / _windowSize.y) * 2 - 1);

        const auto invProjection = glm::inverse(camera.projection(_windowSize.x, _windowSize.y)); // go back to camera coordinates
        const auto offsetFromCamera = glm::vec3(invProjection * glm::vec4{ xTrans, yTrans, 1, 1 });

        auto worldPos = camera.position() + offsetFromCamera;

        _emitterDescriptor.worldPos = simd_make_float3(worldPos.x, worldPos.y, worldPos.z);
    }

    void Renderer::setWindowSize(float w, float h)
    {
        _windowSize = glm::vec2(w, h);
    }

    void Renderer::processState()
    {
        if (_shouldEmit)
        {
            auto emitter = particles::metal::Emitter(_emitterDescriptor, _gpu, _shadersLibrary, _commandQueue);
            _emitters.push_back(emitter);
        }
    }

    void Renderer::forwardEventToImgui(NSEvent* event)
    {
        ImGui_ImplOSX_HandleEvent(event, _view);
    }
}

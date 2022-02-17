#include "Particle.h"
#include "Emitter.h"
#include "Camera.h"
#include "ui/imgui.h"

#define GLFW_INCLUDE_NONE
#define GLFW_EXPOSE_NATIVE_COCOA
#include <GLFW/glfw3.h>
#include <GLFW/glfw3native.h>

#include <iostream>
#include <fstream>
#include <string>
#include <filesystem>

#import <Metal/Metal.h>
#include <MetalPerformanceShaders/MetalPerformanceShaders.h>
#import <QuartzCore/QuartzCore.h>

#include <list>

void quit(GLFWwindow *window, int key, int scancode, int action, int mods);
GLFWwindow* createWindow(CAMetalLayer* metalLayer);
CAMetalLayer* createMetalLayer(id<MTLDevice> gpu);
id<MTLComputePipelineState> createPipelineState(id<MTLDevice> gpu);
id<MTLLibrary> createLibrary(id<MTLDevice> gpu);
void handleInput(GLFWwindow* window, float t, float deltaTime, Camera& camera, id<MTLDevice>, id<MTLLibrary>, id<MTLCommandBuffer>);

const unsigned int SCR_WIDTH = 1920;
const unsigned int SCR_HEIGHT = 1080;
auto CURRENT_WIDTH = SCR_WIDTH;
auto CURRENT_HEIGHT = SCR_HEIGHT;
float deltaTime = 0.f;
float lastFrame = 0.f;
auto camera = Camera{};
auto emitters = std::list<particles::metal::Emitter>();
auto emitterDescriptor = particles::metal::Emitter::Descriptor{};
int aliveParticles = 0;

bool blur = true;
bool bloom = true;
float blurSigma = 9.0f;
int bloomIterations = 1;

int main()
{
    id<MTLDevice> gpu = MTLCreateSystemDefaultDevice();
    id<MTLCommandQueue> queue = [gpu newCommandQueue];
    auto* const metalLayer = createMetalLayer(gpu);
    auto* const window = createWindow(metalLayer);
    id<MTLLibrary> library = createLibrary(gpu);

    metalLayer.framebufferOnly = false;

    particles::metal::imgui::init(gpu, window);
    std::vector<float> fpsValues(100);

    MTLTextureDescriptor* descriptor = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatBGRA8Unorm width:SCR_WIDTH height:SCR_HEIGHT mipmapped:false];
    descriptor.usage = (MTLTextureUsageShaderRead | MTLTextureUsageShaderWrite | MTLTextureUsageRenderTarget);
    descriptor.storageMode = MTLStorageModePrivate;
    id<MTLTexture> particlesTexture = [gpu newTextureWithDescriptor:descriptor];
    id<MTLTexture> blurTexture = [gpu newTextureWithDescriptor:descriptor];
    id<MTLTexture> bloomTexture = [gpu newTextureWithDescriptor:descriptor];
    id<MTLTexture> finalTexture = [gpu newTextureWithDescriptor:descriptor];

    while (!glfwWindowShouldClose(window))
    {
        glfwPollEvents();
        float currentFrame = glfwGetTime();
        deltaTime = currentFrame - lastFrame;
        lastFrame = currentFrame;

        fpsValues.erase(fpsValues.begin());
        fpsValues.push_back(1.f / deltaTime);

        @autoreleasepool {

            id<CAMetalDrawable> surface = [metalLayer nextDrawable];
            MTLRenderPassDescriptor *particlesRenderPass = [MTLRenderPassDescriptor renderPassDescriptor];
    //        // pass.colorAttachments[0].clearColor = color;
            particlesRenderPass.colorAttachments[0].loadAction  = MTLLoadActionClear;
            particlesRenderPass.colorAttachments[0].storeAction = MTLStoreActionStore;
            particlesRenderPass.colorAttachments[0].texture = particlesTexture;
            id<MTLCommandBuffer> commandBuffer = [queue commandBuffer];
            handleInput(window, currentFrame, deltaTime, camera, gpu, library, commandBuffer);

            // Particles render pass
            {
                for (auto&& emitter : emitters)
                {
                    emitter.update(currentFrame, commandBuffer);
                }

                id<MTLRenderCommandEncoder> encoder = [commandBuffer renderCommandEncoderWithDescriptor:particlesRenderPass];
                for (auto emitter = emitters.begin(); emitter != emitters.end(); emitter++)
                {
                    if (emitter->isDead())
                    {
                        emitter = emitters.erase(emitter);
                    }
                    else
                    {
                        emitter->draw(particlesRenderPass, camera, encoder);
                        aliveParticles += emitter->descriptor().particlesCount;
                    }
                }
                [encoder endEncoding];
            }

            finalTexture = particlesTexture;

            // Particles blur pass
            {
                if (blur)
                {
                    MPSImageGaussianBlur* gaussianBlur = [[MPSImageGaussianBlur alloc] initWithDevice:gpu sigma:blurSigma];
                    gaussianBlur.label = [NSString stringWithUTF8String:"MPS Gaussian blur"];
                    [gaussianBlur encodeToCommandBuffer:commandBuffer sourceTexture:particlesTexture destinationTexture:blurTexture];
                    finalTexture = blurTexture;
                }
            }

            // Particle blend pass
            {
                if (bloom)
                {
                    MPSImageAdd* add = [[MPSImageAdd alloc] initWithDevice:gpu];
                    [add encodeToCommandBuffer:commandBuffer primaryTexture:finalTexture secondaryTexture:particlesTexture destinationTexture:bloomTexture];
                    finalTexture = bloomTexture;
                }
            }

            MTLRenderPassDescriptor *imguiPass = [MTLRenderPassDescriptor renderPassDescriptor];
            imguiPass.colorAttachments[0].loadAction  = MTLLoadActionLoad;
            imguiPass.colorAttachments[0].storeAction = MTLStoreActionStore;
            imguiPass.colorAttachments[0].texture = finalTexture;
            id<MTLRenderCommandEncoder> imguiEncoder = [commandBuffer renderCommandEncoderWithDescriptor:imguiPass];

            particles::metal::imgui::newFrame(imguiPass);
            particles::imgui::drawCameraPane(camera);
            particles::imgui::drawFpsPlot(fpsValues);
            particles::imgui::drawParticleSystemPane(emitterDescriptor, aliveParticles, blur, bloom, blurSigma, bloomIterations);
            aliveParticles = 0;
            particles::metal::imgui::render(commandBuffer, imguiEncoder);
            [imguiEncoder endEncoding];

            id<MTLBlitCommandEncoder> blit = [commandBuffer blitCommandEncoder];
            [blit copyFromTexture:finalTexture toTexture:surface.texture];
            [blit endEncoding];

            [commandBuffer presentDrawable:surface];
            [commandBuffer commit];
        }
    }

    glfwDestroyWindow(window);
    glfwTerminate();

    return EXIT_SUCCESS;
}

void quit(GLFWwindow *window, int key, int scancode, int action, int mods)
{
    if (key == GLFW_KEY_ESCAPE && action == GLFW_PRESS) {
        glfwSetWindowShouldClose(window, GLFW_TRUE);
    }
}

GLFWwindow* createWindow(CAMetalLayer* metalLayer)
{
    if (glfwInit() != GLFW_TRUE)
    {
        std::cerr << "Failed to init glfw.\n";
        exit(EXIT_FAILURE);
    }

    glfwWindowHint(GLFW_CLIENT_API, GLFW_NO_API);

    const auto window = glfwCreateWindow(SCR_WIDTH, SCR_HEIGHT, "particles-metal", nullptr, nullptr);

    if (window == nullptr)
    {
        glfwTerminate();
        std::cerr << "Failed to create window.\n";
        exit(EXIT_FAILURE);
    }

    glfwSetKeyCallback(window, quit);

    NSWindow* nswindow = glfwGetCocoaWindow(window);
    // Could assign MTKView here, but GLFW implements its own NSView which handles keyboard and mouse events
    nswindow.contentView.layer = metalLayer;
    nswindow.contentView.wantsLayer = YES;

    return window;
}

CAMetalLayer* createMetalLayer(id<MTLDevice> gpu)
{
    CAMetalLayer *swapchain = [CAMetalLayer layer];
    swapchain.device = gpu;
    swapchain.opaque = YES;

    return swapchain;
}

id<MTLLibrary> createLibrary(id<MTLDevice> gpu)
{
    NSError* errors;
    id<MTLLibrary> lib = [gpu newLibraryWithFile:@"default.metallib" error:&errors];
    assert(!errors);
    return lib;
}

void handleInput(GLFWwindow* window, float t, float deltaTime, Camera& camera, id<MTLDevice> gpu, id<MTLLibrary> library, id<MTLCommandBuffer> commandBuffer)
{
    if (glfwGetKey(window, GLFW_KEY_ESCAPE) == GLFW_PRESS)
        glfwSetWindowShouldClose(window, true);

        //float cameraSpeed = cameraSpeedMultiplier * deltaTime;
    if (glfwGetKey(window, GLFW_KEY_W) == GLFW_PRESS)
        camera.moveForward(deltaTime);
    if (glfwGetKey(window, GLFW_KEY_S) == GLFW_PRESS)
        camera.moveBack(deltaTime);
    if (glfwGetKey(window, GLFW_KEY_A) == GLFW_PRESS)
        camera.strafeLeft(deltaTime);
    if (glfwGetKey(window, GLFW_KEY_D) == GLFW_PRESS)
        camera.strafeRight(deltaTime);

    if (glfwGetMouseButton(window, GLFW_MOUSE_BUTTON_2) == GLFW_PRESS)
    {
        double xpos, ypos;
        glfwGetCursorPos(window, &xpos, &ypos);

        const auto xTrans = ((xpos / CURRENT_WIDTH) * 2 - 1);
        const auto yTrans = ((ypos / CURRENT_HEIGHT) * 2 - 1);

        const auto invProjection = glm::inverse(camera.projection(CURRENT_WIDTH, CURRENT_HEIGHT)); // go back to camera coordinates
        const auto offsetFromCamera = glm::vec3(invProjection * glm::vec4{ xTrans,-yTrans, 1, 1 });

        auto worldPos = camera.position() + offsetFromCamera;

        {
            emitterDescriptor.worldPos = simd_make_float3(worldPos.x, worldPos.y, worldPos.z);
            auto emitter = particles::metal::Emitter(emitterDescriptor, gpu, library, commandBuffer);
            emitters.push_back(emitter);
        }
    }
}

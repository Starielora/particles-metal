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
            MTLRenderPassDescriptor *pass = [MTLRenderPassDescriptor renderPassDescriptor];
    //        // pass.colorAttachments[0].clearColor = color;
            pass.colorAttachments[0].loadAction  = MTLLoadActionClear;
            pass.colorAttachments[0].storeAction = MTLStoreActionStore;
            pass.colorAttachments[0].texture = surface.texture;
            id<MTLCommandBuffer> commandBuffer = [queue commandBuffer];
            handleInput(window, currentFrame, deltaTime, camera, gpu, library, commandBuffer);
            for (auto&& emitter : emitters)
            {
                emitter.update(currentFrame, commandBuffer);
            }

            id<MTLRenderCommandEncoder> encoder = [commandBuffer renderCommandEncoderWithDescriptor:pass];
            for (auto emitter = emitters.begin(); emitter != emitters.end(); emitter++)
            {
                if (emitter->isDead())
                {
                    emitter = emitters.erase(emitter);
                }
                else
                {
                    emitter->draw(pass, camera, encoder);
                    aliveParticles += emitter->descriptor().particlesCount;
                }
            }

            particles::metal::imgui::newFrame(pass);
            particles::imgui::drawCameraPane(camera);
            particles::imgui::drawFpsPlot(fpsValues);
            particles::imgui::drawParticleSystemPane(emitterDescriptor, aliveParticles);
            aliveParticles = 0;
            particles::metal::imgui::render(commandBuffer, encoder);

            [encoder endEncoding];
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

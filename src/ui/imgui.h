#pragma once

#include "Camera.h"
#include "Emitter.h"

#include <glm/gtc/type_ptr.hpp>

#include <imgui.h>
#if TARGET_OS_OSX
#include <imgui_impl_osx.h>
#endif
#include <imgui_impl_metal.h>

#include <Metal/Metal.h>
#include <TargetConditionals.h>

// TODO cleanup compilation conditionals. Make it more readable

namespace particles::metal::imgui
{
#if TARGET_OS_OSX
    void init(NSView* view, id<MTLDevice> device)
#else
    void init(id<MTLDevice> device)
#endif
    {
        // Setup Dear ImGui context
        IMGUI_CHECKVERSION();
        ImGui::CreateContext();
        ImGuiIO& io = ImGui::GetIO(); (void)io;
        io.FontGlobalScale = 1.25f;

        // Setup Dear ImGui style
        ImGui::StyleColorsClassic();

        // Setup Platform/Renderer backends
        // TODO check return values and react
        ImGui_ImplMetal_Init(device);
#if TARGET_OS_OSX
        ImGui_ImplOSX_Init(view);
#endif
    }

    void deinit()
    {
        ImGui_ImplMetal_Shutdown();
#if TARGET_OS_OSX
        ImGui_ImplOSX_Shutdown();
#endif
        ImGui::DestroyContext();
    }

#if TARGET_OS_OSX
    void newFrame(MTLRenderPassDescriptor* renderPassDescriptor, NSView* view)
#else
    void newFrame(MTLRenderPassDescriptor* renderPassDescriptor)
#endif
    {
        ImGui_ImplMetal_NewFrame(renderPassDescriptor);
#if TARGET_OS_OSX
        ImGui_ImplOSX_NewFrame(view);
#endif
        ImGui::NewFrame();
    }

    void render(id<MTLCommandBuffer> commandBuffer, id<MTLRenderCommandEncoder> commandEncoder)
    {
        ImGui::Render();
        ImGui_ImplMetal_RenderDrawData(ImGui::GetDrawData(), commandBuffer, commandEncoder);
    }
}

#include <iostream>
namespace particles::imgui
{
    void drawFpsPlot(std::vector<float> values)
    {
        ImGui::Begin("FPS");
        ImGui::Text("Application average %.3f ms/frame (%.1f FPS)", 1000.0f / ImGui::GetIO().Framerate, ImGui::GetIO().Framerate);
        ImGui::PlotLines("", &values[0], values.size(), 0, nullptr, 1.f, 144.0f, ImVec2(0, 100.0f));
        ImGui::End();
    }

    void drawCameraPane(Camera& camera)
    {
        ImGui::Begin("Camera");

        ImGui::SliderFloat("Movement speed", &camera.speedMultiplier(), 0.0f, 100.0f);
        ImGui::SliderFloat3("Position", &camera.position()[0], -50.f, 50.f);
        ImGui::SliderFloat("FOV", &camera.fov(), 1.0f, 90.0f);

        ImGui::End();
    }

    void drawParticleSystemPane(particles::metal::Emitter::Descriptor& descriptor, int aliveParticles, bool& blur, bool& bloom, float& sigma, int& iterations)
    {
        ImGui::Begin("Particle system");
        ImGui::Text((std::string("Alive particles: ") + std::to_string(aliveParticles)).c_str());
        ImGui::SliderInt("Spawn count", &descriptor.particlesCount, 1, 1e4);
        ImGui::SliderFloat("Scale", &descriptor.scale, 1.f, 100.f);
        ImGui::ColorEdit4("Start", glm::value_ptr(descriptor.startColor));
        ImGui::ColorEdit4("End", glm::value_ptr(descriptor.endColor));
        ImGui::SliderInt("Life time [frames]", &descriptor.lifeTimeFrames, 0, 1000);
        ImGui::SliderFloat("Thickness", &descriptor.thickness, 0.0f, 1.f);
        ImGui::SliderFloat("Speed", &descriptor.speed, 0.0f, 10.f);

        ImGui::PushItemWidth(ImGui::GetWindowWidth() * 0.25);
        ImGui::Text("Initial velocity");
        ImGui::SameLine();
        ImGui::Checkbox("Random direction", &descriptor.randomDirection); // TODO swap with angular direction
        ImGui::BeginDisabled(descriptor.randomDirection);
        ImGui::DragFloat("x", &descriptor.initialDirection[0], 0.0001, -0.05f, 0.05f);
        ImGui::SameLine();
        ImGui::DragFloat("y", &descriptor.initialDirection[1], 0.0001, -0.05f, 0.05f);
        ImGui::SameLine();
        ImGui::DragFloat("z", &descriptor.initialDirection[2], 0.0001, -0.05f, 0.05f);
        ImGui::EndDisabled();

        ImGui::Text("Acceleration");
        ImGui::SameLine();
        ImGui::Checkbox("Random acceleration", &descriptor.randomAcceleration);
        ImGui::BeginDisabled(descriptor.randomAcceleration);
        ImGui::DragFloat("ax", &descriptor.acceleration[0], 0.00001, -0.0005f, 0.0005f, "%.4f");
        ImGui::SameLine();
        ImGui::DragFloat("ay", &descriptor.acceleration[1], 0.00001, -0.0005f, 0.0005f, "%.4f");
        ImGui::SameLine();
        ImGui::DragFloat("az", &descriptor.acceleration[2], 0.00001, -0.0005f, 0.0005f, "%.4f");
        ImGui::EndDisabled();
        ImGui::PopItemWidth();

        ImGui::RadioButton("Square", &descriptor.shape, 0);
        ImGui::SameLine();
        ImGui::RadioButton("Circle", &descriptor.shape, 1);
        ImGui::SameLine();
        ImGui::RadioButton("Triangle", &descriptor.shape, 2);

        ImGui::Checkbox("Gaussian blur", &blur);
        ImGui::BeginDisabled(!blur);
        ImGui::SliderFloat("Sigma", &sigma, 0.0f, 20.f);
        ImGui::Checkbox("Bloom", &bloom);
        ImGui::BeginDisabled(!bloom);
        ImGui::SliderInt("Iterations", &iterations, 0, 10);
        ImGui::EndDisabled();
        ImGui::EndDisabled();
//
//        ImGui::PlotLines("draw [ms]", &particlesDrawTimes[0], particlesDrawTimes.size(), 0, nullptr, 0.f, 16.f, ImVec2(0, 100.f));

        ImGui::End();
    }
}

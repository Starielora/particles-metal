#pragma once

#include "Camera.h"
#include "Emitter.h"

#include <glm/gtc/type_ptr.hpp>

#include <imgui.h>
#include <imgui_impl_glfw.h>
#include <imgui_impl_metal.h>

#include <Metal/Metal.h>

namespace particles::metal::imgui
{
    void init(id<MTLDevice> device, GLFWwindow* window)
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
        ImGui_ImplGlfw_InitForOther(window, true);
        ImGui_ImplMetal_Init(device);
    }

    void deinit()
    {
        ImGui_ImplMetal_Shutdown();
        ImGui_ImplGlfw_Shutdown();
        ImGui::DestroyContext();
    }

    void newFrame(MTLRenderPassDescriptor* renderPassDescriptor)
    {
        ImGui_ImplMetal_NewFrame(renderPassDescriptor);
        ImGui_ImplGlfw_NewFrame();
        ImGui::NewFrame();
    }

    void render(id<MTLCommandBuffer> commandBuffer, id<MTLRenderCommandEncoder> commandEncoder)
    {
        ImGui::Render();
        ImGui_ImplMetal_RenderDrawData(ImGui::GetDrawData(), commandBuffer, commandEncoder);
    }
}

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

    void drawParticleSystemPane(particles::metal::Emitter::Descriptor& descriptor, int aliveParticles)
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

//        ImGui::SliderFloat("Thickness", &particleSystem.shapeThickness(), 0.0f, 1.f);
//
//        ImGui::Checkbox("Gaussian blur", &gaussianBlur.enabled);
//        ImGui::BeginDisabled(!gaussianBlur.enabled);
//        ImGui::SliderInt("Iterations", &gaussianBlur.iterations, 1, 20);
//        ImGui::Checkbox("Bloom", &additiveBlend.enabled);
//        ImGui::BeginDisabled(!additiveBlend.enabled);
//        ImGui::SliderFloat("Factor", &additiveBlend.factor, 0.0f, 10.f);
//        ImGui::EndDisabled();
//        ImGui::EndDisabled();
//
//        ImGui::PlotLines("draw [ms]", &particlesDrawTimes[0], particlesDrawTimes.size(), 0, nullptr, 0.f, 16.f, ImVec2(0, 100.f));

        ImGui::End();
    }
}
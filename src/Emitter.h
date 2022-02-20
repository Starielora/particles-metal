#pragma once

#include "Particle.h"
#include "Camera.h"

#include <Metal/Metal.h>

#include <random>

namespace particles::metal
{
    namespace // TODO yeet to separate file
    {
        namespace rng
        {
            auto Float()
            {
                static std::random_device rd{};
                static auto seed = std::mt19937{ rd() };
                static auto distribution = std::uniform_real_distribution<float>(-0.002f, 0.002f);

                return distribution(seed);
            }
        }
    }

    namespace
    {
        id<MTLComputePipelineState> getComputePipelineState(id<MTLDevice> gpu, id<MTLLibrary> library)
        {
            static id<MTLComputePipelineState> computePipelineState;

            if (!computePipelineState)
            {
                id<MTLFunction> function = [library newFunctionWithName:@"updateParticle"];

                NSError* errors;
                computePipelineState = [gpu newComputePipelineStateWithFunction:function error:&errors];
                assert(!errors);
            }

            return computePipelineState;
        }

        id<MTLRenderPipelineState> getRenderPipelineState(id<MTLDevice> gpu, id<MTLLibrary> library, const char* const vertexShaderName, const char* const fragmentShaderName)
        {
            id<MTLFunction> vertexShader = [library newFunctionWithName:[NSString stringWithUTF8String:vertexShaderName]];
            id<MTLFunction> fragmentShader = [library newFunctionWithName:[NSString stringWithUTF8String:fragmentShaderName]];

            MTLRenderPipelineDescriptor* pipelineDescriptor = [MTLRenderPipelineDescriptor new];

            pipelineDescriptor.vertexFunction = vertexShader;
            pipelineDescriptor.fragmentFunction = fragmentShader;

            pipelineDescriptor.colorAttachments[0].pixelFormat = MTLPixelFormatBGRA8Unorm;
            NSError* errors;
            id<MTLRenderPipelineState> renderPipelineState = [gpu newRenderPipelineStateWithDescriptor:pipelineDescriptor error:&errors];

            assert(renderPipelineState && !errors);

            return renderPipelineState;
        }

        id<MTLRenderPipelineState> getRenderPipelineState(id<MTLDevice> gpu, id<MTLLibrary> library, int shape)
        {
            static id<MTLRenderPipelineState> circle;
            static id<MTLRenderPipelineState> square;
            static id<MTLRenderPipelineState> triangle;
            if (shape == 0)
            {
                if (!square) {
                    square = getRenderPipelineState(gpu, library, "instancedParticleVertexShader", "square");
                }
                return square;
            }
            else if (shape == 1)
            {
                if (!circle) {
                    circle = getRenderPipelineState(gpu, library, "instancedParticleVertexShader", "circle");
                }
                return circle;

            }
            else if (shape == 2)
            {
                if (!triangle) {
                    triangle = getRenderPipelineState(gpu, library, "instancedParticleVertexShader", "triangle");
                }
                return triangle;
            }
            else
            {
                return circle;
            }
        }
    }

    class Emitter
    {
    public:
        struct Descriptor
        {
            int particlesCount = 100;
            int lifeTimeFrames = 100.f; // frames
            simd_float3 worldPos = simd_make_float3(0.f, 0.f, 0.f);
//            simd_float4 startColor = simd_make_float4(1.f, 0.f, 0.f, 1.f);
            glm::vec4 startColor = glm::vec4(1.f, 0.f, 0.f, 1.f); // for imgui purposes
            glm::vec4 endColor = glm::vec4(0.f, 0.f, 1.f, 1.f);
            bool randomDirection = true;
            bool randomAcceleration = false;
            bool randomSpeed = true;
//            simd_float3 direction = simd_make_float3(1.f, 0.f, 0.f);
            glm::vec3 initialDirection = glm::vec3(0.f, 0.f, 0.f); // TODO switch this with value and angular direction
            glm::vec3 acceleration = glm::vec3(0.f, 0.f, 0.f);
            float speed = 1.f;
            float scale = 10.f;
            float thickness = 0.2f;
            int shape = 1; // 1 - circle, 2 - square, 3 - triangle
        };

        Emitter(Descriptor descriptor, id<MTLDevice> gpu, id<MTLLibrary> library, id<MTLCommandQueue> queue)
            : _descriptor(std::move(descriptor))
            , _life(_descriptor.lifeTimeFrames)
            , _particlesUpdatePipelineState(getComputePipelineState(gpu, library))
            , _renderPipelineState(getRenderPipelineState(gpu, library, _descriptor.shape))
//            , _buffer([gpu newBufferWithLength:sizeof(Particle) * _descriptor.particlesCount  options:MTLResourceStorageModeShared]) // TODO switch resource to private
        {
            @autoreleasepool {
                id<MTLBuffer> temp = [gpu newBufferWithLength:sizeof(Particle) * _descriptor.particlesCount options:MTLResourceStorageModeShared];
                auto* particle = reinterpret_cast<Particle*>([temp contents]);
                for (auto i = unsigned{0}; i < _descriptor.particlesCount; ++i)
                {
                    particle->position = _descriptor.worldPos;
                    particle->color = simd_make_float4(_descriptor.startColor.r, _descriptor.startColor.g, _descriptor.startColor.b, _descriptor.startColor.a);
                    particle->direction = _descriptor.randomDirection ? simd_make_float3(rng::Float(), rng::Float(), rng::Float()) : simd_make_float3(_descriptor.initialDirection.x, _descriptor.initialDirection.y, _descriptor.initialDirection.z);
                    particle->acceleration = _descriptor.randomAcceleration ? simd_make_float3(rng::Float(), rng::Float(), rng::Float()) : simd_make_float3(_descriptor.acceleration.x, _descriptor.acceleration.y, _descriptor.acceleration.z);
                    particle->speed = _descriptor.speed;
                    particle->scale = _descriptor.scale;
                    particle++;
                }

                id<MTLCommandBuffer> commandBuffer = [queue commandBuffer];
                _buffer = [gpu newBufferWithLength:sizeof(Particle) * _descriptor.particlesCount options:MTLResourceStorageModePrivate];
                id<MTLBlitCommandEncoder> blit = [commandBuffer blitCommandEncoder];
                [blit copyFromBuffer:temp sourceOffset:0 toBuffer:_buffer destinationOffset:0 size:sizeof(Particle) * _descriptor.particlesCount];
                [blit endEncoding];
                [commandBuffer commit];
            }
        }

        bool isDead() { return _life == 0; }
        const Descriptor& descriptor() { return _descriptor; }

        void update(id<MTLCommandBuffer> commandBuffer)
        {
            if(_life == 0)
            {
                return;
            }
            _life--;

            float progress = 1 - float(_life) / float(_descriptor.lifeTimeFrames);
            simd_float4 startColor = simd_make_float4(_descriptor.startColor.x, _descriptor.startColor.y, _descriptor.startColor.z, _descriptor.startColor.w);
            simd_float4 endColor = simd_make_float4(_descriptor.endColor.x, _descriptor.endColor.y, _descriptor.endColor.z, _descriptor.endColor.w);

            auto computeEncoder = [commandBuffer computeCommandEncoder];
            [computeEncoder pushDebugGroup:@"Particles update"];
            [computeEncoder setComputePipelineState:_particlesUpdatePipelineState];
            const auto width = _particlesUpdatePipelineState.threadExecutionWidth;
            const auto threadsPerGroup = MTLSizeMake(width, 1, 1);
            const auto threadsPerGrid = MTLSizeMake(_descriptor.particlesCount, 1, 1);
            [computeEncoder setBuffer:_buffer offset:0 atIndex:0];
            [computeEncoder setBytes:&progress length:sizeof(progress) atIndex:1];
            [computeEncoder setBytes:&startColor length:sizeof(startColor) atIndex:2];
            [computeEncoder setBytes:&endColor length:sizeof(endColor) atIndex:3];
            [computeEncoder dispatchThreads:threadsPerGrid threadsPerThreadgroup:threadsPerGroup];
            [computeEncoder endEncoding];
            [computeEncoder popDebugGroup];
        }

        // TODO something is no yes with input parameters
        // I'd like to renderEncoder.endEncoding at the end. Probably will have to implement several render targets
        void draw(MTLRenderPassDescriptor* passDescriptor, Camera& camera, id<MTLRenderCommandEncoder> renderEncoder, double windowWidth, double windowHeight)
        {
            assert(_life >= 0.f);

            auto view = camera.view();
            auto projection = camera.projection(windowWidth, windowHeight);
            simd_float3 cameraPos = simd_make_float3(camera.position().x, camera.position().y, camera.position().z);

            [renderEncoder pushDebugGroup:@"Draw particles"];
            [renderEncoder setRenderPipelineState:_renderPipelineState];
            [renderEncoder setVertexBuffer:_buffer offset:0 atIndex:0];
            [renderEncoder setVertexBytes:&view[0][0] length:sizeof(simd_float4x4) atIndex:1];
            [renderEncoder setVertexBytes:&projection[0][0] length:sizeof(simd_float4x4) atIndex:2];
            [renderEncoder setVertexBytes:&cameraPos length:sizeof(cameraPos) atIndex:3];

            [renderEncoder setFragmentBytes:&_descriptor.thickness length:sizeof(_descriptor.thickness) atIndex:0];

            [renderEncoder drawPrimitives:MTLPrimitiveTypePoint vertexStart:0 vertexCount:1 instanceCount:_descriptor.particlesCount];
            [renderEncoder popDebugGroup];
        }

    private:
        const Descriptor _descriptor;
        int _life;
        id<MTLBuffer> _buffer;
        id<MTLComputePipelineState> _particlesUpdatePipelineState;
        id<MTLRenderPipelineState> _renderPipelineState;
    };
}

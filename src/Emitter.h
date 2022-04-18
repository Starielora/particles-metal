#pragma once

#include "Particle.h"
#include "Camera.h"

#include <Metal/Metal.h>

#include <random>
#include <unordered_map>
#include <string>

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
                auto* const descriptor = [MTLComputePipelineDescriptor new];
                descriptor.supportIndirectCommandBuffers = true;
                descriptor.computeFunction = function;
                NSError* errors;

                computePipelineState = [gpu newComputePipelineStateWithDescriptor:descriptor options:MTLPipelineOptionNone reflection:nullptr error:&errors];
                assert(!errors);
            }

            return computePipelineState;
        }

        id<MTLRenderPipelineState> getRenderPipelineState(id<MTLDevice> gpu, id<MTLLibrary> library, id<MTLFunction> vertexShader, id<MTLFunction> fragmentShader)
        {
            MTLRenderPipelineDescriptor* pipelineDescriptor = [MTLRenderPipelineDescriptor new];

            pipelineDescriptor.vertexFunction = vertexShader;
            pipelineDescriptor.fragmentFunction = fragmentShader;

            pipelineDescriptor.colorAttachments[0].pixelFormat = MTLPixelFormatBGRA8Unorm;
            pipelineDescriptor.supportIndirectCommandBuffers = true;
            NSError* errors;
            id<MTLRenderPipelineState> renderPipelineState = [gpu newRenderPipelineStateWithDescriptor:pipelineDescriptor error:&errors];

            assert(renderPipelineState && !errors);

            return renderPipelineState;
        }

        id<MTLFunction> getFunction(std::string shaderName, id<MTLLibrary> library)
        {
            static auto memo = std::unordered_map<std::string, id<MTLFunction>>{};

            const auto it = memo.find(shaderName);
            if (it != memo.end())
            {
                return it->second;
            }
            else
            {
                const auto function = [library newFunctionWithName:[NSString stringWithUTF8String:shaderName.c_str()]];
                memo.insert({std::move(shaderName), function});
                return function;
            }
        }

        id<MTLRenderPipelineState> getRenderPipelineState(id<MTLDevice> gpu, id<MTLLibrary> library, int shape)
        {
            using ShaderNames = struct {
                const std::string vertex;
                const std::string fragment;
            };

            static const auto shapeToShader = std::unordered_map<int, ShaderNames>{
                  {0, {"instancedParticleVertexShader", "square"}}
                , {1, {"instancedParticleVertexShader", "circle"}}
                , {2, {"instancedParticleVertexShader", "triangle"}}
                , {3, {"instancedParticleVertexShader", "color"}}
            };

            static auto memo = std::unordered_map<decltype(shape), id<MTLRenderPipelineState>>{};

            const auto it = memo.find(shape);
            if(it != memo.end())
            {
                return it->second;
            }
            else
            {
                const auto shaderName = shapeToShader.at(shape);
                const auto vertexShader = getFunction(shaderName.vertex, library);
                const auto fragmentShader = getFunction(shaderName.fragment, library);
                const auto pipelineState = getRenderPipelineState(gpu, library, vertexShader, fragmentShader);
                memo.insert({shape, pipelineState});
                return pipelineState;
            }
        }
    }

    class Emitter
    {
    public:
        struct Descriptor
        {
            int particlesCount = 64;
            int lifeTimeFrames = 100; // frames
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

        Emitter(Descriptor descriptor, id<MTLDevice> gpu, id<MTLLibrary> library, id<MTLCommandQueue> queue, id<MTLBuffer> cameraBuffer)
            : _descriptor(std::move(descriptor))
            , _life(_descriptor.lifeTimeFrames)
            , _particlesUpdatePipelineState(getComputePipelineState(gpu, library))
            , _renderPipelineState(getRenderPipelineState(gpu, library, _descriptor.shape))
        {
            @autoreleasepool {
                const auto maxWidth = _particlesUpdatePipelineState.maxTotalThreadsPerThreadgroup;
                const auto width = _particlesUpdatePipelineState.threadExecutionWidth;
                _threadsPerGroup = MTLSizeMake(1, 1, 1);
                _threadgroupsPerGrid = MTLSizeMake(_descriptor.particlesCount, 1, 1);

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
                // TODO should this be synced?
                // [commandBuffer waitUntilCompleted];

                // Descriptor buffer
                _descriptorBuffer = [gpu newBufferWithLength:sizeof(DescriptorBuffer) options:MTLResourceStorageModeShared];
                auto* const descriptorBufferPtr = reinterpret_cast<DescriptorBuffer*>([_descriptorBuffer contents]);
                descriptorBufferPtr->startColor = simd_make_float4(_descriptor.startColor.x, _descriptor.startColor.y, _descriptor.startColor.z, _descriptor.startColor.w);
                descriptorBufferPtr->endColor = simd_make_float4(_descriptor.endColor.x, _descriptor.endColor.y, _descriptor.endColor.z, _descriptor.endColor.w);
                descriptorBufferPtr->currentColor = descriptorBufferPtr->startColor;
                descriptorBufferPtr->thickness = _descriptor.thickness;
                descriptorBufferPtr->progress = 0.0;

                // kernel shader - update positions
                {
                    const auto icbDescriptor = [MTLIndirectCommandBufferDescriptor new];
                    icbDescriptor.commandTypes = MTLIndirectCommandTypeConcurrentDispatch;
                    icbDescriptor.inheritBuffers = false;
                    icbDescriptor.maxKernelBufferBindCount = 2;
                    icbDescriptor.inheritPipelineState = false;

                    _kernelICB = [gpu newIndirectCommandBufferWithDescriptor:icbDescriptor maxCommandCount:1 options:MTLResourceStorageModeShared];

                    const auto icbCommand = [_kernelICB indirectComputeCommandAtIndex:0];
                    [icbCommand setComputePipelineState:_particlesUpdatePipelineState];
                    [icbCommand setKernelBuffer:_buffer offset:0 atIndex:0];
                    [icbCommand setKernelBuffer:_descriptorBuffer offset:0 atIndex:1];
                    [icbCommand concurrentDispatchThreadgroups:_threadgroupsPerGrid threadsPerThreadgroup:_threadsPerGroup];
                }

                // render command
                {
                    const auto icbDescriptor = [MTLIndirectCommandBufferDescriptor new];
                    icbDescriptor.commandTypes = MTLIndirectCommandTypeDraw;;
                    icbDescriptor.inheritBuffers = false;
                    icbDescriptor.maxVertexBufferBindCount = 2;
                    icbDescriptor.maxFragmentBufferBindCount = 2;
                    icbDescriptor.inheritPipelineState = false;

                    _renderICB = [gpu newIndirectCommandBufferWithDescriptor:icbDescriptor maxCommandCount:1 options:MTLResourceStorageModeShared];

                    const auto icbCommand = [_renderICB indirectRenderCommandAtIndex:0];
                    [icbCommand setRenderPipelineState:_renderPipelineState];
                    [icbCommand setVertexBuffer:_buffer offset:0 atIndex:0];
                    [icbCommand setVertexBuffer:cameraBuffer offset:0 atIndex:1];
                    [icbCommand setFragmentBuffer:_descriptorBuffer offset:0 atIndex:0];
                    [icbCommand drawPrimitives:MTLPrimitiveTypePoint vertexStart:0 vertexCount:1 instanceCount:_descriptor.particlesCount baseInstance:0];
                }
            }
        }

        bool isDead() { return _life == 0; }
        const Descriptor& descriptor() { return _descriptor; }

        void updateLife()
        {
            --_life;
        }

        void updateParticles(id<MTLComputeCommandEncoder> computeEncoder)
        {
            auto* const descriptorBufferPtr = reinterpret_cast<DescriptorBuffer*>([_descriptorBuffer contents]);
            descriptorBufferPtr->progress = 1 - float(_life) / float(_descriptor.lifeTimeFrames);

            [computeEncoder pushDebugGroup:@"Particles update"];
            [computeEncoder useResource:_buffer usage:(MTLResourceUsageRead | MTLResourceUsageWrite)];
            [computeEncoder useResource:_descriptorBuffer usage:MTLResourceUsageRead];
            [computeEncoder executeCommandsInBuffer:_kernelICB withRange:NSMakeRange(0, 1)];
            [computeEncoder popDebugGroup];
        }

        // TODO something is no yes with input parameters
        // I'd like to renderEncoder.endEncoding at the end. Probably will have to implement several render targets
        void draw(MTLRenderPassDescriptor* passDescriptor, id<MTLBuffer> cameraBuffer, id<MTLRenderCommandEncoder> renderEncoder)
        {
            [renderEncoder pushDebugGroup:@"Draw particles"];
            [renderEncoder useResource:_buffer usage:MTLResourceUsageRead];
            [renderEncoder useResource:_descriptorBuffer usage:MTLResourceUsageRead];
            [renderEncoder useResource:cameraBuffer usage:MTLResourceUsageRead];
            [renderEncoder executeCommandsInBuffer:_renderICB withRange:NSMakeRange(0, 1)];
            [renderEncoder popDebugGroup];
        }

    private:
        const Descriptor _descriptor;
        int _life;
        id<MTLBuffer> _buffer;
        id<MTLBuffer> _descriptorBuffer;
        id<MTLComputePipelineState> _particlesUpdatePipelineState;
        id<MTLRenderPipelineState> _renderPipelineState;

        id<MTLIndirectCommandBuffer> _renderICB;
        id<MTLIndirectCommandBuffer> _kernelICB;

        MTLSize _threadgroupsPerGrid;
        MTLSize _threadsPerGroup;
    };
}

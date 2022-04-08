#pragma once

#include <simd/simd.h>

namespace particles::metal
{
    struct Particle
    {
        simd_float4 color;
        simd_float3 position;
        simd_float3 direction;
        simd_float3 acceleration;
        float speed = 1.f;
        float scale = 1.f;
    };

    // TODO temp to implement arg buffers and icb
    struct CameraBuffer
    {
        simd_float4x4 view;
        simd_float4x4 projection;
        simd_float3 position;
    };

    struct DescriptorBuffer
    {
        simd_float4 startColor;
        simd_float4 endColor;
        simd_float4 currentColor;
        float thickness;
        float progress;
    };
}

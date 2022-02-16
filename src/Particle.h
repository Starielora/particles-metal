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
}

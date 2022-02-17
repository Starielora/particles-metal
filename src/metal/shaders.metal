#include <metal_stdlib>

#include "Particle.h"

using namespace metal;
using namespace particles::metal;

kernel void compute(texture2d<half, access::read_write> output [[texture(0)]], uint2 id [[thread_position_in_grid]])
{
    constexpr auto thickness = 0.25f;
    const auto v = float2((float(id.x) / 400), (float(id.y) / 300));
    const float len = length(v - float2(1, 1));
    if (len < 1 - thickness || len > 1.f)
        output.write(half4(0.0, 0.0, 0.0, 1.0), id);
    else
        output.write(half4(0.0, len, 0.5, 1.0), id);
}

struct VertexShaderOutput
{
    float4 position [[position]];
    float point_size [[point_size]];
    float4 color;
};

vertex VertexShaderOutput instancedParticleVertexShader(const device Particle* particles [[buffer(0)]]
                                                      , constant matrix_float4x4& view [[buffer(1)]]
                                                      , constant matrix_float4x4& projection [[buffer(2)]]
                                                      , constant float3& cameraPosition [[buffer(3)]]
                                                      , uint instance [[instance_id]]
                                                      )
{
    const device Particle& particle = particles[instance];

    return VertexShaderOutput {
        projection * view * /*matrix_float4x4(1.f) */ float4(particle.position, 1)
        , max(0.f, (particle.scale - length(particle.position - cameraPosition))) // TODO
        , particle.color
    };
}

fragment float4 circle(VertexShaderOutput in [[stage_in]]
                       , float2 point [[point_coord]]
                       , constant float& thickness [[buffer(0)]]
                       )
{
    point = point + float2(-0.5, -0.5);
    half len = length(point);
    if (len < (0.5 - thickness) || len > 0.5)
        discard_fragment();

    return in.color;
}

fragment float4 square(
                       VertexShaderOutput in [[stage_in]]
                       , float2 point [[point_coord]]
                       , constant float& thickness [[buffer(0)]]
                       )
{
    point = point + float2(-0.5, -0.5);
    half x = point.x;
    half y = point.y;
    half lowBound = -0.5 + thickness/2;
    half highBound = 0.5 - thickness/2;

    if (x > lowBound && x < highBound && y > lowBound && y < highBound)
        discard_fragment();

    return in.color;
}

fragment float4 triangle(VertexShaderOutput in [[stage_in]]
                         , float2 point [[point_coord]]
                         , constant float& thickness [[buffer(0)]])
{
    point = point + float2(-0.5, -0.5);
    half x = point.x;
    half y = point.y;

    // outer triangle
    half x1 = (y - 0.5) / 2.0; // point on left line
    half x2 = (y - 0.5) / -2.0; // point on right line

    half d1 = x1 - x;
    half d2 = x2 - x;

    if (d1 * d2 > 0) // if both have same sign
        discard_fragment();

    return in.color;
}

kernel void updateParticle(device Particle* particles [[buffer(0)]]
                           , constant float& progress [[buffer(1)]]
                           , constant simd_float4& startColor [[buffer(2)]]
                           , constant simd_float4& endColor [[buffer(3)]]
                           , uint id [[thread_position_in_grid]])
{
    device auto& particle = particles[id];
    const float3 velocity = particle.direction * particle.speed;
    particle.position += velocity;
    particle.direction += particle.acceleration / particle.speed;
    particle.color = mix(startColor, endColor, progress); // TODO if all particles have the same color this could be computed once on CPU
}


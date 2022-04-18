#include <metal_stdlib>

#include "Particle.h"

using namespace metal;
using namespace particles::metal;

struct VertexShaderOutput
{
    float4 position [[position]];
    float point_size [[point_size]];
    float4 color;
};

vertex VertexShaderOutput instancedParticleVertexShader(
                                                        const device Particle* particles [[buffer(0)]]
                                                      , const constant CameraBuffer* camera [[buffer(1)]]
                                                      , const uint instance [[instance_id]]
                                                      )
{
    const device Particle& particle = particles[instance];
    const constant auto& projection = camera->projection;
    const constant auto& view = camera->view;
    const constant auto& cameraPosition = camera->position;

    return VertexShaderOutput {
        projection * view /** matrix_float4x4(1.f)*/ * float4(particle.position, 1)
        , max(0.f, (particle.scale - length(particle.position - cameraPosition))) // TODO
        , particle.color
    };
}

fragment float4 color(VertexShaderOutput in [[stage_in]]
                      , float2 point [[point_coord]]
                      , constant DescriptorBuffer* descriptor [[buffer(0)]])
{
    return in.color;
}

fragment float4 circle(VertexShaderOutput in [[stage_in]]
                       , float2 point [[point_coord]]
                       , constant DescriptorBuffer* descriptor [[buffer(0)]]
                       )
{
    const float thickness = descriptor->thickness;
    point = point + float2(-0.5, -0.5);
    half len = length(point);
    if (len < (0.5 - thickness/2) || len > 0.5)
        discard_fragment();

    return in.color;
}

fragment float4 square(
                       VertexShaderOutput in [[stage_in]]
                       , float2 point [[point_coord]]
                       , constant DescriptorBuffer* descriptor [[buffer(0)]]
                       )
{
    const float thickness = descriptor->thickness;
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
                         , constant DescriptorBuffer* descriptor [[buffer(0)]])
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
                           , constant const DescriptorBuffer* descriptor [[buffer(1)]]
                           , const uint id [[thread_position_in_grid]])
{
    device auto& particle = particles[id];
    const float3 velocity = particle.direction * particle.speed;
    particle.position += velocity;
    particle.direction += particle.acceleration / particle.speed;
    particle.color = mix(descriptor->startColor, descriptor->endColor, descriptor->progress); // TODO compute on CPU?
}


#include <metal_stdlib>
using namespace metal;

struct RasterizerData {
    float4 position [[position]];
    float2 texCoord;
};

vertex RasterizerData invadersVertex(uint vertexID [[vertex_id]]) {
    constexpr float2 positions[3] = {
        float2(-1.0, -1.0),
        float2( 3.0, -1.0),
        float2(-1.0,  3.0)
    };

    constexpr float2 texCoords[3] = {
        float2(0.0, 1.0),
        float2(2.0, 1.0),
        float2(0.0, -1.0)
    };

    RasterizerData out;
    out.position = float4(positions[vertexID], 0.0, 1.0);
    out.texCoord = texCoords[vertexID];
    return out;
}

fragment float4 invadersFragment(
    RasterizerData in [[stage_in]],
    device const uchar *packedFrame [[buffer(0)]],
    constant float &invertAmount [[buffer(1)]]
) {
    constexpr uint screenWidth = 224;
    constexpr uint screenHeight = 256;
    constexpr uint bytesPerColumn = screenHeight / 8;

    float2 uv = clamp(in.texCoord, float2(0.0), float2(1.0));
    uint x = min(static_cast<uint>(uv.x * float(screenWidth)), screenWidth - 1);
    uint y = min(static_cast<uint>(uv.y * float(screenHeight)), screenHeight - 1);

    uint sourceY = (screenHeight - 1) - y;
    uint byteRow = sourceY / 8;
    uint bitIndex = sourceY & 7;
    uint packedIndex = x * bytesPerColumn + byteRow;

    float value = ((packedFrame[packedIndex] >> bitIndex) & 1) != 0 ? 1.0 : 0.0;
    value = mix(value, 1.0 - value, invertAmount);
    return float4(value, value, value, 1.0);
}

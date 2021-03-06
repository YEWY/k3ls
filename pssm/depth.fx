#include "common.fxsub"

#define CasterAlphaThreshold 0.7

float3 LightDirection : DIRECTION < string Object = "Light";>;
static float4x4 matLightView = CreateLightViewMatrix(LightDirection);
static float4x4 matLightViewProject = mul(matLightView, matLightProject);
static float4x4 matLightProjectToCameraView = mul(matViewInverse, matLightView);
static float4x4 lightParam = CreateLightProjParameters(matLightProjectToCameraView);

texture DiffuseMap: MATERIALTEXTURE;
sampler DiffuseSamp = sampler_state
{
    texture = <DiffuseMap>;
    MINFILTER = POINT; MAGFILTER = POINT; MIPFILTER = POINT;
    ADDRESSU  = WRAP; ADDRESSV  = WRAP;
};


void CascadeShadowMapVS(
    in float4 Position : POSITION,
    in float3 Normal : NORMAL,
    in float2 Texcoord : TEXCOORD0,
    out float4 oTexcoord0 : TEXCOORD0,
    out float4 oTexcoord1 : TEXCOORD1,
    out float4 oPosition : POSITION,
    uniform int3 offset)
{
    float cosAngle = 1 - saturate(dot(Normal, -LightDirection));
    
    oPosition = mul(Position + float4(Normal * cosAngle * 0.02, 0), matLightViewProject);
    oPosition.xy = oPosition.xy * lightParam[offset.z].xy + lightParam[offset.z].zw;
    oPosition.xy = oPosition.xy * 0.5 + (offset.xy * 0.5f);
   
    oTexcoord1 = oPosition;
    oTexcoord0 = float4(Texcoord, offset.xy);
}

float4 CascadeShadowMapPS(float4 coord0 : TEXCOORD0, float4 position : TEXCOORD1, uniform bool useTexture) : COLOR
{
    float2 clipUV = (position.xy - SHADOW_MAP_OFFSET) * coord0.zw;
    clip(clipUV.x);
    clip(clipUV.y);
    clip(!opadd - 0.001f);


    float alpha = MaterialDiffuse.a;
    if ( useTexture ) alpha *= tex2D(DiffuseSamp, coord0.xy).a;
    clip(alpha - CasterAlphaThreshold);

    return position.z;
}

#define PSSM_TEC(name, mmdpass, tex) \
    technique name < string MMDPass = mmdpass; bool UseTexture = tex; \
    > { \
        pass CascadeShadowMap0 { \
            AlphaBlendEnable = false; AlphaTestEnable = false; \
            VertexShader = compile vs_3_0 CascadeShadowMapVS(int3(-1, 1, 0)); \
            PixelShader  = compile ps_3_0 CascadeShadowMapPS(tex); \
        } \
        pass CascadeShadowMap1 { \
            AlphaBlendEnable = false; AlphaTestEnable = false; \
            VertexShader = compile vs_3_0 CascadeShadowMapVS(int3( 1, 1, 1)); \
            PixelShader  = compile ps_3_0 CascadeShadowMapPS(tex); \
        } \
        pass CascadeShadowMap2 { \
            AlphaBlendEnable = false; AlphaTestEnable = false; \
            VertexShader = compile vs_3_0 CascadeShadowMapVS(int3(-1,-1, 2)); \
            PixelShader  = compile ps_3_0 CascadeShadowMapPS(tex); \
        } \
        pass CascadeShadowMap3 { \
            AlphaBlendEnable = false; AlphaTestEnable = false; \
            VertexShader = compile vs_3_0 CascadeShadowMapVS(int3( 1,-1, 3)); \
            PixelShader  = compile ps_3_0 CascadeShadowMapPS(tex); \
        } \
    }

PSSM_TEC(DepthTecBS2, "object_ss", false)
PSSM_TEC(DepthTecBS3, "object_ss", true)

technique DepthTec0 < string MMDPass = "object"; >{}
technique EdgeTec < string MMDPass = "edge"; > {}
technique ShadowTec < string MMDPass = "shadow"; > {}
technique ZplotTec < string MMDPass = "zplot"; > {}
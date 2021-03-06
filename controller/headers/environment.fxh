// �ѥ��`������
float2 ViewportSize : VIEWPORTPIXELSIZE;
static float2 ViewportOffset = (float2(0.5,0.5)/ViewportSize);
float3   CameraPosition    : POSITION  < string Object = "Camera"; >;
float3   LightDirection    : DIRECTION < string Object = "Light"; >;
float3   _LightAmbient      : AMBIENT   < string Object = "Light"; >;
static float3 LightAmbient = _LightAmbient * 4.;
const float PI = 3.14159265359f;
const float invPi = 0.31830988618;

sampler MMDSamp0 : register(s0);
sampler MMDSamp1 : register(s1);
sampler MMDSamp2 : register(s2);

uniform float4   MaterialDiffuse   : DIFFUSE  < string Object = "Geometry"; >;
uniform float3   MaterialAmbient   : AMBIENT  < string Object = "Geometry"; >;
uniform float3   MaterialEmmisive  : EMISSIVE < string Object = "Geometry"; >;
uniform float3   MaterialSpecular  : SPECULAR < string Object = "Geometry"; >;
uniform float    SpecularPower     : SPECULARPOWER < string Object = "Geometry"; >;
uniform float4   MaterialToon      : TOONCOLOR;
static	float4	DiffuseColor  = float4(MaterialDiffuse.rgb, saturate(MaterialDiffuse.a+0.01f));

float  AmbLightPower       : CONTROLOBJECT < string name = "Ambient.x"; string item="Si"; >;
float3 AmbColorXYZ         : CONTROLOBJECT < string name = "Ambient.x"; string item="XYZ"; >;
float3 AmbColorRxyz        : CONTROLOBJECT < string name = "Ambient.x"; string item="Rxyz"; >;

static float3 AmbientColor  = MaterialToon*MaterialEmmisive*AmbLightPower*0.11;
static float3 AmbLightColor0 = saturate(AmbColorXYZ*0.01); 
static float3 AmbLightColor1 = saturate(AmbColorRxyz*1.8/3.141592); 

#define SKYCOLOR AmbLightColor0.xyz
#define GROUNDCOLOR AmbLightColor1.xyz
// �դ���
#define SKYDIR float3(0.0,1.0,0.0)

#include "headers\\BRDF.fxh"


texture ObjectTexture: MATERIALTEXTURE;
sampler ObjTexSampler = sampler_state {
    texture = <ObjectTexture>;
    MINFILTER = ANISOTROPIC;
    MAGFILTER = ANISOTROPIC;
    MIPFILTER = LINEAR;
    MAXANISOTROPY = 16;
};

texture2D NormalTexure: MATERIALSPHEREMAP;
sampler NorTexSampler = sampler_state {
    texture = <NormalTexure>;
    MINFILTER = ANISOTROPIC;
    MAGFILTER = ANISOTROPIC;
    MIPFILTER = ANISOTROPIC;
    MAXANISOTROPY = 16;
    ADDRESSU = WRAP;
    ADDRESSV = WRAP;

};

shared texture2D ScreenShadowMapProcessed : RENDERCOLORTARGET <
    float2 ViewPortRatio = {1,1};
    int MipLevels = 1;
    string Format = "D3DFMT_R16F";
>;
sampler2D ScreenShadowMapProcessedSamp = sampler_state {
    texture = <ScreenShadowMapProcessed>;
    MinFilter = LINEAR; MagFilter = LINEAR; MipFilter = NONE;
    AddressU  = CLAMP; AddressV = CLAMP;
};

shared texture ScreenShadowMap: OFFSCREENRENDERTARGET;

sampler ScreenShadowMapSampler = sampler_state {
    texture = <ScreenShadowMap>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = LINEAR;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};

shared texture2D SSAO_Tex3 : RENDERCOLORTARGET <
    float2 ViewPortRatio = {1.0, 1.0};
    int MipLevels = 0;
    string Format = "D3DFMT_R16F";
>;
sampler2D SSAOSamp = sampler_state {
    texture = <SSAO_Tex3>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = LINEAR;
    AddressU = CLAMP;
    AddressV = CLAMP;
};

float size0 : CONTROLOBJECT < string name = "ExcellentShadow.x"; string item = "Si"; >;
static float size1 = size0 * 0.1;

shared texture ExcellentShadowZMapFar : OFFSCREENRENDERTARGET;

sampler ExcellentShadowZMapFarSampler = sampler_state {
    texture = <ExcellentShadowZMapFar>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = NONE;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};



/*
shared texture2D K3LS_Translucency : RENDERCOLORTARGET <
    float2 ViewPortRatio = {1,1};
    int MipLevels = 1;
    string Format = "D3DFMT_R16F";
>;
sampler2D TranslucencyLengthSamp = sampler_state {
    texture = <K3LS_Translucency>;
    MinFilter = LINEAR; MagFilter = LINEAR; MipFilter = NONE;
    AddressU  = CLAMP; AddressV = CLAMP;
};*/


// ������Q����
float4x4 WorldViewProjMatrix      : WORLDVIEWPROJECTION;
float4x4 WorldMatrix              : WORLD;
float4x4 WorldMatrixInverse       : WORLDINVERSE;
float4x4 ViewMatrix               : VIEW;
float4x4 ViewInverseMatrix		  : VIEWINVERSE;
//float4x4 LightWorldViewProjMatrix : WORLDVIEWPROJECTION < string Object = "Light"; >;
//float4x4 LightWorldViewMatrix     : WORLDVIEW < string Object = "Light"; >;


// ݆���軭�åƥ��˥å�
technique EdgeTec < string MMDPass = "edge"; > {}

// Ӱ�軭�åƥ��˥å�
technique ShadowTec < string MMDPass = "shadow"; > {}



texture IBLDiffuseTexture <
    string ResourceName = "skybox\\skydiff.dds"; 
>;

sampler IBLDiffuseSampler = sampler_state {
    texture = <IBLDiffuseTexture>;
    MINFILTER = LINEAR;
    MAGFILTER = LINEAR;
	MIPFILTER = NONE;
    ADDRESSU  = CLAMP;  
    ADDRESSV  = CLAMP;
};

texture IBLSpecularTexture <
    string ResourceName = "skybox\\skyspec.dds"; 
	int MipLevels = 6;
>;
sampler IBLSpecularSampler = sampler_state {
    texture = <IBLSpecularTexture>;
    MINFILTER = LINEAR;
    MAGFILTER = LINEAR;
    MIPFILTER = LINEAR;
    ADDRESSU  = CLAMP;
    ADDRESSV  = CLAMP;
};


float2 computeSphereCoord(float3 normal)
{
    float2 coord = float2(1 - (atan2(normal.x, normal.z) * invPi * 0.5f + 0.5f), acos(normal.y) * invPi);
    return coord;
}

void IBL(float3 viewNormal, float3 normal,float roughness, out float3 diffuse, out float3 specular)
{
	float3 R = reflect(-viewNormal, normal);
	float mipLayer = lerp(0, 6, roughness);

	float2 coord = computeSphereCoord(R);
	diffuse = tex2D(IBLDiffuseSampler, coord);
    specular = tex2Dlod(IBLSpecularSampler, float4(coord, 0, mipLayer));
}

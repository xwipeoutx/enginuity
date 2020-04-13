//global light variables
float range;
int lightType;
float4 ambient;
float3 lightPos;

float3 vecEye;

float4x4 mWorld; //world matrix
float4x4 mWorldViewProjection; //world*view*projection matrix

//for the lights
float4x4 mlightVPXp; //view*projection matrix
float4x4 mlightVPYp; //view*projection matrix
float4x4 mlightVPZp; //view*projection matrix
float4x4 mlightVPXn; //view*projection matrix
float4x4 mlightVPYn; //view*projection matrix
float4x4 mlightVPZn; //view*projection matrix

//light

texture t_positive;
sampler positive = 
sampler_state
{
    Texture = < t_positive >;
    AddressU = BORDER;
    AddressV = BORDER;
    BorderColor = {-1.0, 0.0, 0.0, 0.0};
};


texture t_negative;
sampler negative = 
sampler_state
{
    Texture = < t_negative >;
    AddressU = BORDER;
    AddressV = BORDER;
    BorderColor = {-1.0, -1.0, -1.0, 0.0};
};

inline float getDepth(float z, float w)
{
	return pow((z / w),64);
}


inline int isLit(float4 depth, float3 el, sampler tex)
{
	//note depth.xy is in range [-0.5, -0.5]
	float2 t = 0.5 - (depth.xy/depth.w);
	
	float currentDepth = dot(tex2D(tex, t).xyz, el);
	float depthDiff = getDepth(depth.z, depth.w) - currentDepth;
	
	return (currentDepth > 0 && depthDiff < 0.01);
}


//vertex shader
struct VS_OUTPUT
{
	float4 position : POSITION;
	float4 depthX : TEXCOORD0;
	float4 depthY : TEXCOORD1;
	float4 depthZ : TEXCOORD2;
	float4 depthXn : TEXCOORD3;
	float4 depthYn : TEXCOORD4;
	float4 depthZn : TEXCOORD5;
};

VS_OUTPUT PerPixelVS(float4 position : POSITION,
				 float3 normal : NORMAL 
				 //float4 color : COLOR
				 )
{
	VS_OUTPUT Output;
	Output.position = mul(position, mWorldViewProjection);
		
	Output.depthX = mul(position, mul(mWorld,mlightVPXp));
	Output.depthX.x *= -1;
	Output.depthX.xy /= 2;
	
	Output.depthY = mul(position, mul(mWorld,mlightVPYp));
	Output.depthY.x *= -1;
	Output.depthY.xy /= 2;
	
	Output.depthZ = mul(position, mul(mWorld,mlightVPZp));
	Output.depthZ.x *= -1;
	Output.depthZ.xy /= 2;
	
	Output.depthXn = mul(position, mul(mWorld,mlightVPXn));
	Output.depthXn.x *= -1;
	Output.depthXn.xy /= 2;
	
	Output.depthYn = mul(position, mul(mWorld,mlightVPYn));
	Output.depthYn.x *= -1;
	Output.depthYn.xy /= 2;
				
	Output.depthZn = mul(position, mul(mWorld,mlightVPZn));
	Output.depthZn.x *= -1;
	Output.depthZn.xy /= 2;
	
	return Output;
}

/****************
 * PIXEL SHADER *
 ****************/
//output structure for pixel shader
struct PS_OUTPUT
{
    float4 color : COLOR0;  // Pixel color    
};

PS_OUTPUT PerPixelPS(VS_OUTPUT In)
{
	PS_OUTPUT Output;
	Output.color.a = 1;
	float inLight = 0;

	if (!inLight) inLight = isLit(In.depthX, float3(1,0,0), positive);
	if (!inLight) inLight = isLit(In.depthY, float3(0,1,0), positive);
	if (!inLight) inLight = isLit(In.depthZ, float3(0,0,1), positive);
	
	if (!inLight) inLight = isLit(In.depthXn, float3(1,0,0), negative);
	if (!inLight) inLight = isLit(In.depthYn, float3(0,1,0), negative);
	if (!inLight) inLight = isLit(In.depthZn, float3(0,0,1), negative);

	Output.color.xyz = inLight;
	return Output;
}

/**************/
void ShadowMapVS( float4 Pos : POSITION,
                 float3 Normal : NORMAL,
                 out float4 oPos : POSITION,
                 out float2 Depth : TEXCOORD0 )
{
    oPos = mul( Pos, mWorldViewProjection );
    Depth.xy = oPos.zw;
}

void ShadowMapPS( float2 Depth : TEXCOORD0,
                out float4 Color : COLOR0 )
{
    //
    // Depth is z / w
    //
    
    Color = ambient*getDepth(Depth.x , Depth.y);
    Color.a = 1;
}

technique OmniShadowMap
{
	pass P0
	{
		VertexShader = compile vs_3_0 PerPixelVS();
		PixelShader = compile ps_3_0 PerPixelPS();
	}
}


technique OmniShadowDepth
{
	pass P0
	{
		VertexShader = compile vs_2_0 ShadowMapVS();
		PixelShader = compile ps_2_0 ShadowMapPS();
	}
}
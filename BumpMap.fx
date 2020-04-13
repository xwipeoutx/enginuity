
//global light variables
float4 g_pLightAmbient;
float4 g_pLightDiffuse;
float4 g_pLightSpecular;
float3 g_pLightAttenuation;
float g_pLightRange;

int lightType;
float3 lightPos;
int useShadowMap;

//material information
float3 g_pMatAmbient;
float3 g_pMatDiffuse;
float3 g_pMatSpecular;
int g_pMatShininess;

float3 vecEye;

float4x4 mWorld; //world matrix
float4x4 mWorldViewProjection; //world*view*projection matrix

//model texture
int g_pUseTexture = 0;
texture g_pTexColourmap;
sampler colourmap = 
sampler_state
{
    Texture = < g_pTexColourmap >;
    MipFilter = LINEAR;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
};

//normal map
texture t_normalmap;
sampler normalmap = 
sampler_state
{
    Texture = < t_normalmap >;
    MipFilter = LINEAR;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
};

//shadow map
texture t_shadowMap;
sampler shadowMap = 
sampler_state
{
    Texture = < t_shadowMap >;
};

//vertex shader
struct VS_OUTPUT
{
	float4 position : POSITION;
	float4 color : COLOR;
	float2 texcoords : TEXCOORD0;
	float3 norm : TEXCOORD1;
	float3 pos : TEXCOORD2;
	float3 view : TEXCOORD3;
	float4 smcoords : TEXCOORD4;
};

VS_OUTPUT BumpMapVS(float4 position : POSITION,
				 float3 normal : NORMAL, 
				 float4 color : COLOR,
				 float2 texcoords : TEXCOORD
				 )
{
	VS_OUTPUT Output;

	float4 color1 = float4(1.0,0.5,0.25,1);

	Output.position = mul(position, mWorldViewProjection);
	Output.norm = normal;//mul(normal,mWorld);
	Output.pos = mul(position, mWorld);
	Output.view = vecEye - Output.pos;
	Output.color = color;
	Output.color = color1;
	Output.texcoords = texcoords;
	Output.smcoords = Output.position;
	
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

PS_OUTPUT BumpMapPS(VS_OUTPUT In)
{
	PS_OUTPUT Output;
	float4 colour = In.color;
	
	Output.color.a = 1;
	
	if (g_pUseTexture)
		colour = tex2D(colourmap, In.texcoords*4);
		
	int lit = 1;
	if (useShadowMap)
	{
		float2 texcoords = 0.5-In.smcoords.xy/In.smcoords.w/2;
		texcoords.x = 1-texcoords.x;
		lit = tex2D(shadowMap, texcoords);
	}
	
	float3 relativePos = lightPos;
	float attenuationFactor = 1;
	if (lightType == 1) //point
	{
		attenuationFactor = 1;
		relativePos = lightPos - In.pos;
		float distance = length(relativePos);
		distance = distance / g_pLightRange;
		
		attenuationFactor -= g_pLightAttenuation.x;
		attenuationFactor -= (distance * g_pLightAttenuation.y);
		attenuationFactor -= (distance * distance * g_pLightAttenuation.z);
	}
	
	//this bit is WEIRD - it turns out the normal maps that come with 
	//directx samples are defined completely different to how normal people
	//would do it... -zxy or -zyx seems to get it ok.
	//The default normal seems to be (-1, 0, 0). Oh well, we'll stick with it.
	
	float3 norm = -(tex2D(normalmap, In.texcoords*4).zyx * 2 - 1);
	//float3 norm = (tex2D(normalmap, In.texcoords).yzx * 2 - 1);
	//float3 norm = float3(-1,0,0); //this works
	norm = mul(norm, mWorld);
	norm = normalize(norm);
	//Output.color.xyz = g_pMatSpecular.xyz;
	//return Output;
	
	float3 viewDir = normalize(In.view);
	float3 light = normalize(relativePos);
	float4 diff = saturate(dot(light , norm));
	
	float3 reflect = normalize(2 * diff * norm - light);
	
	float shadow = saturate(4*diff);
	
	float3 totalAmbient = g_pMatAmbient*g_pLightAmbient;
	float3 totalDiffuse = g_pMatDiffuse*g_pLightDiffuse.xyz * diff;
	float3 totalSpecular = g_pMatSpecular*g_pLightSpecular.xyz * pow(saturate(dot(reflect, viewDir)),g_pMatShininess);
	if (g_pMatShininess == 0) totalSpecular=0;
	
	Output.color.xyz = 
		totalAmbient + lit*shadow*(totalDiffuse + totalSpecular);

	Output.color.xyz *= attenuationFactor * colour;
	
	//Output.color.xyz = norm.xyz;
	return Output;
}

technique BumpMap
{
	pass P0
	{
		VertexShader = compile vs_2_0 BumpMapVS();
		PixelShader = compile ps_2_0 BumpMapPS();
	}
}
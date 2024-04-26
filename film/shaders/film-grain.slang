#version 450

/*
Film Grain post-process shader v1.1    
Martins Upitis (martinsh) devlog-martinsh.blogspot.com
2013

Original shader:
https://devlog-martinsh.blogspot.com/2013/05/image-imperfections-and-film-grain-post.html

--------------------------
This work is licensed under a Creative Commons Attribution 3.0 Unported License.
So you are free to share, modify and adapt it for your needs, and even use it for commercial use.
I would also love to hear about a project you are using it.

Have fun,
Martins
--------------------------
https://www.shadertoy.com/view/Mly3Rw

Perlin noise shader by toneburst:
http://machinesdontcare.wordpress.com/2009/06/25/3d-perlin-noise-sphere-vertex-shader-sourcecode/
*/


//    Ported by Hyllian - 2024


layout(push_constant) uniform Push
{
    vec4 SourceSize;
    vec4 OriginalSize;
    vec4 OutputSize;
    uint FrameCount;
    float GRAIN_AMOUNT, COLOR_AMOUNT, GRAIN_SIZE;
    float LUM_AMOUNT;
    float COLORED;
} params;


#pragma parameter GRAIN_AMOUNT "Grain amount"        0.02 0.01 0.2 0.01
#pragma parameter COLOR_AMOUNT "Color amount"        0.6 0.0 1.0 0.1
#pragma parameter GRAIN_SIZE   "Grain particle size" 1.6 1.5 2.5 0.1
#pragma parameter LUM_AMOUNT   "Luminance amount"    1.0 0.0 2.0 0.1
#pragma parameter COLORED      "Use colored noise"   0.0 0.0 1.0 1.0

#define GRAIN_AMOUNT params.GRAIN_AMOUNT
#define COLOR_AMOUNT params.COLOR_AMOUNT
#define GRAIN_SIZE   params.GRAIN_SIZE
#define LUM_AMOUNT   params.LUM_AMOUNT
#define COLORED      params.COLORED

float timer = mod(params.FrameCount, 4268.);           // Global timer

const float permTexUnit     = 1.0/256.0;               // Perm texture texel-size
const float permTexUnitHalf = 0.5/256.0;               // Half perm texture texel-size
const vec3  rotOffset       = vec3(1.425,3.892,5.835); // Rotation offset values    
const vec3  lumcoeff        = vec3(0.299,0.587,0.114);


layout(std140, set = 0, binding = 0) uniform UBO
{
    mat4 MVP;
} global;

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;

void main()
{
    gl_Position = global.MVP * Position;
    vTexCoord = TexCoord;
}


#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;

//a random texture generator, but you can also use a pre-computed perturbation texture
vec4 rnm(vec2 tc) 
{
    float noise =  sin(dot(tc + vec2(timer,timer),vec2(12.9898,78.233))) * 43758.5453;

    float noiseR =  fract(noise)*2.0-1.0;
    float noiseG =  fract(noise*1.2154)*2.0-1.0; 
    float noiseB =  fract(noise*1.3453)*2.0-1.0;
    float noiseA =  fract(noise*1.3647)*2.0-1.0;
    
    return vec4(noiseR,noiseG,noiseB,noiseA);
}

float fade(float t) {
    return t*t*t*(t*(t*6.0-15.0)+10.0);
}

float pnoise3D(vec3 p)
{
    vec3 pi = permTexUnit*floor(p)+permTexUnitHalf; // Integer part, scaled so +1 moves permTexUnit texel
    // and offset 1/2 texel to sample texel centers
    vec3 pf = fract(p);     // Fractional part for interpolation

    // Noise contributions from (x=0, y=0), z=0 and z=1
    float perm00 = rnm(pi.xy).a ;
    vec3  grad000 = rnm(vec2(perm00, pi.z)).rgb * 4.0 - 1.0;
    float n000 = dot(grad000, pf);
    vec3  grad001 = rnm(vec2(perm00, pi.z + permTexUnit)).rgb * 4.0 - 1.0;
    float n001 = dot(grad001, pf - vec3(0.0, 0.0, 1.0));

    // Noise contributions from (x=0, y=1), z=0 and z=1
    float perm01 = rnm(pi.xy + vec2(0.0, permTexUnit)).a ;
    vec3  grad010 = rnm(vec2(perm01, pi.z)).rgb * 4.0 - 1.0;
    float n010 = dot(grad010, pf - vec3(0.0, 1.0, 0.0));
    vec3  grad011 = rnm(vec2(perm01, pi.z + permTexUnit)).rgb * 4.0 - 1.0;
    float n011 = dot(grad011, pf - vec3(0.0, 1.0, 1.0));

    // Noise contributions from (x=1, y=0), z=0 and z=1
    float perm10 = rnm(pi.xy + vec2(permTexUnit, 0.0)).a ;
    vec3  grad100 = rnm(vec2(perm10, pi.z)).rgb * 4.0 - 1.0;
    float n100 = dot(grad100, pf - vec3(1.0, 0.0, 0.0));
    vec3  grad101 = rnm(vec2(perm10, pi.z + permTexUnit)).rgb * 4.0 - 1.0;
    float n101 = dot(grad101, pf - vec3(1.0, 0.0, 1.0));

    // Noise contributions from (x=1, y=1), z=0 and z=1
    float perm11 = rnm(pi.xy + vec2(permTexUnit, permTexUnit)).a ;
    vec3  grad110 = rnm(vec2(perm11, pi.z)).rgb * 4.0 - 1.0;
    float n110 = dot(grad110, pf - vec3(1.0, 1.0, 0.0));
    vec3  grad111 = rnm(vec2(perm11, pi.z + permTexUnit)).rgb * 4.0 - 1.0;
    float n111 = dot(grad111, pf - vec3(1.0, 1.0, 1.0));

    // Blend contributions along x
    vec4 n_x = mix(vec4(n000, n001, n010, n011), vec4(n100, n101, n110, n111), fade(pf.x));

    // Blend contributions along y
    vec2 n_xy = mix(n_x.xy, n_x.zw, fade(pf.y));

    // Blend contributions along z
    float n_xyz = mix(n_xy.x, n_xy.y, fade(pf.z));

    // We're done, return the final noise value.
    return n_xyz;
}

//2d coordinate orientation thing
vec2 coordRot(in vec2 tc, in float angle, float width, float height)
{
    float aspect = width/height;
    float rotX = ((tc.x*2.0-1.0)*aspect*cos(angle)) - ((tc.y*2.0-1.0)*sin(angle));
    float rotY = ((tc.y*2.0-1.0)*cos(angle)) + ((tc.x*2.0-1.0)*aspect*sin(angle));
    rotX = ((rotX/aspect)*0.5+0.5);
    rotY = rotY*0.5+0.5;
    return vec2(rotX,rotY);
}

void main()
{
    float width  = params.SourceSize.x;
    float height = params.SourceSize.y;

    float dx = params.SourceSize.z;
    float dy = params.SourceSize.w;

    vec2 texCoord = vTexCoord;
    
    vec2 rotCoordsR = coordRot(texCoord, timer + rotOffset.x, width, height);
    vec3 noise = vec3(pnoise3D(vec3(rotCoordsR*vec2(width/GRAIN_SIZE,height/GRAIN_SIZE),0.0)));
  
    if (COLORED == 1.0)
    {
        vec2 rotCoordsG = coordRot(texCoord, timer + rotOffset.y, width, height);
        vec2 rotCoordsB = coordRot(texCoord, timer + rotOffset.z, width, height);
        noise.g = mix(noise.r,pnoise3D(vec3(rotCoordsG*vec2(width/GRAIN_SIZE,height/GRAIN_SIZE),1.0)),COLOR_AMOUNT);
        noise.b = mix(noise.r,pnoise3D(vec3(rotCoordsB*vec2(width/GRAIN_SIZE,height/GRAIN_SIZE),2.0)),COLOR_AMOUNT);
    }

    vec3 col = texture(Source, texCoord).rgb;

    //noisiness response curve based on scene luminance
    float luminance = mix(0.0,dot(col, lumcoeff),LUM_AMOUNT);
    float lum = smoothstep(0.2,0.0,luminance);
    lum += luminance;
    
    
    noise = mix(noise,vec3(0.0),pow(lum,4.0));
    col = col+noise*GRAIN_AMOUNT;
   
    FragColor =  vec4(col,1.0);
}

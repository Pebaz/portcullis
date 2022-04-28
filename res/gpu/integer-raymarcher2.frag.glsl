/*
Author: TrueBoolean https://www.shadertoy.com/view/slXfWN
*/

precision mediump float;

in vec2 uv;
out vec4 color;

uniform vec4 rectangle_color;
uniform uint using_rectangle_texture;
uniform vec2 resolution;
uniform float time;
uniform sampler2D rectangle_texture;

#define iResolution resolution
#define iTime time

#define ITER 1024
#define SCALE 8
void mainImage( out vec4 FCOL, in vec2 FPT ){

    ivec2 PT = ivec2(FPT-iResolution.xy/2.);
    int SIZE = int(min(iResolution.x, iResolution.y))/SCALE;
    ivec2 look = ivec2(int(sin(iTime)*float(SIZE)));
    int scroll = int(iTime*256.)/3;

    ivec2 sum = ivec2(0);
    ivec2 ray = sum;
    int z;
    for(z=scroll;z<ITER+scroll;++z){
        sum += PT;
        sum += look;
        ray = sum>>8;
        if((z&64) != 0 && abs(ray.x) > SIZE || abs(ray.y) > SIZE)
            break;
    }
    ivec3 COL = ivec3((ray.x^ray.y^z)&255);
    if(abs(ray.y) > SIZE)
        COL.x>>=1;
    if(abs(ray.x) > SIZE)
        COL.y>>=1;
    if(z == ITER + scroll)
        COL = ivec3(0);

    FCOL = vec4(vec3(COL)/float(ITER), 1.);
}

void main()
{
    vec2 uv = (2.0 * gl_FragCoord.xy - resolution.xy) / resolution.y;

    mainImage(color, gl_FragCoord.xy);

    // Without this, the GPU compiler optimizes out the uniforms
    if (using_rectangle_texture > uint(0))
    {
        vec4 sample = texture(rectangle_texture, uv);
        color = sample * rectangle_color;
    }
}

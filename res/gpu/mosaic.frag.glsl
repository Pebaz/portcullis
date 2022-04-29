/*
Author: Xor https://www.shadertoy.com/view/slsfRB
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

void mainImage(out vec4 O, vec2 I)
{
    vec3 r = iResolution, c = vec3(0,2,1), T = iTime + c, P = (I+I-r.xy)/r.y*mat3x2(-71,41, 0,-82, 71,41) / 6e1+.2;
    int A = int(T.z) / 2 % 3;
    O=min((.08-length(max(abs(fract(
    P+=(T-sin(T*6.283)/6.).x*floor(mod(T,3.)-1.)*cos(ceil(P[int(T.y)%3])*3.14)
    )-.5)-.4,0.)))*.2*r.y,1.)
    *(sin(dot(mod(ceil(P+vec3(A<1,A<2,A-1)),2.),c+7.)-c)*.5+.5).xzyz;
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

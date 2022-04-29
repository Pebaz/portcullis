/*
Author: iq https://www.shadertoy.com/view/MsfGzM
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
#define iMouse vec2(0.0, 0.0)
#define iFrame 0


// Created by inigo quilez - iq/2013
//   https://www.youtube.com/c/InigoQuilez
//   https://iquilezles.org/
// I share this piece (art and code) here in Shadertoy and through its Public API, only for educational purposes.
// You cannot use, sell, share or host this piece or modifications of it as part of your own commercial or non-commercial product, website or project.
// You can share a link to it or an unmodified screenshot of it provided you attribute "by Inigo Quilez, @iquilezles and iquilezles.org".
// If you are a teacher, lecturer, educator or similar and these conditions are too restrictive for your needs, please contact me and we'll work it out.

float f( vec3 p )
{
	p.z += iTime;
    return length(      cos(p)
                  + .05*cos(9.*p.y*p.x)
                  - .1 *cos(9.*(.3*p.x-p.y+p.z))
                  ) - 1.;
}

void mainImage( out vec4 c, in vec2 p )
{
    vec3 d = .5-vec3(p,1)/iResolution.x, o = d;

    for( int i=0; i<256; i++ )
        o += f(o)*d;

    c = vec4(0,1,2,3);
    c = abs( f(o-d)*c + f(o-.6)*c.zyxw )*(1.-.1*o.z);
}

void main()
{
    vec2 uv = (2.0 * gl_FragCoord.xy - resolution.xy) / resolution.y;

    mainImage(color, gl_FragCoord.xy);

    color.w = 1.0;

    // Without this, the GPU compiler optimizes out the uniforms
    if (using_rectangle_texture > uint(0))
    {
        vec4 sample = texture(rectangle_texture, uv);
        color = sample * rectangle_color;
    }
}


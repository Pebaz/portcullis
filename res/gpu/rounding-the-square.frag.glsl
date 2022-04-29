/*
Author: iq https://www.shadertoy.com/view/3dsSWs
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
#define iMouse vec3(0.0, 0.0, 0.0)
#define iFrame 0

// Created by inigo quilez - iq/2019
// License Creative Commons Attribution-NonCommercial-ShareAlike 3.0 Unported License.


// Converting the unit square into the unit circle, from
// https://arxiv.org/ftp/arxiv/papers/1509/1509.06344.pdf
// but I realized it could be much simplified.
//
// v = maxcomp(abs(v))*normalize(v)
//
// Also I developped an improvement over it to make it more
// uniform.


#define IMPROVED 1           // make 0 for faster approach

//-----------------------------------------------

float dot2( in vec2 v ) { return dot(v,v); }
float maxcomp( in vec2 v ) { return max(v.x,v.y); }

// Take a point in the unit square [-1,1]^2 and map it
// into a point in the unit disk
vec2 square2circle( in vec2 v )
{
    #if IMPROVED==0
    return maxcomp(abs(v))*normalize(v);
    #else
    return maxcomp(abs(v))*normalize(v*(2.0+abs(v)));
    #endif
}

vec2 circle2square( vec2 v )
{
    #if IMPROVED==0
    return v*length(v)/maxcomp(abs(v));
    #else
    return vec2(0.0);
    #endif
}


//-----------------------------------------------

float sdLineSq( in vec2 p, in vec2 a, in vec2 b )
{
	vec2 pa = p-a, ba = b-a;
	float h = clamp(dot(pa,ba)/dot(ba,ba),0.0,1.0);
	return dot2(pa-ba*h);
}

float sdPointSq( in vec2 p, in vec2 a )
{
    return dot2(p-a);
}

//-----------------------------------------------

vec2 vertex( int i, int j, int num, float anim)
{
    // unit square
    vec2 s = -1.0+2.0*vec2(i,j)/float(num);

    // unit circle
    vec2 c = square2circle(s);

    // blend
    return mix(c,s,anim);
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    // plane coords
    vec2 p = (2.0*fragCoord-iResolution.xy)/iResolution.y;
    float w = 2.0/iResolution.y;

    // scale
	p *= 1.15;
	w *= 1.15;

    // anim
    float anim = smoothstep(-0.6,0.6,cos(iTime*2.0+0.0));
    float show = smoothstep(-0.1,0.1,sin(iTime*1.0+3.4));

    // mesh: body
    vec2 di = vec2(10.0);
    const int num = 11;         // Make "num" odd. If even is desired, the
	for( int j=0; j<num; j++ )  // normalize() in square2circle() should be
	for( int i=0; i<num; i++ )  // protected against divisions by zero.
    {
        vec2 a = vertex(i+0,j+0,num,anim);
        vec2 b = vertex(i+1,j+0,num,anim);
        vec2 c = vertex(i+0,j+1,num,anim);
        di = min( di, vec2(min(sdLineSq(p,a,b),
                               sdLineSq(p,a,c)),
                               sdPointSq(p,a)));
    }
    // mesh: top and right edges
	for( int j=0; j<num; j++ )
    {
        vec2 a = vertex(num,j+0,num,anim);
        vec2 b = vertex(num,j+1,num,anim);
        vec2 c = vertex(j+0,num,num,anim);
        vec2 d = vertex(j+1,num,num,anim);
        di = min( di, vec2(min(sdLineSq(p,a,b),
                               sdLineSq(p,c,d)),
                           min(sdPointSq(p,a),
                               sdPointSq(p,c))));
    }
    // mesh: top-right corner
    di.y = min( di.y, sdPointSq(p,vertex(num,num,num,anim)));
    di = sqrt(di);


    // background
    vec3 col = vec3(1.0);

    // colorize displacement
    vec2 q = square2circle(p);
    vec2 p1 = mix(q,p,    anim);
    vec2 p2 = mix(q,p,1.0-anim);
    col = mix( col, 0.6 + 0.5*cos(length(p-p1)*15.0 + 2.5+vec3(0,2,4) ),
               show*smoothstep(0.999,0.99,length(p2)) );
    // draw mesh
    col *= 0.9+0.1*smoothstep(0.0,0.05,di.x);
    col *= smoothstep(0.0,0.008,di.x);
    col *= smoothstep(0.03,0.03+w,di.y );

    // vignette
    col *= 1.0 - 0.15*length(p);

    // output
    fragColor = vec4(col,1.0);
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

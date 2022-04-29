/*
Author: iq https://www.shadertoy.com/view/4sXGDN
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

// Created by inigo quilez - iq/2013
// License Creative Commons Attribution-NonCommercial-ShareAlike 3.0 Unported License.

// Other "Iterations" shaders:
//
// "trigonometric"   : https://www.shadertoy.com/view/Mdl3RH
// "trigonometric 2" : https://www.shadertoy.com/view/Wss3zB
// "circles"         : https://www.shadertoy.com/view/MdVGWR
// "coral"           : https://www.shadertoy.com/view/4sXGDN
// "guts"            : https://www.shadertoy.com/view/MssGW4
// "inversion"       : https://www.shadertoy.com/view/XdXGDS
// "inversion 2"     : https://www.shadertoy.com/view/4t3SzN
// "shiny"           : https://www.shadertoy.com/view/MslXz8
// "worms"           : https://www.shadertoy.com/view/ldl3W4
// "stripes"         : https://www.shadertoy.com/view/wlsfRn

#define AA 2

// define this for slow machines - uses dFdx to approximatge derivatives
//#define LOW_QUALITY

float hash( vec2 p )
{
    vec2 q  = 50.0*fract( p*0.3183099 );
    return -1.0+2.0*fract( (q.x+2.0)*(q.y+5.0)*(q.x+q.y) );
}

float noise( in vec2 p )
{
    vec2 i = floor( p );
    vec2 f = fract( p );

	vec2 u = f*f*(3.0-2.0*f);

    return mix( mix( hash( i + vec2(0.0,0.0) ),
                     hash( i + vec2(1.0,0.0) ), u.x),
                mix( hash( i + vec2(0.0,1.0) ),
                     hash( i + vec2(1.0,1.0) ), u.x), u.y);
}

vec2 iterate( in vec2 p, in vec4 t )
{
	float an  = noise(13.0*p)*3.1416;
	      an += noise(10.0*p)*3.1416;

	return p + 0.01*vec2(cos(an),sin(an));
}

vec2 doPattern( in vec2 p, in vec4 t )
{
    vec2 z = p;
    vec2 s = vec2(0.0);
    for( int i=0; i<100; i++ )
    {
        z = iterate( z, t );

        float d = dot( z-p, z-p );
        s.x += abs(p.x-z.x);
        s.y = max( s.y, d );
    }
    s.x /= 100.0;
	return s;
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec4 t = 0.15*iTime*vec4( 1.0, -1.5, 1.2, -1.6 ) + vec4(0.0,2.0,3.0,1.0);

    vec3 tot = vec3(0.0);
    #if AA>1
    for( int jj=0; jj<AA; jj++ )
    for( int ii=0; ii<AA; ii++ )
    #else
    int ii = 0, jj = 0;
    #endif
    {
        vec2 off = vec2(float(ii),float(jj))/float(AA);

#ifdef LOW_QUALITY
        vec2 p = (-iResolution.xy + 2.0*(fragCoord+off)) / iResolution.y;
        p *= 0.85 * (3.0+2.0*cos(3.1*iTime/10.0));

        vec2 s = doPattern(p,t);

        vec3 nor = normalize( vec3( dFdx(s.x), 0.001, dFdy(s.x) ) );
#else

        vec2 pc = (-iResolution.xy + 2.0*(fragCoord+vec2(0,0)+off)) / iResolution.y;
        vec2 px = (-iResolution.xy + 2.0*(fragCoord+vec2(1,0)+off)) / iResolution.y;
        vec2 py = (-iResolution.xy + 2.0*(fragCoord+vec2(0,1)+off)) / iResolution.y;

        pc *= 0.85 * (3.0+2.0*cos(3.1*iTime/10.0));
        px *= 0.85 * (3.0+2.0*cos(3.1*iTime/10.0));
        py *= 0.85 * (3.0+2.0*cos(3.1*iTime/10.0));

        vec2 sc = doPattern(pc,t);
        vec2 sx = doPattern(px,t);
        vec2 sy = doPattern(py,t);

        vec3 nor = normalize( vec3( sx.x-sc.x, 0.001, sy.x-sc.x ) );

		vec2 s = sc;
        vec2 p = pc;
#endif
        vec3 col = 0.5 + 0.5*cos( s.y*3.2 + 0.5+vec3(4.5,2.4,1.5) );
        col *= s.x*4.0;
        col -= vec3(0.2)*dot( nor, vec3(0.7,0.1,0.7) );
		col *= 1.4*s.y;
        col = sqrt(col)-0.16;
        col += 0.3*s.x*s.y*noise(p*100.0 + 40.0*s.y);
        col *= vec3(1.0,1.,1.4);


        tot += col;
    }
    tot = tot/float(AA*AA);

    vec2 q = fragCoord / iResolution.xy;
    tot *= 0.5 + 0.5*pow( 16.0*q.x*q.y*(1.0-q.x)*(1.0-q.y), 0.1 );

	fragColor = vec4( tot, 1.0 );
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

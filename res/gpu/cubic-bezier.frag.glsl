/*
Author: iq https://www.shadertoy.com/view/XdVBWd
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

// The MIT License
// Copyright © 2018 Inigo Quilez
// Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions: The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software. THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.


// Computes the exact axis aligned bounding box to a cubic Bezier curve. Since
// the bezier is cubic, the bbox can be compute with a quadratic equation:
//
//   Yellow: naive bbox of the 4 control points
//   Blue: exact bbox
//
// More info here: https://iquilezles.org/articles/bezierbbox
//
// Related Shaders:
//     Quadratic Bezier - 3D      : https://www.shadertoy.com/view/ldj3Wh
//     Cubic     Bezier - 2D BBox : https://www.shadertoy.com/view/XdVBWd
//     Cubic     Bezier - 3D BBox : https://www.shadertoy.com/view/MdKBWt
//     Quadratic Bezier - 2D BBox : https://www.shadertoy.com/view/lsyfWc
//     Quadratic Bezier - 3D BBox : https://www.shadertoy.com/view/tsBfRD


#if 1
// Exact BBox to a quadratic bezier
vec4 bboxBezier(in vec2 p0, in vec2 p1, in vec2 p2, in vec2 p3 )
{
    // extremes
    vec2 mi = min(p0,p3);
    vec2 ma = max(p0,p3);

    vec2 k0 = -1.0*p0 + 1.0*p1;
    vec2 k1 =  1.0*p0 - 2.0*p1 + 1.0*p2;
    vec2 k2 = -1.0*p0 + 3.0*p1 - 3.0*p2 + 1.0*p3;

    vec2 h = k1*k1 - k0*k2;

    if( h.x>0.0 )
    {
        h.x = sqrt(h.x);
        //float t = (-k1.x - h.x)/k2.x;
        float t = k0.x/(-k1.x-h.x);
        if( t>0.0 && t<1.0 )
        {
            float s = 1.0-t;
            float q = s*s*s*p0.x + 3.0*s*s*t*p1.x + 3.0*s*t*t*p2.x + t*t*t*p3.x;
            mi.x = min(mi.x,q);
            ma.x = max(ma.x,q);
        }
        //t = (-k1.x + h.x)/k2.x;
        t = k0.x/(-k1.x+h.x);
        if( t>0.0 && t<1.0 )
        {
            float s = 1.0-t;
            float q = s*s*s*p0.x + 3.0*s*s*t*p1.x + 3.0*s*t*t*p2.x + t*t*t*p3.x;
            mi.x = min(mi.x,q);
            ma.x = max(ma.x,q);
        }
    }

    if( h.y>0.0)
    {
        h.y = sqrt(h.y);
        //float t = (-k1.y - h.y)/k2.y;
        float t = k0.y/(-k1.y-h.y);
        if( t>0.0 && t<1.0 )
        {
            float s = 1.0-t;
            float q = s*s*s*p0.y + 3.0*s*s*t*p1.y + 3.0*s*t*t*p2.y + t*t*t*p3.y;
            mi.y = min(mi.y,q);
            ma.y = max(ma.y,q);
        }
        //t = (-k1.y + h.y)/k2.y;
        t = k0.y/(-k1.y+h.y);
        if( t>0.0 && t<1.0 )
        {
            float s = 1.0-t;
            float q = s*s*s*p0.y + 3.0*s*s*t*p1.y + 3.0*s*t*t*p2.y + t*t*t*p3.y;
            mi.y = min(mi.y,q);
            ma.y = max(ma.y,q);
        }
    }

    return vec4( mi, ma );
}
#else
vec4 bboxBezier(in vec2 p0, in vec2 p1, in vec2 p2, in vec2 p3 )
{
    // extremes
    vec2 mi = min(p0,p3);
    vec2 ma = max(p0,p3);

    // note pascal triangle coefficnets
    vec2 c = -1.0*p0 + 1.0*p1;
    vec2 b =  1.0*p0 - 2.0*p1 + 1.0*p2;
    vec2 a = -1.0*p0 + 3.0*p1 - 3.0*p2 + 1.0*p3;

    vec2 h = b*b - a*c;

    // real solutions
    if( any(greaterThan(h,vec2(0.0))))
    {
        vec2 g = sqrt(abs(h));
        vec2 t1 = clamp((-b - g)/a,0.0,1.0); vec2 s1 = 1.0-t1;
        vec2 t2 = clamp((-b + g)/a,0.0,1.0); vec2 s2 = 1.0-t2;
        vec2 q1 = s1*s1*s1*p0 + 3.0*s1*s1*t1*p1 + 3.0*s1*t1*t1*p2 + t1*t1*t1*p3;
        vec2 q2 = s2*s2*s2*p0 + 3.0*s2*s2*t2*p1 + 3.0*s2*t2*t2*p2 + t2*t2*t2*p3;

        if( h.x > 0.0 )
        {
            mi.x = min(mi.x,min(q1.x,q2.x));
            ma.x = max(ma.x,max(q1.x,q2.x));
        }

        if( h.y > 0.0  )
        {
            mi.y = min(mi.y,min(q1.y,q2.y));
            ma.y = max(ma.y,max(q1.y,q2.y));
        }
    }

    return vec4( mi, ma );
}
#endif

// Approximated conservative BBox to a cubic bezier
vec4 bboxBezierSimple(in vec2 p0, in vec2 p1, in vec2 p2, in vec2 p3 )
{
    vec2 mi = min(min(p0,p1),min(p2,p3));
    vec2 ma = max(max(p0,p1),max(p2,p3));

    return vec4( mi, ma );
}

//---------------------------------------------------------------------------------------

float sdBox( in vec2 p, in vec2 b )
{
    vec2 q = abs(p) - b;
    vec2 m = vec2( min(q.x,q.y), max(q.x,q.y) );
    return (m.x > 0.0) ? length(q) : m.y;
}

float length2( in vec2 v ) { return dot(v,v); }

float sdSegmentSq( in vec2 p, in vec2 a, in vec2 b )
{
	vec2 pa = p-a, ba = b-a;
	float h = clamp( dot(pa,ba)/dot(ba,ba), 0.0, 1.0 );
	return length2( pa - ba*h );
}

float sdSegment( in vec2 p, in vec2 a, in vec2 b )
{
	return sqrt(sdSegmentSq(p,a,b));
}

// slow, do not use in production. Can probably do better than
// tesselation in linear segments.
vec2 udBezier(vec2 p0, vec2 p1, vec2 p2, in vec2 p3, vec2 pos)
{
    const int kNum = 50;
    vec2 res = vec2(1e10,0.0);
    vec2 a = p0;
    for( int i=1; i<kNum; i++ )
    {
        float t = float(i)/float(kNum-1);
        float s = 1.0-t;
        vec2 b = p0*s*s*s + p1*3.0*s*s*t + p2*3.0*s*t*t + p3*t*t*t;
        float d = sdSegmentSq( pos, a, b );
        if( d<res.x ) res = vec2(d,t);
        a = b;
    }

    return vec2(sqrt(res.x),res.y);
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    //--------
    // animate
    //--------
    float time = iTime*0.5 - 0.7;
    vec2 p0 = 0.8*sin( time*0.7 + vec2(3.0,1.0) );
    vec2 p1 = 0.8*sin( time*1.1 + vec2(0.0,6.0) );
    vec2 p2 = 0.8*sin( time*1.3 + vec2(4.0,2.0) );
    vec2 p3 = 0.8*sin( time*1.5 + vec2(1.0,5.0) );

	//-------------
    // compute bbox
	//-------------
    vec4 b1 = bboxBezierSimple(p0,p1,p2,p3);
    vec4 b2 = bboxBezier(p0,p1,p2,p3);

    //--------
    // render
    //--------

    vec2 p = (2.0*fragCoord-iResolution.xy)/iResolution.y;
    float px = 2.0/iResolution.y;

    // background
    vec3 col = vec3(0.15);
    float be = udBezier( p0, p1, p2, p3, p ).x;
	col += 0.03*sin(be*150.0);
    col *= 1.0 - 0.3*length(p);


    // naive bbox
    float d = sdBox( p-(b1.xy+b1.zw)*0.5, (b1.zw-b1.xy)*0.5 );
    col = mix( col, vec3(1.0,0.6,0.0), 1.0-smoothstep(0.003,0.003+px,abs(d)) );

    // exact bbox
    d = sdBox( p-(b2.xy+b2.zw)*0.5, (b2.zw-b2.xy)*0.5 );
    col = mix( col, vec3(0.2,0.5,1.0), 1.0-smoothstep(0.003,0.003+px,abs(d)) );

    // control cage
    d = sdSegment( p, p0, p1 );
    col = mix( col, vec3(0.3), 1.0-smoothstep(0.003,0.003+px,d) );
    d = sdSegment( p, p1, p2 );
    col = mix( col, vec3(0.3), 1.0-smoothstep(0.003,0.003+px,d) );
    d = sdSegment( p, p2, p3 );
    col = mix( col, vec3(0.3), 1.0-smoothstep(0.003,0.003+px,d) );

    // bezier
    d = be;
    col = mix( col, vec3(1.0), 1.0-smoothstep(0.003,0.003+px*1.5,d) );

    // control points
    d = length(p0-p); col = mix( col, vec3(1.0), 1.0-smoothstep(0.04,0.04+px,d) );
    d = length(p1-p); col = mix( col, vec3(1.0), 1.0-smoothstep(0.04,0.04+px,d) );
    d = length(p2-p); col = mix( col, vec3(1.0), 1.0-smoothstep(0.04,0.04+px,d) );
    d = length(p3-p); col = mix( col, vec3(1.0), 1.0-smoothstep(0.04,0.04+px,d) );

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

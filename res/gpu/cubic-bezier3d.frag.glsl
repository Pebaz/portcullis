/*
Author: iq https://www.shadertoy.com/view/MdKBWt
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
// Copyright © 2017 Inigo Quilez
// Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions: The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software. THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.



// Analytical computation of the exact bounding box for a cubic bezier segment
//
// See https://iquilezles.org/articles/bezierbbox


// Other bounding box functions:
//
// Disk             - 3D BBox : https://www.shadertoy.com/view/ll3Xzf
// Cylinder         - 3D BBox : https://www.shadertoy.com/view/MtcXRf
// Ellipse          - 3D BBox : https://www.shadertoy.com/view/Xtjczw
// Cone boundong    - 3D BBox : https://www.shadertoy.com/view/WdjSRK
// Cubic     Bezier - 2D BBox : https://www.shadertoy.com/view/XdVBWd
// Cubic     Bezier - 3D BBox : https://www.shadertoy.com/view/MdKBWt
// Quadratic Bezier - 2D BBox : https://www.shadertoy.com/view/lsyfWc
// Quadratic Bezier - 3D BBox : https://www.shadertoy.com/view/tsBfRD


#define AA 3

struct bound3
{
    vec3 mMin;
    vec3 mMax;
};

//---------------------------------------------------------------------------------------
// bounding box for a bezier (https://iquilezles.org/articles/bezierbbox)
//---------------------------------------------------------------------------------------
bound3 BezierAABB( in vec3 p0, in vec3 p1, in vec3 p2, in vec3 p3 )
{
    // extremes
    vec3 mi = min(p0,p3);
    vec3 ma = max(p0,p3);

    // note pascal triangle coefficnets
    vec3 c = -1.0*p0 + 1.0*p1;
    vec3 b =  1.0*p0 - 2.0*p1 + 1.0*p2;
    vec3 a = -1.0*p0 + 3.0*p1 - 3.0*p2 + 1.0*p3;

    vec3 h = b*b - a*c;

    // real solutions
    if( any(greaterThan(h,vec3(0.0))))
    {
        vec3 g = sqrt(abs(h));
        vec3 t1 = clamp((-b - g)/a,0.0,1.0); vec3 s1 = 1.0-t1;
        vec3 t2 = clamp((-b + g)/a,0.0,1.0); vec3 s2 = 1.0-t2;
        vec3 q1 = s1*s1*s1*p0 + 3.0*s1*s1*t1*p1 + 3.0*s1*t1*t1*p2 + t1*t1*t1*p3;
        vec3 q2 = s2*s2*s2*p0 + 3.0*s2*s2*t2*p1 + 3.0*s2*t2*t2*p2 + t2*t2*t2*p3;

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
        if( h.z > 0.0  )
        {
            mi.z = min(mi.z,min(q1.z,q2.z));
            ma.z = max(ma.z,max(q1.z,q2.z));
        }
    }

    return bound3( mi, ma );
}


// ray-ellipse intersection
float iEllipse( in vec3 ro, in vec3 rd,         // ray: origin, direction
             in vec3 c, in vec3 u, in vec3 v )  // disk: center, 1st axis, 2nd axis
{
	vec3 q = ro - c;
	vec3 r = vec3(
        dot( cross(u,v), q ),
		dot( cross(q,u), rd ),
		dot( cross(v,q), rd ) ) /
        dot( cross(v,u), rd );

    return (dot(r.yz,r.yz)<1.0) ? r.x : -1.0;
}


// ray-box intersection (simplified)
vec2 iBox( in vec3 ro, in vec3 rd, in vec3 cen, in vec3 rad )
{
	// ray-box intersection in box space
    vec3 m = 1.0/rd;
    vec3 n = m*(ro-cen);
    vec3 k = abs(m)*rad;

    vec3 t1 = -n - k;
    vec3 t2 = -n + k;

	float tN = max( max( t1.x, t1.y ), t1.z );
	float tF = min( min( t2.x, t2.y ), t2.z );

	if( tN > tF || tF < 0.0) return vec2(-1.0);

	return vec2( tN, tF );
}

float length2( in vec3 v ) { return dot(v,v); }

vec3 iSegment( in vec3 ro, in vec3 rd, in vec3 a, in vec3 b )
{
	vec3 ba = b - a;
	vec3 oa = ro - a;

	float oad  = dot( oa, rd );
	float dba  = dot( rd, ba );
	float baba = dot( ba, ba );
	float oaba = dot( oa, ba );

	vec2 th = vec2( -oad*baba + dba*oaba, oaba - oad*dba ) / (baba - dba*dba);

	th.x = max(   th.x, 0.0 );
	th.y = clamp( th.y, 0.0, 1.0 );

	vec3 p =  a + ba*th.y;
	vec3 q = ro + rd*th.x;

	return vec3( th, length2( p-q ) );

}


float iBezier( in vec3 ro, in vec3 rd, in vec3 p0, in vec3 p1, in vec3 p2, in vec3 p3, in float width)
{
    const int kNum = 50;

    float hit = -1.0;
    float res = 1e10;
    vec3 a = p0;
    for( int i=1; i<kNum; i++ )
    {
        float t = float(i)/float(kNum-1);
        float s = 1.0-t;
        vec3 b = p0*s*s*s + p1*3.0*s*s*t + p2*3.0*s*t*t + p3*t*t*t;
        vec3 r = iSegment( ro, rd, a, b );
        if( r.z<width*width )
        {
            res = min( res, r.x );
            hit = 1.0;
        }
        a = b;
    }

    return res*hit;


}

float hash1( in vec2 p )
{
    return fract(sin(dot(p, vec2(12.9898, 78.233)))*43758.5453);
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec3 tot = vec3(0.0);

#if AA>1
    for( int m=0; m<AA; m++ )
    for( int n=0; n<AA; n++ )
    {
        // pixel coordinates
        vec2 o = vec2(float(m),float(n)) / float(AA) - 0.5;
        vec2 p = (-iResolution.xy + 2.0*(fragCoord+o))/iResolution.y;
#else
        vec2 p = (-iResolution.xy + 2.0*fragCoord)/iResolution.y;
#endif

    // camera position
	vec3 ro = vec3( -0.5, 0.4, 1.5 );
    vec3 ta = vec3( 0.0, 0.0, 0.0 );
    // camera matrix
    vec3 ww = normalize( ta - ro );
    vec3 uu = normalize( cross(ww,vec3(0.0,1.0,0.0) ) );
    vec3 vv = normalize( cross(uu,ww));
	// create view ray
	vec3 rd = normalize( p.x*uu + p.y*vv + 1.5*ww );

    // bezier animation
    float time = iTime*0.5;
    vec3 p0 = vec3(0.8,0.6,0.8)*sin( time*0.7 + vec3(3.0,1.0,2.0) );
    vec3 p1 = vec3(0.8,0.6,0.8)*sin( time*1.1 + vec3(0.0,6.0,1.0) );
    vec3 p2 = vec3(0.8,0.6,0.8)*sin( time*1.3 + vec3(4.0,2.0,3.0) );
    vec3 p3 = vec3(0.8,0.6,0.8)*sin( time*1.5 + vec3(1.0,5.0,4.0) );
	float thickness = 0.01;

    // render
   	vec3 col = vec3(0.4)*(1.0-0.3*length(p));

    // raytrace bezier
    float t = iBezier( ro, rd, p0, p1, p2, p3, thickness);
	float tmin = 1e10;
    if( t>0.0 )
	{
    	tmin = t;
		col = vec3(1.0,0.75,0.3);
	}

    // compute bounding box for bezier
    bound3 bbox = BezierAABB( p0, p1, p2, p3 );
    bbox.mMin -= thickness;
    bbox.mMax += thickness;


    // raytrace bounding box
    vec3 bcen = 0.5*(bbox.mMin+bbox.mMax);
    vec3 brad = 0.5*(bbox.mMax-bbox.mMin);
	vec2 tbox = iBox( ro, rd, bcen, brad );
	if( tbox.x>0.0 )
	{
        // back face
        if( tbox.y < tmin )
        {
            vec3 pos = ro + rd*tbox.y;
            vec3 e = smoothstep( brad-0.03, brad-0.02, abs(pos-bcen) );
            float al = 1.0 - (1.0-e.x*e.y)*(1.0-e.y*e.z)*(1.0-e.z*e.x);
            col = mix( col, vec3(0.0), 0.25 + 0.75*al );
        }
        // front face
        if( tbox.x < tmin )
        {
            vec3 pos = ro + rd*tbox.x;
            vec3 e = smoothstep( brad-0.03, brad-0.02, abs(pos-bcen) );
            float al = 1.0 - (1.0-e.x*e.y)*(1.0-e.y*e.z)*(1.0-e.z*e.x);
            col = mix( col, vec3(0.0), 0.15 + 0.85*al );
        }
	}

        tot += col;
#if AA>1
    }
    tot /= float(AA*AA);
#endif

    // dithering
    tot += ((hash1(fragCoord.xy)+hash1(fragCoord.yx+13.1))/2.0-0.5)/256.0;

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

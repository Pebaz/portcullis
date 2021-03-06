/*
Author: iq https://www.shadertoy.com/view/4dl3Wl
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
// Copyright © 2013 Inigo Quilez
// Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions: The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software. THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.


// return distance and address
vec2 map( vec3 p )
{
    const vec3 va = vec3(  0.0,  0.57735,  0.0 );
    const vec3 vb = vec3(  0.0, -1.0,  1.15470 );
    const vec3 vc = vec3(  1.0, -1.0, -0.57735 );
    const vec3 vd = vec3( -1.0, -1.0, -0.57735 );

	float a = 0.0;
    float s = 1.0;
    float r = 1.0;
    float dm;
    for( int i=0; i<9; i++ )
	{
        vec3 v;
	    float d, t;
		d = dot(p-va,p-va);            { v=va; dm=d; t=0.0; }
        d = dot(p-vb,p-vb); if( d<dm ) { v=vb; dm=d; t=1.0; }
        d = dot(p-vc,p-vc); if( d<dm ) { v=vc; dm=d; t=2.0; }
        d = dot(p-vd,p-vd); if( d<dm ) { v=vd; dm=d; t=3.0; }
		p = v + 2.0*(p - v); r*= 2.0;
		a = t + 4.0*a; s*= 4.0;
	}
	return vec2( (sqrt(dm)-1.0)/r, a/s );
}

const float precis = 0.0002;

vec3 intersect( in vec3 ro, in vec3 rd )
{
	const float maxd = 5.0;
	vec3 res = vec3( 1e20, 0.0, 0.0 );
    float t = 0.5;
	float m = 0.0;
    vec2 r;
	for( int i=0; i<100; i++ )
    {
	    r = map( ro+rd*t );
        if( r.x<precis || t>maxd ) break;
		m = r.y;
        t += r.x;
    }

    if( t<maxd && r.x<precis )
		res = vec3( t, 2.0, m );

	return res;
}

vec3 calcNormal( in vec3 pos )
{
    vec3 eps = vec3(precis,0.0,0.0);
	return normalize( vec3(
           map(pos+eps.xyy).x - map(pos-eps.xyy).x,
           map(pos+eps.yxy).x - map(pos-eps.yxy).x,
           map(pos+eps.yyx).x - map(pos-eps.yyx).x ) );
}

float calcOcclusion( in vec3 pos, in vec3 nor )
{
	float ao = 0.0;
    float sca = 1.0;
    for( int i=0; i<8; i++ )
    {
        float h = 0.001 + 0.5*pow(float(i)/7.0,1.5);
        float d = map( pos + h*nor ).x;
        ao += -(d-h)*sca;
        sca *= 0.95;
    }
    return clamp( 1.0 - 0.8*ao, 0.0, 1.0 );
}


vec3 render( in vec3 ro, in vec3 rd )
{
    vec3 col = vec3(0.0);

	// raymarch
    vec3 tm = intersect(ro,rd);
    if( tm.y>0.5 )
    {
        // geometry
        vec3 pos = ro + tm.x*rd;
		vec3 nor = calcNormal( pos );
		vec3 maa = vec3( 0.0 );

        maa = 0.5 + 0.5*cos( 6.2831*tm.z + vec3(0.0,1.0,2.0) );

		float occ = calcOcclusion( pos, nor );

		// lighting
        const vec3 lig = normalize(vec3(1.0,0.7,0.9));
		float amb = (0.5 + 0.5*nor.y);
		float dif = max(dot(nor,lig),0.0);

        // lights
		vec3 lin = amb*vec3(3.0) * occ;

		// surface-light interacion
		col = maa * lin;
	}

    // gamma
	col = pow( clamp(col,0.0,1.0), vec3(0.45) );

    return col;
}
void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 p = (2.0*fragCoord-iResolution.xy)/iResolution.y;;
    vec2 m = vec2(0.5);
	if( iMouse.z>0.0 ) m = iMouse.xy/iResolution.xy;

    // camera
	float an = 3.2 + 0.5*iTime - 6.2831*(m.x-0.5);
	vec3 ro = vec3(2.5*sin(an),0.0,2.5*cos(an));
    vec3 ta = vec3(0.0,-0.5,0.0);
    vec3 ww = normalize( ta - ro );
    vec3 uu = normalize( cross(ww,vec3(0.0,1.0,0.0) ) );
    vec3 vv = normalize( cross(uu,ww));
	vec3 rd = normalize( p.x*uu + p.y*vv + 5.0*ww*m.y );

    // render
    vec3 col = render( ro, rd );

    fragColor = vec4( col, 1.0 );
}

void mainVR( out vec4 fragColor, in vec2 fragCoord, in vec3 fragRayOri, in vec3 fragRayDir )
{
    vec3 col = render( fragRayOri + vec3(0.0,-0.1,2.0), fragRayDir );

    fragColor = vec4( col, 1.0 );
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

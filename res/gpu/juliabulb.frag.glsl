/*
Author: iq https://www.shadertoy.com/view/MdfGRr
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

// Copyright Inigo Quilez, 2013 - https://iquilezles.org/
// I am the sole copyright owner of this Work.
// You cannot host, display, distribute or share this Work in any form,
// including physical and digital. You cannot use this Work in any
// commercial or non-commercial product, website or project. You cannot
// sell this Work and you cannot mint an NFTs of it.
// I share this Work for educational purposes, and you can link to it,
// through an URL, proper attribution and unmodified screenshot, as part
// of your educational material. If these conditions are too restrictive
// please contact me and we'll definitely work it out.

// This is the code for this video from 2009: https://www.youtube.com/watch?v=iWr5kSZQ7jk


// https://iquilezles.org/articles/intersectors
vec2 isphere( in vec4 sph, in vec3 ro, in vec3 rd )
{
    vec3 oc = ro - sph.xyz;

	float b = dot(oc,rd);
	float c = dot(oc,oc) - sph.w*sph.w;
    float h = b*b - c;
    if( h<0.0 ) return vec2(-1.0);
    h = sqrt( h );
    return -b + vec2(-h,h);
}

float map( in vec3 p, in vec3 c, out vec4 resColor )
{
    vec3 z = p;
    float m = dot(z,z);

    vec4 trap = vec4(abs(z),m);
	float dz = 1.0;

	for( int i=0; i<4; i++ )
    {
        // size of the derivative of z (comp through the chain rule)
        // dz = 8*z^7*dz
		dz = 8.0*pow(m,3.5)*dz;

        // z = z^8+z
        float r = length(z);
        float b = 8.0*acos( clamp(z.y/r, -1.0, 1.0));
        float a = 8.0*atan( z.x, z.z );
        z = c + pow(r,8.0) * vec3( sin(b)*sin(a), cos(b), sin(b)*cos(a) );

        // orbit trapping
        trap = min( trap, vec4(abs(z),m) );

        m = dot(z,z);
		if( m > 2.0 )
            break;
    }

    resColor = trap;

    // distance estimation (through the Hubbard-Douady potential)
    return 0.25*log(m)*sqrt(m)/dz;
}

float raycast( in vec3 ro, in vec3 rd, out vec4 rescol, float fov, vec3 c )
{
    float res = -1.0;

    // bounding volume
    vec2 dis = isphere( vec4( 0.0, 0.0, 0.0, 1.25 ), ro, rd );
    if( dis.y<0.0 )
        return -1.0;
    dis.x = max( dis.x, 0.0 );

	vec4 trap;

    // raymarch
	float fovfactor = 1.0/sqrt(1.0+fov*fov);
	float t = dis.x;
	for( int i=0; i<256; i++  )
    {
        vec3 p = ro + rd*t;

        float surface = clamp( 0.001*t*fovfactor, 0.0001, 0.1 );

		float dt = map( p, c, trap );
		if( t>dis.y || dt<surface ) break;

        t += min(dt,0.05);
    }


    if( t<dis.y )
    {
        rescol = trap;
        res = t;
    }

    return res;
}

// https://iquilezles.org/articles/rmshadows
float softshadow( in vec3 ro, in vec3 rd, float mint, float k, vec3 c )
{
    float res = 1.0;
    float t = mint;
    for( int i=0; i<150; i++ )
    {
        vec4 kk;
        float h = map(ro + rd*t, c, kk);
        res = min( res, k*h/t );
        if( res<0.001 ) break;
        t += clamp( h, 0.001, 0.05 );
    }
    return clamp( res, 0.0, 1.0 );
}

// https://iquilezles.org/articles/normalsSDF
vec3 calcNormal( in vec3 pos, in float t, in float fovfactor, vec3 c )
{
    vec4 tmp;
    float surface = clamp( 0.0005*t*fovfactor, 0.0001, 0.1 );
    vec2 eps = vec2( surface, 0.0 );
	return normalize( vec3(
           map(pos+eps.xyy,c,tmp) - map(pos-eps.xyy,c,tmp),
           map(pos+eps.yxy,c,tmp) - map(pos-eps.yxy,c,tmp),
           map(pos+eps.yyx,c,tmp) - map(pos-eps.yyx,c,tmp) ) );

}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 p = (2.0*fragCoord-iResolution.xy)/iResolution.y;

    float time = iTime*.15;

	vec3 light1 = vec3(  0.577, 0.577, -0.577 );
	vec3 light2 = vec3( -0.707, 0.000,  0.707 );


	float r = 1.3+0.1*cos(.29*time);
	vec3  ro = vec3( r*cos(.33*time), 0.8*r*sin(.37*time), r*sin(.31*time) );
	vec3  ta = vec3(0.0,0.1,0.0);
	float cr = 0.5*cos(0.1*time);

	float fov = 1.5;
    vec3 cw = normalize(ta-ro);
	vec3 cp = vec3(sin(cr), cos(cr),0.0);
	vec3 cu = normalize(cross(cw,cp));
	vec3 cv = normalize(cross(cu,cw));
	vec3 rd = normalize( p.x*cu + p.y*cv + fov*cw );


	vec3 cc = vec3( 0.9*cos(3.9+1.2*time)-.3, 0.8*cos(2.5+1.1*time), 0.8*cos(3.4+1.3*time) );
	if( length(cc)<0.50 ) cc=0.50*normalize(cc);
	if( length(cc)>0.95 ) cc=0.95*normalize(cc);

	vec3 col;
	vec4 tra;
    float t = raycast( ro, rd, tra, fov, cc );
    if( t<0.0 )
    {
     	col = 1.3*vec3(0.8,.95,1.0)*(0.7+0.3*rd.y);
		col += vec3(0.8,0.7,0.5)*pow( clamp(dot(rd,light1),0.0,1.0), 32.0 );
	}
	else
	{
		vec3 pos = ro + t*rd;
        vec3 nor = calcNormal( pos, t, fov, cc );
        vec3 hal = normalize( light1-rd);
        vec3 ref = reflect( rd, nor );

        col = vec3(1.0,1.0,1.0)*0.3;
        col = mix( col, vec3(0.7,0.3,0.3), sqrt(tra.x) );
		col = mix( col, vec3(1.0,0.5,0.2), sqrt(tra.y) );
		col = mix( col, vec3(1.0,1.0,1.0), tra.z );
        col *= 0.4;

		float dif1 = clamp( dot( light1, nor ), 0.0, 1.0 );
		float dif2 = clamp( 0.5 + 0.5*dot( light2, nor ), 0.0, 1.0 );
        float occ = clamp(1.2*tra.w-0.6,0.0,1.0);
        float sha = softshadow( pos,light1, 0.0001, 32.0, cc );
        float fre = 0.04 + 0.96*pow( clamp(1.0-dot(-rd,nor),0.0,1.0), 5.0 );
        float spe = pow( clamp(dot(nor,hal),0.0,1.0), 12.0 ) * dif1 * fre*8.0;

		vec3 lin  = 1.0*vec3(0.15,0.20,0.23)*(0.6+0.4*nor.y)*(0.1+0.9*occ);
		     lin += 4.0*vec3(1.00,0.90,0.60)*dif1*sha;
		     lin += 4.0*vec3(0.14,0.14,0.14)*dif2*occ;
             lin += 2.0*vec3(1.00,1.00,1.00)*spe*sha * occ;
             lin += 0.3*vec3(0.20,0.30,0.40)*(0.02+0.98*occ);
		col *= lin;
        col += spe*1.0*occ*sha;
	}

	col = sqrt( col );

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

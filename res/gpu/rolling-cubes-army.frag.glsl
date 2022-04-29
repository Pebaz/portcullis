/*
Author: Bleuje https://www.shadertoy.com/view/sllfD7
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

// by @etiennejcb

#define PI 3.14159
#define TAU (2.*PI)
#define duration 0.9
#define AA true

float the_time;

float sdBox( vec3 p, vec3 b )
{
  vec3 q = abs(p) - b;
  return length(max(q,0.0)) + min(max(q.x,max(q.y,q.z)),0.0);
}

// Rotation 2D matrix
mat2 rot(float a) { float c = cos(a), s = sin(a); return mat2(c,-s,s,c); }

float cubeSize; // cube size
float spacing = 3.6;
float delayFactor = 0.28;

vec3 rollPosition(vec3 q,float param,float delay)
{
    param -= delay;

    float stp = floor(param);
    float transition = param-stp;

    transition = pow(transition,3.0);

    q -= vec3(0.5*cubeSize,0.,0.);
    q -= vec3(2.0*cubeSize*(stp-param),0.,0.);
    q -= vec3(cubeSize,-cubeSize,0.);
    q.xy *= rot(PI/2.0*transition);
    q += vec3(cubeSize,-cubeSize,0.);
    q.xy *= rot(-PI/2.0*stp);

    return q;
}

struct MapData
{
    float typeId;
    float dist;
    vec2 uv;
    vec2 cubePos;
};


MapData map(vec3 p) {
    MapData res;

    vec3 q = p;

    float repetitionDistance = spacing*cubeSize;
    p.xz = mod(p.xz + repetitionDistance*.5, repetitionDistance) - repetitionDistance*.5;

    // block indices
    vec2 qi = floor((q.xz+0.5*vec2(repetitionDistance))/repetitionDistance);
    float delay = delayFactor*length(qi);

    p = rollPosition(p, the_time, delay);

    float boxDistance = sdBox(p,vec3(cubeSize));
    float waveDistance = max(0.015+0.02*length(q),abs(mod(length(0.94*q/cubeSize/spacing)-the_time/delayFactor+0.53/delayFactor,1.0/delayFactor)-2.0));
    float groundDistance = q.y+cubeSize;

    if(groundDistance<boxDistance) // we're closer to the ground
    {
        res.typeId = 0.;
        res.dist = min(groundDistance,waveDistance);
    }
    else // we're closer to a cube
    {
        vec2 uv;
        // looking for cube face uv
        if(abs(p.x)<=cubeSize&&abs(p.y)<=cubeSize)
            uv = p.xy;
        else if(abs(p.y)<=cubeSize&&abs(p.z)<=cubeSize)
            uv = p.yz;
        else
            uv = p.xz;

        res.typeId = 1.;
        res.dist = min(boxDistance,waveDistance);
        res.uv = uv;
        res.cubePos = qi;
    }

    return res;
}

vec3 camera(vec3 ro, vec2 uv, vec3 ta) {
	vec3 fwd = normalize(ta - ro);
	vec3 left = cross(vec3(0, 1, 0), fwd);
	vec3 up = cross(fwd, left);
	return normalize(fwd + uv.x*left + up*uv.y);
}

// Dave Hoskins
// https://www.shadertoy.com/view/4djSRW
float hash12(vec2 p)
{
	vec3 p3  = fract(vec3(p.xyx) * .1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

void mainImage0(out vec4 fragColor, in vec2 fragCoord)
{
	vec2 q = fragCoord.xy / iResolution.xy;
	vec2 uv = (q - .5) * iResolution.xx / iResolution.yx;

    the_time = mod(iTime/duration,4.0);
    cubeSize = 0.18+0.1*cos(0.5*iTime);

	vec3 ro = vec3(3.4+1.1*cos(0.4*iTime), 2., -4.);
	vec3 ta = vec3(0., 0., 0.);
	vec3 rd;

	rd = camera(ro, uv, ta);

    float rng = hash12(100.*q + 123.*the_time);

	vec3 p;
	MapData res;
	float ri, t = 0.;
	for (float i = 0.; i < 1.; i += 1.0/60.0) {
		ri = i;
		p = ro + rd*t;
		res = map(p);
		if (res.dist<.001) break;
		t += res.dist*(0.9+0.1*rng);
	}

    float delay = 0.9*delayFactor*length(p)/cubeSize/spacing;
    float waveFactor = pow(abs(sin(PI*(the_time-delay-0.6))),3.5);

    vec3 col;

    if(res.typeId < 0.5) // floor case
    {
        // color brightness based on number of raymarching iterations, distance and wave
        col = vec3(pow(ri,3.0)/(t*t)*700.0)*.2*(0.5+2.0*waveFactor);
        float ll = 0.02;
        float f = smoothstep(ll,0.65*ll,mod(abs(p.z),spacing*cubeSize));
        f += smoothstep(ll,0.5*ll,mod(abs(p.x+2.0*cubeSize*the_time),spacing*cubeSize));
        col += f*vec3(1.0);
    }
    else // cube case
    {
        vec2 uuvv = res.uv;
        if(mod(res.cubePos.x+res.cubePos.y,2.0)<0.5) uuvv *= rot(PI/2.0); // alternating face rotation

        // cube edges factor
        float squareDistance = max(abs(uuvv.x),abs(uuvv.y));
        float f_edges = 0.1+1.4*smoothstep(0.88*cubeSize,0.93*cubeSize,squareDistance);

        // factor for stripes on cube faces
        float a = 1.0;
        float b = 0.75;
        float v = clamp((mod(3.0*uuvv.x/cubeSize,a)-b)/(a-b),0.,1.);
        float f_stripes = 1.5*sin(PI*v);

        // brightness with number of raymarching iterations, distance and previous factors
        col = vec3(pow(ri,1.7)/(t*t)*100.0)*max(f_edges,f_stripes);

        // brighter on wave
        col *= (0.75+1.5*waveFactor);
    }

	fragColor = vec4(col, 1.);
}

// smart AA, from FabriceNeyret2
void mainImage(out vec4 O, vec2 U) {
    mainImage0(O,U);
    if(AA)
    if ( fwidth(length(O)) > .01 ) {  // difference threshold between neighbor pixels
        vec4 o;
        for (int k=0; k < 9; k+= k==3?2:1 )
          { mainImage0(o,U+vec2(k%3-1,k/3-1)/3.); O += o; }
        O /= 9.;
     // O.r++;                        // uncomment to see where the oversampling occurs
    }
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

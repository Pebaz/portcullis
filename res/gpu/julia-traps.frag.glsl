/*
Author: iq https://www.shadertoy.com/view/4dfGRn
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
#define iTime (time * 4.0)
#define iMouse vec3(0.0, 0.0, 0.0)
#define iFrame 0

// Created by inigo quilez - iq/2013
// I share this piece (art and code) here in Shadertoy and through its Public API, only for educational purposes.
// You cannot use, sell, share or host this piece or modifications of it as part of your own commercial or non-commercial product, website or project.
// You can share a link to it or an unmodified screenshot of it provided you attribute "by Inigo Quilez, @iquilezles and iquilezles.org".
// If you are a teacher, lecturer, educator or similar and these conditions are too restrictive for your needs, please contact me and we'll work it out.

// Julia - Traps 1 : https://www.shadertoy.com/view/4d23WG
// Julia - Traps 2 : https://www.shadertoy.com/view/4dfGRn

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
	vec2 p = (2.0*fragCoord-iResolution.xy)/iResolution.y;

    float time = 30.0 + 0.1*iTime;
    vec2 cc = 1.1*vec2( 0.5*cos(0.1*time) - 0.25*cos(0.2*time),
	                    0.5*sin(0.1*time) - 0.25*sin(0.2*time) );

	vec4 dmin = vec4(1000.0);
    vec2 z = p;
    for( int i=0; i<64; i++ )
    {
        z = cc + vec2( z.x*z.x - z.y*z.y, 2.0*z.x*z.y );

		dmin=min(dmin, vec4(abs(0.0+z.y + 0.5*sin(z.x)),
							abs(1.0+z.x + 0.5*sin(z.y)),
							dot(z,z),
						    length( fract(z)-0.5) ) );
    }

    vec3 col = vec3( dmin.w );
	col = mix( col, vec3(1.00,0.80,0.60),     min(1.0,pow(dmin.x*0.25,0.20)) );
    col = mix( col, vec3(0.72,0.70,0.60),     min(1.0,pow(dmin.y*0.50,0.50)) );
	col = mix( col, vec3(1.00,1.00,1.00), 1.0-min(1.0,pow(dmin.z*1.00,0.15) ));

	col = 1.25*col*col;
    col = col*col*(3.0-2.0*col);

    p = fragCoord/iResolution.xy;
	col *= 0.5 + 0.5*pow(16.0*p.x*(1.0-p.x)*p.y*(1.0-p.y),0.15);

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

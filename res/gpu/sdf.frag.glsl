precision mediump float;

in vec2 uv;
out vec4 color;

uniform vec4 rectangle_color;
uniform uint using_rectangle_texture;
uniform vec2 resolution;
uniform float time;
uniform sampler2D rectangle_texture;

float circle(vec2 point, vec2 origin, float radius)
{
    return length(point - origin) - radius;
}

void main()
{
    color = vec4(gl_FragCoord.xy / resolution, 0.0, 1.0);

    float dist = circle(
        gl_FragCoord.xy,
        resolution / 2 + vec2(sin(time * 2) * 100, cos(time * 2) * 100),
        32
    );

    if (dist <= 0)
    {
        color = vec4(1, 1, 1, 1);
    }

    // Without this, the GPU compiler optimizes out the uniforms
    if (using_rectangle_texture > uint(0))
    {
        vec4 sample = texture(rectangle_texture, uv);
        color = sample * rectangle_color;
    }
}

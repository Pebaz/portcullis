precision mediump float;

in vec2 uv;
out vec4 color;

uniform vec4 rectangle_color;
uniform sampler2D rectangle_texture;

void main()
{
    vec4 sample = texture(rectangle_texture, uv);

    // if (sample.a < 0.1)
    // {
    //     discard;
    // }

    color = sample * rectangle_color;
}

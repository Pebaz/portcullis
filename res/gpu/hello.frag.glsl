precision mediump float;

in vec2 uv;
out vec4 color;

uniform vec4 rectangle_color;
uniform sampler2D rectangle_texture;

void main()
{
    // color = texture(rectangle_texture, uv) * rectangle_color;
    vec4 sample = texture(rectangle_texture, uv);
    color = vec4(
        rectangle_color.x / 2.0 + sample.x,
        rectangle_color.y / 2.0 + sample.y,
        rectangle_color.z / 2.0 + sample.z,
        rectangle_color.w
    );
}

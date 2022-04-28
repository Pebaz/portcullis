precision mediump float;

in vec2 uv;
out vec4 color;

uniform vec4 rectangle_color;
uniform uint using_rectangle_texture;
uniform sampler2D rectangle_texture;

void main()
{
    color = vec4(1, 1, 1, 1);
}

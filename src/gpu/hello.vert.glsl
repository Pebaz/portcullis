const vec2 verts[4] = vec2[4](
    vec2(-0.5f, 0.5f),
    vec2(0.5f, 0.5f),
    vec2(0.5f, -0.5f),
    vec2(-0.5f, -0.5f)
);

uniform vec2 rectangle_position;
uniform vec2 rectangle_dimensions;
uniform mat4 orthographic_projection;

void main()
{
    vec2 vert = verts[gl_VertexID] * rectangle_dimensions + rectangle_position;

    gl_Position = orthographic_projection * vec4(
        vert,
        0.0,
        1.0
    );
}

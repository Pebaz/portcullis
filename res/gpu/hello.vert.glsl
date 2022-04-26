const vec2 verts[4] = vec2[4](
    vec2(-0.5f, 0.5f),
    vec2(0.5f, 0.5f),
    vec2(0.5f, -0.5f),
    vec2(-0.5f, -0.5f)
);

const vec2 uvs[4] = vec2[4](
    vec2(0, 1),
    vec2(1, 1),
    vec2(1, 0),
    vec2(0, 0)
);

out vec2 uv;

uniform vec2 rectangle_position;
uniform vec2 rectangle_dimensions;
uniform mat4 orthographic_projection;

void main()
{
    vec2 vert = verts[gl_VertexID] * rectangle_dimensions + rectangle_position;
    uv = uvs[gl_VertexID];

    gl_Position = orthographic_projection * vec4(
        vert,
        0.0,
        1.0
    );
}

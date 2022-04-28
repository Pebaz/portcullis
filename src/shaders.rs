use glow::*;

pub unsafe fn load_shader(
    gl: &Context,
    shader_version: &str,
    vertex_shader_file: &str,
    fragment_shader_file: &str,
) -> NativeProgram
{
    let program = gl.create_program().expect("Cannot create program");

    let vertex_shader_source =
        std::fs::read_to_string(vertex_shader_file).expect("Failed to open GLSL vertex shader file");
    let fragment_shader_source =
        std::fs::read_to_string(fragment_shader_file).expect("Failed to open GLSL fragment shader file");

    let shader_sources = [(glow::VERTEX_SHADER, vertex_shader_source), (glow::FRAGMENT_SHADER, fragment_shader_source)];

    let mut shaders = Vec::with_capacity(shader_sources.len());

    for (shader_type, shader_source) in shader_sources.iter()
    {
        let shader = gl.create_shader(*shader_type).expect("Cannot create shader");
        gl.shader_source(shader, &format!("{}\n{}", shader_version, shader_source));
        gl.compile_shader(shader);

        if !gl.get_shader_compile_status(shader)
        {
            panic!("{}", gl.get_shader_info_log(shader));
        }

        gl.attach_shader(program, shader);
        shaders.push(shader);
    }

    gl.link_program(program);

    if !gl.get_program_link_status(program)
    {
        panic!("{}", gl.get_program_info_log(program));
    }

    for shader in shaders
    {
        gl.detach_shader(program, shader);
        gl.delete_shader(shader);
    }

    program
}

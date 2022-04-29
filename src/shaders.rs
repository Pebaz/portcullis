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

pub unsafe fn load_content(gl: &Context, shader_version: &str) -> Vec<NativeProgram>
{
    let mut vec = Vec::new();

    let mut add_content = |s| vec.push(load_shader(gl, shader_version, "res/gpu/hello.vert.glsl", s));

    add_content("res/gpu/ann.frag.glsl");
    add_content("res/gpu/happy-jumping.frag.glsl");
    add_content("res/gpu/neon-futures.frag.glsl");
    add_content("res/gpu/slisesix.frag.glsl");
    add_content("res/gpu/protean-clouds.frag.glsl");
    add_content("res/gpu/rolling-cubes-army.frag.glsl");
    add_content("res/gpu/rounding-the-square.frag.glsl");
    add_content("res/gpu/cubic-bezier.frag.glsl");
    add_content("res/gpu/planet-fall.frag.glsl");
    add_content("res/gpu/julia-traps.frag.glsl");
    add_content("res/gpu/iterations-coral.frag.glsl");
    add_content("res/gpu/cubic-bezier3d.frag.glsl");
    add_content("res/gpu/cylinder.frag.glsl");
    add_content("res/gpu/integer-raymarcher2.frag.glsl");
    add_content("res/gpu/warping-procedural2.frag.glsl");
    add_content("res/gpu/mandelbrot.frag.glsl");
    add_content("res/gpu/iterations-shiny.frag.glsl");
    add_content("res/gpu/eye.frag.glsl");
    add_content("res/gpu/sierpinski.frag.glsl");
    add_content("res/gpu/voronoi-metrics.frag.glsl");
    add_content("res/gpu/fractal-tiling.frag.glsl");
    add_content("res/gpu/disk.frag.glsl");
    add_content("res/gpu/worms.frag.glsl");
    add_content("res/gpu/bubbles.frag.glsl");
    add_content("res/gpu/juliabulb.frag.glsl");
    add_content("res/gpu/analytic-normals.frag.glsl");
    add_content("res/gpu/mandelbulb.frag.glsl");
    add_content("res/gpu/clover.frag.glsl");
    add_content("res/gpu/apollonian.frag.glsl");
    add_content("res/gpu/heart.frag.glsl");
    add_content("res/gpu/two-tweets.frag.glsl");
    add_content("res/gpu/sdf.frag.glsl");

    vec
}

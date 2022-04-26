use glam;
use glow::*;
use image::GenericImageView;
use sdl2::event::{Event, WindowEvent};
use sdl2::keyboard::Keycode;

fn main()
{
    unsafe {
        // Create a context from a sdl2 window
        let (gl, shader_version, window, mut events_loop, context) = {
            let sdl = sdl2::init().unwrap();
            let video = sdl.video().unwrap();

            let gl_attr = video.gl_attr();
            gl_attr.set_context_profile(sdl2::video::GLProfile::Core);
            gl_attr.set_context_version(3, 0);

            let window = video.window("Portcullis", 1024, 768).opengl().resizable().build().unwrap();
            let gl_context = window.gl_create_context().unwrap();
            let gl = glow::Context::from_loader_function(|s| video.gl_get_proc_address(s) as *const _);
            let event_loop = sdl.event_pump().unwrap();

            (gl, "#version 130", window, event_loop, gl_context)
        };

        let vertex_array = gl.create_vertex_array().expect("Cannot create vertex array");
        gl.bind_vertex_array(Some(vertex_array));

        let program = gl.create_program().expect("Cannot create program");

        let vertex_shader_source =
            std::fs::read_to_string("res/gpu/hello.vert.glsl").expect("Failed to open GLSL shader file");
        let fragment_shader_source =
            std::fs::read_to_string("res/gpu/hello.frag.glsl").expect("Failed to open GLSL shader file");

        let shader_sources =
            [(glow::VERTEX_SHADER, vertex_shader_source), (glow::FRAGMENT_SHADER, fragment_shader_source)];

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

        gl.use_program(Some(program));

        gl.clear_color(0.1, 0.2, 0.3, 1.0);

        let image = image::open("res/img/Disney-Logo.png").unwrap();
        let width = image.width();
        let height = image.height();
        let data = image.into_rgba8();
        let data2 = data.into_vec();

        let texture = gl.create_texture().unwrap();

        gl.bind_texture(glow::TEXTURE_2D, Some(texture));

        gl.tex_parameter_i32(glow::TEXTURE_2D, glow::TEXTURE_MIN_FILTER, glow::LINEAR as i32);
        gl.tex_parameter_i32(glow::TEXTURE_2D, glow::TEXTURE_MAG_FILTER, glow::LINEAR as i32);

        gl.tex_image_2d(
            glow::TEXTURE_2D,
            0,
            glow::RGBA8 as i32,
            width as i32,
            height as i32,
            0,
            glow::RGBA,
            glow::UNSIGNED_BYTE,
            Some(&data2),
        );

        gl.generate_mipmap(glow::TEXTURE_2D);

        // gl.tex_image_2d(
        //     glow::TEXTURE_2D,
        //     0,
        //     glow::RGBA as i32,
        //     width as i32,
        //     height as i32,
        //     0,
        //     glow::RGBA,
        //     glow::UNSIGNED_BYTE,
        //     Some(&data2),
        // );

        // let err = gl.get_error();
        // if err != glow::NO_ERROR
        // {
        //     gl.get_gl_error(err);
        // }

        // To stop using the texture
        // gl.bind_texture(glow::TEXTURE_2D, None);

        let mut running = true;
        while running
        {
            for event in events_loop.poll_iter()
            {
                match event
                {
                    Event::Quit { .. } => running = false,
                    Event::KeyDown { keycode: Some(Keycode::Escape), .. } => running = false,
                    Event::Window { win_event, .. } =>
                    {
                        if let WindowEvent::Resized(width, height) = win_event
                        {
                            gl.viewport(0, 0, width, height);
                        }
                    }

                    _ => (),
                }
            }

            let window_width = window.size().0 as f32;
            let window_height = window.size().1 as f32;

            gl.clear(glow::COLOR_BUFFER_BIT);

            let orthographic_projection_matrix =
                glam::f32::Mat4::orthographic_rh(0.0, window_width, window_height, 0.0, -1.0, 1.0);

            draw_quad(
                &gl,
                program,
                glam::vec2(0.0, 0.0),
                glam::vec2(64.0, 64.0),
                glam::vec4(0.6, 1.0, 0.0, 1.0),
                orthographic_projection_matrix,
            );

            draw_quad(
                &gl,
                program,
                glam::vec2(32.0, 32.0),
                glam::vec2(64.0, 64.0),
                glam::vec4(1.0, 0.6, 0.0, 0.5),
                orthographic_projection_matrix,
            );

            let logo_dims = glam::vec2(512.0, 256.0);
            draw_quad_textured(
                &gl,
                program,
                glam::vec2(window_width / 2.0 - (logo_dims.x / 2.0), window_height / 2.0 - (logo_dims.y / 2.0)),
                logo_dims,
                glam::vec4(1.0, 1.0, 1.0, 1.0),
                orthographic_projection_matrix,
                texture,
            );

            window.gl_swap_window();

            if !running
            {
                gl.delete_program(program);
                gl.delete_vertex_array(vertex_array);
            }
        }
    }
}

unsafe fn draw_quad(
    gl: &Context,
    program: NativeProgram,
    position: glam::Vec2,
    dimensions: glam::Vec2,
    color: glam::Vec4,
    orthographic_projection_matrix: glam::Mat4,
) -> ()
{
    let rectangle_color = gl.get_uniform_location(program, "rectangle_color").unwrap();
    gl.uniform_4_f32(Some(&rectangle_color), color.x, color.y, color.z, color.w);

    let rectangle_position = gl.get_uniform_location(program, "rectangle_position").unwrap();
    gl.uniform_2_f32(Some(&rectangle_position), position.x + dimensions.x / 2.0, position.y + dimensions.y / 2.0);

    let rectangle_dimensions = gl.get_uniform_location(program, "rectangle_dimensions").unwrap();
    gl.uniform_2_f32(Some(&rectangle_dimensions), dimensions.x, dimensions.y);

    let orthographic_projection = gl.get_uniform_location(program, "orthographic_projection").unwrap();
    gl.uniform_matrix_4_f32_slice(
        Some(&orthographic_projection),
        false,
        &orthographic_projection_matrix.to_cols_array(),
    );

    gl.draw_arrays(glow::QUADS, 0, 4);
}

unsafe fn draw_quad_textured(
    gl: &Context,
    program: NativeProgram,
    position: glam::Vec2,
    dimensions: glam::Vec2,
    color: glam::Vec4,
    orthographic_projection_matrix: glam::Mat4,
    texture: NativeTexture,
) -> ()
{
    gl.active_texture(glow::TEXTURE0);
    gl.bind_texture(glow::TEXTURE_2D, Some(texture));

    gl.enable(glow::BLEND);
    gl.blend_func(glow::SRC_ALPHA, glow::ONE_MINUS_SRC_ALPHA);

    let using_rectangle_texture = gl.get_uniform_location(program, "using_rectangle_texture").unwrap();
    gl.uniform_1_u32(Some(&using_rectangle_texture), 1);

    draw_quad(gl, program, position, dimensions, color, orthographic_projection_matrix);

    let using_rectangle_texture = gl.get_uniform_location(program, "using_rectangle_texture").unwrap();
    gl.uniform_1_u32(Some(&using_rectangle_texture), 0);

    gl.bind_texture(glow::TEXTURE_2D, None);
}

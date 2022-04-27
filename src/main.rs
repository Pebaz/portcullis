use glam;
use glow::*;
use glow_glyph::{ab_glyph, GlyphBrushBuilder, Section, Text};
use sdl2::event::{Event, WindowEvent};
use sdl2::keyboard::Keycode;
use serde_json::Value;

#[derive(Clone)]
struct Collection
{
    name: String,
    videos: Vec<Video>,
}

#[derive(Clone)]
struct Video
{
    name: String,
    url: String,
}

fn handle_item(item: &Value, aspect_ratio: f32) -> Video
{
    let title_map = {
        let mut title_map = std::collections::HashMap::new();
        title_map.insert("DmcSeries", "series");
        title_map.insert("DmcVideo", "program");
        title_map.insert("StandardCollection", "collection");
        title_map
    };

    let item_type = &item["type"].as_str().unwrap();
    let content_type = title_map[item_type];
    let item_name = &item["text"]["title"]["full"][content_type]["default"]["content"];
    let tiles = item["image"]["tile"].as_object().unwrap();
    let ratios = {
        let mut ratios = Vec::<(String, f32)>::new();
        for tile in tiles.keys()
        {
            let tile_string = tile.to_string();
            let tile_value = tile_string.parse().unwrap();
            ratios.push((tile_string, tile_value));
        }
        ratios
    };

    let closest_aspect_ratio = ratios
        .into_iter()
        .min_by(|a, b| (a.1 - aspect_ratio).abs().partial_cmp(&(b.1 - aspect_ratio).abs()).unwrap())
        .unwrap();

    let appropriate_tiles = &tiles[&closest_aspect_ratio.0].as_object().unwrap();

    let tile_url = if !appropriate_tiles.contains_key(content_type)
    {
        &appropriate_tiles["default"]["default"]["url"]
    }
    else
    {
        &appropriate_tiles[content_type]["default"]["url"]
    };

    // println!("{}: {}", item_name, tile_url);

    Video { name: item_name.to_string(), url: tile_url.to_string() }
}

async fn get_collections(aspect_ratio: f32) -> Vec<Collection>
{
    let body =
        reqwest::get("https://cd-static.bamgrid.com/dp-117731241344/home.json").await.unwrap().text().await.unwrap();

    let json: Value = serde_json::from_str(&body).unwrap();

    let mut collections = Vec::new();

    if let Value::Array(containers) = &json["data"]["StandardCollection"]["containers"]
    {
        collections.reserve(containers.len());

        for container in containers
        {
            let set = &container["set"];
            let set_name = &set["text"]["title"]["full"]["set"]["default"]["content"];
            let mut collection =
                Collection { name: set_name.to_owned().as_str().unwrap().to_string(), videos: Vec::new() };

            if set["type"].as_str().unwrap() == "CuratedSet"
            {
                for item in set["items"].as_array().unwrap()
                {
                    collection.videos.push(handle_item(item, aspect_ratio));
                }
            }
            else
            {
                let ref_id = &set["refId"].as_str().unwrap();

                let body = reqwest::get(format!("https://cd-static.bamgrid.com/dp-117731241344/sets/{ref_id}.json"))
                    .await
                    .unwrap()
                    .text()
                    .await
                    .unwrap();

                let json: Value = serde_json::from_str(&body).unwrap();

                let set = json["data"].as_object().unwrap().values().take(1).next().unwrap();

                for item in set["items"].as_array().unwrap()
                {
                    collection.videos.push(handle_item(item, aspect_ratio));
                }
            }

            collections.push(collection);
        }
    }

    collections
}

struct TextureLibrary
{
    textures: std::collections::HashMap<String, NativeTexture>,
    // asset_load_futures: Vec<dyn std::future::Future<Output = ()>>,
}

struct Tile
{
    texture: NativeTexture,
}

struct Camera2D
{
    position: glam::Vec2,
    viewport: glam::Vec2,
}

impl Camera2D
{
    fn new() -> Self
    {
        Self { position: glam::Vec2::ZERO, viewport: glam::Vec2::ZERO }
    }

    fn update_viewport_dimensions(&mut self, window_width: f32, window_height: f32)
    {
        self.viewport = glam::vec2(window_width, window_height);
    }

    /// Useful for drawing items that should not move along with navigation.
    fn get_origin_matrix(&self) -> glam::Mat4
    {
        glam::f32::Mat4::orthographic_rh(0.0, self.viewport.x, self.viewport.y, 0.0, -1.0, 1.0)
    }

    /// Useful for drawing items that should move along with navigation.
    fn get_matrix(&self) -> glam::Mat4
    {
        glam::f32::Mat4::orthographic_rh(
            self.position.x,
            self.position.x + self.viewport.x,
            self.position.y + self.viewport.y,
            self.position.y,
            -1.0,
            1.0,
        )
    }

    fn get_position_in_screen_space(&self, position: glam::Vec2) -> glam::Vec2
    {
        position - self.position
    }

    fn is_rectangle_in_view(&self, rectangle_position: glam::Vec2, rectangle_dimensions: glam::Vec2) -> bool
    {
        // Left, Right, Top, Bottom edges = xyzw
        let a = glam::vec4(
            rectangle_position.x,
            rectangle_position.x + rectangle_dimensions.x,
            rectangle_position.y,
            rectangle_position.y + rectangle_dimensions.y,
        );

        let b = glam::vec4(
            self.position.x,
            self.position.x + self.viewport.x,
            self.position.y,
            self.position.y + self.viewport.y,
        );

        a.x.max(b.x) < a.y.min(b.y) && a.z.max(b.z) < a.w.min(b.z)
    }
}

#[tokio::main]
async fn main()
{
    // !!!!!!!!!!!!!!!!!!!!!!!!! tokio::yield_now();

    let aspect_ratio = 1080.0 / 1920.0;

    let collections_future = get_collections(aspect_ratio);
    tokio::pin!(collections_future);

    unsafe {
        let (gl, shader_version, window, mut events_loop, _context) = {
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
        gl.bind_texture(glow::TEXTURE_2D, None);

        let font = ab_glyph::FontArc::try_from_slice(include_bytes!("../res/font/Roboto/Roboto-Regular.ttf")).unwrap();
        let mut glyph_brush = GlyphBrushBuilder::using_font(font).build(&gl);

        let mut running = true;
        let time_counter_milliseconds = std::time::Instant::now();

        let mut collections = None;

        let mut camera = Camera2D::new();

        while running
        {
            // Only using 62% of the frame budget of 16 ms at 60 FPS
            let timeout = tokio::time::sleep(tokio::time::Duration::from_millis(10));
            tokio::pin!(timeout);

            if !collections.is_some()
            {
                tokio::select! {
                    _ = &mut timeout => (),
                    collections_results = &mut collections_future =>
                    {
                        println!("HTTP Request completed! Len: {}", collections_results.len());

                        collections = Some(collections_results);
                    },
                };
            }

            let time_milliseconds = time_counter_milliseconds.elapsed().as_millis() as f32 / 1000.0;

            for event in events_loop.poll_iter()
            {
                match event
                {
                    Event::Quit { .. } => running = false,
                    Event::KeyDown { keycode: Some(Keycode::Escape), .. } => running = false,
                    Event::KeyDown { keycode: Some(Keycode::Right), .. } => camera.position.x -= 64.0,
                    Event::KeyDown { keycode: Some(Keycode::Left), .. } => camera.position.x += 64.0,
                    Event::KeyDown { keycode: Some(Keycode::Down), .. } => camera.position.y += 64.0,
                    Event::KeyDown { keycode: Some(Keycode::Up), .. } => camera.position.y -= 64.0,
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

            // let orthographic_projection_matrix =
            //     glam::f32::Mat4::orthographic_rh(0.0, window_width, window_height, 0.0, -1.0, 1.0);
            let orthographic_projection_matrix = camera.get_matrix();

            gl.use_program(Some(program));

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
            let origin_matrix = camera.get_origin_matrix();
            draw_quad_textured(
                &gl,
                program,
                glam::vec2(window_width / 2.0 - (logo_dims.x / 2.0), window_height / 2.0 - (logo_dims.y / 2.0)),
                logo_dims,
                glam::vec4(1.0, 1.0, 1.0, 1.0),
                origin_matrix,
                texture,
            );

            glyph_brush.queue(Section {
                screen_position: camera.get_position_in_screen_space(glam::vec2(30.0, 30.0)).into(),
                bounds: (window_width, window_height),
                text: vec![Text::default()
                    .with_text("Hello glow_glyph!")
                    .with_color([0.0, 0.0, 0.0, 1.0])
                    .with_scale(40.0)],
                ..Section::default()
            });

            glyph_brush.queue(Section {
                screen_position: camera.get_position_in_screen_space(glam::vec2(30.0, 90.0)).into(),
                bounds: (window_width, window_height),
                text: vec![Text::default()
                    .with_text(format!("{}", time_milliseconds).as_str())
                    .with_color([1.0, 1.0, 1.0, 1.0])
                    .with_scale(40.0)],
                ..Section::default()
            });

            glyph_brush.draw_queued(&gl, window_width as u32, window_height as u32).expect("Draw queued");

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

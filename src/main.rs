use std::collections::{HashMap, HashSet, VecDeque};

use glow::*;
use glow_glyph::{ab_glyph, GlyphBrushBuilder, Section, Text};
use keyframe::{functions, keyframes, AnimationSequence};
use keyframe_derive::CanTween;
use sdl2::event::{Event, WindowEvent};
use sdl2::keyboard::Keycode;
use serde_json::Value;

mod shaders;

const RUN_LOCAL: bool = false; // Use local home.json copy, don't load images

#[derive(Clone, Copy, Default, CanTween)]
struct V2(f32, f32);

impl From<V2> for glam::Vec2
{
    fn from(v2: V2) -> Self
    {
        glam::vec2(v2.0, v2.1)
    }
}

impl From<glam::Vec2> for V2
{
    fn from(v2: glam::Vec2) -> Self
    {
        V2(v2.x, v2.y)
    }
}

#[derive(Clone)]
struct Collection
{
    name: String,
    videos: Vec<Video>,
    selected_video: i32,
}

const CONTENT_NOT_SET: usize = 50000;
const JSON_ERR: &str = "JSON structure doesn't match expected format. Did the schema change?";
const API_ERR: &str = "Fatal Error: Failed to get any data from API";
const IMG_ERR: &str = "Failed to load image";

#[derive(Clone)]
struct Video
{
    _name: String,
    url: String,
    content_index: usize,
}

fn handle_item(item: &Value, aspect_ratio: f32) -> Video
{
    let title_map = {
        let mut title_map = HashMap::new();
        title_map.insert("DmcSeries", "series");
        title_map.insert("DmcVideo", "program");
        title_map.insert("StandardCollection", "collection");
        title_map
    };

    let item_type = &item["type"].as_str().expect(JSON_ERR);
    let content_type = title_map[item_type];
    let item_name = &item["text"]["title"]["full"][content_type]["default"]["content"];
    let tiles = item["image"]["tile"].as_object().expect(JSON_ERR);
    let ratios = {
        let mut ratios = Vec::<(String, f32)>::new();
        for tile in tiles.keys()
        {
            let tile_string = tile.to_string();
            let tile_value = tile_string.parse().expect(JSON_ERR);
            ratios.push((tile_string, tile_value));
        }
        ratios
    };

    let closest_aspect_ratio = ratios
        .into_iter()
        .min_by(|a, b| (a.1 - aspect_ratio).abs().partial_cmp(&(b.1 - aspect_ratio).abs()).expect(JSON_ERR))
        .unwrap();

    let appropriate_tiles = &tiles[&closest_aspect_ratio.0].as_object().expect(JSON_ERR);

    let tile_url = if !appropriate_tiles.contains_key(content_type)
    {
        &appropriate_tiles["default"]["default"]["url"]
    }
    else
    {
        &appropriate_tiles[content_type]["default"]["url"]
    };

    Video {
        _name: item_name.to_string(),
        url: tile_url.as_str().expect(JSON_ERR).to_owned(),
        content_index: CONTENT_NOT_SET,
    }
}

async fn get_collections(aspect_ratio: f32) -> Vec<Collection>
{
    let json: Value = if RUN_LOCAL
    {
        let body = reqwest::get("https://cd-static.bamgrid.com/dp-117731241344/home.json")
            .await
            .expect(API_ERR)
            .text()
            .await
            .expect(API_ERR);

        serde_json::from_str(&body).expect(JSON_ERR)
    }
    else
    {
        serde_json::from_str(include_str!("home.json")).expect(JSON_ERR)
    };

    let mut collections = Vec::new();

    if let Value::Array(containers) = &json["data"]["StandardCollection"]["containers"]
    {
        collections.reserve(containers.len());

        for container in containers
        {
            let set = &container["set"];
            let set_name = &set["text"]["title"]["full"]["set"]["default"]["content"];
            let mut collection = Collection {
                name: set_name.to_owned().as_str().expect(JSON_ERR).to_string(),
                videos: Vec::new(),
                selected_video: 0,
            };

            if set["type"].as_str().expect(JSON_ERR) == "CuratedSet"
            {
                for item in set["items"].as_array().expect(JSON_ERR)
                {
                    collection.videos.push(handle_item(item, aspect_ratio));
                }
            }
            else
            {
                let ref_id = &set["refId"].as_str().expect(JSON_ERR);

                let body = reqwest::get(format!("https://cd-static.bamgrid.com/dp-117731241344/sets/{ref_id}.json"))
                    .await
                    .expect(API_ERR)
                    .text()
                    .await
                    .expect(API_ERR);

                let json: Value = serde_json::from_str(&body).expect(JSON_ERR);

                let set = json["data"].as_object().expect(JSON_ERR).values().take(1).next().expect(JSON_ERR);

                for item in set["items"].as_array().expect(JSON_ERR)
                {
                    collection.videos.push(handle_item(item, aspect_ratio));
                }
            }

            collections.push(collection);
        }
    }

    collections
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

    fn is_rectangle_in_view(&self, position: glam::Vec2, dimensions: glam::Vec2) -> bool
    {
        position.x <= (self.position.x + self.viewport.x)
            && (position.x + dimensions.x) >= self.position.x
            && position.y <= (self.position.y + self.viewport.y)
            && (position.y + dimensions.y) >= self.position.y
    }
}

fn calc_row_height(camera: &Camera2D) -> f32
{
    let row_cell_height = camera.viewport.y / 6.0;
    let title_height = row_cell_height / 4.0;
    let row_margin = row_cell_height / 5.0;
    title_height + row_cell_height + row_margin
}

const STARTING_WINDOW_WIDTH: f32 = 1024.0;
const STARTING_WINDOW_HEIGHT: f32 = 768.0;

#[tokio::main]
async fn main()
{
    unsafe {
        let (gl, shader_version, window, mut events_loop, _context) = {
            let sdl = sdl2::init().expect("Failed to initialize SDL");
            let video = sdl.video().expect("Failed to initialize SDL video");

            let gl_attr = video.gl_attr();
            gl_attr.set_context_profile(sdl2::video::GLProfile::Core);
            gl_attr.set_context_version(3, 0);

            let window = video
                .window("Portcullis", STARTING_WINDOW_WIDTH as u32, STARTING_WINDOW_HEIGHT as u32)
                .opengl()
                .resizable()
                .build()
                .expect("Could not create window");
            let gl_context = window.gl_create_context().expect("Could not create OpenGL context");
            let gl = glow::Context::from_loader_function(|s| video.gl_get_proc_address(s) as *const _);
            let event_loop = sdl.event_pump().expect("Could not obtain event pump from SDL");

            (gl, "#version 130", window, event_loop, gl_context)
        };

        let vertex_array = gl.create_vertex_array().expect("Cannot create vertex array");
        gl.bind_vertex_array(Some(vertex_array));

        let program = shaders::load_shader(&gl, shader_version, "res/gpu/hello.vert.glsl", "res/gpu/hello.frag.glsl");

        gl.clear_color(0.098, 0.129, 0.180, 1.0);

        let font = ab_glyph::FontArc::try_from_slice(include_bytes!("../res/font/Roboto/Roboto-Regular.ttf"))
            .expect("Failed to load font");

        let mut glyph_brush = GlyphBrushBuilder::using_font(font).build(&gl);

        let mut running = true;
        let time_counter_milliseconds = std::time::Instant::now();
        let mut time_counter_delta = std::time::Instant::now();

        let mut collections: Option<Vec<Collection>> = None;

        let mut camera = Camera2D::new();
        camera.update_viewport_dimensions(STARTING_WINDOW_WIDTH, STARTING_WINDOW_HEIGHT);

        let aspect_ratio = {
            let row_cell_height = camera.viewport.y / 6.0;
            let col_cell_width = camera.viewport.x / 6.0;
            row_cell_height / col_cell_width
        };

        let collections_future = get_collections(aspect_ratio);
        tokio::pin!(collections_future);

        let mut selection = glam::Vec2::ZERO;

        let disney_logo =
            image::io::Reader::new(std::io::Cursor::new(include_bytes!("../res/img/DisneyPlus-Logo.png")))
                .with_guessed_format()
                .expect(IMG_ERR)
                .decode()
                .expect(IMG_ERR);
        let disney_logo_dims = glam::vec2(disney_logo.width() as f32, disney_logo.height() as f32);
        let disney_logo_texture = upload_image_to_gpu(&gl, disney_logo);

        let spinner = image::io::Reader::new(std::io::Cursor::new(include_bytes!("../res/img/Spinner.png")))
            .with_guessed_format()
            .expect(IMG_ERR)
            .decode()
            .expect(IMG_ERR);
        let spinner_texture = upload_image_to_gpu(&gl, spinner);
        let mut spinner_rotation_angle_degrees: f32 = 0.0;
        let mut spinners = Vec::new();

        let mut textures: HashMap<String, NativeTexture> = HashMap::new(); // Successfully loaded textures
        let mut pending: HashSet<String> = HashSet::new(); // Any pending, non-current jobs
        let mut failed: HashSet<String> = HashSet::new(); // Prevents repeated fetches for failed images
        let mut current_job = None;
        let mut current_url: Option<String> = None;

        let mut camera_tweens = VecDeque::<AnimationSequence<V2>>::new();
        let mut col_tweens = VecDeque::<AnimationSequence<f32>>::new();
        let mut content_tweens = VecDeque::<AnimationSequence<f32>>::new();

        let mut showing_content = None;
        let mut content_size = 0.0;
        let all_content = shaders::load_content(&gl, shader_version);
        let mut content_index_provider = (0 .. all_content.len()).cycle();

        while running
        {
            if collections.is_none()
            {
                let timeout = tokio::time::sleep(tokio::time::Duration::from_millis(1));
                tokio::pin!(timeout);

                tokio::select! {
                    _ = &mut timeout => (),

                    collections_results = &mut collections_future =>
                    {
                        println!("HTTP Request completed! Len: {}", collections_results.len());

                        collections = Some(collections_results);
                    },
                };
            }

            let mut job_complete = false;
            if let Some(ref mut current_job) = current_job
            {
                let timeout = tokio::time::sleep(tokio::time::Duration::from_millis(1));
                tokio::pin!(timeout);

                if !RUN_LOCAL
                {
                    tokio::select! {
                        _ = &mut timeout => (),

                        http_image = current_job =>
                        {
                            let url = current_url.take().unwrap();
                            pending.remove(&url);

                            if let Some(http_image) = http_image
                            {
                                println!("Fetched Image: {}", url);
                                textures.insert(url, upload_image_to_gpu(&gl, http_image));
                            }
                            else
                            {
                                println!("Something went wrong for: {}", url);
                                failed.insert(url);
                            }

                            job_complete = true;
                        },
                    };
                }
            }
            else if !pending.is_empty()
            {
                let url = pending.iter().take(1).next().cloned().unwrap();
                current_job = Some(Box::pin(load_image_from_http(url.clone())));
                current_url = Some(url);
            }

            if job_complete
            {
                current_job = None;
            }

            let time_milliseconds = time_counter_milliseconds.elapsed().as_millis() as f32 / 1000.0;
            let time_delta = time_counter_delta.elapsed().as_millis() as f32 / 1000.0;
            time_counter_delta = std::time::Instant::now();

            if !camera_tweens.is_empty()
            {
                if camera_tweens[0].finished()
                {
                    camera_tweens.pop_front();
                }
                else
                {
                    camera_tweens[0].advance_by(time_delta as f64);
                    camera.position = camera_tweens[0].now().into();
                }
            }

            if !col_tweens.is_empty()
            {
                if col_tweens[0].finished()
                {
                    col_tweens.pop_front();
                }
                else
                {
                    col_tweens[0].advance_by(time_delta as f64);
                    selection.x = col_tweens[0].now();
                }
            }

            if !content_tweens.is_empty()
            {
                if content_tweens[0].finished()
                {
                    if content_tweens[0].now() < 1.0
                    {
                        showing_content = None;
                    }

                    content_tweens.pop_front();
                }
                else
                {
                    content_tweens[0].advance_by(time_delta as f64);
                    content_size = content_tweens[0].now();
                }
            }

            for event in events_loop.poll_iter()
            {
                match event
                {
                    Event::Quit { .. } => running = false,
                    Event::KeyDown { keycode: Some(Keycode::D), .. } => camera.position.x += 64.0,
                    Event::KeyDown { keycode: Some(Keycode::A), .. } => camera.position.x -= 64.0,
                    Event::KeyDown { keycode: Some(Keycode::S), .. } => camera.position.y += 64.0,
                    Event::KeyDown { keycode: Some(Keycode::W), .. } => camera.position.y -= 64.0,

                    Event::KeyDown { keycode: Some(Keycode::Right), .. }
                        if showing_content.is_none() && col_tweens.is_empty() =>
                    {
                        if let Some(ref mut collections) = collections
                        {
                            let index = selection.y as usize;
                            let origin = collections[index].selected_video;
                            collections[index].selected_video += 1;

                            if collections[index].selected_video >= collections[index].videos.len() as i32
                            {
                                collections[index].selected_video = 0;
                            }

                            let target = collections[index].selected_video;

                            #[rustfmt::skip]
                            col_tweens.push_back(
                                keyframes![
                                    (origin as f32, 0.0f32, functions::EaseInOut),
                                    (target as f32, 0.5f32, functions::EaseInOut)
                                ]
                            );
                        }
                    }

                    Event::KeyDown { keycode: Some(Keycode::Left), .. }
                        if showing_content.is_none() && col_tweens.is_empty() =>
                    {
                        if let Some(ref mut collections) = collections
                        {
                            let index = selection.y as usize;
                            let origin = collections[index].selected_video;
                            collections[index].selected_video -= 1;

                            if collections[index].selected_video < 0
                            {
                                collections[index].selected_video = collections[index].videos.len() as i32 - 1;
                            }

                            let target = collections[index].selected_video;

                            #[rustfmt::skip]
                            col_tweens.push_back(
                                keyframes![
                                    (origin as f32, 0.0f32, functions::EaseInOut),
                                    (target as f32, 0.5f32, functions::EaseInOut)
                                ]
                            );
                        }
                    }

                    Event::KeyDown { keycode: Some(Keycode::Down), .. }
                        if showing_content.is_none() && camera_tweens.is_empty() && col_tweens.is_empty() =>
                    {
                        if let Some(ref collections) = collections
                        {
                            selection.y += 1.0;

                            if selection.y >= collections.len() as f32
                            {
                                selection.y = 0.0;
                            }

                            let col_target = collections[selection.y as usize].selected_video;

                            selection.x = col_target as f32;

                            let row_height = calc_row_height(&camera);

                            let origin = camera.position;
                            let target = glam::Vec2::Y * selection.y * row_height;

                            #[rustfmt::skip]
                            camera_tweens.push_back(
                                keyframes![
                                    (origin.into(), 0.0, functions::EaseInOut),
                                    (target.into(), 0.5, functions::EaseInOut)
                                ]
                            );
                        }
                    }

                    Event::KeyDown { keycode: Some(Keycode::Up), .. }
                        if showing_content.is_none() && camera_tweens.is_empty() && col_tweens.is_empty() =>
                    {
                        if let Some(ref collections) = collections
                        {
                            selection.y -= 1.0;

                            if selection.y < 0.0
                            {
                                selection.y = collections.len() as f32 - 1.0;
                            }

                            let col_target = collections[selection.y as usize].selected_video;

                            selection.x = col_target as f32;

                            let row_height = calc_row_height(&camera);

                            let origin = camera.position;
                            let target = glam::Vec2::Y * selection.y * row_height;

                            #[rustfmt::skip]
                            camera_tweens.push_back(
                                keyframes![
                                    (origin.into(), 0.0, functions::EaseInOut),
                                    (target.into(), 0.5, functions::EaseInOut)
                                ]
                            );
                        }
                    }

                    Event::KeyDown { keycode: Some(Keycode::Return), .. }
                        if showing_content.is_none()
                            && camera_tweens.is_empty()
                            && col_tweens.is_empty()
                            && collections.is_some() =>
                    {
                        if let Some(ref mut collections) = collections
                        {
                            let current_collection = &mut collections[selection.y as usize];

                            let content_index = &mut current_collection.videos
                                [current_collection.selected_video as usize]
                                .content_index;

                            if *content_index == CONTENT_NOT_SET
                            {
                                *content_index = content_index_provider.next().unwrap()
                            }

                            showing_content = Some(all_content[*content_index]);

                            #[rustfmt::skip]
                            content_tweens.push_back(
                                keyframes![
                                    (0.0, 0.0, functions::EaseInOut),
                                    (1.0, 1.0, functions::EaseInOut)
                                ]
                            );
                        }
                    }

                    Event::KeyDown { keycode: Some(Keycode::Escape), .. } if showing_content.is_some() =>
                    {
                        #[rustfmt::skip]
                        content_tweens.push_back(
                            keyframes![
                                (1.0, 0.0, functions::EaseInOut),
                                (0.0, 1.0, functions::EaseInOut)
                            ]
                        );
                    }

                    Event::KeyDown { keycode: Some(Keycode::Escape), .. } => running = false,

                    Event::Window { win_event: WindowEvent::Resized(width, height), .. } =>
                    {
                        camera.update_viewport_dimensions(width as f32, height as f32);
                        gl.viewport(0, 0, width, height);
                    }

                    _ => (),
                }
            }

            let window_width = window.size().0 as f32;
            let window_height = window.size().1 as f32;

            gl.clear(glow::COLOR_BUFFER_BIT);

            gl.use_program(Some(program));

            let origin_matrix = camera.get_origin_matrix();
            let smaller_dims = disney_logo_dims * 0.5;
            draw_quad_textured(
                &gl,
                program,
                glam::vec2(window_width / 2.0 - (smaller_dims.x / 2.0), window_height / 2.0 - (smaller_dims.y / 2.0)),
                smaller_dims,
                glam::vec4(1.0, 1.0, 1.0, 1.0),
                origin_matrix,
                disney_logo_texture,
            );

            if RUN_LOCAL
            {
                glyph_brush.queue(Section {
                    screen_position: camera.get_position_in_screen_space(glam::vec2(0.0, 0.0)).into(),
                    bounds: camera.viewport.into(),
                    text: vec![Text::default()
                        .with_text(format!("{}", time_milliseconds).as_str())
                        .with_color([1.0, 1.0, 1.0, 1.0])
                        .with_scale(12.0)],
                    ..Section::default()
                });
            }

            spinners.clear();
            spinner_rotation_angle_degrees += time_delta * 100.0;

            if let Some(ref collections) = collections
            {
                draw_all_collections(
                    collections,
                    &gl,
                    program,
                    &camera,
                    &mut glyph_brush,
                    selection,
                    &mut spinners,
                    &textures,
                    &mut pending,
                    &failed,
                );
            }

            if collections.is_none()
            {
                let spinner = glam::vec2(window_width / 2.0, window_height / 2.0);

                let transform_matrix = glam::f32::Mat4::orthographic_rh(
                    camera.position.x - spinner.x,
                    camera.position.x - spinner.x + camera.viewport.x,
                    camera.position.y - spinner.y + camera.viewport.y,
                    camera.position.y - spinner.y,
                    -1.0,
                    1.0,
                );

                draw_image_centered(
                    &gl,
                    program,
                    glam::Vec2::ZERO,
                    glam::vec2(64.0, 64.0),
                    glam::vec4(1.0, 1.0, 1.0, 1.0),
                    transform_matrix * glam::f32::Mat4::from_rotation_z(spinner_rotation_angle_degrees.to_radians()),
                    spinner_texture,
                );
            }

            for spinner in &spinners
            {
                let transform_matrix = glam::f32::Mat4::orthographic_rh(
                    camera.position.x - spinner.x,
                    camera.position.x - spinner.x + camera.viewport.x,
                    camera.position.y - spinner.y + camera.viewport.y,
                    camera.position.y - spinner.y,
                    -1.0,
                    1.0,
                );

                draw_image_centered(
                    &gl,
                    program,
                    glam::Vec2::ZERO,
                    glam::vec2(64.0, 64.0),
                    glam::vec4(1.0, 1.0, 1.0, 1.0),
                    transform_matrix * glam::f32::Mat4::from_rotation_z(spinner_rotation_angle_degrees.to_radians()),
                    spinner_texture,
                );
            }

            glyph_brush.draw_queued(&gl, window_width as u32, window_height as u32).expect("Draw queued");

            if let Some(content) = showing_content
            {
                let content_position = (glam::vec2(window_width, window_height) / 2.0) * (1.0 - content_size);
                let content_dimensions = glam::vec2(window_width, window_height) * content_size;

                gl.use_program(Some(content));

                let time = gl.get_uniform_location(showing_content.unwrap(), "time").unwrap();
                gl.uniform_1_f32(Some(&time), time_milliseconds);

                let resolution = gl.get_uniform_location(showing_content.unwrap(), "resolution").unwrap();
                gl.uniform_2_f32(Some(&resolution), content_dimensions.x, content_dimensions.y);

                draw_quad(
                    &gl,
                    content,
                    content_position,
                    content_dimensions,
                    glam::Vec4::ONE,
                    camera.get_origin_matrix(),
                );
            }

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
)
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
)
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

#[allow(clippy::too_many_arguments)]
unsafe fn draw_all_collections(
    collections: &[Collection],
    gl: &Context,
    program: NativeProgram,
    camera: &Camera2D,
    glyph_brush: &mut glow_glyph::GlyphBrush,
    selection: glam::Vec2,
    spinners: &mut Vec<glam::Vec2>,
    textures: &HashMap<String, NativeTexture>,
    pending: &mut HashSet<String>,
    failed: &HashSet<String>,
)
{
    let global_margin = 16.0;

    let row_cell_height = camera.viewport.y / 6.0;
    let title_height = row_cell_height / 4.0;
    let row_margin = row_cell_height / 5.0;
    let row_height = title_height + row_cell_height + row_margin;

    for (row, collection) in collections.iter().enumerate()
    {
        let row_y = row as f32 * row_height + global_margin;

        let title = collection.name.as_str();
        let title_section = Section {
            screen_position: camera.get_position_in_screen_space(glam::vec2(24.0, row_y - 14.0)).into(),
            bounds: camera.viewport.into(),
            text: vec![Text::default().with_text(title).with_color([1.0, 1.0, 1.0, 1.0]).with_scale(40.0)],
            ..Section::default()
        };

        glyph_brush.queue(title_section);

        let col_cell_width = camera.viewport.x / 6.0;
        let col_margin = col_cell_width / 6.0;
        let both_sides = 2.0;
        let col_width = col_cell_width + col_margin * both_sides;

        let row_selected = row as i32 == selection.y as i32;

        for (col, video) in collection.videos.iter().enumerate()
        {
            let selected = row_selected && col as i32 == collection.selected_video;
            let col_y = row_y + title_height;
            let selection_offset_x =
                if row_selected { selection.x * col_width } else { collection.selected_video as f32 * col_width };
            let col_x = col as f32 * col_width - selection_offset_x + global_margin;
            let position = glam::vec2(col_x, col_y);
            let dimensions = glam::vec2(col_margin + col_cell_width, row_height - title_height - row_margin);

            if camera.is_rectangle_in_view(position, dimensions)
            {
                if !textures.contains_key(&video.url) && !failed.contains(&video.url)
                {
                    pending.insert(video.url.clone());
                }

                if selected
                {
                    let selection_border_size = 4.0;
                    draw_quad(
                        gl,
                        program,
                        position - glam::vec2(selection_border_size, selection_border_size),
                        dimensions + (glam::vec2(selection_border_size, selection_border_size) * 2.0),
                        glam::vec4(1.0, 1.0, 1.0, 0.75),
                        camera.get_matrix(),
                    );
                }

                if textures.contains_key(&video.url)
                {
                    draw_quad_textured(
                        gl,
                        program,
                        position,
                        dimensions,
                        glam::vec4(1.0, 1.0, 1.0, 1.0),
                        camera.get_matrix(),
                        textures[&video.url],
                    );
                }
                else
                {
                    draw_quad(
                        gl,
                        program,
                        position,
                        dimensions,
                        glam::vec4(0.227, 0.227, 0.258, 0.5),
                        camera.get_matrix(),
                    );

                    spinners.push(position + dimensions / 2.0);
                }
            }
        }
    }
}

unsafe fn upload_image_to_gpu(gl: &Context, image: image::DynamicImage) -> NativeTexture
{
    let texture = gl.create_texture().unwrap();

    gl.bind_texture(glow::TEXTURE_2D, Some(texture));

    gl.tex_parameter_i32(glow::TEXTURE_2D, glow::TEXTURE_MIN_FILTER, glow::LINEAR as i32);
    gl.tex_parameter_i32(glow::TEXTURE_2D, glow::TEXTURE_MAG_FILTER, glow::LINEAR as i32);

    gl.tex_image_2d(
        glow::TEXTURE_2D,
        0,
        glow::RGBA8 as i32,
        image.width() as i32,
        image.height() as i32,
        0,
        glow::RGBA,
        glow::UNSIGNED_BYTE,
        Some(&image.into_rgba8().into_vec()),
    );

    gl.generate_mipmap(glow::TEXTURE_2D);
    gl.bind_texture(glow::TEXTURE_2D, None);

    texture
}

async fn load_image_from_http(url: String) -> Option<image::DynamicImage>
{
    let url = &url;

    match reqwest::get(url).await
    {
        Ok(request) => match request.bytes().await
        {
            Ok(bytes) => match image::io::Reader::new(std::io::Cursor::new(bytes)).with_guessed_format()
            {
                Ok(http_image_bytes) => match http_image_bytes.decode()
                {
                    Ok(http_image) => Some(http_image),
                    Err(err) =>
                    {
                        println!("  Err(4): {:?} {}", err, url);
                        None
                    }
                },
                Err(err) =>
                {
                    println!("  Err(3): {:?} {}", err, url);
                    None
                }
            },
            Err(err) =>
            {
                println!("  Err(2): {:?} {}", err, url);
                None
            }
        },
        Err(err) =>
        {
            println!("  Err(1): {:?} {}", err, url);
            None
        }
    }
}

unsafe fn draw_image_centered(
    gl: &Context,
    program: NativeProgram,
    position: glam::Vec2,
    dimensions: glam::Vec2,
    color: glam::Vec4,
    orthographic_projection_matrix: glam::Mat4,
    texture: NativeTexture,
)
{
    gl.active_texture(glow::TEXTURE0);
    gl.bind_texture(glow::TEXTURE_2D, Some(texture));

    gl.enable(glow::BLEND);
    gl.blend_func(glow::SRC_ALPHA, glow::ONE_MINUS_SRC_ALPHA);

    let using_rectangle_texture = gl.get_uniform_location(program, "using_rectangle_texture").unwrap();
    gl.uniform_1_u32(Some(&using_rectangle_texture), 1);

    let rectangle_color = gl.get_uniform_location(program, "rectangle_color").unwrap();
    gl.uniform_4_f32(Some(&rectangle_color), color.x, color.y, color.z, color.w);

    let rectangle_position = gl.get_uniform_location(program, "rectangle_position").unwrap();
    gl.uniform_2_f32(Some(&rectangle_position), position.x, position.y);

    let rectangle_dimensions = gl.get_uniform_location(program, "rectangle_dimensions").unwrap();
    gl.uniform_2_f32(Some(&rectangle_dimensions), dimensions.x, dimensions.y);

    let orthographic_projection = gl.get_uniform_location(program, "orthographic_projection").unwrap();
    gl.uniform_matrix_4_f32_slice(
        Some(&orthographic_projection),
        false,
        &orthographic_projection_matrix.to_cols_array(),
    );

    gl.draw_arrays(glow::QUADS, 0, 4);

    let using_rectangle_texture = gl.get_uniform_location(program, "using_rectangle_texture").unwrap();
    gl.uniform_1_u32(Some(&using_rectangle_texture), 0);

    gl.bind_texture(glow::TEXTURE_2D, None);
}

#[cfg(test)]
mod test
{
    use super::*;

    #[test]
    fn test()
    {
        let camera = Camera2D { position: glam::vec2(0.0, 0.0), viewport: glam::vec2(256.0, 256.0) };

        assert_eq!(camera.is_rectangle_in_view(glam::vec2(0.0, 0.0), glam::vec2(64.0, 64.0)), true);
        assert_eq!(camera.is_rectangle_in_view(glam::vec2(1000.0, 1000.0), glam::vec2(64.0, 64.0)), false);
    }
}

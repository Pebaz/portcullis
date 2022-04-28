/*
Samuel Wilder
*/

precision mediump float;

in vec2 uv;
out vec4 color;

uniform vec4 rectangle_color;
uniform uint using_rectangle_texture;
uniform vec2 resolution;
uniform float time;
uniform sampler2D rectangle_texture;

void fragment(vec2 uv, out vec3 color);

void main()
{
    vec2 uv = (2.0 * gl_FragCoord.xy - resolution.xy) / resolution.y;
    vec3 final_color = vec3(0);
    fragment(uv, final_color);
    color = vec4(final_color, 1);

    if (using_rectangle_texture > uint(0))
    {
        vec4 sample = texture(rectangle_texture, uv);
        color = sample * rectangle_color;
    }
}

const int max_steps = 100;
const float max_distance = 5.0;
const float surface_hit = 0.001;
const float epsilon = 0.001;

#define WHITE 1
#define BLACK 2
#define LIGHT_BROWN 3
#define BROWN 4
#define YELLOW 5

struct Ray
{
    vec3 origin;
    vec3 direction;
    float length;
};

struct Hit
{
    vec3 position;
    float distance;
    int object_type;
    vec2 uv;
    vec3 normal;
};

float sdf_sphere(const in vec3 point, const in vec3 origin, const in float radius)
{
    return length(point - origin) - radius;
}

float sdf_box(vec3 point, vec3 origin, vec3 bounds)
{
    vec3 dist = abs(point - origin) - bounds;
    return length(
        max(dist, 0.0)
    ) + min(
        max(dist.x, max(dist.y, dist.z)),
        0.0
    );
}

float sdf_line(vec3 point, vec3 point_a, vec3 point_b, float radius)
{
    vec3 a = point - point_a;
    vec3 b = point_b - point_a;
    float h = clamp(dot(a, b) / dot(b, b), 0.0, 1.0);
    return length(a - b * h) - radius;
}

vec3 rotate_x(const in vec3 point, const in float angle)
{
    float s = sin(angle);
    float c = cos(angle);

    vec3 result = vec3(
        point.x,
        c * point.y + s * point.z,
        -s * point.y + c * point.z
    );

    return result;
}

vec3 rotate_y(const in vec3 point, const in float angle)
{
    float s = sin(angle);
    float c = cos(angle);

    vec3 result = vec3(
        c * point.x + s * point.z,
        point.y,
        -s * point.x + c * point.z
    );

    return result;
}

vec3 rotate_z(const in vec3 point, const in float angle)
{
    float s = sin(angle);
    float c = cos(angle);

    vec3 result = vec3(
        c * point.x + s * point.y,
        -s * point.x + c * point.y,
        point.z
    );

    return result;
}

Hit get_closer_hit(Hit a, Hit b)
{
    if (a.distance <= b.distance)
        return a;
    else
        return b;
}

mat3 skew(float skew_angle, const in vec3 a, const in vec3 b)
{
    skew_angle = tan(skew_angle);
    float x = a.x * skew_angle;
    float y = a.y * skew_angle;
    float z = a.z * skew_angle;

    return mat3(
        x * b.x + 1.0, x * b.y, x * b.z,
        y * b.x, y * b.y + 1.0, y * b.z,
        z * b.x, z * b.y, z * b.z + 1.0
    );
}

// float round_merge(float shape1, float shape2, float radius) {
//     float2 intersectionSpace = float2(shape1 - radius, shape2 - radius);
//     intersectionSpace = min(intersectionSpace, 0);
//     return length(intersectionSpace) - radius;
// }

Hit body(vec3 point)
{
    Hit result;

    result.position = point;

    vec3 sample_point = point;
    vec3 a = vec3(0, 1.0, 0);
    vec3 b = vec3(0, 0, -1.0);
    float skew_angle = 0.2;

    sample_point = skew(skew_angle, a, b) * sample_point;

    vec3 head_point = vec3(0, 0.05, 0.3);
    vec3 tail_point = vec3(0, 0, -0.3);
    float roundness = 1.0;
    float body = sdf_line(sample_point, head_point, tail_point, roundness);

    result.distance = body;
    result.object_type = YELLOW;

    // Determine material based on point on body
    if (distance(sample_point, head_point * 5.5) < 1.0001)
    {
        result.object_type = LIGHT_BROWN;
    }

    else if (distance(sample_point, head_point * 2.5) < 1.005)
    {
        result.object_type = BROWN;
    }

    // else if (distance(sample_point, tail_point) < 1.0005)
    // {
    //     result.object_type = WHITE;
    // }

    else if (distance(point, tail_point * 4.0) < 1.25)
    {
        result.object_type = BROWN;
    }

    // Face

    float eye1 = sdf_sphere(point, vec3(-0.35, 0.1, 1.18), 0.1);
    float highlight1 = sdf_sphere(point, vec3(-0.36, 0.12, 1.27), 0.01);

    if (eye1 < result.distance)
    {
        result.distance = min(result.distance, eye1);
        result.object_type = BLACK;

        if (highlight1 < result.distance)
        {
            result.distance = highlight1;
            result.object_type = WHITE;
        }
    }

    float eye2 = sdf_sphere(point, vec3(0.35, 0.1, 1.18), 0.1);
    float highlight2 = sdf_sphere(point, vec3(0.36, 0.12, 1.27), 0.01);

    if (eye2 < result.distance)
    {
        result.distance = min(result.distance, eye2);
        result.object_type = BLACK;

        if (highlight2 < result.distance)
        {
            result.distance = highlight2;
            result.object_type = WHITE;
        }
    }

    float smile_base = sdf_sphere(point, vec3(0, 0, 1.16), 0.2);
    float smile_cutout = sdf_sphere(point, vec3(0, -0.15, 1.16), 0.1);
    float smile = max(-smile_base, smile_cutout);
    // float smile = min(smile_base, smile_cutout);

    if (smile < result.distance)
    {
        result.distance = min(result.distance, smile);
        result.object_type = BLACK;
    }

    return result;
}

Hit foot(vec3 point, vec3 point_a, vec3 point_b, float radius)
{
    Hit result;

    result.position = point;

    float line = sdf_line(point, point_a, point_b, radius);

    result.distance = line;
    result.object_type = BLACK;

    return result;
}

float rounded_cylinder(vec3 point, vec3 origin, float ra, float rb, float h)
{
    point -= origin;
    vec2 d = vec2(length(point.xz) - 2.0 * ra + rb, abs(point.y) - h);
    return min(max(d.x, d.y), 0.0) + length(max(d, 0.0)) - rb;
}

Hit wings(vec3 point)
{
    Hit result;

    result.position = point;

    // float sphere = sdf_sphere(point, vec3(0, 2, 0), 1.0);

    // float sphere = length(point - vec3(0, 2, 0)) - 1.0;

    // float wing = rounded_cylinder(rotate_x(point, 1.5), vec3(0, 1, 0), 0.5, 0.1, 0.5);

    vec3 origin = rotate_x(vec3(0.8, 0.8, 0.55) - point, 1.5) + point;
    float wing = rounded_cylinder(point, origin, 0.17, 0.01, 0.03);
    float wing_cutout = rounded_cylinder(point, origin + vec3(0, 0.05, 0), 0.1, 0.01, 0.03);
    wing = max(wing, -wing_cutout);

    vec3 origin2 = rotate_x(vec3(-0.8, 0.8, 0.55) - point, 1.5) + point;
    float wing2 = rounded_cylinder(point, origin2, 0.17, 0.01, 0.03);
    float wing_cutout2 = rounded_cylinder(point, origin2 + vec3(0, 0.05, 0), 0.1, 0.01, 0.03);
    wing2 = max(wing2, -wing_cutout2);

    result.distance = min(wing, wing2);
    result.object_type = WHITE;

    return result;
}

Hit scene(vec3 point)
{
    Hit result = foot(point, vec3(0), vec3(0, 0, -1.35), 0.05);

    Hit foot1 = foot(point, vec3(0, 0, 0.15), vec3(-0.65, -0.65, 0.75), 0.1);
    Hit foot2 = foot(point, vec3(0, 0, -0.1), vec3(-0.75, -0.75, 0.0), 0.1);
    Hit foot3 = foot(point, vec3(0, 0, -0.55), vec3(-0.75, -0.75, -0.65), 0.1);

    Hit foot4 = foot(point, vec3(0, 0, 0.15), vec3(0.65, -0.65, 0.75), 0.1);
    Hit foot5 = foot(point, vec3(0, 0, -0.1), vec3(0.75, -0.75, 0.0), 0.1);
    Hit foot6 = foot(point, vec3(0, 0, -0.55), vec3(0.75, -0.75, -0.65), 0.1);

    Hit wings = wings(point);

    result = get_closer_hit(result, body(point));
    result = get_closer_hit(result, foot1);
    result = get_closer_hit(result, foot2);
    result = get_closer_hit(result, foot3);
    result = get_closer_hit(result, foot4);
    result = get_closer_hit(result, foot5);
    result = get_closer_hit(result, foot6);

    result = get_closer_hit(result, wings);

    return result;
}

vec3 get_scene_normal(const in vec3 point)
{
    vec3 offset1 = vec3(epsilon, -epsilon, -epsilon);
    float f1 = scene(point + offset1).distance;
    vec3 normal = offset1 * f1;

    vec3 offset2 = vec3(-epsilon, -epsilon, epsilon);
    float f2 = scene(point + offset2).distance;
    normal += offset2 * f2;

    vec3 offset3 = vec3(-epsilon, epsilon, -epsilon);
    float f3 = scene(point + offset3).distance;
    normal += offset3 * f3;

    vec3 offset4 = vec3(epsilon, epsilon, epsilon);
    float f4 = scene(point + offset4).distance;
    normal += offset4 * f4;

    return normalize(normal);
}

Hit raymarch(Ray ray)
{
    Hit closest;

    for (int step = 0; step < max_steps; step++)
    {
        vec3 point = ray.origin + ray.direction * ray.length;
        closest = scene(point);
        closest.position = point;

        if (closest.distance < surface_hit)
            break;

        ray.length += closest.distance;

        if (ray.length >= max_distance)
            break;
    }

    closest.distance = ray.length;
    return closest;
}

vec3 render(Ray ray)
{
    vec3 color = vec3(0);

    Hit hit = raymarch(ray);

    if (hit.distance <= max_distance)
    {
        vec3 normal = get_scene_normal(hit.position);

        if (hit.object_type == WHITE)
        {
            color = vec3(1.0) - normal.x;
        }

        else if (hit.object_type == BLACK)
        {
            // color = abs(get_scene_normal(hit.position));
            color = vec3(0.15);
        }

        else if (hit.object_type == LIGHT_BROWN)
        {
            color = vec3(189, 153, 91) / 255.0;
        }

        else if (hit.object_type == BROWN)
        {
            color = vec3(0.27, 0.17, 0.09);
        }

        else if (hit.object_type == YELLOW)
        {
            color = vec3(1, 0.78, 0);
        }

        vec3 light_color = vec3(0.2, 0.5, 0.7);
        vec3 light_dir = normalize(rotate_y(vec3(0, -0.25, 1), -1.25));
        float diff = max(dot(normal, light_dir), 0.0);
        float sky_energy = 1.7;
        vec3 sky = diff * light_color * sky_energy;
        // sky = vec3(0);

        vec3 light_color2 = vec3(0.7, 0.5, 0.2);
        vec3 light_dir2 = normalize(rotate_y(vec3(0, 0.25, 1), 1.0));
        float diff2 = max(dot(normal, light_dir2), 0.0);
        float sun_energy = 1.2;
        vec3 sun = diff2 * light_color2 * sun_energy;
        // sun = vec3(0);

        vec3 light_color3 = vec3(1);
        vec3 light_dir3 = normalize(rotate_y(vec3(0, 1, 4), 2.75));
        float diff3 = max(dot(normal, light_dir3), 0.0);
        float wormhole_energy = 0.5;
        vec3 wormhole = diff3 * light_color3 * wormhole_energy;
        // wormhole = vec3(0);

        // float diff2 = max(dot(normal, light_dir2), 0.0);
        // lighting += vec3(diff2) * 0.5 * vec3(0.7, 0.5, 0.2);

        // color = albedo * lighting;

        vec3 ambient = vec3(0.3);

        color = color * (ambient + sun + sky + wormhole);
    }

    else
    {
        color = normalize(normalize(hit.position) + vec3(2));
    }

    return color;
}

Ray get_camera_ray(
    const in vec3 vPos,
    const in vec3 vForwards,
    const in vec3 vWorldUp,
    const in vec2 uv
) {
    vec2 vUV = uv;
    vec2 vViewCoord = vUV;// * 2.0 - 1.0;

    // float fRatio = resolution.x / resolution.y;
    // vViewCoord.y /= fRatio;

    Ray ray;

    ray.origin = vPos;

    vec3 vRight = normalize(cross(vForwards, vWorldUp));
    vec3 vUp = cross(vRight, vForwards);

    ray.direction = normalize(
        vRight * vViewCoord.x + vUp * vViewCoord.y + vForwards
    );

    return ray;
}

Ray look_at(
    const in vec3 vPos,
    const in vec3 vInterest,
    const in vec2 uv
) {
    vec3 vForwards = normalize(vInterest - vPos);
    vec3 vUp = vec3(0.0, 1.0, 0.0);

    return get_camera_ray(vPos, vForwards, vUp, uv);
}

void fragment(vec2 uv, out vec3 color)
{
    // vec3 ray_origin = rotate_y(vec3(0, sin(time * 0.25) * 1.5, 2.5), cos(time));
    vec3 ray_origin = rotate_y(vec3(0, sin(time * 0.2), 2.5), time * 0.4);

    Ray ray = look_at(
        ray_origin,
        vec3(0),
        uv
    );

    color = render(ray);
}

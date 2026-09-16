shader_type spatial;
render_mode cull_back, shadows_disabled;
uniform vec4 light_color : source_color = vec4(1.0);
uniform float center_degrees = 0.0;
uniform float arc_degrees = 225.0;
uniform float intensity : hint_range(0.0, 12.0) = 0.0;
varying vec3 lamp_position;
varying vec3 ship_forward;
varying vec3 ship_starboard;
void vertex() {
    lamp_position = MODEL_MATRIX[3].xyz;
    ship_forward = normalize((MODEL_MATRIX * vec4(0.0, 0.0, -1.0, 0.0)).xyz);
    ship_starboard = normalize((MODEL_MATRIX * vec4(1.0, 0.0, 0.0, 0.0)).xyz);
}
void fragment() {
    vec3 sightline = normalize(CAMERA_POSITION_WORLD - lamp_position);
    float bearing = atan(dot(sightline, ship_starboard), dot(sightline, ship_forward));
    float difference = atan(sin(bearing - radians(center_degrees)), cos(bearing - radians(center_degrees)));
    if (arc_degrees < 359.0 && abs(difference) > radians(arc_degrees * 0.5)) { discard; }
    ALBEDO = light_color.rgb * 0.045;
    EMISSION = light_color.rgb * intensity;
}

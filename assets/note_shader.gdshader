shader_type spatial;
render_mode unshaded, skip_vertex_transform;

global uniform float elapsed_time;
global uniform float approach_time;
global uniform float spawn_distance;
global uniform float vanish_distance;
global uniform float grid_distance;

global uniform float note_transparency;
global uniform float note_begin_transparency;
global uniform float note_end_transparency;

global uniform float note_fade_in_begin;
global uniform float note_fade_in_end;

global uniform float note_fade_out_begin;
global uniform float note_fade_out_end;

varying flat lowp vec4 color;

void vertex() {
	float pos_x = MODEL_MATRIX[0][0];
	float pos_y = MODEL_MATRIX[1][0];
	float time = MODEL_MATRIX[2][0];
	float scale_x = MODEL_MATRIX[0][1];
	float scale_y = MODEL_MATRIX[1][1];
	float scale_z = MODEL_MATRIX[2][1];
	float r = MODEL_MATRIX[0][2];
	float g = MODEL_MATRIX[1][2];
	float b = MODEL_MATRIX[2][2];
	
	float time_til_hit = time - elapsed_time;
	float note_lerp = time_til_hit / approach_time;
	float new_pos = spawn_distance * note_lerp;
	
	float fade_in = clamp((note_lerp - note_fade_in_begin) / (note_fade_in_end - note_fade_in_begin), 0.0, 1);
	float fade_out = clamp((note_lerp - note_fade_out_begin) / (note_fade_out_end - note_fade_out_begin), 0.0, 1.0);
	
	float transparency = mix(note_begin_transparency, note_transparency, fade_in);
	transparency = mix(note_transparency, note_end_transparency, fade_out);
	
	transparency = mix(transparency, 1.0, step(new_pos, vanish_distance));
	
	color = vec4(r, g, b, 1.0 - transparency);
 	
	VERTEX = (VIEW_MATRIX * vec4(VERTEX * vec3(scale_x, scale_y, scale_z) + vec3(pos_x, pos_y, grid_distance + new_pos), 1.0)).xyz;
	POSITION = PROJECTION_MATRIX * vec4(VERTEX, 1.0);
}

void fragment() {
	ALBEDO = color.rgb;
	ALPHA = color.a;
}


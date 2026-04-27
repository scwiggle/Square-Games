shader_type spatial;
render_mode unshaded;

global uniform float elapsed_time;
global uniform float approach_time;
global uniform float spawn_distance;
global uniform float vanish_distance;

global uniform float note_z_multiplier; //used to counteract

global uniform float note_transparency;
global uniform float note_begin_transparency;
global uniform float note_end_transparency;

global uniform float note_fade_in_begin;
global uniform float note_fade_in_end;

global uniform float note_fade_out_begin;
global uniform float note_fade_out_end;

//varying float alpha;
//varying lowp vec3 color;

//output = output_start + ((output_end - output_start) / (input_end - input_start)) * (input - input_start)

float map(float input, float input_start, float input_end, float output_start, float output_end) {
	return output_start + ((output_end - output_start) / (input_end - input_start)) * (input - input_start);
}

void vertex() {
	//color = INSTANCE_CUSTOM.rgb;

	float time_til_hit = INSTANCE_CUSTOM.a-elapsed_time;
	float note_lerp = time_til_hit/approach_time;
	float new_pos = spawn_distance * note_lerp * note_z_multiplier;

	//float map_in_begin = mix(note_fade_in_begin, note_fade_out_begin, float(note_lerp < note_fade_out_begin && note_lerp > note_fade_out_end));
	//float map_in_end = mix(note_fade_in_end, note_fade_out_end, float(note_lerp < note_fade_out_begin && note_lerp > note_fade_out_end));
	//float map_out_begin = mix(note_begin_transparency, note_transparency, float(note_lerp < note_fade_out_begin && note_lerp > note_fade_out_end));
	//float map_out_end = mix(note_transparency, note_end_transparency, float(note_lerp < note_fade_out_begin && note_lerp > note_fade_out_end));

	//alpha = mix(map(note_lerp, map_in_begin, map_in_end, map_out_begin, map_out_end), 1.0, float(new_pos < vanish_distance));

	float transparency = note_transparency;

	if (new_pos < vanish_distance) {
		transparency = 1.0;
	} else if (note_lerp < note_fade_out_end){
		transparency = note_end_transparency;
	} else if (note_lerp < note_fade_in_begin && note_lerp > note_fade_in_end) {
		transparency = map(note_lerp, note_fade_in_begin, note_fade_in_end, note_begin_transparency, note_transparency);
	} else if (note_lerp < note_fade_out_begin && note_lerp > note_fade_out_end) {
		transparency = map(note_lerp, note_fade_out_begin, note_fade_out_end, note_transparency, note_end_transparency);
	} else if (note_lerp > note_fade_in_begin){
		transparency = note_begin_transparency;
	}

	//alpha = new_pos<vanish_distance ? 1.0 : 0.0;
	COLOR = vec4(INSTANCE_CUSTOM.rgb, 1.0 - transparency);
	VERTEX.z += new_pos;
}

void fragment() {
	ALBEDO = COLOR.rgb;
	ALPHA = COLOR.a;
}

//void light() {
//	// Called for every pixel for every light affecting the material.
//	// Uncomment to replace the default light processing function with this one.
//}

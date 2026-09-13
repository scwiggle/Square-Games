using Godot;
using Godot.NativeInterop;
using System;
using System.Collections.Generic;
using System.Runtime.CompilerServices;
using System.Linq;
using System.Runtime.InteropServices;
using System.Diagnostics;
using System.Globalization;
using System.Net.Http;
using System.Threading.Tasks;

[GlobalClass]
public partial class GameHandler : MultiMeshInstance3D {

	private readonly PackedScene cursor_base = (PackedScene)GD.Load("res://scenes/prefabs/cursor.tscn");
	private readonly ArrayMesh note_mesh = (ArrayMesh)GD.Load("res://assets/meshes/Rounded.obj");
	private readonly ShaderMaterial note_material = (ShaderMaterial)GD.Load("res://assets/materials/note_shader_material.tres");
	private readonly PackedScene hud_base = (PackedScene)GD.Load("res://scenes/prefabs/hud.tscn");
	private readonly AudioStreamWav default_hit_sound = (AudioStreamWav)GD.Load("res://assets/audio/hitsound.wav");
	private readonly AudioStreamMP3 default_miss_sound = (AudioStreamMP3)GD.Load("res://assets/audio/misssound.mp3");

	private class Note {
		public Vector2 pos;
		public Color color;
		public float time;
		public int multimesh_index;
		public int chart_index;
		public bool dead;

		readonly float grid_distance;
		readonly MultiMesh multimesh;
		readonly Basis scale;

		[MethodImpl(MethodImplOptions.AggressiveInlining | MethodImplOptions.AggressiveOptimization)]
		public void initialize(Vector2 pos, float time, Color color, int multimesh_index, int chart_index) {
			this.pos = pos;
			this.time = time;
			this.multimesh_index = multimesh_index;
			this.chart_index = chart_index;
			this.color = color;

			dead = false;

			multimesh.SetInstanceTransform(multimesh_index, new Transform3D(scale, new Vector3(pos.X, pos.Y, grid_distance)));
			// multimesh.SetInstanceCustomData(multimesh_index, new Color(color, time));
		}

		[MethodImpl(MethodImplOptions.AggressiveInlining | MethodImplOptions.AggressiveOptimization)]
		public void reinitialize() {
			dead = false;

			multimesh.SetInstanceTransform(multimesh_index, new Transform3D(scale, new Vector3(pos.X, pos.Y, grid_distance)));
			// multimesh.SetInstanceCustomData(multimesh_index, new Color(color, time));
		}

		public Note(MultiMesh multimesh, float grid_distance, Basis scale) {
			this.grid_distance = grid_distance;
			this.multimesh = multimesh;
			this.scale = scale;
		}
	}

	private class NoteData {
		public readonly float x;
		public readonly float y;
		public readonly float t;
		public NoteData(float x, float y, float t) {
			this.x = x;
			this.y = y;
			this.t = t;
		}
	}

	private struct MultimeshData {
		float transformxx;
		float transformxy;
		float transformxz;

		float transformyx;
		float transformyy;
		float transformyz;

		float transformzx;
		float transformzy;
		float transformzz;

		float customr;
		float customg;
		float customb;
		float customa;
	}

	static readonly GDScript AutoplayHandler = GD.Load<GDScript>("res://scripts/classes/AutoplayHandler.gd");
	static readonly GDScript ObjParse = GD.Load<GDScript>("res://addons/obj_parse.gd");
	static readonly GDScript Space = GD.Load<GDScript>("res://scripts/classes/Space.gd");
	static readonly GDScript ReplayParser = GD.Load<GDScript>("res://scripts/classes/ReplayParser.gd");

	private Node SSCS;
	
	private RefCounted settings;
	
	private RefCounted modifiers;

	private Camera3D camera;

	private RefCounted map;
	private NoteData[] map_data;

	private Note[] notes;
	private int notes_tail;
	private int notes_head;

	private Note[] note_rendering_stack;
	private float[] multimesh_buffer_raw;
	private int note_rendering_stack_size;

	private Sprite3D cursor;
	private Node3D hud;

	private int max_loaded_notes;

	public int misses;
	public int hits;
	
	private int last_loaded_note_index;

	private bool ran;
	private bool stopped;
	private bool playing;

	private float speed_multiplier;

	private float hit_time;
	private float hitbox_size;

	private float approach_time;

	private bool no_fail;

	private bool autoplay;

	private float health = 5;
	private int reset_timer = -1;

	private Node autoplay_handler;

	private bool is_replay;
	private byte[] replay_note_hit_data;
	private Vector3[] replay_cursor_pos_data;

	private bool use_hit_sound;
	private bool use_miss_sound;

	private bool record_replays;
	private bool smooth_replays;

	private List<byte> recorded_replay_note_hit_data;
	private List<Vector3> recorded_replay_cursor_pos_data;

	private int last_replay_cursor_pos_index = 0;

	private AudioStreamPlayer hit_sound_player;
	private AudioStreamPlayer miss_sound_player;

	private bool horizontal_flip;
	private bool vertical_flip;

	private Color[] color_set;
	private int color_set_len;
	private float grid_distance;

	private float note_scale;

	private bool end_replay_on_end_of_data;

	private Basis note_basis;

	private Node audio_manager;
	private float start_from;


	[Signal]
	public delegate void endedEventHandler();

	[Signal]
	public delegate void note_hitEventHandler(int note_id, Vector2 note_position, float note_arrival_time);

	[Signal]
	public delegate void note_missedEventHandler(int note_id, Vector2 note_position, float note_arrival_time);

	public void initialize(RefCounted map, bool is_replay = false, byte[] replay_note_hit_data = null, Vector3[] replay_cursor_pos_data = null, bool end_replay_on_end_of_data = false) {
		this.map = map;
		this.is_replay = is_replay;
		this.end_replay_on_end_of_data = end_replay_on_end_of_data;

		if (is_replay) {
			this.replay_note_hit_data = replay_note_hit_data;
			this.replay_cursor_pos_data = replay_cursor_pos_data;
		}

		Godot.Collections.Array raw_map_data = map.Get("data").AsGodotArray();

		map_data = new NoteData[raw_map_data.Count];
		
		float x_flip = horizontal_flip ? -1 : 1;
		float y_flip = vertical_flip ? -1 : 1;
		
		for(int i = 0; i < raw_map_data.Count; i++) {
			Variant v = raw_map_data[i];
			float[] array = v.AsFloat32Array();
			map_data[i] = new NoteData(array[0] * x_flip, array[1] * y_flip, array[2] / 1000f);
		}

		camera = this.GetNode<Camera3D>("/root/Game/Camera");

		cursor = cursor_base.Instantiate<Sprite3D>();

		if (autoplay || is_replay) {
			cursor.Set("accepts_input", false);
		}
		this.AddChild(cursor);

		hud = hud_base.Instantiate<Node3D>();
		this.AddChild(hud);

		SSCS = this.GetNode("/root/SSCS");

		settings = SSCS.Get("settings").As<RefCounted>();
		modifiers = SSCS.Get("modifiers").As<RefCounted>();

		Node3D space = (Node3D)Space.New(SSCS.Get("SPACES_PATH").AsString() + settings.Get("space_id"));
		this.AddChild(space);

		camera.Environment = space.Get("environment").As<Godot.Environment>();
		camera.Environment.GlowEnabled = settings.Get("glow_enabled").As<bool>();
		camera.Environment.GlowStrength = settings.Get("glow_strength").As<float>();
		camera.Environment.GlowBloom = settings.Get("glow_bloom").As<float>();

		speed_multiplier = modifiers.Get("speed").As<float>();

		hit_time = modifiers.Get("hit_time").As<float>() * (speed_multiplier / 1000f);

		hitbox_size = modifiers.Get("hitbox_size").As<float>();

		no_fail = modifiers.Get("no_fail").As<bool>();

		autoplay = modifiers.Get("autoplay").As<bool>();

		color_set = settings.Get("color_set").AsColorArray();

		note_scale = settings.Get("note_scale").As<float>();

		grid_distance = settings.Get("grid_distance").As<float>();

		if (autoplay) {
			autoplay_handler = (Node)AutoplayHandler.New(new Variant[]{map, cursor});
		}

		approach_time = (settings.Get("spawn_distance").As<float>() / settings.Get("approach_rate").As<float>()) * speed_multiplier;

		Multimesh = new MultiMesh();

		string custom_mesh_path = SSCS.Call("get_arbitrary_exension", "user://mesh", new string[]{"obj"}).AsString();
		
		Mesh base_mesh;

		if (custom_mesh_path.Length == 0) {
			base_mesh = note_mesh;
		} else {
			base_mesh = ObjParse.Call("from_path", custom_mesh_path).As<Mesh>();
		}

		Mesh mesh = (Mesh)base_mesh.Duplicate();

		mesh.SurfaceSetMaterial(0, note_material);

		Multimesh.Mesh = mesh;

		Aabb mesh_aabb = mesh.GetAabb();

		note_basis = Basis.FromScale(mesh_aabb.Size.Inverse() * new Vector3(1, 1, 0.2f) * note_scale);

		Multimesh.TransformFormat = MultiMesh.TransformFormatEnum.Transform3D;
		Multimesh.UseCustomData = true;
		
		Multimesh.CustomAabb = new Aabb(new Vector3(0, 0, 0), new Vector3(1000, 1000, 1000));

		GD.Print(1 / note_basis.Scale.Z);

		RenderingServer.GlobalShaderParameterSet("note_z_multiplier", 1 / note_basis.Scale.Z);

		RenderingServer.GlobalShaderParameterSet("approach_time", approach_time);
		RenderingServer.GlobalShaderParameterSet("spawn_distance", settings.Get("spawn_distance"));
		RenderingServer.GlobalShaderParameterSet("vanish_distance", settings.Get("vanish_distance"));

		RenderingServer.GlobalShaderParameterSet("note_begin_transparency", settings.Get("note_begin_transparency"));
		RenderingServer.GlobalShaderParameterSet("note_transparency", settings.Get("note_transparency"));
		RenderingServer.GlobalShaderParameterSet("note_end_transparency", settings.Get("note_end_transparency"));

		RenderingServer.GlobalShaderParameterSet("note_fade_in_begin", settings.Get("note_fade_in_begin"));
		RenderingServer.GlobalShaderParameterSet("note_fade_in_end", settings.Get("note_fade_in_end"));

		RenderingServer.GlobalShaderParameterSet("note_fade_out_begin", settings.Get("note_fade_out_begin"));
		RenderingServer.GlobalShaderParameterSet("note_fade_out_end", settings.Get("note_fade_out_end"));
		
		float max_t_difference = (SSCS.Get("spawn_distance").As<float>() / SSCS.Get("approach_rate").As<float>()) + hit_time + 0.15f;
		int current_note = 0;
		int backward_note = 0;

		foreach (NoteData note in map_data) {
			float note_time = note.t / speed_multiplier;

			while (note_time - (map_data[backward_note].t / speed_multiplier) < max_t_difference) backward_note++;

			current_note += 1;
			
			max_loaded_notes = Math.Max(max_loaded_notes, current_note - backward_note);
		}

		notes = new Note[max_loaded_notes];
		note_rendering_stack = new Note[max_loaded_notes];

		Multimesh.InstanceCount = max_loaded_notes;
		Multimesh.VisibleInstanceCount = 0;

		multimesh_buffer_raw = new float[max_loaded_notes * 16];

		for (int i = 0; i < max_loaded_notes; i++) {
			notes[i] = new Note(Multimesh, grid_distance, note_basis);
		}

		hit_sound_player = new AudioStreamPlayer();
		hit_sound_player.MaxPolyphony = 50;
		hit_sound_player.VolumeLinear = settings.Get("hit_sound_volume").As<float>() * 0.15f;
		hit_sound_player.Bus = "Sounds";

		miss_sound_player = new AudioStreamPlayer();
		miss_sound_player.MaxPolyphony = 50;
		miss_sound_player.VolumeLinear = settings.Get("miss_sound_volume").As<float>() * 0.15f;
		miss_sound_player.Bus = "Sounds";

		string custom_hit_sound_path = SSCS.Call("get_arbitrary_exension", "user://hitsound", new string[]{"mp3", "wav"}).AsString();

		if (custom_hit_sound_path.Length == 0) {
			hit_sound_player.Stream = default_hit_sound;
		} else {
			hit_sound_player.Stream = SSCS.Call("load_audio", custom_hit_sound_path).As<AudioStream>();
		}

		string custom_miss_sound_path = SSCS.Call("get_arbitrary_exension", "user://misssound", new string[]{"mp3", "wav"}).AsString();

		if (custom_miss_sound_path.Length == 0) {
			miss_sound_player.Stream = default_miss_sound;
		} else {
			miss_sound_player.Stream = SSCS.Call("load_audio", custom_miss_sound_path).As<AudioStream>();
		}

		this.AddChild(hit_sound_player);
		this.AddChild(miss_sound_player);

		audio_manager = this.GetNode("/root/AudioManager");

		GD.Print(audio_manager);
		
		audio_manager.Call("set_stream", map.Get("audio"));
		audio_manager.Call("set_playback_speed", speed_multiplier);

		if (record_replays && !autoplay && !is_replay) {
			note_hit += (int note_id, Vector2 note_position, float note_t) => {
				recorded_replay_note_hit_data.Add(1);
			};

			note_missed += (int note_id, Vector2 note_position, float note_t) => {
				recorded_replay_note_hit_data.Add(1);
			};

			ended += () => {
				FileAccess replay_file = FileAccess.Open("user://replays/" + DirAccess.GetFilesAt("user://replays/").Length.ToString() + "_" + map.Get("map_name").AsString().Replace(" ", "_") + "_" + Time.GetDatetimeStringFromSystem(false, true).Replace(" ", "_").Replace(":", "_"), FileAccess.ModeFlags.Write);

				if (replay_file == null) {
					return;
				}

				replay_file.StoreBuffer(ReplayParser.Call("create_replay_without_map", map, recorded_replay_note_hit_data.ToArray(), recorded_replay_cursor_pos_data.ToArray(), settings, modifiers, start_from).AsByteArray());
			};
		}

		GD.Print("datatatat");
		GD.Print(Multimesh.InstanceCount);
		GD.Print(Multimesh.VisibleInstanceCount);
	}

	public void play(float from) {
		Debug.Assert(!ran, "Tried to run game manager more than once");
		ran = true;

		Input.MouseMode = settings.Get("absolute_input").AsBool() ? Input.MouseModeEnum.ConfinedHidden : Input.MouseModeEnum.Captured;

		cursor.Set("pos", new Vector2());
		cursor.Call("update_position");

		playing = true;

		audio_manager.Call("play", from - 1 * speed_multiplier);

		start_from = from;

		float threshold = audio_manager.Get("elapsed").As<float>() + approach_time;

		while (last_loaded_note_index < map_data.Length) {
			NoteData note = map_data[last_loaded_note_index];

			if (note.t <= threshold) {
				if (is_replay) {
					if (replay_note_hit_data[last_loaded_note_index] == 1) {
						hits++;
					} else {
						misses++;
					}
				}
				last_loaded_note_index++;
			} else {
				break;
			}
		}
	}

	public void stop() {
		Debug.Assert(!stopped, "Tried to stop game manager more than once");
		stopped = true;

		Input.MouseMode = Input.MouseModeEnum.Visible;
		playing = false;
		audio_manager.Call("full_stop");

		EmitSignal(SignalName.ended);
	}

	public void pause() {
		playing = false;
		audio_manager.Call("stop");
	}

	public void unpause() {
		playing = true;
		audio_manager.Call("resume");
	}

	public bool check_death() {
		if ((health == 0 && !is_replay && !no_fail) || (audio_manager.Get("elapsed").As<float>() > map_data[map_data.Length - 1].t + 1)) return true;
		return false;
	}

	[MethodImpl(MethodImplOptions.AggressiveOptimization)]
	public void load_notes() {
		float threshold = audio_manager.Get("elapsed").As<float>() + approach_time;

		while (last_loaded_note_index < map_data.Length) {
			NoteData note = map_data[last_loaded_note_index];

			if (note.t <= threshold) {
				Note new_note = notes[notes_tail];

				new_note.initialize(new Vector2(note.x, note.y), note.t, color_set[last_loaded_note_index % color_set.Length], note_rendering_stack_size, last_loaded_note_index);

				note_rendering_stack[note_rendering_stack_size] = new_note;

				note_rendering_stack_size++;

				Multimesh.VisibleInstanceCount = note_rendering_stack_size;

				notes_tail = (notes_tail + 1) % max_loaded_notes;

				last_loaded_note_index++;
			} else {
				break;
			}
		}
	}

	[MethodImpl(MethodImplOptions.AggressiveOptimization)]
	public void check_hitreg() {
		float elapsed = audio_manager.Get("elapsed").As<float>();
		float threshold = elapsed - hit_time;
		
		Vector2 cursor_pos = cursor.Get("pos").AsVector2();

		int i = notes_head;

		while (i != notes_tail) {
			Note note = notes[i];

			i = (i + 1) % max_loaded_notes;

			if (note.dead) continue;

			float note_t = note.time;

			if (note_t < elapsed) {
				if (note_t < threshold) {
					misses += 1;
					health -= 1;

					if (use_miss_sound) miss_sound_player.Play(0);

					note_rendering_stack_size--;

					Note replacement_note = note_rendering_stack[note_rendering_stack_size];

					replacement_note.multimesh_index = note.multimesh_index;
					replacement_note.reinitialize();

					note.dead = true;

					Multimesh.VisibleInstanceCount = note_rendering_stack_size;

					note_rendering_stack[note.multimesh_index] = replacement_note;

					// EmitSignal(SignalName.note_missed, note.chart_index, note.pos, note.time);
				} else {
					Vector2 diff = note.pos - cursor_pos;

					if (Math.Max(Math.Abs(diff.X), Math.Abs(diff.Y)) < hitbox_size) {
						hits += 1;
						health += 0.5f;

						if (use_hit_sound) hit_sound_player.Play(0);

						note_rendering_stack_size--;

						Note replacement_note = note_rendering_stack[note_rendering_stack_size];

						replacement_note.multimesh_index = note.multimesh_index;
						replacement_note.reinitialize();

						note.dead = true;

						Multimesh.VisibleInstanceCount = note_rendering_stack_size;

						note_rendering_stack[note.multimesh_index] = replacement_note;

						// EmitSignal(SignalName.note_hit, note.chart_index, note.pos, note.time);
					}
				}
			} else {
				break;
			}
		}

		health = Math.Clamp(health, 0, 5);

		while (notes_head != notes_tail && notes[notes_head].dead) notes_head = (notes_head + 1) % max_loaded_notes;
	}

	[MethodImpl(MethodImplOptions.AggressiveOptimization)]
	public void check_hitreg_replay() {
		float elapsed = audio_manager.Get("elapsed").As<float>();
		float threshold = elapsed + hit_time;
		
		Vector2 cursor_pos = cursor.Get("pos").AsVector2();

		int i = notes_head;

		while (i != notes_tail) {
			Note note = notes[i];

			i = (i + 1) % max_loaded_notes;

			if (note.dead) continue;

			float note_t = note.time;

			if (note_t < threshold) {
				if (replay_note_hit_data[note.chart_index] == 0) {
					misses += 1;
					health -= 1;

					if (use_miss_sound) miss_sound_player.Play(0);

					note_rendering_stack_size--;

					Note replacement_note = note_rendering_stack[note_rendering_stack_size];

					replacement_note.multimesh_index = note.multimesh_index;
					replacement_note.reinitialize();

					note.dead = true;

					Multimesh.VisibleInstanceCount = note_rendering_stack_size;

					note_rendering_stack[note.multimesh_index] = replacement_note;

					EmitSignal(SignalName.note_missed, note.chart_index, note.pos, note.time);
				} else {
					hits += 1;
					health += 0.5f;

					if (use_hit_sound) hit_sound_player.Play(0);

					note_rendering_stack_size--;

					Note replacement_note = note_rendering_stack[note_rendering_stack_size];

					replacement_note.multimesh_index = note.multimesh_index;
					replacement_note.reinitialize();

					note.dead = true;

					Multimesh.VisibleInstanceCount = note_rendering_stack_size;

					note_rendering_stack[note.multimesh_index] = replacement_note;

					EmitSignal(SignalName.note_hit, note.chart_index, note.pos, note.time);
				}
			} else {
				break;
			}
		}

		health = Math.Clamp(health, 0, 5);

		while (notes_head != notes_tail && notes[notes_head].dead) notes_head = (notes_head + 1) % max_loaded_notes;
	}

	[MethodImpl(MethodImplOptions.AggressiveOptimization)]
	public async override void _Process(double dt) {
		if (Input.IsActionPressed("reset")) {
			if (reset_timer == -1) {
				reset_timer = (int)Time.GetTicksMsec();
			} else if ((int)Time.GetTicksMsec() - reset_timer > 500) {
				stop();
			}
		} else {
			reset_timer = -1;
		}

		if (!(playing || stopped)) return;

		if (autoplay) {
			cursor.Set("pos", autoplay_handler.Call("get_cursor_position"));
			cursor.Call("update_position");
		}

		if (is_replay) {
			Vector3 cursor_pos_data = replay_cursor_pos_data[last_replay_cursor_pos_index];

			float elapsed = audio_manager.Get("elapsed").As<float>();

			while (cursor_pos_data.Z < elapsed && last_replay_cursor_pos_index + 1 < replay_cursor_pos_data.Length) {
				last_replay_cursor_pos_index++;
				cursor_pos_data = replay_cursor_pos_data[last_replay_cursor_pos_index];
			}

			if (last_replay_cursor_pos_index + 1 >= replay_cursor_pos_data.Length) {
				if (end_replay_on_end_of_data) {
					GD.Print("we done");
					stop();
				} else {
					GD.Print("you a foreteller bro");
					pause();
					await ToSignal(GetTree().CreateTimer(0.75f), SceneTreeTimer.SignalName.Timeout);
					unpause();
				}
			}

			if (smooth_replays) {
				Vector3 previous_cursor_pos_data = replay_cursor_pos_data[Math.Max(last_replay_cursor_pos_index-1, 0)];

				float progress = elapsed - previous_cursor_pos_data.Z;
				float time_distance = cursor_pos_data.Z - previous_cursor_pos_data.Z;

				cursor.Set("pos", new Vector2(cursor_pos_data.X, cursor_pos_data.Y).Lerp(new Vector2(previous_cursor_pos_data.X, previous_cursor_pos_data.Y), progress / time_distance));
			} else {
				cursor.Set("pos", new Vector2(cursor_pos_data.X, cursor_pos_data.Y));
			}
			cursor.Call("update_position");

			check_hitreg_replay();
		} else {
			check_hitreg();
		}

		load_notes();
		check_death();

		hud.Call("update_info_right", hits, misses);
		hud.Call("update_info_bottom", health);
	}
}

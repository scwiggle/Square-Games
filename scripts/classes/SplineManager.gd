extends Node
class_name SplineManager
# class for handling spline calculations
# massive credit to Laith Hijazi (https://github.com/Gapva) who provided basically everything here

const tension: float = 0.75

static func _catmull_rom(pos_0: float, pos_1: float, pos_2: float, pos_3: float, u: float, time_0: float, time_1: float, time_2: float, time_3: float) -> float:

	var dt0: float = max(time_1 - time_0,0)
	var dt1: float = max(time_2 - time_1,0)
	var dt2: float = max(time_3 - time_2,0)

	var dt1_tension:float = dt1**tension

	var m0: float = ((pos_1 - pos_0) / (dt0**tension) * (dt1_tension)) if dt0>0.0 else 0.0
	var m1: float = ((pos_3 - pos_2) / (dt2**tension) * (dt1_tension)) if dt2>0.0 else 0.0

	var u2: float = u * u
	var u3: float = u2 * u

	return (2*u3 - 3*u2 + 1)*pos_1 + (u3 - 2*u2 + u)*m0 + (-2*u3 + 3*u2)*pos_2 + (u3 - u2)*m1

static func _catmull_rom_2(pos_0: float, pos_1: float, pos_2: float, pos_3: float, u: float, time_0: float, time_1: float, time_2: float, time_3: float) -> float:

	var dt0: float = max(time_1 - time_0,1)
	var dt1: float = max(time_2 - time_1,1)
	var dt2: float = max(time_3 - time_2,1)

	var dt1_tension:float = dt1**tension

	var m0: float = ((pos_1 - pos_0) / (dt0**tension) * (dt1_tension)) #if dt0>0.0 else 0.0
	var m1: float = ((pos_3 - pos_2) / (dt2**tension) * (dt1_tension)) #if dt2>0.0 else 0.0

	if !(is_finite(m0) and is_finite(m1)): print("{0}, {1}, {2}".format([dt0, dt1, dt2]))

	m0 = sign(m0)*abs(m0)**tension
	m1 = sign(m1)*abs(m1)**tension

	#print(m0, " ", m1)

	var u2: float = u * u
	var u3: float = u2 * u

	return (2*u3 - 3*u2 + 1)*pos_1 + (u3 - 2*u2 + u)*m0 + (-2*u3 + 3*u2)*pos_2 + (u3 - u2)*m1

static func _catmull_rom_raw(pos_0: float, pos_1: float, pos_2: float, pos_3: float, u: float, time_0: float, time_1: float, time_2: float, time_3: float) -> float:
	const spline_alpha: float = 0.4
	const spline_tension: float = -1

	var t01: float = max(abs(time_0 - time_1), 1) ** spline_alpha
	var t12: float = max(abs(time_1 - time_2), 1) ** spline_alpha
	var t23: float = max(abs(time_2 - time_3), 1) ** spline_alpha

	#(1.0f - tension) * (t2 - t1) * ((p1 - p0) / (t1 - t0) - (p2 - p0) / (t2 - t0) + (p2 - p1) / (t2 - t1));
	var m1: float = (1.0 - spline_tension) * (pos_2 - pos_1 + t12 * ((pos_1 - pos_0) / t01 - (pos_2 - pos_0) / (t01 + t12)))
	var m2: float = (1.0 - spline_tension) * (pos_2 - pos_1 + t12 * ((pos_3 - pos_2) / t23 - (pos_3 - pos_1) / (t12 + t23)))

	m1 = sign(m1)*abs(m1)**1 #smoothness?
	m2 = sign(m2)*abs(m2)**1 #smoothness?

	if !(is_finite(m1) and is_finite(m2)): print("{0}, {1}, {2}".format([t01,t12,t23]))
	if !is_finite(m1): m1 = 0
	if !is_finite(m2): m2 = 0

	var u2: float = u*u

	return (2 * (pos_1 - pos_2) + m1 + m2)*u2*u + (-3 * (pos_1 - pos_2) - m1 - m1 - m2)*u2 + (m1)*u + (pos_1)

static func _get_position(note_0: Array, note_1: Array, note_2: Array, note_3: Array, time: float) -> Vector2:
	var segment_duration: float = note_2[2] - note_1[2]
	if segment_duration <= 0: return Vector2(note_1[0],note_1[1])

	var u: float = (time - note_1[2]) / segment_duration

	return Vector2(
		_catmull_rom_raw(note_0[0], note_1[0], note_2[0], note_3[0], u, note_0[2], note_1[2], note_2[2], note_3[2]),
		_catmull_rom_raw(note_0[1], note_1[1], note_2[1], note_3[1], u, note_0[2], note_1[2], note_2[2], note_3[2])
	)

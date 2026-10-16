class_name InkAnims
extends RefCounted
## Hand-authored key poses for the ink golfer (docs/INK_ART_SPEC.md §7).
##
## A clip is {loop, len, keys: [[time, pose, ease], ...]}. `ease` shapes the motion *into* that
## key: s = smooth, i = ease in (accelerate), o = ease out (decelerate), b = overshoot, l = linear.
## Pose keys (all optional, rig units, facing +x, y down):
##   hip: Vector2 offset from the rest hip     lean: torso lean (rad, + forward)
##   bend: torso curve (+ hunches forward)     tilt: head nod relative to the neck (+ down)
##   addr: true = club gripped at address; da / dh offset that arm angle / wrist hinge
##   grip: true = club gripped; arm / hinge set the swing angles (Golfer.gd §swing)
##   hb / hf: back / front hand target relative to the shoulder (when not gripping)
##   fb / ff: back / front foot position (y < 0 lifts it); tb / tf: toe angles (+ toe down)
##   club: hands | planted | shoulder | carry | raised | none;  crot: club angle (0 = shaft down)
##   sq: vertical squash (1 = none);  expr: {eyes, mouth} expression override

const ADDRESS := {"addr": true, "lean": 0.3, "bend": 1.4, "hip": Vector2(-2.0, 0.9), "tilt": 0.34,
	"fb": Vector2(-6.8, 0), "ff": Vector2(6.2, 0)}
## Top of the backswing at full power. Aim blends ADDRESS -> TOP by shot power.
const TOP := {"grip": true, "arm": -2.45, "hinge": -1.85, "lean": 0.22, "bend": -0.6, "hip": Vector2(-3.6, 1.2), "tilt": 0.5,
	"fb": Vector2(-7.4, 0), "ff": Vector2(5.4, -0.6), "tf": 0.35, "sq": 0.985}
const IMPACT_POSE := {"addr": true, "dh": 0.08, "lean": 0.38, "bend": 1.6, "hip": Vector2(0.6, 1.4), "tilt": 0.45,
	"fb": Vector2(-6.4, -0.4), "ff": Vector2(6.4, 0), "tb": 0.25}
const FINISH := {"grip": true, "arm": 2.7, "hinge": 1.55, "lean": -0.26, "bend": 3.4, "hip": Vector2(2.8, -0.4), "tilt": -0.42,
	"fb": Vector2(-2.6, -2.6), "ff": Vector2(6.0, 0), "tb": 1.15, "sq": 1.02}

const CLIPS := {
	# Address stance: breathing comes from the procedural layer; one club waggle per cycle.
	"idle": {"loop": true, "len": 3.4, "keys": [
		[0.0, ADDRESS, "s"],
		[1.35, ADDRESS, "s"],
		[1.62, {"addr": true, "da": -0.07, "dh": 0.24, "lean": 0.34, "bend": 1.2, "hip": Vector2(-2.0, 1.4), "tilt": 0.4,
			"fb": Vector2(-6.8, 0), "ff": Vector2(6.2, 0)}, "s"],
		[1.95, {"addr": true, "da": 0.02, "dh": -0.05, "lean": 0.36, "bend": 1.2, "hip": Vector2(-2.3, 1.7), "tilt": 0.42,
			"fb": Vector2(-6.8, 0), "ff": Vector2(6.2, 0)}, "s"],
		[2.3, ADDRESS, "s"],
		[3.4, ADDRESS, "s"],
	]},
	# Glances down the fairway toward the target, then back to the ball.
	"lookaround": {"loop": false, "len": 2.4, "keys": [
		[0.0, ADDRESS, "s"],
		[0.45, {"addr": true, "dh": 0.05, "lean": 0.26, "bend": 0.6, "hip": Vector2(-2.0, 1.3), "tilt": -0.32,
			"fb": Vector2(-6.8, 0), "ff": Vector2(6.2, 0)}, "o"],
		[1.5, {"addr": true, "dh": 0.05, "lean": 0.27, "bend": 0.6, "hip": Vector2(-2.0, 1.3), "tilt": -0.26,
			"fb": Vector2(-6.8, 0), "ff": Vector2(6.2, 0)}, "s"],
		[2.4, ADDRESS, "s"],
	]},
	# Swing: the first key is replaced at runtime by the top of the backswing for the shot power.
	"swing": {"loop": false, "len": 0.78, "keys": [
		[0.0, TOP, "l"],
		[0.045, IMPACT_POSE, "i"],
		[0.13, {"grip": true, "arm": 1.15, "hinge": 0.3, "lean": 0.18, "bend": 2.6, "hip": Vector2(1.8, 0.4), "tilt": 0.05,
			"fb": Vector2(-5.2, -1.4), "ff": Vector2(6.2, 0), "tb": 0.7}, "l"],
		[0.32, FINISH, "o"],
		[0.78, {"grip": true, "arm": 2.6, "hinge": 1.62, "lean": -0.22, "bend": 3.1, "hip": Vector2(2.6, -0.2), "tilt": -0.36,
			"fb": Vector2(-2.6, -2.6), "ff": Vector2(6.0, 0), "tb": 1.15, "sq": 1.0}, "s"],
	]},
	# Holding the finish while the ball flies (head follows the ball procedurally).
	"watch": {"loop": true, "len": 3.0, "keys": [
		[0.0, {"grip": true, "arm": 2.6, "hinge": 1.62, "lean": -0.22, "bend": 3.1, "hip": Vector2(2.6, -0.2), "tilt": -0.36,
			"fb": Vector2(-2.6, -2.6), "ff": Vector2(6.0, 0), "tb": 1.15}, "s"],
		[1.5, {"grip": true, "arm": 2.52, "hinge": 1.7, "lean": -0.18, "bend": 2.8, "hip": Vector2(2.4, 0.1), "tilt": -0.32,
			"fb": Vector2(-2.6, -2.6), "ff": Vector2(6.0, 0), "tb": 1.1}, "s"],
		[3.0, {"grip": true, "arm": 2.6, "hinge": 1.62, "lean": -0.22, "bend": 3.1, "hip": Vector2(2.6, -0.2), "tilt": -0.36,
			"fb": Vector2(-2.6, -2.6), "ff": Vector2(6.0, 0), "tb": 1.15}, "s"],
	]},
	"walk": {"loop": true, "len": 0.84, "keys": [
		[0.0, {"club": "shoulder", "crot": 2.55, "lean": 0.12, "bend": 1.2, "hip": Vector2(0, 1.6), "tilt": 0.05,
			"hb": Vector2(7, 18), "hf": Vector2(5, 3), "fb": Vector2(-8.5, 0), "ff": Vector2(8.5, 0), "tf": -0.35, "sq": 0.985}, "s"],
		[0.21, {"club": "shoulder", "crot": 2.6, "lean": 0.1, "bend": 1.0, "hip": Vector2(0, -0.8), "tilt": 0.02,
			"hb": Vector2(1, 21), "hf": Vector2(5, 2), "fb": Vector2(0.5, -5.0), "ff": Vector2(0, 0), "tb": 0.5, "sq": 1.01}, "s"],
		[0.42, {"club": "shoulder", "crot": 2.55, "lean": 0.12, "bend": 1.2, "hip": Vector2(0, 1.6), "tilt": 0.05,
			"hb": Vector2(-7, 18), "hf": Vector2(5, 3), "fb": Vector2(8.5, 0), "ff": Vector2(-8.5, 0), "tb": -0.35, "sq": 0.985}, "s"],
		[0.63, {"club": "shoulder", "crot": 2.6, "lean": 0.1, "bend": 1.0, "hip": Vector2(0, -0.8), "tilt": 0.02,
			"hb": Vector2(1, 21), "hf": Vector2(5, 2), "fb": Vector2(0, 0), "ff": Vector2(0.5, -5.0), "tf": 0.5, "sq": 1.01}, "s"],
		[0.84, {"club": "shoulder", "crot": 2.55, "lean": 0.12, "bend": 1.2, "hip": Vector2(0, 1.6), "tilt": 0.05,
			"hb": Vector2(7, 18), "hf": Vector2(5, 3), "fb": Vector2(-8.5, 0), "ff": Vector2(8.5, 0), "tf": -0.35, "sq": 0.985}, "s"],
	]},
	"run": {"loop": true, "len": 0.52, "keys": [
		[0.0, {"club": "carry", "crot": 2.2, "lean": 0.42, "bend": 2.4, "hip": Vector2(1, 2.4), "tilt": -0.2,
			"hb": Vector2(-14, 8), "hf": Vector2(14, 6), "fb": Vector2(-13, -1.5), "ff": Vector2(12, 0), "tb": 0.8, "tf": -0.4, "sq": 0.97}, "s"],
		[0.13, {"club": "carry", "crot": 2.0, "lean": 0.38, "bend": 2.0, "hip": Vector2(1, -2.6), "tilt": -0.18,
			"hb": Vector2(0, 17), "hf": Vector2(4, 14), "fb": Vector2(0, -10), "ff": Vector2(-3, -1), "tb": 0.9, "sq": 1.03}, "s"],
		[0.26, {"club": "carry", "crot": 2.2, "lean": 0.42, "bend": 2.4, "hip": Vector2(1, 2.4), "tilt": -0.2,
			"hb": Vector2(14, 6), "hf": Vector2(-14, 8), "fb": Vector2(12, 0), "ff": Vector2(-13, -1.5), "tb": -0.4, "tf": 0.8, "sq": 0.97}, "s"],
		[0.39, {"club": "carry", "crot": 2.0, "lean": 0.38, "bend": 2.0, "hip": Vector2(1, -2.6), "tilt": -0.18,
			"hb": Vector2(4, 14), "hf": Vector2(0, 17), "fb": Vector2(-3, -1), "ff": Vector2(0, -10), "tf": 0.9, "sq": 1.03}, "s"],
		[0.52, {"club": "carry", "crot": 2.2, "lean": 0.42, "bend": 2.4, "hip": Vector2(1, 2.4), "tilt": -0.2,
			"hb": Vector2(-14, 8), "hf": Vector2(14, 6), "fb": Vector2(-13, -1.5), "ff": Vector2(12, 0), "tb": 0.8, "tf": -0.4, "sq": 0.97}, "s"],
	]},
	"jump": {"loop": false, "len": 0.9, "keys": [
		[0.0, {"club": "carry", "crot": 0.4, "lean": 0.08, "hb": Vector2(-4, 21), "hf": Vector2(4, 21)}, "s"],
		[0.16, {"club": "carry", "crot": 0.6, "lean": 0.35, "bend": 2.5, "hip": Vector2(-1, 7), "tilt": 0.3, "sq": 0.9,
			"hb": Vector2(-15, 10), "hf": Vector2(-12, 12), "fb": Vector2(-6, 0), "ff": Vector2(6, 0)}, "o"],
		[0.3, {"club": "carry", "crot": 2.6, "lean": -0.12, "bend": -1.5, "hip": Vector2(0, -18), "tilt": -0.3, "sq": 1.08,
			"hb": Vector2(-8, -20), "hf": Vector2(9, -21), "fb": Vector2(-4, -12), "ff": Vector2(5, -14), "tb": 0.9, "tf": 0.7}, "i"],
		[0.5, {"club": "carry", "crot": 2.4, "lean": 0.05, "bend": 1.0, "hip": Vector2(0, -24), "tilt": -0.1,
			"hb": Vector2(-14, -6), "hf": Vector2(14, -8), "fb": Vector2(-7, -16), "ff": Vector2(7, -15), "tb": 0.4, "tf": 0.4}, "o"],
		[0.72, {"club": "carry", "crot": 1.2, "lean": 0.18, "bend": 1.5, "hip": Vector2(0, -6), "tilt": 0.05, "sq": 1.02,
			"hb": Vector2(-13, 4), "hf": Vector2(12, 3), "fb": Vector2(-6, -2), "ff": Vector2(6, -1)}, "i"],
		[0.9, {"club": "carry", "crot": 0.8, "lean": 0.36, "bend": 2.6, "hip": Vector2(-1, 7), "tilt": 0.3, "sq": 0.9,
			"hb": Vector2(-12, 12), "hf": Vector2(10, 12), "fb": Vector2(-6.5, 0), "ff": Vector2(6.5, 0)}, "i"],
	]},
	"land": {"loop": false, "len": 0.45, "keys": [
		[0.0, {"club": "carry", "crot": 0.8, "lean": 0.36, "bend": 2.6, "hip": Vector2(-1, 7), "tilt": 0.3, "sq": 0.9,
			"hb": Vector2(-12, 12), "hf": Vector2(10, 12), "fb": Vector2(-6.5, 0), "ff": Vector2(6.5, 0)}, "s"],
		[0.45, {"club": "carry", "crot": 0.4, "lean": 0.08, "hip": Vector2(0, 0), "hb": Vector2(-4, 21), "hf": Vector2(4, 21)}, "b"],
	]},
	"celebrate": {"loop": true, "len": 0.9, "keys": [
		[0.0, {"club": "planted", "lean": 0.1, "bend": 1.5, "hip": Vector2(0, 3), "sq": 0.93, "tilt": 0.0,
			"hb": Vector2(-12, -14), "hf": Vector2(12, -15), "expr": {"eyes": "joy", "mouth": "open"}}, "s"],
		[0.3, {"club": "planted", "lean": -0.12, "bend": -1.5, "hip": Vector2(0, -12), "sq": 1.06, "tilt": -0.25,
			"hb": Vector2(-10, -24), "hf": Vector2(9, -25), "fb": Vector2(-6, -7), "ff": Vector2(6, -8), "tb": 0.6, "tf": 0.6,
			"expr": {"eyes": "joy", "mouth": "open"}}, "o"],
		[0.6, {"club": "planted", "lean": -0.05, "bend": 0.0, "hip": Vector2(0, -6), "sq": 1.02, "tilt": -0.15,
			"hb": Vector2(-13, -20), "hf": Vector2(12, -20), "fb": Vector2(-6, -3), "ff": Vector2(6, -3), "expr": {"eyes": "joy", "mouth": "open"}}, "i"],
		[0.9, {"club": "planted", "lean": 0.1, "bend": 1.5, "hip": Vector2(0, 3), "sq": 0.93, "tilt": 0.0,
			"hb": Vector2(-12, -14), "hf": Vector2(12, -15), "expr": {"eyes": "joy", "mouth": "open"}}, "i"],
	]},
	"victory": {"loop": true, "len": 1.2, "keys": [
		[0.0, {"club": "raised", "crot": 3.0, "lean": -0.1, "bend": -1.0, "hip": Vector2(0, 0), "tilt": -0.2,
			"hf": Vector2(4, -22), "hb": Vector2(-11, -4), "fb": Vector2(-7, 0), "ff": Vector2(7, 0), "expr": {"mouth": "grin"}}, "s"],
		[0.3, {"club": "raised", "crot": 3.3, "lean": -0.16, "bend": -1.8, "hip": Vector2(0, -2.5), "tilt": -0.3, "sq": 1.03,
			"hf": Vector2(6, -25), "hb": Vector2(-13, -10), "fb": Vector2(-7, 0), "ff": Vector2(7, 0), "expr": {"mouth": "open", "eyes": "joy"}}, "b"],
		[0.6, {"club": "raised", "crot": 3.0, "lean": -0.1, "bend": -1.0, "hip": Vector2(0, 0.5), "tilt": -0.2,
			"hf": Vector2(4, -22), "hb": Vector2(-11, -4), "fb": Vector2(-7, 0), "ff": Vector2(7, 0), "expr": {"mouth": "grin"}}, "s"],
		[0.9, {"club": "raised", "crot": 2.7, "lean": -0.14, "bend": -1.6, "hip": Vector2(0, -2.5), "tilt": -0.28, "sq": 1.03,
			"hf": Vector2(3, -25), "hb": Vector2(-13, -10), "fb": Vector2(-7, 0), "ff": Vector2(7, 0), "expr": {"mouth": "open", "eyes": "joy"}}, "b"],
		[1.2, {"club": "raised", "crot": 3.0, "lean": -0.1, "bend": -1.0, "hip": Vector2(0, 0), "tilt": -0.2,
			"hf": Vector2(4, -22), "hb": Vector2(-11, -4), "fb": Vector2(-7, 0), "ff": Vector2(7, 0), "expr": {"mouth": "grin"}}, "s"],
	]},
	"sad": {"loop": true, "len": 3.0, "keys": [
		[0.0, {"club": "carry", "crot": 0.55, "lean": 0.34, "bend": -3.5, "hip": Vector2(0, 2.2), "tilt": 0.55, "sq": 0.95,
			"hb": Vector2(-2, 22), "hf": Vector2(4, 22), "fb": Vector2(-4.5, 0), "ff": Vector2(4.5, 0), "expr": {"eyes": "sad", "mouth": "frown"}}, "s"],
		[1.5, {"club": "carry", "crot": 0.6, "lean": 0.37, "bend": -3.8, "hip": Vector2(0, 2.6), "tilt": 0.66, "sq": 0.94,
			"hb": Vector2(-2, 22.5), "hf": Vector2(4, 22.5), "fb": Vector2(-4.5, 0), "ff": Vector2(4.5, 0), "expr": {"eyes": "sad", "mouth": "frown"}}, "s"],
		[3.0, {"club": "carry", "crot": 0.55, "lean": 0.34, "bend": -3.5, "hip": Vector2(0, 2.2), "tilt": 0.55, "sq": 0.95,
			"hb": Vector2(-2, 22), "hf": Vector2(4, 22), "fb": Vector2(-4.5, 0), "ff": Vector2(4.5, 0), "expr": {"eyes": "sad", "mouth": "frown"}}, "s"],
	]},
	"disappointed": {"loop": false, "len": 1.8, "keys": [
		[0.0, ADDRESS, "s"],
		[0.22, {"club": "planted", "lean": -0.2, "bend": -1.0, "hip": Vector2(0, -1), "tilt": -0.4,
			"hb": Vector2(-6, -19), "hf": Vector2(6, -20), "expr": {"eyes": "wide", "mouth": "o"}}, "o"],
		[0.55, {"club": "planted", "lean": 0.42, "bend": -3.0, "hip": Vector2(0, 2.5), "tilt": 0.7, "sq": 0.95,
			"hb": Vector2(-3, 22), "hf": Vector2(3, 22), "expr": {"eyes": "closed", "mouth": "frown"}}, "i"],
		[1.4, {"club": "planted", "lean": 0.4, "bend": -3.0, "hip": Vector2(0, 2.2), "tilt": 0.62, "sq": 0.96,
			"hb": Vector2(-3, 22), "hf": Vector2(3, 22), "expr": {"eyes": "sad", "mouth": "frown"}}, "s"],
		[1.8, ADDRESS, "s"],
	]},
	"wave": {"loop": true, "len": 0.6, "keys": [
		[0.0, {"club": "planted", "lean": -0.04, "tilt": -0.08, "hb": Vector2(-4, 21), "hf": Vector2(12, -18), "expr": {"mouth": "open"}}, "s"],
		[0.3, {"club": "planted", "lean": -0.06, "tilt": -0.12, "hb": Vector2(-4, 21), "hf": Vector2(4, -23), "expr": {"mouth": "open"}}, "s"],
		[0.6, {"club": "planted", "lean": -0.04, "tilt": -0.08, "hb": Vector2(-4, 21), "hf": Vector2(12, -18), "expr": {"mouth": "open"}}, "s"],
	]},
	"laugh": {"loop": true, "len": 0.28, "keys": [
		[0.0, {"club": "planted", "lean": -0.3, "bend": -2.5, "hip": Vector2(-1, 1.0), "tilt": -0.4, "sq": 0.97,
			"hb": Vector2(2, 15), "hf": Vector2(7, 14), "expr": {"eyes": "joy", "mouth": "laugh"}}, "s"],
		[0.14, {"club": "planted", "lean": -0.22, "bend": -2.0, "hip": Vector2(-1, 2.0), "tilt": -0.28, "sq": 0.94,
			"hb": Vector2(3, 17), "hf": Vector2(8, 16), "expr": {"eyes": "joy", "mouth": "laugh"}}, "s"],
		[0.28, {"club": "planted", "lean": -0.3, "bend": -2.5, "hip": Vector2(-1, 1.0), "tilt": -0.4, "sq": 0.97,
			"hb": Vector2(2, 15), "hf": Vector2(7, 14), "expr": {"eyes": "joy", "mouth": "laugh"}}, "s"],
	]},
	"wow": {"loop": false, "len": 1.6, "keys": [
		[0.0, {"club": "planted", "lean": 0.05, "hb": Vector2(-4, 21), "hf": Vector2(4, 21)}, "s"],
		[0.14, {"club": "planted", "lean": -0.24, "bend": -2.0, "hip": Vector2(-3, -6), "tilt": -0.2, "sq": 1.06,
			"hb": Vector2(-12, -10), "hf": Vector2(13, -11), "fb": Vector2(-8, -3), "ff": Vector2(3, -5), "expr": {"eyes": "wide", "mouth": "o"}}, "o"],
		[0.32, {"club": "planted", "lean": -0.16, "bend": -1.2, "hip": Vector2(-3, 0.5), "tilt": -0.14,
			"hb": Vector2(-5, -12), "hf": Vector2(9, -13), "fb": Vector2(-8.5, 0), "ff": Vector2(3, 0), "expr": {"eyes": "wide", "mouth": "o"}}, "b"],
		[1.6, {"club": "planted", "lean": -0.12, "bend": -1.0, "hip": Vector2(-3, 0.5), "tilt": -0.1,
			"hb": Vector2(-5, -11), "hf": Vector2(9, -12), "fb": Vector2(-8.5, 0), "ff": Vector2(3, 0), "expr": {"eyes": "wide", "mouth": "o"}}, "s"],
	]},
	"thumbs_up": {"loop": false, "len": 1.8, "keys": [
		[0.0, {"club": "planted", "hb": Vector2(-4, 21), "hf": Vector2(4, 21)}, "s"],
		[0.25, {"club": "planted", "lean": -0.08, "tilt": -0.05, "hb": Vector2(-5, 20), "hf": Vector2(17, -4), "thumb": 1.0, "expr": {"eyes": "wink", "mouth": "grin"}}, "b"],
		[0.5, {"club": "planted", "lean": -0.06, "tilt": -0.05, "hb": Vector2(-5, 20), "hf": Vector2(17, -7), "thumb": 1.0, "expr": {"eyes": "wink", "mouth": "grin"}}, "s"],
		[1.8, {"club": "planted", "lean": -0.06, "tilt": -0.05, "hb": Vector2(-5, 20), "hf": Vector2(17, -5), "thumb": 1.0, "expr": {"eyes": "wink", "mouth": "grin"}}, "s"],
	]},
	"clap": {"loop": true, "len": 0.42, "keys": [
		[0.0, {"club": "planted", "lean": 0.06, "bend": 1.5, "hip": Vector2(0, 0.5), "hb": Vector2(9, 3), "hf": Vector2(15, 3), "expr": {"eyes": "joy", "mouth": "open"}}, "s"],
		[0.16, {"club": "planted", "lean": 0.08, "bend": 1.8, "hip": Vector2(0, 1.5), "hb": Vector2(13, 4), "hf": Vector2(14, 4), "expr": {"eyes": "joy", "mouth": "open"}}, "i"],
		[0.42, {"club": "planted", "lean": 0.06, "bend": 1.5, "hip": Vector2(0, 0.5), "hb": Vector2(9, 3), "hf": Vector2(15, 3), "expr": {"eyes": "joy", "mouth": "open"}}, "o"],
	]},
	"facepalm": {"loop": false, "len": 2.0, "keys": [
		[0.0, {"club": "planted", "hb": Vector2(-4, 21), "hf": Vector2(4, 21)}, "s"],
		[0.3, {"club": "planted", "lean": 0.22, "bend": -2.5, "tilt": 0.38, "hip": Vector2(0, 1.5), "face_hand": 1.0,
			"hb": Vector2(-2, 22), "hf": Vector2(9, -6), "expr": {"eyes": "closed", "mouth": "flat"}}, "o"],
		[1.2, {"club": "planted", "lean": 0.26, "bend": -2.8, "tilt": 0.5, "hip": Vector2(0, 1.8), "face_hand": 1.0,
			"hb": Vector2(-2, 22), "hf": Vector2(9, -6), "expr": {"eyes": "closed", "mouth": "flat"}}, "s"],
		[2.0, {"club": "planted", "lean": 0.24, "bend": -2.6, "tilt": 0.4, "hip": Vector2(0, 1.6), "face_hand": 1.0,
			"hb": Vector2(-2, 22), "hf": Vector2(9, -6), "expr": {"eyes": "closed", "mouth": "flat"}}, "s"],
	]},
	"flex": {"loop": false, "len": 1.8, "keys": [
		[0.0, {"club": "planted", "hb": Vector2(-4, 21), "hf": Vector2(4, 21)}, "s"],
		[0.22, {"club": "planted", "lean": -0.06, "bend": 2.0, "hip": Vector2(0, 2.0), "sq": 0.95, "tilt": -0.12,
			"hb": Vector2(-15, -3), "hf": Vector2(15, -4), "elbow_up": 1.0, "fb": Vector2(-9, 0), "ff": Vector2(9, 0), "expr": {"eyes": "angry", "mouth": "smirk"}}, "b"],
		[0.6, {"club": "planted", "lean": -0.04, "bend": 2.2, "hip": Vector2(0, 2.4), "sq": 0.94, "tilt": -0.1,
			"hb": Vector2(-14, -6), "hf": Vector2(14, -7), "elbow_up": 1.0, "fb": Vector2(-9, 0), "ff": Vector2(9, 0), "expr": {"eyes": "angry", "mouth": "smirk"}}, "s"],
		[1.0, {"club": "planted", "lean": -0.06, "bend": 2.0, "hip": Vector2(0, 2.0), "sq": 0.95, "tilt": -0.12,
			"hb": Vector2(-15, -3), "hf": Vector2(15, -4), "elbow_up": 1.0, "fb": Vector2(-9, 0), "ff": Vector2(9, 0), "expr": {"eyes": "angry", "mouth": "smirk"}}, "s"],
		[1.8, {"club": "planted", "lean": -0.04, "bend": 2.2, "hip": Vector2(0, 2.4), "sq": 0.94, "tilt": -0.1,
			"hb": Vector2(-14, -6), "hf": Vector2(14, -7), "elbow_up": 1.0, "fb": Vector2(-9, 0), "ff": Vector2(9, 0), "expr": {"eyes": "angry", "mouth": "smirk"}}, "s"],
	]},
	"dance": {"loop": true, "len": 0.8, "keys": [
		[0.0, {"club": "planted", "lean": 0.15, "bend": 3.0, "hip": Vector2(-3, 1.5), "tilt": 0.2,
			"hb": Vector2(-12, -20), "hf": Vector2(8, 8), "fb": Vector2(-7, 0), "ff": Vector2(8, -6), "tf": 0.6, "expr": {"eyes": "joy", "mouth": "open"}}, "s"],
		[0.2, {"club": "planted", "lean": 0.0, "bend": 0.0, "hip": Vector2(0, -2), "tilt": 0.0, "sq": 1.03,
			"hb": Vector2(-6, 4), "hf": Vector2(6, 4), "fb": Vector2(-6, 0), "ff": Vector2(6, 0), "expr": {"eyes": "joy", "mouth": "open"}}, "o"],
		[0.4, {"club": "planted", "lean": -0.15, "bend": -3.0, "hip": Vector2(3, 1.5), "tilt": -0.2,
			"hb": Vector2(-8, 8), "hf": Vector2(12, -20), "fb": Vector2(-8, -6), "ff": Vector2(7, 0), "tb": 0.6, "expr": {"eyes": "joy", "mouth": "open"}}, "s"],
		[0.6, {"club": "planted", "lean": 0.0, "bend": 0.0, "hip": Vector2(0, -2), "tilt": 0.0, "sq": 1.03,
			"hb": Vector2(-6, 4), "hf": Vector2(6, 4), "fb": Vector2(-6, 0), "ff": Vector2(6, 0), "expr": {"eyes": "joy", "mouth": "open"}}, "o"],
		[0.8, {"club": "planted", "lean": 0.15, "bend": 3.0, "hip": Vector2(-3, 1.5), "tilt": 0.2,
			"hb": Vector2(-12, -20), "hf": Vector2(8, 8), "fb": Vector2(-7, 0), "ff": Vector2(8, -6), "tf": 0.6, "expr": {"eyes": "joy", "mouth": "open"}}, "s"],
	]},
}

## Aliases: older animation names used by game code.
const ALIASES := {"defeat": "sad", "aim": "idle", "recover": "idle"}

## Clips that play once and then return to idle.
const ONE_SHOTS := ["lookaround", "disappointed", "jump", "land"]


static func has(name: String) -> bool:
	return CLIPS.has(name) or ALIASES.has(name)


static func clip(name: String) -> Dictionary:
	return CLIPS.get(ALIASES.get(name, name), CLIPS.idle)


static func ease(k: float, mode: String) -> float:
	k = clampf(k, 0.0, 1.0)
	match mode:
		"l":
			return k
		"i":
			return k * k * k
		"o":
			var u := 1.0 - k
			return 1.0 - u * u * u
		"b":
			var c := 1.9
			var u2 := k - 1.0
			return 1.0 + (c + 1.0) * u2 * u2 * u2 + c * u2 * u2
		_:
			return k * k * (3.0 - 2.0 * k)

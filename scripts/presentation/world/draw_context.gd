extends RefCounted
class_name DrawContext

const CameraRig := preload("res://scripts/presentation/camera/camera_rig.gd")

## Presentation host read for outlines, anim helpers, and tool state during sync.
var host: Node2D
## Camera rig that defined the world-view rect and iso mapping for this frame.
var cam_rig: CameraRig
## Global animation clock used for feature frames, pops, and throng clips.
var anim_time: float
## World-space rectangle expanded from the camera for visibility culling.
var view: Rect2
## True when zoom LOD should simplify throng animation without batching features.
var far_view: bool
## Primary y-sorted prop draw dicts flushed to world multimesh bands.
var draws: Array = []
## Airborne eggs and high apples drawn after the main sort pass.
var egg_front: Array = []
## Items falling into void that must sit behind cliff-facing sprites.
var void_back_draws: Array = []
## Kit-drag and placement ghosts rendered on top of sorted world props.
var drag_front: Array = []

## Constructs a draw context for the current frame and view.
static func make(
	p_host: Node2D,
	p_cam: CameraRig,
	p_time: float,
	p_view: Rect2,
	p_far: bool
) -> DrawContext:
	var ctx: DrawContext = new()
	ctx.host = p_host
	ctx.cam_rig = p_cam
	ctx.anim_time = p_time
	ctx.view = p_view
	ctx.far_view = p_far
	return ctx


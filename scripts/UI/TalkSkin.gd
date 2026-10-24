extends RefCounted
## What a character's talk box is painted with (the talk and quests spec,
## section 4, "Character skins"). TalkBox draws every skin the same way, by
## draft 28's layout; only these differ.
##
## The plain skin (plain(), every character until its paintings come) has no
## paintings at all: its backdrop is painted from noise by talk_paint, its
## portrait is the live render of the shade's head, its marker a painted spike,
## its swipes in the plain colours. A painted skin (Task 6b) sets the textures
## and where on its backdrop the swipes take their paint from.

## The panel's painting (cropped, scaled only down), or null: painted from noise.
var backdrop: Texture2D = null
## The speaker, painted, or null: the live render.
var portrait: Texture2D = null
## The chosen swipe's marker (keyed), or null: a painted spike.
var cursor: Texture2D = null
## Where the cursor's tip is, down its height (0..1).
var cursor_tip := 0.685

## The plain skin's panel shape (draft 28's backdrop crop, 1802 x 1050) and
## its portrait's (width over height).
var backdrop_aspect := 1802.0 / 1050.0
var portrait_aspect := 320.0 / 470.0

## The swipes' paint: rects of the backdrop in UV (an unchosen swipe's dim
## flank, the chosen one's warm gold), used when there is a backdrop.
var dark_region := Rect2()
var warm_region := Rect2()
## The plain skin's swipe colours: dim purple, and the gold before its wash.
var paint_dark := Color(0.5, 0.38, 0.46)
var paint_warm := Color(0.62, 0.48, 0.26)

## The reading pool under the words: an ellipse's box in fractions of the
## panel (draft 28: x 60..940 of 1000, y -25%..92%).
var pool := Rect2(0.06, -0.25, 0.88, 1.17)
var pool_strength := 200.0 / 255.0


## Every character's, until its paintings come.
static func plain():
	return new()


## The panel's width over its height.
func panel_aspect() -> float:
	return float(backdrop.get_width()) / float(backdrop.get_height()) if backdrop != null else backdrop_aspect


## The portrait's width over its height.
func face_aspect() -> float:
	return float(portrait.get_width()) / float(portrait.get_height()) if portrait != null else portrait_aspect

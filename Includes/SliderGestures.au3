; SliderGestures 0.1.16
; Native gain-slider selection, group movement and horizontal curve drawing.
#include-once
#include <WinAPIConstants.au3>
#include <WinAPISys.au3>
#include <WinAPIGdi.au3>

global const $SLIDER_GESTURE_MOUSE_STRUCT = "long X;long Y;hwnd Window;uint HitTest;ulong_ptr Extra"
global const $SLIDER_GESTURE_IDLE = 0, $SLIDER_GESTURE_SELECT = 1, $SLIDER_GESTURE_SINGLE = 2, $SLIDER_GESTURE_GROUP = 3
global const $SLIDER_GESTURE_BLUE = 0xB8DDF8
global const $SLIDER_GESTURE_ALPHA = 70
global const $SLIDER_GESTURE_HOOK_ACTION = 0
global const $SLIDER_GESTURE_RAIL_HALF_WIDTH = 5
global const $SLIDER_MARK_LENGTH = 5
global const $SLIDER_MARK_DRAW_STRUCT = $tagNMHDR & ";dword DrawStage;handle HDC;" & $tagRECT & ";ulong_ptr ItemSpec;uint ItemState;lparam ItemParam"
global const $SLIDER_GESTURE_HINT = "Click a slider rail to set its gain. Drag between sliders to select handles. Drag a selected handle to move the group. Drag one handle sideways to draw."
global $slider_gesture_callback = 0, $slider_gesture_pointer = 0, $slider_gesture_overlay = 0, $slider_gesture_default_bg = 0
global $slider_gesture_hook = 0, $slider_gesture_handles[$MAX_PARAM_BANDS]
global $slider_gesture_labels[$MAX_PARAM_BANDS], $slider_gesture_tooltips_dirty[$MAX_PARAM_BANDS]
global $slider_gesture_state = $SLIDER_GESTURE_IDLE, $slider_gesture_active = -1
global $slider_gesture_start_x = 0, $slider_gesture_start_y = 0, $slider_gesture_mouse_offset = 0
global $slider_gesture_selected[$MAX_PARAM_BANDS], $slider_gesture_base[$MAX_PARAM_BANDS], $slider_gesture_bounds[$MAX_PARAM_BANDS][6]

; Enable native mouse interception without replacing the existing sliders.
; Reads $main_gui, creates one hidden translucent selection rectangle and a
; mouse hook on this GUI thread, and restores the main control parent.
; Called once after control creation, before the first grid build; no return.
func InitializeSliderGestures()
	$slider_gesture_default_bg = _WinAPI_GetSysColor($COLOR_BTNFACE)
	$slider_gesture_callback = DllCallbackRegister("SliderGestureProc", "lresult", "int;wparam;lparam")
	$slider_gesture_pointer = DllCallbackGetPtr($slider_gesture_callback)
	local $gesture_thread = DllCall("kernel32.dll", "dword", "GetCurrentThreadId")
	$slider_gesture_hook = _WinAPI_SetWindowsHookEx($WH_MOUSE, $slider_gesture_pointer, 0, $gesture_thread[0])
	if not $slider_gesture_hook then
		GUICtrlSetData($status_label, "Could not enable slider mouse gestures.")
		return
	endif
	GUIRegisterMsg($WM_CANCELMODE, "OnSliderGestureCancel")
	GUIRegisterMsg($WM_CAPTURECHANGED, "OnSliderGestureCancel")
	GUIRegisterMsg($WM_ACTIVATEAPP, "OnSliderGestureCancel")
	$slider_gesture_overlay = GUICreate("", 1, 1, 0, 0, $WS_POPUP, BitOR($WS_EX_LAYERED, $WS_EX_TRANSPARENT, $WS_EX_NOACTIVATE, $WS_EX_TOOLWINDOW), $main_gui)
	GUISetBkColor($SLIDER_GESTURE_BLUE, $slider_gesture_overlay)
	WinSetTrans($slider_gesture_overlay, "", $SLIDER_GESTURE_ALPHA)
	GUISwitch($main_gui)
endfunc

; Cache each native thumb's actual travel after layout, including DPI sizing.
; Reads the current slider controls and range. Measures both extreme thumb
; positions without redraw or notifications, then restores each position.
; Writes parent-client rectangles and top/bottom thumb centres; no return.
func CacheSliderGestureGeometry()
	for $gesture_index = 0 to $ctrl_count - 1
		$slider_gesture_handles[$gesture_index] = GUICtrlGetHandle($gain_ctrl[$gesture_index])
		$slider_gesture_labels[$gesture_index] = GUICtrlGetHandle($gain_value[$gesture_index])
		local $gesture_rect = ControlGetPos($main_gui, "", GUICtrlGetHandle($gain_ctrl[$gesture_index]))
		if @error then continueloop
		for $gesture_axis = 0 to 3
			$slider_gesture_bounds[$gesture_index][$gesture_axis] = $gesture_rect[$gesture_axis]
		next
		local $gesture_position = GUICtrlSendMsg($gain_ctrl[$gesture_index], $TBM_GETPOS, 0, 0)
		local $gesture_thumb = DllStructCreate($tagRECT)
		GUICtrlSendMsg($gain_ctrl[$gesture_index], $WM_SETREDRAW, false, 0)
		GUICtrlSendMsg($gain_ctrl[$gesture_index], $TBM_SETPOS, true, -$range_db * 2)
		GUICtrlSendMsg($gain_ctrl[$gesture_index], $TBM_GETTHUMBRECT, 0, DllStructGetPtr($gesture_thumb))
		$slider_gesture_bounds[$gesture_index][4] = $gesture_rect[1] + (DllStructGetData($gesture_thumb, "Top") + DllStructGetData($gesture_thumb, "Bottom")) / 2
		GUICtrlSendMsg($gain_ctrl[$gesture_index], $TBM_SETPOS, true, $range_db * 2)
		GUICtrlSendMsg($gain_ctrl[$gesture_index], $TBM_GETTHUMBRECT, 0, DllStructGetPtr($gesture_thumb))
		$slider_gesture_bounds[$gesture_index][5] = $gesture_rect[1] + (DllStructGetData($gesture_thumb, "Top") + DllStructGetData($gesture_thumb, "Bottom")) / 2
		GUICtrlSendMsg($gain_ctrl[$gesture_index], $TBM_SETPOS, true, $gesture_position)
		GUICtrlSendMsg($gain_ctrl[$gesture_index], $WM_SETREDRAW, true, 0)
		_WinAPI_InvalidateRect($slider_gesture_handles[$gesture_index], 0, false)
	next
endfunc

; Mark a band's membership visibly without changing its frequency or gain.
; Reads the band index, selected flag and control IDs. Updates backgrounds
; only when membership changes. Called during selection and drag start.
; Returns no value; selection is editor-only and is never saved to the INI.
func SelectSliderBand($gesture_index, $gesture_selected)
	if $slider_gesture_selected[$gesture_index] = $gesture_selected then return
	$slider_gesture_selected[$gesture_index] = $gesture_selected
	local $gesture_colour = $slider_gesture_default_bg
	if $gesture_selected then $gesture_colour = $SLIDER_GESTURE_BLUE
	GUICtrlSetBkColor($gain_ctrl[$gesture_index], $gesture_colour)
	GUICtrlSetBkColor($gain_value[$gesture_index], $gesture_colour)
endfunc

; Clear all highlighted gain sliders without changing their gains or capture.
; Reads the populated control count and selection flags. Reuses the existing
; per-band highlight update. Called for clicks outside the slider grid and
; after Flat has used its selection. Returns no value; writes no settings.
func ClearSliderGestureSelection()
	for $gesture_row = 0 to $ctrl_count - 1
		SelectSliderBand($gesture_row, false)
	next
endfunc

; Map a parent-client mouse height to the native slider's half-dB gain.
; Reads cached thumb travel and range. Returns a clamped gain from -range
; to +range, or the existing gain if the measured travel is zero.
func SliderGestureGainAtY($gesture_index, $gesture_y)
	local $gesture_top = $slider_gesture_bounds[$gesture_index][4], $gesture_bottom = $slider_gesture_bounds[$gesture_index][5]
	if $gesture_bottom <= $gesture_top then return $band_gain[$gesture_index]
	local $gesture_gain = Round(($range_db - ($gesture_y - $gesture_top) * 2 * $range_db / ($gesture_bottom - $gesture_top)) * 2) / 2
	if $gesture_gain > $range_db then $gesture_gain = $range_db
	if $gesture_gain < -$range_db then $gesture_gain = -$range_db
	return $gesture_gain
endfunc

; Apply one mouse-driven gain without rebuilding tooltips during a drag.
; Reads band gain and the new half-dB value. Updates its control, label and
; deferred tooltip flag; marks EQ dirty only when the value differs. Native
; messages update cached control handles immediately. Returns no value.
func SetSliderGestureGain($gesture_index, $gesture_gain)
	if $band_gain[$gesture_index] = $gesture_gain then return
	RecordSliderUndo()
	$band_gain[$gesture_index] = $gesture_gain
	_SendMessage($slider_gesture_handles[$gesture_index], $TBM_SETPOS, true, -Int($gesture_gain * 2))
	_WinAPI_SetWindowText($slider_gesture_labels[$gesture_index], StringFormat("%.1f", $gesture_gain))
	$slider_gesture_tooltips_dirty[$gesture_index] = true
	$dirty = true
endfunc

; Refresh changed tooltips after dragging without a large release-time pause.
; Reads pending flags and gesture state, refreshes one existing band through
; RefreshBandGain per editor loop while idle, and clears its pending flag.
; Called before the response redraw. Returns no value; writes no settings.
func RefreshSliderGestureTooltips()
	if $slider_gesture_state <> $SLIDER_GESTURE_IDLE then return
	for $gesture_row = 0 to $ctrl_count - 1
		if not $slider_gesture_tooltips_dirty[$gesture_row] then continueloop
		$slider_gesture_tooltips_dirty[$gesture_row] = false
		RefreshBandGain($gesture_row)
		return
	next
endfunc

; Set a clicked slider gain or start dragging thumbs or selecting bands.
; Receives parent-client coordinates and a slider index, -1 for background.
; Reads native thumb bounds, selection and gains. Rail presses select only
; that band and set its gain at the pointer; thumb presses retain the grab
; offset and selected group. Rail clicks use a ten-pixel strip centred on
; the thumb; space beside it starts rectangle selection like background.
; Captures mouse to the main GUI. Returns false outside the slider grid,
; true when a gesture starts. Gain changes use the existing autosave path.
func BeginSliderGesture($gesture_x, $gesture_y, $gesture_index)
	if $ctrl_count < 1 then return false
	local $gesture_grid_left = $GRP_BAND_X, $gesture_grid_right = $GRP_BAND_X + $ctrl_count * $BAND_CW
	if $gesture_x < $gesture_grid_left or $gesture_x >= $gesture_grid_right then return false
	if $gesture_y < $slider_gesture_bounds[0][1] or $gesture_y >= $slider_gesture_bounds[0][1] + $slider_gesture_bounds[0][3] then return false
	$slider_gesture_start_x = $gesture_x
	$slider_gesture_start_y = $gesture_y
	local $gesture_on_thumb = false, $gesture_thumb_centre = 0
	if $gesture_index >= 0 then
		local $gesture_thumb = DllStructCreate($tagRECT)
		GUICtrlSendMsg($gain_ctrl[$gesture_index], $TBM_GETTHUMBRECT, 0, DllStructGetPtr($gesture_thumb))
		local $gesture_local_x = $gesture_x - $slider_gesture_bounds[$gesture_index][0]
		local $gesture_local_y = $gesture_y - $slider_gesture_bounds[$gesture_index][1]
		$gesture_on_thumb = $gesture_local_x >= DllStructGetData($gesture_thumb, "Left") and $gesture_local_x < DllStructGetData($gesture_thumb, "Right") and _
			$gesture_local_y >= DllStructGetData($gesture_thumb, "Top") and $gesture_local_y < DllStructGetData($gesture_thumb, "Bottom")
		$gesture_thumb_centre = $slider_gesture_bounds[$gesture_index][1] + (DllStructGetData($gesture_thumb, "Top") + DllStructGetData($gesture_thumb, "Bottom")) / 2
		local $gesture_rail_centre = (DllStructGetData($gesture_thumb, "Left") + DllStructGetData($gesture_thumb, "Right")) / 2
		if not $gesture_on_thumb and ($gesture_local_x < $gesture_rail_centre - $SLIDER_GESTURE_RAIL_HALF_WIDTH or $gesture_local_x >= $gesture_rail_centre + $SLIDER_GESTURE_RAIL_HALF_WIDTH) then $gesture_index = -1
		endif
	if $gesture_index >= 0 and not $gesture_on_thumb then
		ClearSliderGestureSelection()
		SetSliderGestureGain($gesture_index, SliderGestureGainAtY($gesture_index, $gesture_y))
		$gesture_thumb_centre = $gesture_y
	endif
	if $gesture_index >= 0 then
		_WinAPI_SetFocus($slider_gesture_handles[$gesture_index])
		if not $slider_gesture_selected[$gesture_index] then
			for $gesture_row = 0 to $ctrl_count - 1
				SelectSliderBand($gesture_row, $gesture_row = $gesture_index)
			next
		endif
		local $gesture_count = 0
		for $gesture_row = 0 to $ctrl_count - 1
			$slider_gesture_base[$gesture_row] = $band_gain[$gesture_row]
			if $slider_gesture_selected[$gesture_row] then $gesture_count += 1
		next
		$slider_gesture_state = $SLIDER_GESTURE_SINGLE
		if $gesture_count > 1 then $slider_gesture_state = $SLIDER_GESTURE_GROUP
		$slider_gesture_active = $gesture_index
		$slider_gesture_mouse_offset = $gesture_y - $gesture_thumb_centre
	else
		$slider_gesture_state = $SLIDER_GESTURE_SELECT
		for $gesture_row = 0 to $ctrl_count - 1
			SelectSliderBand($gesture_row, false)
		next
	endif
	_WinAPI_SetCapture($main_gui)
	return true
endfunc

; Update a captured rectangle, group movement or horizontal drawing gesture.
; Receives parent-client mouse coordinates. Selection encloses thumb centres.
; A group keeps its gain offsets and stops as one at the range boundary.
; A single drag switches at column boundaries, retaining previous gains;
; crossed columns receive the current mouse height. Outside the horizontal
; grid, single drags clear the highlight and leave gains unchanged until
; reentry. Returns no value.
func MoveSliderGesture($gesture_x, $gesture_y)
	if $slider_gesture_state = $SLIDER_GESTURE_IDLE then return
	if $slider_gesture_state = $SLIDER_GESTURE_SELECT then
		local $gesture_left = $slider_gesture_start_x, $gesture_right = $gesture_x
		local $gesture_top = $slider_gesture_start_y, $gesture_bottom = $gesture_y
		if $gesture_left > $gesture_right then
			$gesture_left = $gesture_x
			$gesture_right = $slider_gesture_start_x
		endif
		if $gesture_top > $gesture_bottom then
			$gesture_top = $gesture_y
			$gesture_bottom = $slider_gesture_start_y
		endif
		if $gesture_left < $GRP_BAND_X then $gesture_left = $GRP_BAND_X
		if $gesture_right > $GRP_BAND_X + $ctrl_count * $BAND_CW then $gesture_right = $GRP_BAND_X + $ctrl_count * $BAND_CW
		if $gesture_top < $slider_gesture_bounds[0][1] then $gesture_top = $slider_gesture_bounds[0][1]
		if $gesture_bottom > $slider_gesture_bounds[0][1] + $slider_gesture_bounds[0][3] then $gesture_bottom = $slider_gesture_bounds[0][1] + $slider_gesture_bounds[0][3]
		local $gesture_origin = DllStructCreate($tagPOINT)
		_WinAPI_ClientToScreen($main_gui, $gesture_origin)
		if $gesture_right > $gesture_left and $gesture_bottom > $gesture_top then
			local $gesture_flags = $SWP_NOACTIVATE
			if WinActive($main_gui) then $gesture_flags = BitOR($gesture_flags, $SWP_SHOWWINDOW)
			_WinAPI_SetWindowPos($slider_gesture_overlay, $HWND_TOP, DllStructGetData($gesture_origin, "X") + $gesture_left, _
				DllStructGetData($gesture_origin, "Y") + $gesture_top, $gesture_right - $gesture_left, $gesture_bottom - $gesture_top, $gesture_flags)
		else
			_WinAPI_ShowWindow($slider_gesture_overlay, @SW_HIDE)
		endif
		for $gesture_row = 0 to $ctrl_count - 1
			local $gesture_centre_x = $slider_gesture_bounds[$gesture_row][0] + $slider_gesture_bounds[$gesture_row][2] / 2
			local $gesture_position = -GUICtrlRead($gain_ctrl[$gesture_row]) / 2
			local $gesture_centre_y = $slider_gesture_bounds[$gesture_row][4] + ($range_db - $gesture_position) / (2 * $range_db) * _
				($slider_gesture_bounds[$gesture_row][5] - $slider_gesture_bounds[$gesture_row][4])
			SelectSliderBand($gesture_row, $gesture_centre_x >= $gesture_left and $gesture_centre_x <= $gesture_right and _
				$gesture_centre_y >= $gesture_top and $gesture_centre_y <= $gesture_bottom)
		next
		return
	endif
	if $slider_gesture_state = $SLIDER_GESTURE_GROUP then
		local $gesture_delta = SliderGestureGainAtY($slider_gesture_active, $gesture_y - $slider_gesture_mouse_offset) - $slider_gesture_base[$slider_gesture_active]
		local $gesture_min_delta = -2 * $range_db, $gesture_max_delta = 2 * $range_db
		for $gesture_row = 0 to $ctrl_count - 1
			if not $slider_gesture_selected[$gesture_row] then continueloop
			if -$range_db - $slider_gesture_base[$gesture_row] > $gesture_min_delta then $gesture_min_delta = -$range_db - $slider_gesture_base[$gesture_row]
			if $range_db - $slider_gesture_base[$gesture_row] < $gesture_max_delta then $gesture_max_delta = $range_db - $slider_gesture_base[$gesture_row]
		next
		if $gesture_delta < $gesture_min_delta then $gesture_delta = $gesture_min_delta
		if $gesture_delta > $gesture_max_delta then $gesture_delta = $gesture_max_delta
		for $gesture_row = 0 to $ctrl_count - 1
			if $slider_gesture_selected[$gesture_row] then SetSliderGestureGain($gesture_row, $slider_gesture_base[$gesture_row] + $gesture_delta)
		next
		return
	endif
	if $gesture_x < $GRP_BAND_X or $gesture_x >= $GRP_BAND_X + $ctrl_count * $BAND_CW then
		SelectSliderBand($slider_gesture_active, false)
		return
	endif
	local $gesture_next = Int(($gesture_x - $GRP_BAND_X) / $BAND_CW)
	if $gesture_next < 0 then $gesture_next = 0
	if $gesture_next >= $ctrl_count then $gesture_next = $ctrl_count - 1
	if $gesture_next <> $slider_gesture_active then
		local $gesture_direction = 1
		if $gesture_next < $slider_gesture_active then $gesture_direction = -1
		SelectSliderBand($slider_gesture_active, false)
		for $gesture_row = $slider_gesture_active + $gesture_direction to $gesture_next step $gesture_direction
			SetSliderGestureGain($gesture_row, SliderGestureGainAtY($gesture_row, $gesture_y))
		next
		$slider_gesture_active = $gesture_next
		$slider_gesture_mouse_offset = 0
		SelectSliderBand($gesture_next, true)
	else
		SelectSliderBand($gesture_next, true)
		SetSliderGestureGain($gesture_next, SliderGestureGainAtY($gesture_next, $gesture_y - $slider_gesture_mouse_offset))
	endif
endfunc

; End mouse capture and hide the rectangle without changing any band gains.
; Reads gesture state, overlay and main GUI. Selection remains highlighted.
; Called on release, cancellation, deactivation and grid replacement.
; Returns no value; state clears before releasing capture to avoid reentry.
func EndSliderGesture()
	EndFrequencyDrag()
	FinishSliderUndoAction()
	$slider_gesture_state = $SLIDER_GESTURE_IDLE
	$slider_gesture_active = -1
	if $slider_gesture_overlay then _WinAPI_ShowWindow($slider_gesture_overlay, @SW_HIDE)
	if _WinAPI_GetCapture() = $main_gui then _WinAPI_ReleaseCapture()
endfunc

; Cancel a gesture when capture or application activation is lost.
; Reads the GUI message and parameters, ends capture without reverting gains,
; and returns GUI_RUNDEFMSG so native window processing continues.
func OnSliderGestureCancel($gesture_window, $gesture_message, $gesture_wparam, $gesture_lparam)
	#forceref $gesture_window, $gesture_lparam
	if $gesture_message = $WM_CANCELMODE or $gesture_message = $WM_CAPTURECHANGED or ($gesture_message = $WM_ACTIVATEAPP and not $gesture_wparam) then
		EndSliderGesture()
	endif
	return $GUI_RUNDEFMSG
endfunc

; Route this GUI thread's mouse messages into the shared gesture controller.
; Reads MOUSEHOOKSTRUCT screen coordinates and target HWND. Consumes only
; slider gestures, including selection on background labels, returning 1;
; passes all other mouse messages to the next
; hook. No global mouse hook or mouse-position polling is installed.
func SliderGestureProc($gesture_code, $gesture_message, $gesture_lparam)
	if $gesture_code = $SLIDER_GESTURE_HOOK_ACTION and ($gesture_message = $WM_LBUTTONDOWN or $gesture_message = $WM_MOUSEMOVE or $gesture_message = $WM_LBUTTONUP) then
		local $gesture_mouse = DllStructCreate($SLIDER_GESTURE_MOUSE_STRUCT, $gesture_lparam)
		local $gesture_window = DllStructGetData($gesture_mouse, "Window"), $gesture_index = -1
		if FrequencyDragMouse($gesture_message, $gesture_window, DllStructGetData($gesture_mouse, "X")) then return 1
		if $gesture_message = $WM_LBUTTONDOWN then
			FinishSliderUndoAction()
			for $gesture_row = 0 to $ctrl_count - 1
				if $gesture_window = $slider_gesture_handles[$gesture_row] then
					$gesture_index = $gesture_row
					exitloop
				endif
			next
			if $gesture_window <> $main_gui and $gesture_window <> GUICtrlGetHandle($window_drag_top) and $gesture_window <> GUICtrlGetHandle($window_drag_bottom) and $gesture_index = -1 then
				if $gesture_window <> GUICtrlGetHandle($flat_button) then ClearSliderGestureSelection()
				return _WinAPI_CallNextHookEx($slider_gesture_hook, $gesture_code, $gesture_message, $gesture_lparam)
			endif
		elseif $slider_gesture_state = $SLIDER_GESTURE_IDLE then
			return _WinAPI_CallNextHookEx($slider_gesture_hook, $gesture_code, $gesture_message, $gesture_lparam)
		endif
		local $gesture_point = DllStructCreate($tagPOINT)
		DllStructSetData($gesture_point, "X", DllStructGetData($gesture_mouse, "X"))
		DllStructSetData($gesture_point, "Y", DllStructGetData($gesture_mouse, "Y"))
		_WinAPI_ScreenToClient($main_gui, $gesture_point)
		local $gesture_x = DllStructGetData($gesture_point, "X"), $gesture_y = DllStructGetData($gesture_point, "Y")
		if $gesture_message = $WM_LBUTTONDOWN then
			if BeginSliderGesture($gesture_x, $gesture_y, $gesture_index) then return 1
			ClearSliderGestureSelection()
		elseif $slider_gesture_state <> $SLIDER_GESTURE_IDLE then
			MoveSliderGesture($gesture_x, $gesture_y)
			if $gesture_message = $WM_LBUTTONUP then EndSliderGesture()
			return 1
		endif
	endif
	return _WinAPI_CallNextHookEx($slider_gesture_hook, $gesture_code, $gesture_message, $gesture_lparam)
endfunc

; Distinguishes boost, cut and zero on each vertical gain slider.
; Reads native custom-draw notifications and cached slider bounds. Draws a
; plus at maximum gain, minus at minimum gain and a short zero-gain notch.
; Requests item and final-paint notifications at prepaint. Skips native
; ticks at item prepaint and draws + and - marks at final postpaint,
; after Windows draws the slider. Returns CDRF_DODEFAULT after drawing, and
; GUI_RUNDEFMSG for unrelated notifications. Reads no EQ settings and writes
; none; Windows draws the rail and thumb. Called for native slider repaints.
func OnSliderMarksDraw($marks_window, $marks_message, $marks_wparam, $marks_lparam)
	#forceref $marks_window, $marks_message, $marks_wparam
	local $marks_header = DllStructCreate($tagNMHDR, $marks_lparam)
	if DllStructGetData($marks_header, "Code") <> $NM_CUSTOMDRAW then return $GUI_RUNDEFMSG
	local $marks_index = -1
	for $marks_row = 0 to $ctrl_count - 1
		if DllStructGetData($marks_header, "hWndFrom") = $slider_gesture_handles[$marks_row] then
			$marks_index = $marks_row
			exitloop
		endif
	next
	if $marks_index < 0 then return $GUI_RUNDEFMSG
	local $marks_draw = DllStructCreate($SLIDER_MARK_DRAW_STRUCT, $marks_lparam)
	local $marks_stage = DllStructGetData($marks_draw, "DrawStage")
	if $marks_stage = $CDDS_PREPAINT then return BitOR($CDRF_NOTIFYITEMDRAW, $CDRF_NOTIFYPOSTPAINT)
	if $marks_stage = $CDDS_ITEMPREPAINT and DllStructGetData($marks_draw, "ItemSpec") = $TBCD_TICS then return $CDRF_SKIPDEFAULT
	if $marks_stage <> $CDDS_POSTPAINT then return $CDRF_DODEFAULT
	local $marks_top = Int($slider_gesture_bounds[$marks_index][4] - $slider_gesture_bounds[$marks_index][1])
	local $marks_bottom = Int($slider_gesture_bounds[$marks_index][5] - $slider_gesture_bounds[$marks_index][1])
	if $marks_bottom <= $marks_top then return $CDRF_DODEFAULT
	local $marks_left = $slider_gesture_bounds[$marks_index][2] - $SLIDER_MARK_LENGTH - 1
	local $marks_right = $marks_left + $SLIDER_MARK_LENGTH
	local $marks_centre_x = $marks_left + Int($SLIDER_MARK_LENGTH / 2)
	local $marks_dc = DllStructGetData($marks_draw, "HDC")
	local $marks_pen = _WinAPI_CreatePen($PS_SOLID, 1, _WinAPI_GetSysColor($COLOR_GRAYTEXT))
	local $marks_old_pen = _WinAPI_SelectObject($marks_dc, $marks_pen)
	_WinAPI_DrawLine($marks_dc, $marks_left, $marks_top, $marks_right, $marks_top)
	_WinAPI_DrawLine($marks_dc, $marks_centre_x, $marks_top - Int($SLIDER_MARK_LENGTH / 2), $marks_centre_x, $marks_top + Int($SLIDER_MARK_LENGTH / 2) + 1)
	_WinAPI_DrawLine($marks_dc, $marks_left, $marks_bottom, $marks_right, $marks_bottom)
	_WinAPI_SelectObject($marks_dc, $marks_old_pen)
	_WinAPI_DeleteObject($marks_pen)
	return $CDRF_DODEFAULT
endfunc

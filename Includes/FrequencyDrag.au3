; FrequencyDrag 0.1.1
; Drag Parametric band frequencies with reusable thumb-only controls.
#include-once
#include <GuiMenu.au3>
#include <Math.au3>
#include <WinAPIvkeysConstants.au3>

global const $FREQUENCY_DRAG_CONTROL_DOWN = 0x8000
global const $FREQUENCY_DELETE_COMMAND = 1, $FREQUENCY_MENU_RETURN_COMMAND = 2
global $frequency_thumb_ctrl[$MAX_PARAM_BANDS], $frequency_thumb_handles[$MAX_PARAM_BANDS]
global $frequency_column_left[$MAX_PARAM_BANDS], $frequency_drag_anchors[$MAX_PARAM_BANDS]
global $frequency_drag_active = -1, $frequency_drag_grab_offset = 0, $frequency_drag_last_x = 0
global $frequency_delete_visible = false, $frequency_delete_pending = -1, $frequency_delete_menu = 0

; Creates one shared Delete this band command for every frequency thumb.
; Called once for the main GUI. Stores a native popup menu handle; the
; context-menu handler identifies the band in a loop. Returns no value.
func InitializeFrequencyDrag()
	$frequency_delete_menu = _GUICtrlMenu_CreatePopup()
	_GUICtrlMenu_AddMenuItem($frequency_delete_menu, "Delete this band", $FREQUENCY_DELETE_COMMAND)
endfunc

; Shows Del while Ctrl is held, or the frequency thumb otherwise.
; Reads native Ctrl state and band controls. Does not replace controls or
; change visibility during a frequency drag. Called each main-loop pass and
; after a grid rebuild; force refreshes newly created controls. No return.
func UpdateFrequencyDragModifiers($frequency_force=false)
	if $frequency_drag_active >= 0 then return
	local $frequency_pressed = BitAND(_WinAPI_GetAsyncKeyState($VK_CONTROL), $FREQUENCY_DRAG_CONTROL_DOWN) <> 0
	if not $frequency_force and $frequency_pressed = $frequency_delete_visible then return
	$frequency_delete_visible = $frequency_pressed
	for $frequency_row = 0 to $ctrl_count - 1
		if $frequency_thumb_ctrl[$frequency_row] = 0 then continueloop
		local $frequency_thumb_state = $GUI_SHOW, $frequency_delete_state = $GUI_HIDE
		if $frequency_pressed then
			$frequency_thumb_state = $GUI_HIDE
			$frequency_delete_state = $GUI_SHOW
		endif
		GUICtrlSetState($frequency_thumb_ctrl[$frequency_row], $frequency_thumb_state)
		GUICtrlSetState($remove_ctrl[$frequency_row], $frequency_delete_state)
	next
endfunc

; Routes left-button thumb dragging through the existing thread mouse hook.
; Receives the native mouse message, target HWND and screen X coordinate.
; Returns true for a frequency press/drag/release, false for other targets.
; Mouse capture sends subsequent movement to the main GUI; no mouse polling.
func FrequencyDragMouse($frequency_message, $frequency_window, $frequency_screen_x)
	local $frequency_point = 0
	if $frequency_message = $WM_LBUTTONDOWN then
		for $frequency_row = 0 to $ctrl_count - 1
			if $frequency_thumb_handles[$frequency_row] <> $frequency_window then continueloop
			if $frequency_delete_visible then return false
			$frequency_point = DllStructCreate($tagPOINT)
			DllStructSetData($frequency_point, "X", $frequency_screen_x)
			_WinAPI_ScreenToClient($main_gui, $frequency_point)
			BeginFrequencyDrag($frequency_row, DllStructGetData($frequency_point, "X"))
			return true
		next
	elseif $frequency_drag_active >= 0 then
		if $frequency_message = $WM_MOUSEMOVE then
			$frequency_point = DllStructCreate($tagPOINT)
			DllStructSetData($frequency_point, "X", $frequency_screen_x)
			_WinAPI_ScreenToClient($main_gui, $frequency_point)
			MoveFrequencyDrag(DllStructGetData($frequency_point, "X"))
		elseif $frequency_message = $WM_LBUTTONUP then
			EndFrequencyDrag()
		endif
		return true
	endif
	return false
endfunc

; Starts dragging one band without changing its frequency or undo slot.
; Reads current frequencies and pending inputs. Invalid inputs return false.
; Otherwise sorts bands together with their controls, retains the grabbed
; control's identity, selects it, captures the mouse and returns true.
func BeginFrequencyDrag($frequency_index, $frequency_x)
	if $preset_mode <> $MODE_PARAMETRIC or not ReadParamBoxes() then return false
	EndSliderGesture()
	local $frequency_control = $frequency_thumb_ctrl[$frequency_index]
	for $frequency_row = 1 to $band_count - 1
		local $frequency_sort = $frequency_row
		while $frequency_sort > 0
			if $band_freq[$frequency_sort - 1] <= $band_freq[$frequency_sort] then exitloop
			SwapFrequencyBands($frequency_sort - 1, $frequency_sort)
			$frequency_sort -= 1
		wend
	next
	for $frequency_row = 0 to $band_count - 1
		MoveFrequencyBandControls($frequency_row, $GRP_BAND_PX + $frequency_row * $BAND_CW)
		if $frequency_thumb_ctrl[$frequency_row] = $frequency_control then $frequency_index = $frequency_row
	next
	$frequency_drag_anchors = $band_freq
	$frequency_drag_active = $frequency_index
	$frequency_drag_grab_offset = $frequency_x - ($GRP_BAND_PX + ($frequency_index + 0.5) * $BAND_CW)
	$frequency_drag_last_x = $frequency_x
	for $frequency_row = 0 to $band_count - 1
		SelectSliderBand($frequency_row, $frequency_row = $frequency_index)
	next
	_WinAPI_SetFocus($frequency_thumb_handles[$frequency_index])
	_WinAPI_SetCapture($main_gui)
	WinSetTitle($main_gui, "", $APP_NAME & "        " & String($band_freq[$frequency_index]) & " Hz")
	return true
endfunc

; Maps pointer position to Hz using the frequencies at drag start as anchors.
; Receives parent-client X after removing the thumb's grab offset. Returns a
; rounded 20-20000 Hz value using logarithmic interpolation between column
; centres. One extra column beyond each end reaches the frequency limits.
; Reads drag anchors and band_count; does not modify controls or settings.
func FrequencyDragValueAtX($frequency_x)
	local $frequency_position = ($frequency_x - $GRP_BAND_PX) / $BAND_CW - 0.5
	local $frequency_segment = Floor($frequency_position), $frequency_fraction = $frequency_position - Floor($frequency_position)
	local $frequency_low = 0, $frequency_high = 0
	if $frequency_segment < 0 then
		$frequency_low = $RESPONSE_FREQ_MIN
		$frequency_high = $frequency_drag_anchors[0]
		$frequency_fraction = _Max(0, $frequency_position + 1)
	elseif $frequency_segment >= $band_count - 1 then
		$frequency_low = $frequency_drag_anchors[$band_count - 1]
		$frequency_high = $RESPONSE_FREQ_MAX
		$frequency_fraction = _Min(1, $frequency_position - ($band_count - 1))
	else
		$frequency_low = $frequency_drag_anchors[$frequency_segment]
		$frequency_high = $frequency_drag_anchors[$frequency_segment + 1]
	endif
	return Round(Exp(Log($frequency_low) + $frequency_fraction * Log($frequency_high / $frequency_low)))
endfunc

; Changes the grabbed frequency, retaining its gain and native control IDs.
; Receives parent-client pointer X. Records undo on the first actual change,
; skips occupied integer frequencies, and reorders parallel arrays when the
; band crosses a neighbour. Moves existing controls without rebuilding the
; grid. Updates the title/input and marks EQ dirty for graph redraw; no return.
func MoveFrequencyDrag($frequency_x)
	if $frequency_drag_active < 0 then return
	local $frequency_anchor_x = $frequency_x - $frequency_drag_grab_offset
	local $frequency_value = FrequencyDragValueAtX($frequency_anchor_x)
	local $frequency_direction = 1
	if $frequency_x < $frequency_drag_last_x then $frequency_direction = -1
	for $frequency_attempt = 0 to $band_count * 2
		local $frequency_occupied = false
		for $frequency_row = 0 to $band_count - 1
			if $frequency_row <> $frequency_drag_active and $band_freq[$frequency_row] = $frequency_value then $frequency_occupied = true
		next
		if not $frequency_occupied then exitloop
		$frequency_value += $frequency_direction
		if $frequency_value < $RESPONSE_FREQ_MIN or $frequency_value > $RESPONSE_FREQ_MAX then
			$frequency_direction = -$frequency_direction
			$frequency_value += $frequency_direction * 2
		endif
	next
	if $frequency_value <> $band_freq[$frequency_drag_active] then
		RecordSliderUndo()
		$band_freq[$frequency_drag_active] = $frequency_value
		GUICtrlSetData($freq_ctrl[$frequency_drag_active], String($frequency_value))
		while $frequency_drag_active > 0
			if $band_freq[$frequency_drag_active - 1] < $frequency_value then exitloop
			SwapFrequencyBands($frequency_drag_active - 1, $frequency_drag_active)
			$frequency_drag_active -= 1
		wend
		while $frequency_drag_active < $band_count - 1
			if $band_freq[$frequency_drag_active + 1] > $frequency_value then exitloop
			SwapFrequencyBands($frequency_drag_active, $frequency_drag_active + 1)
			$frequency_drag_active += 1
		wend
		$dirty = true
	endif
	for $frequency_row = 0 to $band_count - 1
		local $frequency_left = $GRP_BAND_PX + $frequency_row * $BAND_CW
		if $frequency_row = $frequency_drag_active then $frequency_left = _Max($GRP_BAND_PX, _Min($GRP_BAND_PX + ($band_count - 1) * $BAND_CW, Round($frequency_anchor_x - $BAND_CW / 2)))
		MoveFrequencyBandControls($frequency_row, $frequency_left)
	next
	$frequency_drag_last_x = $frequency_x
	WinSetTitle($main_gui, "", $APP_NAME & "        " & String($band_freq[$frequency_drag_active]) & " Hz")
endfunc

; Swaps one entry in a parallel band array without changing its type.
; Receives an array by reference and two valid indices; exchanges entries.
; Called only by SwapFrequencyBands(); returns no value and writes no files.
func SwapFrequencyEntries(byref $frequency_array, $frequency_first, $frequency_second)
	local $frequency_temp = $frequency_array[$frequency_first]
	$frequency_array[$frequency_first] = $frequency_array[$frequency_second]
	$frequency_array[$frequency_second] = $frequency_temp
endfunc

; Keeps band data, selection, cached geometry and control identity together.
; Receives two valid band indices. Exchanges their parallel-array entries
; and the six native geometry fields. Called during frequency sorting only;
; returns no value. Native controls are retained, not destroyed or recreated.
func SwapFrequencyBands($frequency_first, $frequency_second)
	SwapFrequencyEntries($band_freq, $frequency_first, $frequency_second)
	SwapFrequencyEntries($band_gain, $frequency_first, $frequency_second)
	SwapFrequencyEntries($gain_ctrl, $frequency_first, $frequency_second)
	SwapFrequencyEntries($gain_value, $frequency_first, $frequency_second)
	SwapFrequencyEntries($freq_ctrl, $frequency_first, $frequency_second)
	SwapFrequencyEntries($remove_ctrl, $frequency_first, $frequency_second)
	SwapFrequencyEntries($band_tag, $frequency_first, $frequency_second)
	SwapFrequencyEntries($frequency_thumb_ctrl, $frequency_first, $frequency_second)
	SwapFrequencyEntries($frequency_thumb_handles, $frequency_first, $frequency_second)
	SwapFrequencyEntries($frequency_column_left, $frequency_first, $frequency_second)
	SwapFrequencyEntries($slider_gesture_handles, $frequency_first, $frequency_second)
	SwapFrequencyEntries($slider_gesture_labels, $frequency_first, $frequency_second)
	SwapFrequencyEntries($slider_gesture_selected, $frequency_first, $frequency_second)
	SwapFrequencyEntries($slider_gesture_base, $frequency_first, $frequency_second)
	SwapFrequencyEntries($slider_gesture_tooltips_dirty, $frequency_first, $frequency_second)
	for $frequency_axis = 0 to 5
		local $frequency_temp = $slider_gesture_bounds[$frequency_first][$frequency_axis]
		$slider_gesture_bounds[$frequency_first][$frequency_axis] = $slider_gesture_bounds[$frequency_second][$frequency_axis]
		$slider_gesture_bounds[$frequency_second][$frequency_axis] = $frequency_temp
	next
endfunc

; Moves one complete band column only when its horizontal position changes.
; Receives its sorted index and left coordinate. Reads cached vertical
; slider geometry; positions the gain, value, frequency input, thumb and Del
; controls together. Updates the cached X coordinate; returns no value.
func MoveFrequencyBandControls($frequency_index, $frequency_left)
	if $frequency_column_left[$frequency_index] = $frequency_left then return
	local $frequency_top = $slider_gesture_bounds[$frequency_index][1]
	local $frequency_rows_y = $frequency_top + $slider_gesture_bounds[$frequency_index][3] + 4
	GUICtrlSetPos($gain_ctrl[$frequency_index], $frequency_left + Int(($BAND_CW - 26) / 2), $frequency_top)
	GUICtrlSetPos($gain_value[$frequency_index], $frequency_left, $GRP_BAND_Y)
	GUICtrlSetPos($freq_ctrl[$frequency_index], $frequency_left, $frequency_rows_y)
	GUICtrlSetPos($remove_ctrl[$frequency_index], $frequency_left, $frequency_rows_y + 24)
	GUICtrlSetPos($frequency_thumb_ctrl[$frequency_index], $frequency_left, $frequency_rows_y + 24)
	$frequency_column_left[$frequency_index] = $frequency_left
	$slider_gesture_bounds[$frequency_index][0] = $frequency_left + Int(($BAND_CW - 26) / 2)
endfunc

; Settles the dragged band into its sorted column and ends the undo action.
; Reads drag state, controls and link-warning title state. Clears active state
; before releasing capture, refreshes gain tooltips/parametric values, and
; restores the normal title. Called on release, capture loss or grid removal.
; Returns no value; autosave resumes in the main loop after this call.
func EndFrequencyDrag()
	if $frequency_drag_active < 0 then return
	$frequency_drag_active = -1
	for $frequency_row = 0 to $band_count - 1
		MoveFrequencyBandControls($frequency_row, $GRP_BAND_PX + $frequency_row * $BAND_CW)
		RefreshBandGain($frequency_row)
	next
	CaptureParametric()
	FinishSliderUndoAction()
	if _WinAPI_GetCapture() = $main_gui then _WinAPI_ReleaseCapture()
	local $frequency_caption = $APP_NAME
	if $link_warning_visible and $link_warning_text_visible then $frequency_caption = $LINK_WARNING_TITLE
	WinSetTitle($main_gui, "", $frequency_caption)
	UpdateFrequencyDragModifiers(true)
endfunc

; Hides the native channel and ticks of each frequency drag control.
; Receives WM_NOTIFY parameters. Returns GUI_RUNDEFMSG for unrelated
; controls, NOTIFYITEMDRAW at prepaint and SKIPDEFAULT for channel/ticks.
; Draws a grey upward-pointing thumb. Class/style checks also recognise the
; control during its first paint; no control-array registration is required.
func OnFrequencyThumbDraw($frequency_window, $frequency_message, $frequency_wparam, $frequency_lparam)
	#forceref $frequency_window, $frequency_message, $frequency_wparam
	local $frequency_header = DllStructCreate($tagNMHDR, $frequency_lparam)
	if DllStructGetData($frequency_header, "Code") <> $NM_CUSTOMDRAW then return $GUI_RUNDEFMSG
	local $frequency_control = DllStructGetData($frequency_header, "hWndFrom")
	local $frequency_style = _WinAPI_GetWindowLong($frequency_control, $GWL_STYLE)
	if BitAND($frequency_style, $TBS_VERT) or not BitAND($frequency_style, $TBS_TOP) then return $GUI_RUNDEFMSG
	if _WinAPI_GetClassName($frequency_control) <> "msctls_trackbar32" then return $GUI_RUNDEFMSG
	local $frequency_draw = DllStructCreate($SLIDER_MARK_DRAW_STRUCT, $frequency_lparam)
	if DllStructGetData($frequency_draw, "DrawStage") = $CDDS_PREPAINT then return $CDRF_NOTIFYITEMDRAW
	if DllStructGetData($frequency_draw, "DrawStage") <> $CDDS_ITEMPREPAINT then return $CDRF_DODEFAULT
	if DllStructGetData($frequency_draw, "ItemSpec") = $TBCD_THUMB then
		local $frequency_rect = DllStructCreate($tagRECT)
		_SendMessage($frequency_control, $TBM_GETTHUMBRECT, 0, DllStructGetPtr($frequency_rect))
		local $frequency_left = DllStructGetData($frequency_rect, "Left"), $frequency_right = DllStructGetData($frequency_rect, "Right") - 1
		local $frequency_top = DllStructGetData($frequency_rect, "Top"), $frequency_bottom = DllStructGetData($frequency_rect, "Bottom") - 1
		local $frequency_shape[5][2] = [[Int(($frequency_left + $frequency_right) / 2), $frequency_top], [$frequency_right, $frequency_top + 3], _
			[$frequency_right, $frequency_bottom], [$frequency_left, $frequency_bottom], [$frequency_left, $frequency_top + 3]]
		local $frequency_dc = DllStructGetData($frequency_draw, "HDC")
		local $frequency_brush = _WinAPI_CreateSolidBrush(_WinAPI_GetSysColor($COLOR_BTNSHADOW)), $frequency_pen = _WinAPI_CreatePen($PS_SOLID, 1, _WinAPI_GetSysColor($COLOR_GRAYTEXT))
		local $frequency_old_brush = _WinAPI_SelectObject($frequency_dc, $frequency_brush), $frequency_old_pen = _WinAPI_SelectObject($frequency_dc, $frequency_pen)
		_WinAPI_Polygon($frequency_dc, $frequency_shape)
		_WinAPI_SelectObject($frequency_dc, $frequency_old_brush)
		_WinAPI_SelectObject($frequency_dc, $frequency_old_pen)
		_WinAPI_DeleteObject($frequency_brush)
		_WinAPI_DeleteObject($frequency_pen)
	endif
	return $CDRF_SKIPDEFAULT
endfunc

; Opens the single shared deletion menu for the right-clicked frequency thumb.
; Receives WM_CONTEXTMENU's target HWND. Finds its band in one loop and
; queues that index only when Delete this band is chosen. Returns true for
; a thumb, false for other targets. The main loop calls OnDeleteBand(), so
; no grid rebuild occurs inside this native notification callback.
func FrequencyThumbContextMenu($frequency_window)
	for $frequency_row = 0 to $ctrl_count - 1
		if $frequency_window <> $frequency_thumb_handles[$frequency_row] then continueloop
		if _GUICtrlMenu_TrackPopupMenu($frequency_delete_menu, $main_gui, -1, -1, 1, 1, $FREQUENCY_MENU_RETURN_COMMAND) = $FREQUENCY_DELETE_COMMAND then $frequency_delete_pending = $frequency_row
		return true
	next
	return false
endfunc

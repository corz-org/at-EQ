; Undo 0.1.6
; One in-memory undo slot for gains, frequency drags, preamp and deletion.
#include-once

global $undo_slider_command = 0, $undo_slider_valid = false, $undo_slider_recorded = false
global $undo_slider_gains[$MAX_PARAM_BANDS], $undo_slider_preamp = 0
global $undo_slider_freq[$MAX_PARAM_BANDS], $undo_slider_count = 0

; Enables Ctrl+Z for the main @EQ window's last slider action.
; Reads $main_gui and creates a dummy command in $undo_slider_command.
; Optional undo_enter_command adds Enter to the same accelerator table.
; Called once after control creation; returns no value. The main event loop
; calls UndoSliderAction() for Ctrl+Z and commits the focused frequency input
; for Enter when supplied.
func InitializeSliderUndo($undo_enter_command=0)
	$undo_slider_command = GUICtrlCreateDummy()
	local $undo_slider_keys[2][2] = [["^z", $undo_slider_command], ["{ENTER}", $undo_enter_command]]
	if $undo_enter_command = 0 then redim $undo_slider_keys[1][2]
	GUISetAccelerators($undo_slider_keys, $main_gui)
endfunc

; Discards slider undo when the edited EQ layout or context changes.
; Clears $undo_slider_valid and $undo_slider_recorded. Called before loading
; a preset, changing frequencies or rebuilding without preserve_undo.
; Returns no value; writes no settings and does not change EQ values.
func ClearSliderUndo()
	$undo_slider_valid = false
	$undo_slider_recorded = false
endfunc

; Saves EQ before the first change in one slider action or band deletion.
; Reads band_gain, band_freq, band_count and preamp into the undo slot only
; when $undo_slider_recorded is false; later changes in that action reuse
; the snapshot. Call only before a value changes. Returns no value; the
; snapshot remains in memory and is never written to a file.
func RecordSliderUndo()
	if $undo_slider_recorded then return
	$undo_slider_gains = $band_gain
	$undo_slider_freq = $band_freq
	$undo_slider_count = $band_count
	$undo_slider_preamp = $preamp
	$undo_slider_valid = true
	$undo_slider_recorded = true
endfunc

; Allows the next slider action to replace the single undo slot.
; Clears $undo_slider_recorded without discarding the saved values. Called
; at mouse press, gesture end, and after native slider changes when mouse
; capture has ended. Returns no value; writes no settings.
func FinishSliderUndoAction()
	$undo_slider_recorded = false
endfunc

; Restores the most recent slider action or band deletion once, without redo.
; Reads the undo slot and current controls. Commits pending frequency edits
; first, which discard the slot if frequencies changed. Returns false when
; no snapshot remains; otherwise ends dragging and restores band count,
; frequencies, gains and preamp. A changed count or frequency order rebuilds
; controls and captures parametric values. Marks EQ dirty for autosave/listener
; notification, consumes the slot and returns true. Writes no settings here.
func UndoSliderAction()
	ReadParamBoxes()
	if not $undo_slider_valid then return false
	EndSliderGesture()
	if _WinAPI_GetCapture() = GUICtrlGetHandle($preamp_slider) then _WinAPI_ReleaseCapture()
	local $undo_slider_rebuild = $band_count <> $undo_slider_count
	for $undo_frequency_index = 0 to $band_count - 1
		if $band_freq[$undo_frequency_index] <> $undo_slider_freq[$undo_frequency_index] then $undo_slider_rebuild = true
	next
	$band_count = $undo_slider_count
	$band_freq = $undo_slider_freq
	$band_gain = $undo_slider_gains
	$preamp = $undo_slider_preamp
	ClearSliderUndo()
	if $undo_slider_rebuild then
		CaptureParametric()
		RebuildBandGrid()
	else
		for $undo_slider_index = 0 to $ctrl_count - 1
			RefreshBandGain($undo_slider_index)
		next
	endif
	GUICtrlSetData($preamp_slider, Int($preamp * 2))
	GUICtrlSetData($preamp_value, StringFormat("%.1f dB", $preamp))
	GUICtrlSetTip($preamp_slider, StringFormat("%.1f dB Preamp", $preamp))
	$dirty = true
	GUICtrlSetData($status_label, "Undid last slider action")
	return true
endfunc

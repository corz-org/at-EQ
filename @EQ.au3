#AutoIt3Wrapper_Res_Fileversion=1.1.0
global const $VERSION = "1.1.0"

#include <Array.au3>
#include <GUIConstantsEx.au3>
#include <ButtonConstants.au3>
#include <FontConstants.au3>
#include <TrayConstants.au3>
#include <StaticConstants.au3>
#include <WindowsConstants.au3>
#include <WindowsNotifsConstants.au3>
#include <SliderConstants.au3>
#include <FileConstants.au3>
#include <AutoItConstants.au3>
#include <EditConstants.au3>
#include <GuiComboBox.au3>
#include <GuiListView.au3>
#include <GuiToolTip.au3>
#include <WinAPIShellEx.au3>
#include <MsgBoxConstants.au3>
#include <GDIPlus.au3>
#include <StringConstants.au3>
#include <WinAPIProc.au3>
#include <Date.au3>

global const $STR_STRIP_ENDS = BitOR($STR_STRIPLEADING, $STR_STRIPTRAILING)
global const $MONITOR_PRIMARY_DEVICE = 0x00000004
global const $MONITOR_ACTIVE_DEVICE = 0x00000001
global const $APP_NAME = "@EQ"
global const $OUTPUT_SWAP_SECTION = "OutputSwap"
global const $PREVIOUS_PRESET_KEY = "PreviousPreset"
global const $PRESET_SORT_KEY = "SortPresets"
global const $SELECTED_MONITOR_KEY = "SelectedMonitor"
global const $DIALOG_Y_FRACTION = 0.25
global const $LINK_WARNING_FLASH_DURATION = 3000
global const $LINK_WARNING_FLASH_INTERVAL = 500
global const $LINK_WARNING_CALLBACK = "BlinkLinkWarning"
global const $LINK_WARNING_TITLE = $APP_NAME & "        Link a Monitor and an Output to enable sound"
global $link_warning_visible = false, $link_warning_text_visible = true, $link_warning_timer = 0
global const $MESSAGE_WIDTH = 440
global const $MESSAGE_MARGIN = 12
global const $MESSAGE_BUTTON_WIDTH = 80
global const $MESSAGE_BUTTON_HEIGHT = 26
global const $MESSAGE_BUTTON_GAP = 8
global const $INI_SUB = "\corz\@EQ\@EQ.ini"
global const $LISTENER_EXE = "@EQListener.exe"
global const $LISTENER_POLL_MS = 1000
global const $ABOUT_URL = "https://corz.org/windows/software/@EQ/"
global const $ABOUT_SECONDS_PER_MINUTE = 60
global const $ABOUT_SECONDS_PER_HOUR = 3600
global const $ABOUT_SECONDS_PER_DAY = 86400
global const $ABOUT_FILETIME_TICKS_PER_SECOND = 10000000
global const $TRAY_MENU_NO_DEFAULT = 1
global const $TRAY_MENU_NO_AUTO_CHECK = 2
global $tray_about_item = 0, $tray_quit_item = 0, $tray_startup_item = 0
global const $RANGE_CHOICES = "3 dB|6 dB|12 dB|18 dB|24 dB"
global const $GAIN_MIN = -24
global const $GAIN_MAX = 24
global const $MAX_PARAM_BANDS = 32
global const $FREQ_5[5] = [63, 250, 1000, 4000, 16000]
global const $FREQ_10[10] = [31, 62, 125, 250, 500, 1000, 2000, 4000, 8000, 16000]
global const $FREQ_15[15] = [25, 40, 63, 100, 160, 250, 400, 630, 1000, 1600, 2500, 4000, 6300, 10000, 16000]
global const $MODE_GRAPHIC_5 = "5 Band"
global const $MODE_GRAPHIC_10 = "10 Band"
global const $MODE_GRAPHIC_15 = "15 Band"
global const $MODE_PARAMETRIC = "Parametric"
global const $MODE_GRAPHIC = "Graphic"
global const $TOP_MIN_W = 516
global const $MIN_W = 320
global const $MIN_H = 240
global const $BAND_CW = 40
global const $GRP_TOP_X = 8
global const $GRP_TOP_Y = 8
global const $GRP_BAND_X = 8
global const $GRP_BAND_PX = $GRP_BAND_X
global const $GRP_BAND_Y = 72
global const $GRP_SETUP_Y = 72
global const $GROUP_GAP = 8
global const $SETUP_W = 240
global const $TOP_H = 64
global const $DEF_W = 760
global const $DEF_H = 453
global const $STATUS_H = 24
global const $SETUP_BOTTOM = 367
global const $BOTTOM_SPACE_REDUCTION = 42
global const $RESPONSE_HEIGHT_INCREASE = 50
global const $RESPONSE_TOP = $GRP_SETUP_Y + 204 + 26 + 8
global const $RESPONSE_FREQ_MIN = 20
global const $RESPONSE_FREQ_MAX = 20000
global const $RESPONSE_BG = 0xFFF8FAFC
global const $RESPONSE_GRID = 0xFFD8E0E8
global const $RESPONSE_ZERO = 0xFF8996A5
global const $RESPONSE_TOTAL = 0xFF1677C8
global const $RESPONSE_FILL = 0xFFCCE6FA
global const $RESPONSE_TEXT = 0xFF344354
global const $RESPONSE_FONT = "Segoe UI"

global $profile_monitor = ""
global $profile_monitor_name = ""
global $preset_name = "Default"
global $preset_mode = $MODE_GRAPHIC
global $graphic_count = 10
global $band_count = 10
global $preamp = 0.0
global $swap = 0
global $band_freq[$MAX_PARAM_BANDS] = [31, 62, 125, 250, 500, 1000, 2000, 4000, 8000, 16000, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
global $band_gain[$MAX_PARAM_BANDS]
global $dirty = false
global $autosave_armed = 0
global $listener_pid = 0
global $app_mutex = 0

global $main_gui = 0
global $window_drag_top = 0, $window_drag_bottom = 0
global $preset_label = 0
global $range_label = 0
global $range_list = 0
global $range_db = 18
global $monitor_rename_item = 0, $output_rename_item = 0
global $preset_rename_item = 0, $preset_export_item = 0, $preset_sort_item = 0
global $preamp_label = 0
global $preset_list = 0
global $mode_list = 0
global $preamp_slider = 0
global $preamp_value = 0
global $check_swap = 0
global $monitor_list = 0, $monitor_tip_callback = 0
global $speaker_list = 0
global $monitor_label = 0
global $output_label = 0

global $status_label = 0
global $response_picture = 0, $response_bitmap = 0, $response_signature = ""
global $add_button = 0
global $flat_button = 0
global $apply_button = 0
global $refresh_button = 0
global $import_button = 0
global $export_button = 0
global $delete_button = 0
global $new_button = 0
global $duplicate_button = 0
global $param_count = 0
global $param_freq[$MAX_PARAM_BANDS], $param_gain[$MAX_PARAM_BANDS]
global const $NEW_FREQ[20] = [31, 62, 125, 250, 500, 1000, 2000, 4000, 8000, 16000, 40, 80, 160, 315, 630, 1250, 2500, 5000, 10000, 20000]
global $start_button = 0
global $stop_button = 0
global $gain_ctrl[$MAX_PARAM_BANDS]
global $gain_value[$MAX_PARAM_BANDS]
global $freq_ctrl[$MAX_PARAM_BANDS]
global $frequency_commit_command = 0
global const $FREQUENCY_INVALID_COLOUR = 0xCC0000
global const $BAND_RANDOM_INTEGER = 1
global $remove_ctrl[$MAX_PARAM_BANDS]
global $ctrl_count = 0
global $gb = 0
global $gw = 0
global $band_tag[$MAX_PARAM_BANDS]
global $last_client_w = 0
global $last_client_h = 0
global $monitor_key[16]
global $monitor_row[16]
global $monitor_total = 0, $monitor_refreshing = false, $monitor_selection_changed = false
global $speaker_id[32]
global $speaker_name[32], $speaker_windows_name[32]
global $speaker_total = 0
global $speaker_default_id = ""
global const $SPEAKER_DEFAULT_PREFIX = "DefaultOutput="
global const $OUTPUT_LIST_TIP = "Output that plays for the selected screen. Select one, press Link."

#include "Includes\SliderGestures.au3"
#include "Includes\Undo.au3"
#include "Includes\FrequencyDrag.au3"
#include "Includes\StartupTask.au3"
#include "Includes\DialogPosition.au3"

Opt("TrayAutoPause", 0)
Opt("TrayMenuMode", BitOR($TRAY_MENU_NO_DEFAULT, $TRAY_MENU_NO_AUTO_CHECK))
$tray_startup_item = TrayCreateItem("Create " & $STARTUP_TASK_NAME & " Task")
TrayCreateItem("")
$tray_about_item = TrayCreateItem("About " & $APP_NAME & "...")
TrayCreateItem("")
$tray_quit_item = TrayCreateItem("Quit " & $APP_NAME & @TAB & "Alt+F4/Esc")
TraySetToolTip($APP_NAME & " " & $VERSION)

Opt("GUIResizeMode", $GUI_DOCKALL)
VerifyIni()
$profile_monitor = IniRead(GetIniPath(), $APP_NAME, $SELECTED_MONITOR_KEY, "")

if not LoadPreset(IniRead(GetIniPath(), "Playback", "Preset", "Default")) then
	local $startup_names = StringSplit(LoadPresetNames(), "|")
	LoadPreset($startup_names[1])
endif

local $ini_path = GetIniPath()

local $ww = Int(IniRead($ini_path, $APP_NAME, "Width", $DEF_W))
local $hh = Int(IniRead($ini_path, $APP_NAME, "Height", $DEF_H))
if $ww < $MIN_W then $ww = $MIN_W
if $hh < $MIN_H then $hh = $MIN_H
local $wx = Int(IniRead($ini_path, $APP_NAME, "Left", -1))
local $wy = Int(IniRead($ini_path, $APP_NAME, "Top", -1))

$main_gui = GUICreate($APP_NAME, $ww, $hh, $wx, $wy, BitOR($WS_CAPTION, $WS_SYSMENU, $WS_MINIMIZEBOX, $WS_SIZEBOX))

	WinMove($main_gui, "", default, default, $ww, $hh)
	GUIRegisterMsg($WM_GETMINMAXINFO, "OnWindowTrackLimits")
	GUIRegisterMsg($WM_NCHITTEST, "OnWindowResizeHitTest")
	GUIRegisterMsg($WM_CONTEXTMENU, "OnMonitorContextMenu")
	GUIRegisterMsg($WM_NOTIFY, "OnAppNotify")
	$window_drag_top = GUICtrlCreateLabel("", 0, 0, 1, 1, BitOR($SS_NOTIFY, $SS_LEFT), $GUI_WS_EX_PARENTDRAG)
	GUICtrlSetBkColor($window_drag_top, $GUI_BKCOLOR_TRANSPARENT)
	$window_drag_bottom = GUICtrlCreateLabel("", 0, 0, 1, 1, BitOR($SS_NOTIFY, $SS_LEFT), $GUI_WS_EX_PARENTDRAG)
	GUICtrlSetBkColor($window_drag_bottom, $GUI_BKCOLOR_TRANSPARENT)
	$preset_label = GUICtrlCreateLabel("Preset:", 0, 0, 32, 18, $SS_RIGHT)
	$preset_list = GUICtrlCreateCombo("", 0, 0, 140, 24, $CBS_DROPDOWNLIST)
	local $preset_context_menu = GUICtrlCreateContextMenu($preset_list)
	$preset_rename_item = GUICtrlCreateMenuItem("Rename this preset", $preset_context_menu)
	GUICtrlCreateMenuItem("", $preset_context_menu)
	$preset_export_item = GUICtrlCreateMenuItem("Export this preset", $preset_context_menu)
	GUICtrlCreateMenuItem("", $preset_context_menu)
	$preset_sort_item = GUICtrlCreateMenuItem("Sort this list", $preset_context_menu)
	if IniRead(GetIniPath(), $APP_NAME, $PRESET_SORT_KEY, "0") = "1" then GUICtrlSetState($preset_sort_item, $GUI_CHECKED)
	GUICtrlSetTip($preset_list, "Your saved presets. Select a preset to load its settings.")
	$range_label = GUICtrlCreateLabel("Range:", 0, 0, 38, 18)
	GUICtrlSetTip($range_label, "Gain display range for this preset and monitor, shared across EQ modes.")
	$range_list = GUICtrlCreateCombo("", 0, 0, 52, 24, $CBS_DROPDOWNLIST)
	GUICtrlSetData($range_list, $RANGE_CHOICES, $range_db & " dB")
	$mode_list = GUICtrlCreateCombo("", 0, 0, 80, 24, $CBS_DROPDOWNLIST)
	GUICtrlSetTip($mode_list, "Bands per preset. Points define straight lines on a logarithmic frequency axis." & @LF & _
								"Graphic modes use fixed ISO frequencies. Parametric lets you edit the frequencies.")
	$preamp_label = GUICtrlCreateLabel("Preamp:", 0, 0, 44, 18)
	$preamp_slider = GUICtrlCreateSlider(0, 0, 98, 24)
	GUICtrlSetLimit($preamp_slider, $GAIN_MAX * 2, $GAIN_MIN * 2)
	GUICtrlSetTip($preamp_slider, "Preamp gain for the whole preset, plus or minus up to 24 dB.")
	$preamp_value = GUICtrlCreateLabel("0.0 dB", 0, 0, 52, 18)
	GUICtrlSetTip($preamp_value, "Preamp value." & @LF & _
									"Click here to reset preamp to 0 dB.")
	$new_button = GUICtrlCreateButton("New", 0, 0, 60, 26)
	GUICtrlSetTip($new_button, "Click to create a new blank preset." & @LF & _
								"You will need to link a monitor to an audio output to hear anything.")
	$duplicate_button = GUICtrlCreateButton("Duplicate", 0, 0, 72, 26)
	GUICtrlSetTip($duplicate_button, "Duplicate this preset to a new preset." & @LF & "You will be asked to supply a name for the new preset")
	$delete_button = GUICtrlCreateButton("Delete", 0, 0, 60, 26)
	GUICtrlSetTip($delete_button, "Delete the selected preset.")
	$add_button = GUICtrlCreateButton("Add band", 0, 0, 60, 26)
	GUICtrlSetTip($add_button, "Insert a new frequency band.")
	$flat_button = GUICtrlCreateButton("Flat", 0, 0, 50, 26)
	GUICtrlSetTip($flat_button, "Zero the selected gain sliders." & @LF & "With no sliders selected, this zeros all sliders and preamp.")
	$check_swap = GUICtrlCreateCheckbox("Swap channels:", 0, 0, 102, 22, BitOR($GUI_SS_DEFAULT_CHECKBOX, $BS_RIGHTBUTTON))
	GUICtrlSetTip($check_swap, "Swap left and right channels for this preset and monitor." & @LF & _
								"The setting applies to each preset's seleted audio output.")
	$monitor_label = GUICtrlCreateLabel("Monitor:", 0, 0, 60, 18)
	$monitor_list = GUICtrlCreateListView("Monitor", 0, 0, 240, 75, BitOR($LVS_REPORT, $LVS_SINGLESEL, $LVS_SHOWSELALWAYS, $LVS_NOCOLUMNHEADER))
	_GUICtrlListView_SetExtendedListViewStyle($monitor_list, BitOR($LVS_EX_FULLROWSELECT, $LVS_EX_INFOTIP, $LVS_EX_DOUBLEBUFFER))
	_GUICtrlListView_SetUnicodeFormat($monitor_list, true)
	$monitor_tip_callback = DllCallbackRegister("MonitorTipProc", "lresult", "hwnd;uint;wparam;lparam;uint_ptr;dword_ptr")
	_WinAPI_SetWindowSubclass(_GUICtrlListView_GetToolTips($monitor_list), DllCallbackGetPtr($monitor_tip_callback), 0)
	_GUIToolTip_SetMaxTipWidth(_GUICtrlListView_GetToolTips($monitor_list), 0)
	local $monitor_context_menu = GUICtrlCreateContextMenu($monitor_list)
	$monitor_rename_item = GUICtrlCreateMenuItem("Rename Monitor...", $monitor_context_menu)
	$output_label = GUICtrlCreateLabel("Output:", 0, 0, 60, 18)
	$speaker_list = GUICtrlCreateCombo("", 0, 0, 240, 24, $CBS_DROPDOWNLIST)
	local $output_context_menu = GUICtrlCreateContextMenu($speaker_list)
	$output_rename_item = GUICtrlCreateMenuItem("Rename Output...", $output_context_menu)
	GUICtrlSetTip($speaker_list, $OUTPUT_LIST_TIP)
	$apply_button = GUICtrlCreateButton("Link monitor", 0, 0, 240, 26)
	GUICtrlSetState($apply_button, $GUI_DISABLE)
	GUICtrlSetTip($apply_button, "Link the selected screen to the current preset and output. Switching is automatic after this.")
	$refresh_button = GUICtrlCreateButton("Refresh", 0, 0, 240, 24)
	GUICtrlSetTip($refresh_button, "Refresh (re-read) all Windows monitors and audio outputs.")
	$import_button = GUICtrlCreateButton("Import", 0, 0, 240, 24)
	GUICtrlSetTip($import_button, "Import presets from a file.")
	$export_button = GUICtrlCreateButton("Export", 0, 0, 240, 24)
	GUICtrlSetTip($export_button, "Export all presets to a file." & @LF & "Right-click the presets dropdown to export individual presets.")
	$start_button = GUICtrlCreateButton("Start", 0, 0, 240, 24)
	GUICtrlSetTip($start_button, "Start the background listener. It plays CABLE audio through your linked output.")
	$stop_button = GUICtrlCreateButton("Stop", 0, 0, 240, 24)
	GUICtrlSetTip($stop_button, "Stop the background listener.")
	_GDIPlus_Startup()
	$response_picture = GUICtrlCreatePic("", 0, 0, $SETUP_W, 100, BitOR($SS_BITMAP, $SS_NOTIFY), $GUI_WS_EX_PARENTDRAG)
	GUICtrlSetTip($response_picture, "Logarithmic frequency response including preamp. Shading marks gain above 0 dB.")
	$status_label = GUICtrlCreateLabel("Ready", 0, 0, 744, 18, BitOR($SS_NOTIFY, $SS_LEFTNOWORDWRAP), $GUI_WS_EX_PARENTDRAG)
	GUICtrlSetTip($status_label, "What the program just did.")

	InitializeSliderGestures()
	$frequency_commit_command = GUICtrlCreateDummy()
	InitializeSliderUndo($frequency_commit_command)
	InitializeFrequencyDrag()
	RefreshTopControls()
	RefreshMonitorList()

		RebuildBandGrid()
		RestoreVisibleWindow()
		GUISetState(@SW_SHOW, $main_gui)
		AdoptListener()
		local $fresh = DllCall("kernel32.dll", "handle", "CreateMutexA", "ptr", 0, "bool", 0, "str", "Local\@EQApp")
		if not @error then $app_mutex = $fresh[0]
		PromptListenerStartupTask()

	local $listener_poll_timer = TimerInit()
	while 1
		if TimerDiff($listener_poll_timer) >= $LISTENER_POLL_MS then
			AdoptListener(true)
			$listener_poll_timer = TimerInit()
		endif
		local $tray_menu_event = TrayGetMsg()
		if $tray_menu_event = $tray_quit_item then exitloop
		if $tray_menu_event = $tray_about_item then DoAboutBox(default, default)
		if $tray_menu_event = $tray_startup_item then CreateListenerStartupTask()
		UpdateFrequencyDragModifiers()
		if $frequency_delete_pending >= 0 then
			local $frequency_delete_index = $frequency_delete_pending
			$frequency_delete_pending = -1
			OnDeleteBand($frequency_delete_index)
		endif
		local $msg = GUIGetMsg()
		if $msg = $GUI_EVENT_CLOSE then exitloop
		if $msg = $frequency_commit_command then
			local $frequency_focus = _WinAPI_GetFocus()
			for $frequency_index = 0 to $ctrl_count - 1
				if $freq_ctrl[$frequency_index] = 0 then continueloop
				if GUICtrlGetHandle($freq_ctrl[$frequency_index]) <> $frequency_focus then continueloop
				CommitBandFrequency($frequency_index, true)
				exitloop
			next
			$msg = 0
		endif
		if $msg = $undo_slider_command then
			UndoSliderAction()
			$msg = 0
		endif
		if $msg = $new_button then
			OnNewPreset()
			$msg = 0
		endif
		if $msg = $duplicate_button then
			OnNewPreset(true)
			$msg = 0
		endif
		if $msg = $delete_button then
			OnDeletePreset()
			$msg = 0
		endif
		if $msg = $mode_list then
			OnModeChange()
			$msg = 0
		endif
		if $msg = $add_button then
			OnAddBand(default, default)
			$msg = 0
		endif
		if $msg = $flat_button then
			FlatPreset()
			ClearSliderGestureSelection()
		endif
		if $msg = $range_list then OnRangeChange()
		if $msg = $monitor_rename_item then OnRenameMonitor()
		if $msg = $output_rename_item then OnRenameOutput()
		if $msg = $preset_rename_item then OnNewPreset(false, true)
		if $msg = $preset_sort_item then
			local $preset_sort_enabled = 1, $preset_sort_state = $GUI_CHECKED
			if BitAND(GUICtrlRead($preset_sort_item), $GUI_CHECKED) then
				$preset_sort_enabled = 0
				$preset_sort_state = $GUI_UNCHECKED
			endif
			if IniWrite(GetIniPath(), $APP_NAME, $PRESET_SORT_KEY, $preset_sort_enabled) then
				GUICtrlSetState($preset_sort_item, $preset_sort_state)
				GUICtrlSetData($preset_list, "")
				GUICtrlSetData($preset_list, LoadPresetNames(), $preset_name)
			endif
		endif
		if $msg = $preset_export_item then
			local $preset_export_count = ExportPresets($preset_name)
			if @error then
				GUICtrlSetData($status_label, "Could not export preset " & $preset_name)
			elseif $preset_export_count > 0 then
				GUICtrlSetData($status_label, "Exported preset " & $preset_name)
			endif
		endif
		if $msg = $check_swap then
			$swap = 0
			if GUICtrlRead($check_swap) = $GUI_CHECKED then $swap = 1
			$dirty = true
		endif
		if $msg = $preset_list then
			local $picked = StringStripWS(GUICtrlRead($preset_list), 3)
			if $picked <> "" and $picked <> $preset_name and PresetExists($picked) then
				if $dirty then SavePreset()
				LoadPreset($picked)
				ActivatePreset()
				$msg = 0
			endif
		endif
		if GUICtrlRead($preamp_slider) / 2 <> $preamp then
			RecordSliderUndo()
			$preamp = GUICtrlRead($preamp_slider) / 2
			GUICtrlSetData($preamp_value, StringFormat("%.1f dB", $preamp))
			GUICtrlSetTip($preamp_slider, StringFormat("%.1f dB Preamp", $preamp))
			$dirty = true
		endif
		if $msg = $preamp_value then
			if $preamp <> 0 then RecordSliderUndo()
			$preamp = 0
			GUICtrlSetData($preamp_slider, 0)
			GUICtrlSetData($preamp_value, "0.0 dB")
			GUICtrlSetTip($preamp_slider, StringFormat("%.1f dB Preamp", $preamp))
			$dirty = true
		endif
		if $monitor_selection_changed then
			$monitor_selection_changed = false
			local $chosen = MonitorKey()
			if $chosen <> "" then ShowBinding($chosen)
		endif
		if $msg = $speaker_list then
			UpdateOutputTooltip()
			UpdateLinkButton()
		endif
		if $msg = $apply_button then OnApplyBinding()
		if $msg = $refresh_button then RefreshMonitorList()
		if $msg = $import_button then
			local $got = ImportPresets()
			GUICtrlSetData($status_label, "Imported " & $got & " presets")
		endif
		if $msg = $export_button then
			local $sent = ExportPresets()
			GUICtrlSetData($status_label, "Exported " & $sent & " presets")
		endif
		if $msg = $start_button then OnStartListener()
		if $msg = $stop_button then OnStopListener()
		if $msg = $GUI_EVENT_RESIZED or $msg = $GUI_EVENT_MAXIMIZE or $msg = $GUI_EVENT_RESTORE then OnResize()
		local $scan = 0
		while $scan < $ctrl_count
			local $gain_expected = $band_gain[$scan]
			if $gain_expected > $range_db then $gain_expected = $range_db
			if $gain_expected < -$range_db then $gain_expected = -$range_db
			if $msg = $gain_ctrl[$scan] or -GUICtrlRead($gain_ctrl[$scan]) / 2 <> $gain_expected then
				if $band_gain[$scan] <> -GUICtrlRead($gain_ctrl[$scan]) / 2 then RecordSliderUndo()
				$band_gain[$scan] = -GUICtrlRead($gain_ctrl[$scan]) / 2
				RefreshBandGain($scan)
				$dirty = true
			endif
			if $preset_mode = $MODE_PARAMETRIC and $msg = $remove_ctrl[$scan] then
				OnDeleteBand($scan)
				; Rebuild recycles control IDs: this event is now fully handled.
				exitloop
			endif
			if $freq_ctrl[$scan] <> 0 and $msg = $freq_ctrl[$scan] then
				CommitBandFrequency($scan)
				exitloop
			endif
			if $gain_value[$scan] <> 0 and $msg = $gain_value[$scan] then
				if $band_gain[$scan] <> 0 then RecordSliderUndo()
				$band_gain[$scan] = 0
				GUICtrlSetData($gain_ctrl[$scan], 0)
				RefreshBandGain($scan)
				$dirty = true
			endif
			$scan += 1
		wend
		if $frequency_drag_active < 0 and $slider_gesture_state = $SLIDER_GESTURE_IDLE and _WinAPI_GetCapture() <> GUICtrlGetHandle($preamp_slider) then FinishSliderUndoAction()
		RefreshSliderGestureTooltips()
		UpdateResponseGraph()
		if $dirty and $frequency_drag_active < 0 and GUICtrlRead($preset_list) = $preset_name then
			if $autosave_armed = 0 then $autosave_armed = TimerInit()
			if TimerDiff($autosave_armed) > 500 then
				SavePreset()
				$autosave_armed = 0
				GUICtrlSetData($status_label, "Saved preset " & $preset_name)
			endif
		else
			$autosave_armed = 0
		endif
	wend


EndSliderGesture()
_GUICtrlMenu_DestroyMenu($frequency_delete_menu)
_WinAPI_UnhookWindowsHookEx($slider_gesture_hook)
DllCallbackFree($slider_gesture_callback)
GUIDelete($slider_gesture_overlay)
if $dirty then SavePreset()
SaveWindowRect()
local $response_last_bitmap = GUICtrlSendMsg($response_picture, $STM_SETIMAGE, $IMAGE_BITMAP, 0)
if $response_last_bitmap and $response_last_bitmap <> $response_bitmap then _WinAPI_DeleteObject($response_last_bitmap)
if $response_bitmap then _WinAPI_DeleteObject($response_bitmap)
_GDIPlus_Shutdown()
GUIDelete($main_gui)
DllCallbackFree($monitor_tip_callback)
if $app_mutex <> 0 then DllCall("kernel32.dll", "bool", "CloseHandle", "handle", $app_mutex)
; Closing the editor leaves the background listener running.






; Returns the full path of the live settings file under the user
; application data folder. Returns the path string.
func GetIniPath()
	local $base = EnvGet("APPDATA")
	return $base & $INI_SUB
endfunc


; Creates general settings sections before the default preset in a new INI.
; Reads GetIniPath(), APP_NAME and OUTPUT_SWAP_SECTION; creates the parent
; directory when absent. Writes empty @EQ, Playback, Monitors and OutputSwap
; sections, then Default with Preset=1 and Mode=10band, using UTF-16LE and LF.
; Returns true for an existing file or successful write and close; false if
; opening, writing or closing fails. Called at startup before controls are
; created. Existing files are not rewritten.
func VerifyIni()
	local $path = GetIniPath()
	local $folder = StringLeft($path, StringInStr($path, "\", 0, -1) - 1)
	if not FileExists($folder) then DirCreate($folder)
	if FileExists($path) then return true
	local $ini_initial_text = "[" & $APP_NAME & "]" & @LF & @LF & "[Playback]" & @LF & @LF & "[Monitors]" & @LF & @LF & _
		"[" & $OUTPUT_SWAP_SECTION & "]" & @LF & @LF & "[Default]" & @LF & "Preset=1" & @LF & "Mode=10band" & @LF
	local $ini_initial_file = FileOpen($path, BitOR($FO_OVERWRITE, $FO_UTF16_LE))
	if $ini_initial_file = -1 then return false
	local $ini_initial_written = FileWrite($ini_initial_file, $ini_initial_text)
	local $ini_initial_closed = FileClose($ini_initial_file)
	return $ini_initial_written and $ini_initial_closed
endfunc




; Lists saved presets with Default first and optional alphabetical sorting.
; Reads GetIniPath() section names, each Preset flag and [@EQ] SortPresets.
; Only Preset=1 sections are included. Default is matched without case and
; retains its stored spelling. Other names retain INI order unless sorting
; is enabled. Returns names separated by | with a trailing |, or "" for no
; presets/read failure. Writes no settings; callers include startup, combo
; refresh and deletion fallback selection.
func LoadPresetNames()
	local $path = GetIniPath()
	local $names = IniReadSectionNames($path)
	if @error then return ""
	local $out = "", $preset_sort_default = ""
	for $index = 1 to $names[0]
		if IniRead($path, $names[$index], "Preset", "") <> "1" then continueloop
		if $names[$index] = "Default" then
			$preset_sort_default = $names[$index] & "|"
		else
			$out &= $names[$index] & "|"
		endif
	next
	if $out <> "" and IniRead($path, $APP_NAME, $PRESET_SORT_KEY, "0") = "1" then
		local $preset_sort_names = StringSplit(StringTrimRight($out, 1), "|")
		if $preset_sort_names[0] > 1 then _ArraySort($preset_sort_names, 0, 1)
		$out = _ArrayToString($preset_sort_names, "|", 1) & "|"
	endif
	return $preset_sort_default & $out
endfunc

; Enforces the absolute EQ gain limits for loaded and imported values.
; Reads GAIN_MIN and GAIN_MAX; converts the supplied value to a number and
; returns it unchanged within those limits, GAIN_MIN below or GAIN_MAX above.
; Does not write settings or apply the currently selected slider range.
func CapGain($gain)
	$gain = Number($gain)
	if $gain < $GAIN_MIN then return $GAIN_MIN
	if $gain > $GAIN_MAX then return $GAIN_MAX
	return $gain
endfunc


; Loads the chosen preset's EQ for the selected monitor and saved mode.
; Reads the name, optional mode, $profile_monitor_name and the INI. An
; omitted mode uses Mode_<monitor>, falling back to the preset's Mode key.
; Reads bands and Preamp from [name_monitor_mode]; missing EQ values
; produce flat gains. Reads Range_<monitor> from [name], shared across
; modes; missing or invalid ranges use 18 dB. Reads the linked Output_<monitor>
; endpoint and its value in OUTPUT_SWAP_SECTION; missing values or no link
; use Swap=0. Returns false for an unknown named preset; otherwise updates
; preset globals, clears $dirty and returns true.
func LoadPreset($name, $mode="")
	local $path = GetIniPath()
	if not PresetExists($name) then return false
	$range_db = Number(IniRead($path, $name, "Range_" & $profile_monitor_name, "18"))
	if StringInStr("|3|6|12|18|24|", "|" & $range_db & "|") = 0 then $range_db = 18
	ClearSliderUndo()
	if $mode = "" then $mode = IniRead($path, $name, "Mode_" & $profile_monitor_name, IniRead($path, $name, "Mode", "10band"))
	local $section = $name & "_" & $profile_monitor_name & "_" & $mode
	$preset_name = $name
	$preset_mode = $MODE_GRAPHIC
	if $mode = $MODE_PARAMETRIC then $preset_mode = $MODE_PARAMETRIC
	local $profile_saved_count = IniRead($path, $section, "BandCount", "")
	local $profile_default_count = Int($mode)
	if $mode = $MODE_PARAMETRIC then $profile_default_count = UBound($NEW_FREQ)
	$band_count = Int(IniRead($path, $section, "BandCount", String($profile_default_count)))
	if $band_count < 1 then $band_count = 10
	if $band_count > $MAX_PARAM_BANDS then $band_count = $MAX_PARAM_BANDS
	if $preset_mode = $MODE_GRAPHIC then $graphic_count = $band_count
	$preamp = CapGain(IniRead($path, $section, "Preamp", "0"))
	local $swap_output = IniRead($path, $name, "Output_" & $profile_monitor_name, "")
	$swap = 0
	if $swap_output <> "" then $swap = Int(IniRead($path, $OUTPUT_SWAP_SECTION, $swap_output, "0"))
	local $table = GraphicTable($band_count)
	local $index = 0
	while $index < $band_count
		if $preset_mode = $MODE_GRAPHIC and $table <> "" then
			$band_freq[$index] = TableFreq($table, $index)
		else
			local $profile_default_freq = 1000
			if $index < UBound($NEW_FREQ) then $profile_default_freq = $NEW_FREQ[$index]
			$band_freq[$index] = Number(IniRead($path, $section, "Band" & $index & "_Freq", String($profile_default_freq)))
		endif
		$band_gain[$index] = CapGain(IniRead($path, $section, "Band" & $index & "_Gain", "0"))
		$index += 1
	wend
	$param_count = Int(IniRead($path, $section, "ParamCount", "0"))
	if $param_count < 0 or $param_count > $MAX_PARAM_BANDS then $param_count = 0
	for $i = 0 to $param_count - 1
		$param_freq[$i] = Number(IniRead($path, $section, "Param" & $i & "_Freq", "1000"))
		$param_gain[$i] = CapGain(IniRead($path, $section, "Param" & $i & "_Gain", "0"))
	next
	if $preset_mode = $MODE_PARAMETRIC then
		if $profile_saved_count = "" then SortBands()
		CaptureParametric()
	endif

	$dirty = false
	return true
endfunc

; Distinguishes named presets from monitor/mode storage sections.
; Reads the supplied section name in the INI. Returns true exactly when its
; Preset key is 1; returns false otherwise. Does not create or modify keys.
func PresetExists($name)
	return IniRead(GetIniPath(), $name, "Preset", "") = "1"
endfunc

; Deletes a confirmed preset and all curve sections owned by that name.
; Reads preset globals, GetIniPath() and PresetName backlinks. Removes owned
; sections before the preset metadata; a read/delete failure reports an error
; and retains the metadata. Earlier successful deletions are not rolled back.
; Keeps at least one preset. Loads [@EQ] PreviousPreset if it exists and
; differs from the deleted preset; otherwise selects the first other preset.
; Refreshes controls and playback after success. Returns no value.
func OnDeletePreset()
	local $names = StringSplit(StringTrimRight(LoadPresetNames(), 1), "|")
	if $names[0] < 2 then
		GUICtrlSetData($status_label, "Keep at least one preset. Save another preset before deleting this one.")
		return
	endif
	local $replacement = IniRead(GetIniPath(), $APP_NAME, $PREVIOUS_PRESET_KEY, "")
	if $replacement = $preset_name or not PresetExists($replacement) then $replacement = ""
	for $i = 1 to $names[0]
		if $replacement <> "" then exitloop
		if $names[$i] <> $preset_name then
			$replacement = $names[$i]
			exitloop
		endif
	next
	local $deleted = $preset_name
	local $path = GetIniPath()
	InputDialog("Delete preset", 'Permanently delete preset "' & $deleted & '"?' & @LF & @LF & "Its saved EQ settings cannot be recovered.", "", default, default, true)
	if @error then return
	local $delete_sections = IniReadSectionNames($path)
	local $delete_saved = not @error
	if $delete_saved then
		for $delete_index = 1 to $delete_sections[0]
			if IniRead($path, $delete_sections[$delete_index], "PresetName", "") <> $deleted then continueloop
			if not IniDelete($path, $delete_sections[$delete_index]) then
				$delete_saved = false
				exitloop
			endif
		next
	endif
	if $delete_saved then $delete_saved = IniDelete($path, $deleted)
	if not $delete_saved then
		GUICtrlSetData($status_label, "Could not delete preset " & $deleted)
		return
	endif
	LoadPreset($replacement)
	$autosave_armed = 0
	RefreshTopControls()
	RebuildBandGrid()
	ActivatePreset()
	GUICtrlSetData($status_label, "Deleted preset " & $deleted)
endfunc

; Returns the frequency table name for a graphic band count: F5,
; F10 or F15. Reads nothing else. Returns "" for other counts,
; which marks the preset as parametric shaped.
func GraphicTable($count)
	if $count = 5 then return "F5"
	if $count = 10 then return "F10"
	if $count = 15 then return "F15"
	return ""
endfunc

; Returns one frequency from a named graphic table. Reads the
; $FREQ_5/$FREQ_10/$FREQ_15 constants. Returns 1000 when the
; table or index is unknown. Keeps ISO values in one place.
func TableFreq($table, $index)
	if $table = "F5" and $index >= 0 and $index < 5 then return $FREQ_5[$index]
	if $table = "F10" and $index >= 0 and $index < 10 then return $FREQ_10[$index]
	if $table = "F15" and $index >= 0 and $index < 15 then return $FREQ_15[$index]
	return 1000
endfunc

; Saves EQ edits for the selected preset, monitor and band mode.
; Reads preset globals, $profile_monitor_name and parametric input controls.
; Writes mode metadata in [preset] and EQ with a PresetName backlink in
; [preset_monitor_mode] for import/export. Writes Swap in OUTPUT_SWAP_SECTION
; keyed by the linked output endpoint; an unlinked monitor writes no Swap.
; With no selected monitor, writes metadata only. Returns true, clears
; $dirty after saving EQ and signals the listener.
func SavePreset()
	local $path = GetIniPath()
	local $profile_mode = $MODE_PARAMETRIC
	if $preset_mode = $MODE_GRAPHIC then $profile_mode = $band_count & "band"
	IniWrite($path, $preset_name, "Preset", "1")
	IniWrite($path, $preset_name, "Mode", $profile_mode)
	if $profile_monitor_name = "" then return true
	IniWrite($path, $preset_name, "Mode_" & $profile_monitor_name, $profile_mode)
	local $swap_output = IniRead($path, $preset_name, "Output_" & $profile_monitor_name, "")
	if $swap_output <> "" then IniWrite($path, $OUTPUT_SWAP_SECTION, $swap_output, $swap)
	local $section = $preset_name & "_" & $profile_monitor_name & "_" & $profile_mode
	IniWrite($path, $section, "PresetName", $preset_name)
	ReadParamBoxes()
	if $preset_mode = $MODE_PARAMETRIC then
		local $tip_index = 0
		while $tip_index < $band_count
			RefreshBandGain($tip_index)
			$tip_index += 1
		wend
	endif
	IniWrite($path, $section, "Mode", $preset_mode)
	IniWrite($path, $section, "BandCount", $band_count)
	IniWrite($path, $section, "Preamp", $preamp)
	local $index = 0
	while $index < $band_count
		IniWrite($path, $section, "Band" & $index & "_Freq", $band_freq[$index])
		IniWrite($path, $section, "Band" & $index & "_Gain", $band_gain[$index])
		$index += 1
	wend
	if $preset_mode = $MODE_PARAMETRIC then CaptureParametric()
	IniWrite($path, $section, "ParamCount", $param_count)
	for $i = 0 to $param_count - 1
		IniWrite($path, $section, "Param" & $i & "_Freq", $param_freq[$i])
		IniWrite($path, $section, "Param" & $i & "_Gain", $param_gain[$i])
	next

	$dirty = false
	SignalListener()
	return true
endfunc

; Pokes the listener's reload event after writing settings so
; moves apply at once instead of waiting for its check. Silent
; when no listener runs. Called after preset, link and import
; writes, never for the window rect. No return.
func SignalListener()
	local $open = DllCall("kernel32.dll", "handle", "OpenEventA", "dword", 2, "bool", 0, "str", "Local\@EQReload")
	if @error or $open[0] = 0 then return
	DllCall("kernel32.dll", "bool", "SetEvent", "handle", $open[0])
	DllCall("kernel32.dll", "bool", "CloseHandle", "handle", $open[0])
endfunc

; Moves a valid Parametric frequency edit into order and selects its band.
; Receives the band index and whether Enter should refocus its rebuilt input.
; ReadParamBoxes() rejects duplicate frequencies; rejection leaves the input
; red and the last valid frequency unchanged. Otherwise sorts existing pairs,
; finds the unique edited frequency and rebuilds/highlights that band. Enter
; selects its input text. Marks EQ dirty for normal autosave; writes no file
; directly and returns no value. Called on input commit or Enter.
func CommitBandFrequency($frequency_index, $frequency_refocus=false)
	if $frequency_drag_active >= 0 then return
	if $preset_mode <> $MODE_PARAMETRIC or $frequency_index < 0 or $frequency_index >= $band_count then return
	local $frequency_previous = $band_freq
	if not ReadParamBoxes() then return
	local $frequency_changed = false
	for $frequency_row = 0 to $band_count - 1
		if $frequency_previous[$frequency_row] <> $band_freq[$frequency_row] then $frequency_changed = true
	next
	if not $frequency_changed then return
	local $frequency_value = $band_freq[$frequency_index]
	SortBands()
	local $frequency_selected = 0
	while $band_freq[$frequency_selected] <> $frequency_value
		$frequency_selected += 1
	wend
	CaptureParametric()
	$dirty = true
	RebuildBandGrid()
	SelectSliderBand($frequency_selected, true)
	if $frequency_refocus then
		GUICtrlSetState($freq_ctrl[$frequency_selected], $GUI_FOCUS)
		GUICtrlSendMsg($freq_ctrl[$frequency_selected], $EM_SETSEL, 0, -1)
	endif
endfunc

; Reads Parametric frequency edits without accepting duplicate frequencies.
; Reads freq_ctrl and band_freq through band_count. Clamps inputs to 20-20000
; Hz. A frequency already used by another band marks its input red, retains
; the last valid frequency and contributes false to the result. Valid inputs
; restore the system text colour and update band_freq, clearing slider undo
; on a change. Returns true if all inputs were accepted or mode is Graphic;
; false if any duplicate was rejected. Called before saving/changing controls.
func ReadParamBoxes()
	if $preset_mode <> $MODE_PARAMETRIC then return true
	local $frequency_valid = true
	for $index = 0 to $band_count - 1
		if $freq_ctrl[$index] = 0 then continueloop
		local $freq = Number(GUICtrlRead($freq_ctrl[$index]))
		if $freq < 20 then $freq = 20
		if $freq > 20000 then $freq = 20000
		local $frequency_duplicate = false
		for $frequency_other = 0 to $band_count - 1
			if $frequency_other <> $index and $band_freq[$frequency_other] = $freq then
				$frequency_duplicate = true
				exitloop
			endif
		next
		if $frequency_duplicate then
			GUICtrlSetColor($freq_ctrl[$index], $FREQUENCY_INVALID_COLOUR)
			$frequency_valid = false
		else
			GUICtrlSetColor($freq_ctrl[$index], _WinAPI_GetSysColor($COLOR_WINDOWTEXT))
			if $band_freq[$index] <> $freq then ClearSliderUndo()
			$band_freq[$index] = $freq
		endif
	next
	return $frequency_valid
endfunc

; Lists physical monitors once even when Windows repeats adapter records.
; Enumerates monitor DeviceIDs under every display adapter, including
; disconnected monitors, and skips empty or duplicate IDs. Fills the global
; monitor arrays up to their capacity, resolves model names and applies
; list-only aliases. Returns display rows separated by |, or "" if no
; monitors are found. Does not modify stored identities, EQ or Output links.
func FillMonitorArrays()
	local $adapter = DllStructCreate("dword;char[32];char[128];dword;char[128];char[128]")
	local $screen = DllStructCreate("dword;char[32];char[128];dword;char[128];char[128]")
	if @error then return ""
	$monitor_total = 0
	local $rows = ""
	local $a = 0
	while $a < 8
		DllStructSetData($adapter, 1, DllStructGetSize($adapter))
		local $ok = DllCall("user32.dll", "bool", "EnumDisplayDevicesA", "ptr", 0, "dword", $a, "ptr", DllStructGetPtr($adapter), "dword", 0)
		if @error or not $ok[0] then exitloop
		local $adapter_name = DllStructGetData($adapter, 2)
		local $m = 0
		while $m < 8
			DllStructSetData($screen, 1, DllStructGetSize($screen))
			local $found = DllCall("user32.dll", "bool", "EnumDisplayDevicesA", "str", $adapter_name, "dword", $m, "ptr", DllStructGetPtr($screen), "dword", 0)
			if @error or not $found[0] then exitloop
			local $key = DllStructGetData($screen, 5)
			if $profile_monitor = "" and BitAND(DllStructGetData($adapter, 4), $MONITOR_PRIMARY_DEVICE) and BitAND(DllStructGetData($screen, 4), $MONITOR_ACTIVE_DEVICE) then $profile_monitor = $key
			local $monitor_duplicate = false
			for $monitor_existing = 0 to $monitor_total - 1
				if $monitor_key[$monitor_existing] = $key then
					$monitor_duplicate = true
					exitloop
				endif
			next
			if $key <> "" and not $monitor_duplicate and $monitor_total < UBound($monitor_key) then
				local $friendly = DllStructGetData($screen, 3)
				if $friendly = "" then $friendly = $key
				$monitor_key[$monitor_total] = $key
				$monitor_row[$monitor_total] = $friendly & " [" & $key & "]"
				$rows &= $monitor_row[$monitor_total] & "|"
				$monitor_total += 1
			endif
			$m += 1
		wend
		$a += 1
	wend
	$adapter = 0
	$screen = 0
	ResolveMonitorNames()
	$rows = ""
	local $r = 0
	while $r < $monitor_total
		$rows &= MonitorDisplayRow($r) & "|"
		$r += 1
	wend
	return $rows
endfunc

; Decodes a WMI uint16 array holding one ASCII char per
; element up to the first zero. Reads the array object,
; returns the stripped string, "" when empty.
func DecodeWmiString($chars)
	local $out = ""
	for $code in $chars
		if $code = 0 then exitloop
		$out &= Chr(BitAND($code, 255))
	next
	return StringStripWS($out, 3)
endfunc

; Returns the device part of a monitor DeviceID key, the text
; between the first and second backslash (_]C67B7 in
; MONITOR\_]C67B7\...). Reads nothing else. Returns "" when
; the key holds fewer than two backslashes. Pairs WMI monitor
; entries, whose InstanceName carries the same device part,
; with EnumDisplayDevices keys.
func MonitorDevicePart($key)
	local $first = StringInStr($key, "\")
	if $first = 0 then return ""
	local $second = StringInStr($key, "\", 0, 1, $first + 1)
	if $second = 0 then return ""
	return StringMid($key, $first + 1, $second - $first - 1)
endfunc

; Queries WMI WmiMonitorID once and swaps the panel model name
; from EDID (UserFriendlyName) into rows still showing
; Generic PnP Monitor. Matches entries to keys by device part.
; Rows with a real driver name keep it. No match or no WMI
; leaves the row untouched. No return.
func ResolveMonitorNames()
	local $monitor_wmi_errors = ObjEvent("AutoIt.Error", "OnMonitorWmiError")
	if not IsObj($monitor_wmi_errors) then return
	local $wmi = ObjGet("winmgmts:\\.\root\wmi")
	if @error or not IsObj($wmi) then return
	local $items = $wmi.ExecQuery("SELECT UserFriendlyName, InstanceName FROM WmiMonitorID")
	if @error or not IsObj($items) then return
	for $item in $items
		if not IsObj($item) then continueloop
		local $monitor_wmi_name = $item.UserFriendlyName
		if @error or not IsArray($monitor_wmi_name) then continueloop
		local $model = DecodeWmiString($monitor_wmi_name)
		if $model = "" then continueLoop
		local $inst = $item.InstanceName
		if @error or not IsString($inst) then continueloop
		local $index = 0
		while $index < $monitor_total
			local $devpart = MonitorDevicePart($monitor_key[$index])
			local $row = $monitor_row[$index]
			local $generic = StringLeft($row, 19) = "Generic PnP Monitor" or StringLeft($row, StringLen($monitor_key[$index])) = $monitor_key[$index]
			if $generic and $devpart <> "" and StringInStr($inst, $devpart) > 0 then $monitor_row[$index] = $model & " [" & $monitor_key[$index] & "]"
			$index += 1
		wend
	next
endfunc

; Allows optional WMI monitor-name lookup to fail without terminating @EQ.
; Receives the COM error object; returns 0 with @error set to its error number.
; ResolveMonitorNames() registers this callback only for its own lifetime and
; checks failed calls before using their results. Reads no globals.
func OnMonitorWmiError($monitor_wmi_error)
	return SetError($monitor_wmi_error.number, 0, 0)
endfunc

; Returns the selected Monitor row's DeviceID without matching display names.
; Reads monitor_list, monitor_total and monitor_key. Returns "" when no valid
; row is selected. Used by selection, renaming and output-link commands.
func MonitorKey()
	local $monitor_selected = _GUICtrlListView_GetNextItem($monitor_list)
	if $monitor_selected < 0 or $monitor_selected >= $monitor_total then return ""
	return $monitor_key[$monitor_selected]
endfunc

; Returns the friendly list row for one DeviceID key. Reads
; $monitor_row/$monitor_key. Returns the key itself when no
; row matches, so status lines still show something.
func MonitorRow($key)
	local $index = 0
	while $index < $monitor_total
		if $monitor_key[$index] = $key then return $monitor_row[$index]
		$index += 1
	wend
	return $key
endfunc

; Runs the listener with --list once and fills $speaker_id
; with endpoint IDs plus $speaker_name with the friendly names
; shown in the combo, sets $speaker_total. Returns the names
; as a pipe separated string. IDs never appear on screen, the
; combo shows names only. Keeps endpoint IDs from C++ in one
; place. Applies nonempty [@EQ] aliases keyed by endpoint ID to display
; names only. Sets $speaker_default_id to Windows' multimedia default endpoint ID,
; or "" if unavailable. Returns "" when the listener binary is missing.
func FillSpeakerArrays()
	$speaker_total = 0
	$speaker_default_id = ""
	local $exe = @ScriptDir & "\" & $LISTENER_EXE
	if not FileExists($exe) then return ""
	local $text = ""
	local $speaker_queries[2] = ["--list", "--default"]
	for $speaker_query in $speaker_queries
		local $pid = Run('"' & $exe & '" ' & $speaker_query, @ScriptDir, @SW_HIDE, $STDOUT_CHILD)
		if @error then return ""
		while 1
			local $chunk = StdoutRead($pid)
			if @error then exitloop
			$text &= $chunk
			if $chunk = "" then sleep(50)
		wend
		ProcessClose($pid)
		$text &= @LF
	next
	local $names = ""
	local $lines = StringSplit(StringStripCR($text), @LF, 1)
	local $index = 1
	while $index <= $lines[0]
		local $line = StringStripWS($lines[$index], 3)
		if StringLeft($line, StringLen($SPEAKER_DEFAULT_PREFIX)) = $SPEAKER_DEFAULT_PREFIX then $speaker_default_id = StringTrimLeft($line, StringLen($SPEAKER_DEFAULT_PREFIX))
		if $line <> "" then
			local $bar = StringInStr($line, "|")
			if $bar > 1 and $speaker_total < 32 then
				local $id = StringLeft($line, $bar - 1)
				local $known = false
				local $scan = 0
				while $scan < $speaker_total
					if $speaker_id[$scan] = $id then $known = true
					$scan += 1
				wend
				if not $known then
					$speaker_id[$speaker_total] = $id
					$speaker_windows_name[$speaker_total] = StringTrimLeft($line, $bar)
					local $output_alias = IniRead(GetIniPath(), $APP_NAME, $id, "")
					if $output_alias = "" then $output_alias = $speaker_windows_name[$speaker_total]
					$speaker_name[$speaker_total] = $output_alias
					$names &= $speaker_name[$speaker_total] & "|"
					$speaker_total += 1
				endif
			endif
		endif
		$index += 1
	wend
	return $names
endfunc

; Returns the endpoint ID for one friendly speaker name shown
; in the combo. Reads $speaker_id/$speaker_name. Returns ""
; when the name matches nothing.
func SpeakerIdFromName($name)
	local $index = 0
	while $index < $speaker_total
		if $speaker_name[$index] = $name then return $speaker_id[$index]
		$index += 1
	wend
	return ""
endfunc

; Returns the friendly speaker name for one endpoint ID.
; Reads $speaker_id/$speaker_name. Returns the id itself when
; the name is unknown, so status lines still show something.
func SpeakerNameFromId($id)
	local $index = 0
	while $index < $speaker_total
		if $speaker_id[$index] = $id then return $speaker_name[$index]
		$index += 1
	wend
	return $id
endfunc

; Refills Output names while retaining the requested endpoint selection.
; Reads the endpoint ID parameter and speaker_list. FillSpeakerArrays() queries
; Windows and applies [@EQ] endpoint aliases. Empty endpoint selects Windows'
; default output for display only; writes no audio link. Updates the global
; speaker arrays and combo, then returns no value. Used by ShowBinding() and
; output renaming so a pending, unlinked selection survives a name change.
func RefreshOutputList($output_selected)
	local $output_rows = FillSpeakerArrays()
	if $output_selected = "" then $output_selected = $speaker_default_id
	GUICtrlSetData($speaker_list, "")
	GUICtrlSetData($speaker_list, $output_rows)
	for $output_index = 0 to $speaker_total - 1
		if $speaker_id[$output_index] <> $output_selected then continueloop
		GUICtrlSendMsg($speaker_list, $CB_SETCURSEL, $output_index, 0)
		exitloop
	next
	UpdateOutputTooltip()
endfunc

; Shows the selected output's alias and underlying Windows name together.
; Reads speaker_list's selection index, speaker_name and speaker_windows_name.
; Sets a two-line tooltip when the names differ, otherwise shows the Windows
; name alone. With no selection, uses OUTPUT_LIST_TIP. Writes no settings and
; returns no value. Called after list refresh and Output selection changes.
func UpdateOutputTooltip()
	local $output_tip_index = GUICtrlSendMsg($speaker_list, $CB_GETCURSEL, 0, 0)
	local $output_tip = $OUTPUT_LIST_TIP
	if $output_tip_index >= 0 and $output_tip_index < $speaker_total then
		$output_tip = $speaker_name[$output_tip_index]
		if $speaker_name[$output_tip_index] <> $speaker_windows_name[$output_tip_index] then $output_tip &= @LF & $speaker_windows_name[$output_tip_index]
	endif
	GUICtrlSetTip($speaker_list, $output_tip)
endfunc

; Changes only the selected output's displayed name, preserving its endpoint ID.
; Reads the combo selection index, speaker arrays and [@EQ] alias keyed by ID.
; Prompts for a name; an empty value restores Windows' name by writing an empty
; alias. Cancel, |, linefeeds and another output's displayed name write nothing.
; Refreshes names and the Link button without changing presets, EQ or output
; links. Returns no value; called by the Output combo's Rename Output menu.
func OnRenameOutput()
	local $output_index = GUICtrlSendMsg($speaker_list, $CB_GETCURSEL, 0, 0)
	if $output_index < 0 or $output_index >= $speaker_total then return
	local $output_identity = $speaker_id[$output_index]
	local $output_alias = InputDialog("Rename Output", "Output name (empty restores original):", IniRead(GetIniPath(), $APP_NAME, $output_identity, ""), default, default)
	if @error then return
	$output_alias = StringStripWS($output_alias, $STR_STRIP_ENDS)
	if StringRegExp($output_alias, "[|\r\n]") then return
	for $output_scan = 0 to $speaker_total - 1
		if $speaker_id[$output_scan] <> $output_identity and $output_alias <> "" and $speaker_name[$output_scan] = $output_alias then
			GUICtrlSetData($status_label, "That Output name is already in use")
			return
		endif
	next
	if not IniWrite(GetIniPath(), $APP_NAME, $output_identity, $output_alias) then return
	RefreshOutputList($output_identity)
	UpdateLinkButton()
endfunc

; Deletes the band grid controls from the previous preset view.
; Sweeps all allocated slider slots and labels, never just the
; current count, so shrinking the band count leaks no tail
; controls. No return. Called before every rebuild.
func ClearBandGrid()
	EndSliderGesture()
	$frequency_delete_pending = -1
	local $index = 0
	while $index < $MAX_PARAM_BANDS
		if $gain_ctrl[$index] <> 0 then
			GUICtrlDelete($gain_ctrl[$index])
		endif
		if $frequency_thumb_ctrl[$index] <> 0 then GUICtrlDelete($frequency_thumb_ctrl[$index])
		$frequency_thumb_ctrl[$index] = 0
		$frequency_thumb_handles[$index] = 0
		$slider_gesture_selected[$index] = false
		$slider_gesture_tooltips_dirty[$index] = false
		if $gain_value[$index] <> 0 then GUICtrlDelete($gain_value[$index])
		if $freq_ctrl[$index] <> 0 then GUICtrlDelete($freq_ctrl[$index])
		if $remove_ctrl[$index] <> 0 then GUICtrlDelete($remove_ctrl[$index])
		if $band_tag[$index] <> 0 then GUICtrlDelete($band_tag[$index])
		$gain_ctrl[$index] = 0
		$gain_value[$index] = 0
		$freq_ctrl[$index] = 0
		$remove_ctrl[$index] = 0
		$band_tag[$index] = 0
		$index += 1
	wend
	$ctrl_count = 0
endfunc

; Returns the minimum client height for the current band mode.
; Reads $preset_mode and layout constants. Returns pixels sufficient for the
; minimum-height sliders, controls below them, two message lines and status.
; Resize and grid rebuilding use this value without depending on stretched
; slider positions, so a previously enlarged window can shrink again.
func GetMinimumClientHeight()
	local $layout_bottom = $GRP_BAND_Y + 18 + 200 + 4 + 14
	if $preset_mode = $MODE_PARAMETRIC then $layout_bottom = $GRP_BAND_Y + 18 + 160 + 4 + 20 + 46
	local $layout_minimum = $SETUP_BOTTOM + 8 + $STATUS_H + 8
	local $layout_bands_minimum = $layout_bottom + 12 + $STATUS_H + 8
	if $layout_bands_minimum > $layout_minimum then $layout_minimum = $layout_bands_minimum
	return $layout_minimum - $BOTTOM_SPACE_REDUCTION + $RESPONSE_HEIGHT_INCREASE
endfunc

; Prevent horizontal resize cursors on the fixed-width editor window.
; Reads $main_gui and Windows' default hit test for the supplied message.
; Returns $HTBORDER for side borders, $HTTOP or $HTBOTTOM for corners, and
; the default hit-test value for other main-window positions. Returns
; $GUI_RUNDEFMSG for other windows or a failed DLL call. Windows calls this
; as the pointer moves; no settings or window dimensions are changed.
func OnWindowResizeHitTest($window, $message, $wparam, $lparam)
	if $window <> $main_gui then return $GUI_RUNDEFMSG
	local $layout_hit = DllCall("user32.dll", "lresult", "DefWindowProcW", "hwnd", $window, "uint", $message, "wparam", $wparam, "lparam", $lparam)
	if @error then return $GUI_RUNDEFMSG
	switch $layout_hit[0]
		case $HTLEFT, $HTRIGHT
			return $HTBORDER
		case $HTTOPLEFT, $HTTOPRIGHT
			return $HTTOP
		case $HTBOTTOMLEFT, $HTBOTTOMRIGHT
			return $HTBOTTOM
	endswitch
	return $layout_hit[0]
endfunc

; Restricts user resizing to height; EQ mode determines window width.
; Reads band count, mode, window rectangle and client size. Sets Windows'
; MINMAXINFO minimum and maximum tracking widths to the required grid width,
; and minimum tracking height to the controls' required height.
; Returns 0 for the main window, $GUI_RUNDEFMSG otherwise. Windows calls this
; during sizing and programmatic window changes.
func OnWindowTrackLimits($window, $message, $wparam, $lparam)
	#forceref $message, $wparam
	if $window <> $main_gui then return $GUI_RUNDEFMSG
	local $layout_outer = WinGetPos($main_gui)
	local $layout_client = WinGetClientSize($main_gui)
	local $layout_limits = DllStructCreate("long reserved_x;long reserved_y;long max_x;long max_y;long pos_x;long pos_y;long min_track_x;long min_track_y;long max_track_x;long max_track_y", $lparam)
	local $layout_minimum_width = $GRP_BAND_X + $band_count * $BAND_CW + $GROUP_GAP + $SETUP_W + 8
	if $preset_mode = $MODE_PARAMETRIC then $layout_minimum_width += $GRP_BAND_PX - $GRP_BAND_X
	if $layout_minimum_width < $TOP_MIN_W then $layout_minimum_width = $TOP_MIN_W
	DllStructSetData($layout_limits, "min_track_x", $layout_minimum_width + $layout_outer[2] - $layout_client[0])
	DllStructSetData($layout_limits, "max_track_x", $layout_minimum_width + $layout_outer[2] - $layout_client[0])
	DllStructSetData($layout_limits, "min_track_y", GetMinimumClientHeight() + $layout_outer[3] - $layout_client[1])
	return 0
endfunc

; Displays one band's actual gain and updates its slider tooltip.
; Reads the band index, gain/frequency arrays, control IDs and $range_db.
; Sets the thumb position, numeric label and tooltip. Windows clips the
; thumb to the selected range; the stored gain remains unchanged until the
; user moves that slider. Returns no value. Used after changes and resets.
func RefreshBandGain($gain_index)
	GUICtrlSetData($gain_ctrl[$gain_index], -Int($band_gain[$gain_index] * 2))
	GUICtrlSetData($gain_value[$gain_index], StringFormat("%.1f", $band_gain[$gain_index]))
	GUICtrlSetTip($gain_ctrl[$gain_index], StringFormat("%.1f dB at %g Hz. ", $band_gain[$gain_index], $band_freq[$gain_index]) & $SLIDER_GESTURE_HINT)
endfunc

; Changes the displayed gain scale without changing saved EQ gains.
; Reads the Range combo, $preset_name and $profile_monitor_name; writes
; Range_<monitor> in [preset] when a monitor is selected. Updates all band
; slider limits and tooltips. Returns no value. Values outside the chosen scale
; remain saved and appear numerically; their thumbs stop at the scale edge.
func OnRangeChange()
	$range_db = Number(GUICtrlRead($range_list))
	if $profile_monitor_name <> "" then IniWrite(GetIniPath(), $preset_name, "Range_" & $profile_monitor_name, $range_db)
	for $range_index = 0 to $ctrl_count - 1
		GUICtrlSetLimit($gain_ctrl[$range_index], $range_db * 2, -$range_db * 2)
		RefreshBandGain($range_index)
	next
	CacheSliderGestureGeometry()
endfunc

; Gets a monitor's list-only display name without changing its identity.
; Reads the array index, physical monitor arrays and [MonitorNames]. Returns
; its nonempty alias or the original list row. The listener and EQ section
; names use [Monitors] instead and never read these aliases.
func MonitorDisplayRow($monitor_index)
	local $monitor_alias = IniRead(GetIniPath(), $APP_NAME, $monitor_key[$monitor_index], "")
	if $monitor_alias <> "" then return $monitor_alias
	return $monitor_row[$monitor_index]
endfunc

; Lets Monitor tooltip text use the screen width despite native width resets.
; Receives native tooltip subclass parameters and reads main_gui and
; monitor_tip_callback. Replaces TTM_SETMAXTIPWIDTH's text limit with the
; screen work-area width minus tooltip borders. Windows retains control of
; placement and sizing. Removes the subclass when the tooltip is destroyed.
; Returns the native default result for every message; writes no settings.
func MonitorTipProc($tip_window, $tip_message, $tip_wparam, $tip_lparam, $tip_subclass, $tip_data)
	#forceref $tip_data
	if $tip_message = $TTM_SETMAXTIPWIDTH then
		local $tip_screen = _WinAPI_GetMonitorInfo(_WinAPI_MonitorFromWindow($main_gui))
		if IsArray($tip_screen) then
			local $tip_work = $tip_screen[1], $tip_border = DllStructCreate($tagRECT)
			_GUIToolTip_AdjustRect($tip_window, $tip_border)
			$tip_lparam = DllStructGetData($tip_work, "Right") - DllStructGetData($tip_work, "Left") - (DllStructGetData($tip_border, "Right") - DllStructGetData($tip_border, "Left"))
		endif
	elseif $tip_message = $WM_NCDESTROY then
		_WinAPI_RemoveWindowSubclass($tip_window, DllCallbackGetPtr($monitor_tip_callback), $tip_subclass)
	endif
	return _WinAPI_DefSubclassProc($tip_window, $tip_message, $tip_wparam, $tip_lparam)
endfunc

; Supplies native Monitor infotips and queues selection changes for the loop.
; Windows passes WM_NOTIFY parameters. Reads monitor arrays and [@EQ] aliases;
; returns the requested row's alias/original name through the Unicode tooltip
; buffer. Monitor tips wrap at the screen work-area width; Windows selects
; their position. Selection sets monitor_selection_changed unless refreshing.
; Returns 0 for handled Monitor notifications and GUI_RUNDEFMSG for other
; Monitor notifications, including context menus. Forwards other controls to
; OnSliderMarksDraw() to preserve native slider drawing.
; Writes no settings and never loads EQ inside a notification callback.
func OnAppNotify($notify_window, $notify_message, $notify_wparam, $notify_lparam)
	local $notify_header = DllStructCreate($tagNMHDR, $notify_lparam)
	local $frequency_draw_result = OnFrequencyThumbDraw($notify_window, $notify_message, $notify_wparam, $notify_lparam)
	if $frequency_draw_result <> $GUI_RUNDEFMSG then return $frequency_draw_result
	if DllStructGetData($notify_header, "hWndFrom") <> GUICtrlGetHandle($monitor_list) then return OnSliderMarksDraw($notify_window, $notify_message, $notify_wparam, $notify_lparam)
	switch DllStructGetData($notify_header, "Code")
		case $LVN_GETINFOTIPW
			_GUIToolTip_SetMaxTipWidth(_GUICtrlListView_GetToolTips($monitor_list), 0)
			local $monitor_info = DllStructCreate($tagNMLVGETINFOTIP, $notify_lparam)
			local $monitor_index = DllStructGetData($monitor_info, "Item")
			if $monitor_index < 0 or $monitor_index >= $monitor_total then return 0
			local $monitor_tip = $monitor_row[$monitor_index]
			local $monitor_alias = IniRead(GetIniPath(), $APP_NAME, $monitor_key[$monitor_index], "")
			if $monitor_alias <> "" then $monitor_tip = $monitor_alias & @LF & $monitor_tip
			local $monitor_buffer = DllStructCreate("wchar[" & DllStructGetData($monitor_info, "TextMax") & "]", DllStructGetData($monitor_info, "Text"))
			DllStructSetData($monitor_buffer, 1, $monitor_tip)
		case $LVN_ITEMCHANGED
			if $monitor_refreshing then return 0
			local $monitor_change = DllStructCreate($tagNMLISTVIEW, $notify_lparam)
			if BitAND(DllStructGetData($monitor_change, "NewState"), $LVIS_SELECTED) and not BitAND(DllStructGetData($monitor_change, "OldState"), $LVIS_SELECTED) then $monitor_selection_changed = true
		case else
			return $GUI_RUNDEFMSG
	endswitch
	return 0
endfunc

; Selects the right-clicked Monitor row using the ListView's native hit test.
; Reads WM_CONTEXTMENU's target handle and invocation type. Mouse invocation
; selects the hit row without loading EQ here; keyboard invocation preserves
; selection. Returns GUI_RUNDEFMSG to open the existing menu; writes no file.
func OnMonitorContextMenu($window, $message, $wparam, $lparam)
	#forceref $window, $message
	if FrequencyThumbContextMenu($wparam) then return 0
	if $wparam <> GUICtrlGetHandle($monitor_list) or $lparam = -1 then return $GUI_RUNDEFMSG
	local $monitor_hit = _GUICtrlListView_HitTest($monitor_list)
	if IsArray($monitor_hit) then
		if $monitor_hit[0] >= 0 then _GUICtrlListView_SetItemSelected($monitor_list, $monitor_hit[0], true, true)
	endif
	return $GUI_RUNDEFMSG
endfunc

; Changes only the selected monitor's name in the Monitor list.
; Reads the selected list row and [MonitorNames]. Prompts for a unique name,
; writes it under the physical DeviceID and refreshes that list. An empty
; name restores the original row. Cancel, duplicate names, | and linefeeds
; leave settings unchanged. Returns no value; does not change audio links.
func OnRenameMonitor()
	local $monitor_identity = MonitorKey()
	if $monitor_identity = "" then return
	local $monitor_alias = InputDialog("Rename Monitor", "Monitor name (empty restores original):", IniRead(GetIniPath(), $APP_NAME, $monitor_identity, ""), default, default)
	if @error then return
	$monitor_alias = StringStripWS($monitor_alias, $STR_STRIP_ENDS)
	if StringRegExp($monitor_alias, "[|\r\n]") then return
	for $monitor_index = 0 to $monitor_total - 1
		if $monitor_key[$monitor_index] <> $monitor_identity and $monitor_alias <> "" and MonitorDisplayRow($monitor_index) = $monitor_alias then
			GUICtrlSetData($status_label, "That Monitor name is already in use")
			return
		endif
	next
	IniWrite(GetIniPath(), $APP_NAME, $monitor_identity, $monitor_alias)
	$profile_monitor = $monitor_identity
	RefreshMonitorList()
endfunc

; Builds fixed-width band columns on the left. Only the grid width
; changes with band count; the right panel keeps its own geometry.
; preserve_undo retains the deletion snapshot; other callers clear it.
func RebuildBandGrid($preserve_undo=false)
	if not $preserve_undo then ClearSliderUndo()
	ClearBandGrid()
	; Fit both directions when the grid changes, including 10 to 5 bands.
	local $size = WinGetClientSize($main_gui)
	local $pos = WinGetPos($main_gui)
	local $width = $GRP_BAND_X + $band_count * $BAND_CW + $GROUP_GAP + $SETUP_W + 8
	if $width < $TOP_MIN_W then $width = $TOP_MIN_W
	local $height = $size[1]
	if $height < GetMinimumClientHeight() then $height = GetMinimumClientHeight()
	WinMove($main_gui, "", $pos[0], $pos[1], $pos[2] + $width - $size[0], $pos[3] + $height - $size[1])
	local $sh = GetBandSliderHeight()
	local $cw = $BAND_CW
	local $top = $GRP_BAND_Y
	$gb = 0
	$gw = 0
	if $preset_mode = $MODE_GRAPHIC then
		local $index = 0
		while $index < $band_count
			local $left = $GRP_BAND_X + $index * $cw
			$band_tag[$index] = GUICtrlCreateLabel(String($band_freq[$index]), $left, $top, $cw, 14)
			$gain_ctrl[$index] = GUICtrlCreateSlider($left + Int(($cw - 26) / 2), $top + 18, 26, $sh, $TBS_VERT)
			GUICtrlSetLimit($gain_ctrl[$index], $range_db * 2, -$range_db * 2)
			GUICtrlSetData($gain_ctrl[$index], -Int($band_gain[$index] * 2))
			GUICtrlSetTip($gain_ctrl[$index], "Band " & $index & " gain at " & $band_freq[$index] & " Hz. Up boosts, down cuts. Saves itself.")
			$gain_value[$index] = GUICtrlCreateLabel(StringFormat("%.1f", $band_gain[$index]), $left, $top + 18 + $sh + 4, $cw, 14)
			GUICtrlSetTip($gain_value[$index], "Band " & $index & " gain value. Click to reset this band to 0 dB.")
			$index += 1
		wend
		$gb = $top + 18 + $sh + 4 + 14
		$gw = $band_count * $BAND_CW
		$ctrl_count = $band_count
		GUICtrlSetState($add_button, $GUI_HIDE)
	else
	local $row = 0
	while $row < $band_count
		$left = $GRP_BAND_PX + $row * $cw
			$gain_ctrl[$row] = GUICtrlCreateSlider($left + Int(($cw - 26) / 2), $top + 18, 26, $sh, $TBS_VERT)
			GUICtrlSetLimit($gain_ctrl[$row], $range_db * 2, -$range_db * 2)
			GUICtrlSetData($gain_ctrl[$row], -Int($band_gain[$row] * 2))
			GUICtrlSetTip($gain_ctrl[$row], "Band " & $row & " gain. Up boosts, down cuts. Frequency sits below. Points define a single GraphicEQ curve. Saves itself.")
			$gain_value[$row] = GUICtrlCreateLabel(StringFormat("%.1f", $band_gain[$row]), $left, $top + 18 + $sh + 4, $cw, 14)
			GUICtrlSetTip($gain_value[$row], "Band " & $row & " gain value. Click to reset this band to 0 dB.")
			$row += 1
		wend
		local $ry = $top + 18 + $sh + 4
	$row = 0
	while $row < $band_count
		local $box = $GRP_BAND_PX + $row * $cw
			$freq_ctrl[$row] = GUICtrlCreateInput(String(Int($band_freq[$row])), $box, $ry, $cw - 4, 22, $ES_NUMBER)
			GUICtrlSetTip($freq_ctrl[$row], "Centre frequency of band " & $row & ", in Hz, 20 to 20000." & @LF & "Input any unused number in that range.")
			$remove_ctrl[$row] = GUICtrlCreateButton("Del", $box, $ry + 24, $cw - 4, 22)
			GUICtrlSetState($remove_ctrl[$row], $GUI_HIDE)
			$frequency_thumb_ctrl[$row] = GUICtrlCreateSlider($box, $ry + 24, $cw - 4, 22, BitOR($TBS_NOTICKS, $TBS_TOP))
			GUICtrlSetLimit($frequency_thumb_ctrl[$row], 1, -1)
			GUICtrlSetData($frequency_thumb_ctrl[$row], 0)
			$frequency_thumb_handles[$row] = GUICtrlGetHandle($frequency_thumb_ctrl[$row])
			GUICtrlSetTip($frequency_thumb_ctrl[$row], "Drag left or right to change frequency. Ctrl-click or right-click to delete this band.")
			GUICtrlSetTip($remove_ctrl[$row], "Delete band " & $row)
			$row += 1
		wend
		$gb = $ry + 46
		$gw = $band_count * $BAND_CW
		$ctrl_count = $band_count
		GUICtrlSetState($add_button, $GUI_SHOW)
	endif
	ApplyLayout()
endfunc

; Moves the right panel as a unit. All member positions and sizes
; are fixed offsets from its origin. AutoIt automatic resizing is off.
func ApplyLayout()
	local $size = WinGetClientSize($main_gui)
	if @error then return
	LayoutBandGroup($GRP_BAND_X, $GRP_BAND_Y)
	LayoutTopGroup($GRP_TOP_X, $GRP_TOP_Y)
	LayoutSetupGroup($size[0] - $SETUP_W - 8, $GRP_SETUP_Y)
	LayoutBandActions($GRP_BAND_X, $gb + 8)
	local $response_left = $size[0] - $SETUP_W - 8
	GUICtrlSetPos($status_label, 10, $size[1] - $STATUS_H + 4, $response_left - 18, 20)
	GUICtrlSetPos($response_picture, $response_left, $RESPONSE_TOP, $SETUP_W, $size[1] - $RESPONSE_TOP - 8)
	; Update AutoIt's stored rectangles before lowering the labels behind controls.
	GUICtrlSetPos($window_drag_top, 0, 0, $size[0], $GRP_BAND_Y)
	GUICtrlSetPos($window_drag_bottom, $GRP_BAND_X, $GRP_BAND_Y, $size[0] - $GRP_BAND_X, $size[1] - $GRP_BAND_Y)
	local $window_drag_flags = BitOR($SWP_NOMOVE, $SWP_NOSIZE, $SWP_NOACTIVATE)
	_WinAPI_SetWindowPos(GUICtrlGetHandle($window_drag_top), $HWND_BOTTOM, 0, 0, 0, 0, $window_drag_flags)
	_WinAPI_SetWindowPos(GUICtrlGetHandle($window_drag_bottom), $HWND_BOTTOM, 0, 0, 0, 0, $window_drag_flags)
	$response_signature = ""
	UpdateResponseGraph()
endfunc

; Display the selected GraphicEQ target including its preamp gain.
; Reads band frequencies/gains, count, preamp, range and picture dimensions.
; Interpolates dB on a logarithmic 20-20000 Hz axis and adds preamp.
; Fills only positive gain between the single response curve and 0 dB.
; Replaces the picture bitmap when its input signature changes and releases
; the preceding bitmap. Called on layout and each editor loop; no return.
func UpdateResponseGraph()
	if $response_picture = 0 or $band_count < 1 then return
	local $response_size = WinGetClientSize(GUICtrlGetHandle($response_picture))
	if @error then return
	local $response_width = $response_size[0], $response_height = $response_size[1]
	if $response_width < 80 or $response_height < 60 then return
	local $response_key = $response_width & ":" & $response_height & ":" & $preamp & ":" & $range_db & ":" & $band_count
	local $response_limit = $range_db
	for $response_index = 0 to $band_count - 1
		$response_key &= ":" & $band_freq[$response_index] & ":" & $band_gain[$response_index]
		if Abs($band_gain[$response_index] + $preamp) > $response_limit then $response_limit = Abs($band_gain[$response_index] + $preamp)
	next
	if $response_key = $response_signature then return
	$response_limit = Ceiling($response_limit / 6) * 6
	if $response_limit < 6 then $response_limit = 6
	local $response_image = _GDIPlus_BitmapCreateFromScan0($response_width, $response_height)
	if not $response_image then return
	local $response_graphics = _GDIPlus_ImageGetGraphicsContext($response_image)
	_GDIPlus_GraphicsClear($response_graphics, $RESPONSE_BG)
	local $response_left = 31, $response_top = 8, $response_right = $response_width - 10, $response_bottom = $response_height - 22
	local $response_plot_width = $response_right - $response_left, $response_plot_height = $response_bottom - $response_top
	local $response_centre = ($response_top + $response_bottom) / 2
	local $response_scale = $response_plot_height / (2 * $response_limit)
	local $response_log_span = Log($RESPONSE_FREQ_MAX / $RESPONSE_FREQ_MIN)
	local $response_grid_pen = _GDIPlus_PenCreate($RESPONSE_GRID)
	local $response_zero_pen = _GDIPlus_PenCreate($RESPONSE_ZERO)
	local $response_total_pen = _GDIPlus_PenCreate($RESPONSE_TOTAL, 1.5)
	local $response_fill_brush = _GDIPlus_BrushCreateSolid($RESPONSE_FILL)
	local $response_sorted = $band_freq
	if $band_count > 1 then _ArraySort($response_sorted, 0, 0, $band_count - 1)
	local $response_points[$band_count + 5][2], $response_point_count = 2
	$response_points[1][0] = $response_left
	$response_points[1][1] = $response_centre
	$response_points[2][0] = $response_left
	$response_points[2][1] = $response_centre - (InterpolateModeGain($band_freq, $band_gain, $band_count, $RESPONSE_FREQ_MIN, false) + $preamp) * $response_scale
	for $response_index = 0 to $band_count - 1
		local $response_frequency = $response_sorted[$response_index]
		if $response_frequency <= $RESPONSE_FREQ_MIN or $response_frequency >= $RESPONSE_FREQ_MAX then continueloop
		if $response_index > 0 and $response_frequency = $response_sorted[$response_index - 1] then continueloop
		$response_point_count += 1
		$response_points[$response_point_count][0] = $response_left + Log($response_frequency / $RESPONSE_FREQ_MIN) / $response_log_span * $response_plot_width
		$response_points[$response_point_count][1] = $response_centre - (InterpolateModeGain($band_freq, $band_gain, $band_count, $response_frequency, false) + $preamp) * $response_scale
	next
	$response_point_count += 1
	$response_points[$response_point_count][0] = $response_right
	$response_points[$response_point_count][1] = $response_centre - (InterpolateModeGain($band_freq, $band_gain, $band_count, $RESPONSE_FREQ_MAX, false) + $preamp) * $response_scale
	$response_point_count += 1
	$response_points[$response_point_count][0] = $response_right
	$response_points[$response_point_count][1] = $response_centre
	$response_points[0][0] = $response_point_count
	_GDIPlus_GraphicsSetClipRect($response_graphics, $response_left, $response_top, $response_plot_width, $response_centre - $response_top)
	_GDIPlus_GraphicsFillPolygon($response_graphics, $response_points, $response_fill_brush)
	_GDIPlus_GraphicsResetClip($response_graphics)
	local $response_frequencies[10] = [20, 50, 100, 200, 500, 1000, 2000, 5000, 10000, 20000]
	local $response_labels[10] = ["20", "", "100", "", "", "1k", "", "", "10k", "20k"]
	for $response_tick = 0 to UBound($response_frequencies) - 1
		local $response_tick_x = $response_left + Log($response_frequencies[$response_tick] / $RESPONSE_FREQ_MIN) / $response_log_span * $response_plot_width
		_GDIPlus_GraphicsDrawLine($response_graphics, $response_tick_x, $response_top, $response_tick_x, $response_bottom, $response_grid_pen)
		if $response_labels[$response_tick] <> "" then _GDIPlus_GraphicsDrawString($response_graphics, $response_labels[$response_tick], _
			$response_tick_x - 10, $response_bottom + 3, $RESPONSE_FONT, 7, default, $RESPONSE_TEXT)
	next
	for $response_tick = -1 to 1
		local $response_tick_y = $response_centre - $response_tick * $response_limit * $response_scale
		_GDIPlus_GraphicsDrawLine($response_graphics, $response_left, $response_tick_y, $response_right, $response_tick_y, $response_grid_pen)
		_GDIPlus_GraphicsDrawString($response_graphics, String($response_tick * $response_limit), 1, $response_tick_y - 7, $RESPONSE_FONT, 7, default, $RESPONSE_TEXT)
	next
	_GDIPlus_GraphicsDrawLine($response_graphics, $response_left, $response_centre, $response_right, $response_centre, $response_zero_pen)
	for $response_index = 3 to $response_point_count - 1
		_GDIPlus_GraphicsDrawLine($response_graphics, $response_points[$response_index - 1][0], $response_points[$response_index - 1][1], _
			$response_points[$response_index][0], $response_points[$response_index][1], $response_total_pen)
	next
	local $response_new_bitmap = _GDIPlus_BitmapCreateHBITMAPFromBitmap($response_image)
	if $response_new_bitmap then
		local $response_old_bitmap = GUICtrlSendMsg($response_picture, $STM_SETIMAGE, $IMAGE_BITMAP, $response_new_bitmap)
		if $response_old_bitmap and $response_old_bitmap <> $response_bitmap then _WinAPI_DeleteObject($response_old_bitmap)
		if $response_bitmap then _WinAPI_DeleteObject($response_bitmap)
		$response_bitmap = $response_new_bitmap
		$response_signature = $response_key
	endif
	_GDIPlus_BrushDispose($response_fill_brush)
	_GDIPlus_PenDispose($response_total_pen)
	_GDIPlus_PenDispose($response_zero_pen)
	_GDIPlus_PenDispose($response_grid_pen)
	_GDIPlus_GraphicsDispose($response_graphics)
	_GDIPlus_ImageDispose($response_image)
endfunc

; Each group has an absolute origin; its members use relative offsets.
func LayoutTopGroup($x, $y)
	GUICtrlSetPos($preset_label, $x, $y + 4, 32, 18)
	GUICtrlSetPos($preset_list, $x + 40, $y, 208, 24)
	GUICtrlSetPos($new_button, $x + 256, $y - 2, 60, 26)
	GUICtrlSetPos($duplicate_button, $x + 324, $y - 2, 72, 26)
	GUICtrlSetPos($delete_button, $x + 404, $y - 2, 60, 26)
	GUICtrlSetPos($mode_list, $x, $y + 34, 80, 24)
	GUICtrlSetPos($range_label, $x + 90, $y + 38, 38, 18)
	GUICtrlSetPos($range_list, $x + 130, $y + 34, 52, 24)
	GUICtrlSetPos($preamp_label, $x + 194, $y + 38, 44, 18)
	GUICtrlSetPos($preamp_slider, $x + 238, $y + 34, 98, 24)
	GUICtrlSetPos($preamp_value, $x + 340, $y + 38, 52, 18)
	GUICtrlSetPos($check_swap, $x + 388, $y + 34, 102, 22)
endfunc

; Calculates the final band-slider height for creation and window layout.
; Reads $main_gui, $preset_mode and layout constants. Returns the slider
; height in pixels: the mode's base height plus available vertical space.
; Called after window sizing by RebuildBandGrid() and LayoutBandGroup();
; creates no controls and writes no settings.
func GetBandSliderHeight()
	local $slider_height = 200
	if $preset_mode = $MODE_PARAMETRIC then $slider_height = 160
	local $slider_size = WinGetClientSize($main_gui)
	return $slider_height + $slider_size[1] - GetMinimumClientHeight() + $RESPONSE_HEIGHT_INCREASE
endfunc

; Position the complete grid after window sizing, including parametric rows.
func LayoutBandGroup($x, $y)
	local $height = GetBandSliderHeight()
	local $offset = 0
	if $preset_mode = $MODE_PARAMETRIC then $offset = $GRP_BAND_PX - $GRP_BAND_X
	local $values_y = $y + 18 + $height + 4
	local $rows_y = $values_y
	for $i = 0 to $ctrl_count - 1
		local $left = $x + $offset + $i * $BAND_CW
		if $band_tag[$i] <> 0 then GUICtrlSetPos($band_tag[$i], $left, $values_y, $BAND_CW, 14)
		GUICtrlSetPos($gain_ctrl[$i], $left + Int(($BAND_CW - 26) / 2), $y + 18, 26, $height)
		RefreshBandGain($i)
		GUICtrlSetPos($gain_value[$i], $left, $y, $BAND_CW, 14)
		if $preset_mode = $MODE_PARAMETRIC then
			GUICtrlSetPos($freq_ctrl[$i], $left, $rows_y, $BAND_CW - 4, 22)
			GUICtrlSetPos($remove_ctrl[$i], $left, $rows_y + 24, $BAND_CW - 4, 22)
			GUICtrlSetPos($frequency_thumb_ctrl[$i], $left, $rows_y + 24, $BAND_CW - 4, 22)
			$frequency_column_left[$i] = $left
			GUICtrlSetState($freq_ctrl[$i], $GUI_SHOW)
			GUICtrlSetState($remove_ctrl[$i], $GUI_HIDE)
		endif
	next
	$gb = $values_y + 14
	if $preset_mode = $MODE_PARAMETRIC then
		$gb = $rows_y + 46
	endif
	CacheSliderGestureGeometry()
	UpdateFrequencyDragModifiers(true)
endfunc

func LayoutBandActions($x, $y)
	GUICtrlSetPos($flat_button, $x, $y, 50, 26)
	GUICtrlSetPos($add_button, $x + 58, $y, 60, 26)
endfunc

func LayoutSetupGroup($x, $y)
	local $col = 116
	local $right = $x + $col + 8
	GUICtrlSetPos($monitor_label, $x, $y, 60, 18)
	GUICtrlSetPos($monitor_list, $x, $y + 14, $SETUP_W, 75)
	GUICtrlSetPos($output_label, $x, $y + 92, 60, 18)
	GUICtrlSetPos($speaker_list, $x, $y + 106, $SETUP_W, 24)
	GUICtrlSetPos($apply_button, $x, $y + 140, $col, 26)
	GUICtrlSetPos($refresh_button, $right, $y + 140, $col, 26)
	GUICtrlSetPos($import_button, $x, $y + 172, $col, 26)
	GUICtrlSetPos($export_button, $right, $y + 172, $col, 26)
	GUICtrlSetPos($start_button, $x, $y + 204, $col, 26)
	GUICtrlSetPos($stop_button, $right, $y + 204, $col, 26)
endfunc

; Fits the layout to a resized window, enforcing the minimum
; size. Called on resize, maximize and restore. Saves the new
; rect. No return.
func OnResize()
	local $pos = WinGetPos($main_gui)
	if @error then return
	local $cli = WinGetClientSize($main_gui)
	if @error then return
	local $nn = $band_count
	if $nn < 1 then $nn = 1
	local $needw = $GRP_BAND_X + $nn * $BAND_CW + 8 + $SETUP_W + 8
	if $preset_mode <> $MODE_GRAPHIC then $needw += ($GRP_BAND_PX - $GRP_BAND_X)
	if $needw < $TOP_MIN_W then $needw = $TOP_MIN_W
	local $needh = GetMinimumClientHeight()
	local $w = $needw + ($pos[2] - $cli[0])
	local $h = $pos[3]
	if $h < $needh + ($pos[3] - $cli[1]) then $h = $needh + ($pos[3] - $cli[1])
	if $h < $MIN_H then $h = $MIN_H
	if $w <> $pos[2] or $h <> $pos[3] then
		WinMove($main_gui, "", $pos[0], $pos[1], $w, $h)
		return
	endif
	local $size = WinGetClientSize($main_gui)
	if @error then return
	if $size[0] = $last_client_w and $size[1] = $last_client_h then return
	$last_client_w = $size[0]
	$last_client_h = $size[1]
	ApplyLayout()
	SaveWindowRect()
endfunc

; Restores access to @EQ when its saved screen is no longer active.
; Reads the supplied window (0 selects main_gui) and active monitor
; rectangles. The main caller runs this after startup grid sizing.
; Returns no value. A window intersecting any active monitor is untouched.
; Otherwise moves it into the nearest monitor's work area without resizing,
; saving through SaveWindowRect() only for the main window when requested.
; Oversized windows align
; to the work area's left or top edge. Failed Windows queries leave it alone.
; Defaults to the main window and saves its rectangle. Dialog callers supply
; a window and restore_save=false to retain their separate position keys.
func RestoreVisibleWindow($restore_window=0, $restore_save=true)
	if $restore_window = 0 then $restore_window = $main_gui
	local $restore_monitor = _WinAPI_MonitorFromWindow($restore_window, $MONITOR_DEFAULTTONULL)
	if @error or $restore_monitor <> 0 then return
	local $restore_position = WinGetPos($restore_window)
	if @error then return
	$restore_monitor = _WinAPI_MonitorFromWindow($restore_window, $MONITOR_DEFAULTTONEAREST)
	if @error or $restore_monitor = 0 then return
	local $restore_info = _WinAPI_GetMonitorInfo($restore_monitor)
	if @error then return
	local $restore_work = $restore_info[1]
	local $restore_x = $restore_position[0], $restore_y = $restore_position[1]
	local $restore_right = DllStructGetData($restore_work, "Right") - $restore_position[2]
	local $restore_bottom = DllStructGetData($restore_work, "Bottom") - $restore_position[3]
	if $restore_x > $restore_right then $restore_x = $restore_right
	if $restore_y > $restore_bottom then $restore_y = $restore_bottom
	if $restore_x < DllStructGetData($restore_work, "Left") then $restore_x = DllStructGetData($restore_work, "Left")
	if $restore_y < DllStructGetData($restore_work, "Top") then $restore_y = DllStructGetData($restore_work, "Top")
	WinMove($restore_window, "", $restore_x, $restore_y)
	if $restore_save and $restore_window = $main_gui then SaveWindowRect()
endfunc

; Stores the outer window rect under [Window] for the next
; launch. Called on resize and exit. Import and export skip
; it, they copy preset sections only. No return.
func SaveWindowRect()
	local $pos = WinGetPos($main_gui)
	if @error then return
	local $path = GetIniPath()
	IniWrite($path, $APP_NAME, "Left", $pos[0])
	IniWrite($path, $APP_NAME, "Top", $pos[1])
	IniWrite($path, $APP_NAME, "Width", $pos[2])
	IniWrite($path, $APP_NAME, "Height", $pos[3])
endfunc

; Refreshes the preset, range, mode and preamp controls after a load.
; Reads preset globals, $swap, $profile_monitor_name and the linked output
; in the INI. Disables Swap when there is no output link. Returns no value;
; writes no settings.
func RefreshTopControls()
	GUICtrlSetData($range_list, "")
	GUICtrlSetData($range_list, $RANGE_CHOICES, $range_db & " dB")
	GUICtrlSetData($preset_list, "")
	GUICtrlSetData($preset_list, LoadPresetNames(), $preset_name)
	local $label = $MODE_GRAPHIC_10
	if $preset_mode = $MODE_PARAMETRIC then
		$label = $MODE_PARAMETRIC
	else
		if $band_count = 5 then $label = $MODE_GRAPHIC_5
		if $band_count = 15 then $label = $MODE_GRAPHIC_15
	endif
	GUICtrlSetData($mode_list, "")
	GUICtrlSetData($mode_list, $MODE_GRAPHIC_5 & "|" & $MODE_GRAPHIC_10 & "|" & $MODE_GRAPHIC_15 & "|" & $MODE_PARAMETRIC, $label)
	GUICtrlSetData($preamp_slider, Int($preamp * 2))
	GUICtrlSetData($preamp_value, StringFormat("%.1f dB", $preamp))
	GUICtrlSetTip($preamp_slider, StringFormat("%.1f dB Preamp", $preamp))
	if IniRead(GetIniPath(), $preset_name, "Output_" & $profile_monitor_name, "") = "" then
		GUICtrlSetState($check_swap, $GUI_DISABLE)
	else
		GUICtrlSetState($check_swap, $GUI_ENABLE)
	endif
	if $swap then
		GUICtrlSetState($check_swap, $GUI_CHECKED)
	else
		GUICtrlSetState($check_swap, $GUI_UNCHECKED)
	endif
endfunc

; Loads one row per physical screen into the monitor list and
; selects the first one. Reads $monitor_key/$monitor_row via
; FillMonitorArrays. Sorts by displayed name with matching identities and
; original tooltip rows. Shows the selected screen's binding afterwards.
func RefreshMonitorList()
	$monitor_refreshing = true
	$monitor_selection_changed = false
	local $selected_monitor = $profile_monitor
	FillMonitorArrays()
	if $monitor_total > 1 then
		local $monitor_sorted[$monitor_total][3]
		for $monitor_index = 0 to $monitor_total - 1
			$monitor_sorted[$monitor_index][0] = MonitorDisplayRow($monitor_index)
			$monitor_sorted[$monitor_index][1] = $monitor_key[$monitor_index]
			$monitor_sorted[$monitor_index][2] = $monitor_row[$monitor_index]
		next
		_ArraySort($monitor_sorted)
		for $monitor_index = 0 to $monitor_total - 1
			$monitor_key[$monitor_index] = $monitor_sorted[$monitor_index][1]
			$monitor_row[$monitor_index] = $monitor_sorted[$monitor_index][2]
		next
	endif
	_GUICtrlListView_DeleteAllItems($monitor_list)
	local $selected_row = -1
	for $monitor_index = 0 to $monitor_total - 1
		GUICtrlCreateListViewItem(MonitorDisplayRow($monitor_index), $monitor_list)
		if $monitor_key[$monitor_index] = $selected_monitor then $selected_row = $monitor_index
	next
	if $selected_row < 0 and $monitor_total > 0 then $selected_row = 0
	if $selected_row >= 0 then _GUICtrlListView_SetItemSelected($monitor_list, $selected_row, true, true)
	_GUICtrlListView_SetColumnWidth($monitor_list, 0, $LVSCW_AUTOSIZE_USEHEADER)
	$monitor_refreshing = false
	if $selected_row >= 0 then ShowBinding($monitor_key[$selected_row])
	UpdateLinkButton()
endfunc

; Displays monitor EQ and selects its linked Output or Windows' default.
; Reads the DeviceID parameter, preset globals and INI. Saves pending edits,
; assigns a stable readable name in [Monitors] if absent, and loads that
; monitor's values for the current mode or flat defaults. Refreshes the
; controls and setup message. Saves the selected DeviceID as
; [@EQ] SelectedMonitor only when its saved value differs. A default
; selection creates no link. Returns no value; creates no presets or links.
; Selection changes editing only; the listener follows Windows' primary.
func ShowBinding($monitor)
	if $dirty then SavePreset()
	local $path = GetIniPath()
	if IniRead($path, $APP_NAME, $SELECTED_MONITOR_KEY, "") <> $monitor then IniWrite($path, $APP_NAME, $SELECTED_MONITOR_KEY, $monitor)
	$profile_monitor = $monitor
	$profile_monitor_name = IniRead($path, "Monitors", $monitor, "")
	if $profile_monitor_name = "" then
		local $profile_row = MonitorRow($monitor)
		local $profile_split = StringInStr($profile_row, " [")
		if $profile_split > 0 then $profile_row = StringLeft($profile_row, $profile_split - 1)
		local $profile_base = StringRegExpReplace($profile_row, "[\[\]\r\n|=]", "")
		$profile_monitor_name = $profile_base
		local $profile_names = IniReadSection($path, "Monitors")
		if not @error then
			local $profile_suffix = 2, $profile_unique = false
			while not $profile_unique
				$profile_unique = true
				for $profile_index = 1 to $profile_names[0][0]
					if $profile_names[$profile_index][1] = $profile_monitor_name then $profile_unique = false
				next
				if not $profile_unique then
					$profile_monitor_name = $profile_base & " " & $profile_suffix
					$profile_suffix += 1
				endif
			wend
		endif
		IniWrite($path, "Monitors", $monitor, $profile_monitor_name)
	endif
	local $preset = $preset_name
	local $profile_selected_mode = $MODE_PARAMETRIC
	if $preset_mode = $MODE_GRAPHIC then $profile_selected_mode = $band_count & "band"
	LoadPreset($preset, $profile_selected_mode)
	$autosave_armed = 0
	RefreshTopControls()
	RebuildBandGrid()
	local $linked_endpoint = IniRead($path, $preset_name, "Output_" & $profile_monitor_name, "")
	RefreshOutputList($linked_endpoint)
	local $endpoint = $linked_endpoint
	if $endpoint = "" then $endpoint = $speaker_default_id
	if $linked_endpoint = "" then
		WinSetTitle($main_gui, "", $LINK_WARNING_TITLE)
		if not $link_warning_visible then
			$link_warning_visible = true
			$link_warning_text_visible = true
			$link_warning_timer = TimerInit()
			AdlibRegister($LINK_WARNING_CALLBACK, $LINK_WARNING_FLASH_INTERVAL)
		endif
	else
		AdlibUnRegister($LINK_WARNING_CALLBACK)
		$link_warning_timer = 0
		$link_warning_visible = false
		WinSetTitle($main_gui, "", $APP_NAME)
	endif
	GUICtrlSetData($status_label, $profile_monitor_name & ": " & $preset & " / " & SpeakerNameFromId($endpoint))
	UpdateLinkButton()
endfunc

; Blinks only the warning text, then leaves the complete title visible.
; Reads main_gui, link_warning_timer and link_warning_text_visible. Adlib
; calls this every LINK_WARNING_FLASH_INTERVAL milliseconds. Alternates
; APP_NAME and LINK_WARNING_TITLE until LINK_WARNING_FLASH_DURATION elapses,
; then restores LINK_WARNING_TITLE and unregisters itself. Returns no value;
; changes no window colours, activation state or settings.
func BlinkLinkWarning()
	if TimerDiff($link_warning_timer) >= $LINK_WARNING_FLASH_DURATION then
		AdlibUnRegister($LINK_WARNING_CALLBACK)
		$link_warning_timer = 0
		$link_warning_text_visible = true
	else
		$link_warning_text_visible = not $link_warning_text_visible
	endif
	local $link_warning_caption = $APP_NAME
	if $link_warning_text_visible then $link_warning_caption = $LINK_WARNING_TITLE
	if $frequency_drag_active >= 0 then return
	WinSetTitle($main_gui, "", $link_warning_caption)
endfunc

; Estimates a slider gain at a frequency between existing band positions.
; Reads frequency and gain arrays, their populated count and the target Hz.
; Returns the nearest endpoint gain outside the source range, or a linear
; interpolation of gain in dB against logarithmic frequency between the two
; nearest surrounding bands. Input frequencies must be positive. Source
; arrays need not be sorted. Interpolated results round to 0.5 dB unless
; mode_round is false; endpoint gains retain their exact values. For
; repeated frequencies, the last array entry wins, matching the listener.
; Used for first-use mode curves and the unrounded GraphicEQ response graph.
func InterpolateModeGain(const byref $mode_freq, const byref $mode_gain, $mode_count, $mode_target, $mode_round=true)
	local $mode_lower = -1, $mode_upper = -1
	for $mode_index = 0 to $mode_count - 1
		if $mode_freq[$mode_index] <= $mode_target then
			if $mode_lower = -1 then
				$mode_lower = $mode_index
			elseif $mode_freq[$mode_index] >= $mode_freq[$mode_lower] then
				$mode_lower = $mode_index
			endif
		endif
		if $mode_freq[$mode_index] >= $mode_target then
			if $mode_upper = -1 then
				$mode_upper = $mode_index
			elseif $mode_freq[$mode_index] <= $mode_freq[$mode_upper] then
				$mode_upper = $mode_index
			endif
		endif
	next
	if $mode_lower = -1 then return $mode_gain[$mode_upper]
	if $mode_upper = -1 then return $mode_gain[$mode_lower]
	if $mode_freq[$mode_lower] = $mode_freq[$mode_upper] then return $mode_gain[$mode_lower]
	local $mode_fraction = Log($mode_target / $mode_freq[$mode_lower]) / Log($mode_freq[$mode_upper] / $mode_freq[$mode_lower])
	local $mode_result = $mode_gain[$mode_lower] + ($mode_gain[$mode_upper] - $mode_gain[$mode_lower]) * $mode_fraction
	if not $mode_round then return $mode_result
	return Round($mode_result * 2) / 2
endfunc

; Loads a mode's layout and copies a nonflat source into a flat destination.
; Reads the Mode combo and preset/monitor globals. Saves pending EQ edits,
; captures source frequencies, gains and preamp, then uses LoadPreset() for
; the destination's saved layout or defaults. Interpolates only if a source
; gain is nonzero and every destination gain is zero. Retains destination
; frequencies and band count; unsaved Parametric uses NEW_FREQ through
; LoadPreset(). Saved destination preamp is retained; an unsaved mode uses
; source preamp. Updates parametric point arrays after interpolation. Clears
; dirty and the autosave timer, then rebuilds controls. Returns no value.
; Conversion writes no settings and does not delete INI sections.
func OnModeChange()
	local $choice = GUICtrlRead($mode_list)
	if $dirty then SavePreset()
	local $mode_source_freq = $band_freq, $mode_source_gain = $band_gain
	local $mode_source_count = $band_count, $mode_source_preamp = $preamp
	local $mode_recalculate = false
	for $mode_gain_index = 0 to $mode_source_count - 1
		if $mode_source_gain[$mode_gain_index] <> 0 then
			$mode_recalculate = true
			exitloop
		endif
	next
	local $profile_mode = $MODE_PARAMETRIC
	if $choice = $MODE_GRAPHIC_5 then $profile_mode = "5band"
	if $choice = $MODE_GRAPHIC_10 then $profile_mode = "10band"
	if $choice = $MODE_GRAPHIC_15 then $profile_mode = "15band"
	local $path = GetIniPath()
	local $section = $preset_name & "_" & $profile_monitor_name & "_" & $profile_mode
	local $mode_destination_saved = IniRead($path, $section, "BandCount", "") <> ""
	LoadPreset($preset_name, $profile_mode)
	if not $mode_destination_saved then $preamp = $mode_source_preamp
	if $mode_recalculate then
		for $mode_gain_index = 0 to $band_count - 1
			if $band_gain[$mode_gain_index] <> 0 then
				$mode_recalculate = false
				exitloop
			endif
		next
	endif
	if $mode_recalculate then
		for $mode_gain_index = 0 to $band_count - 1
			$band_gain[$mode_gain_index] = InterpolateModeGain($mode_source_freq, $mode_source_gain, $mode_source_count, $band_freq[$mode_gain_index])
		next
		if $preset_mode = $MODE_PARAMETRIC then CaptureParametric()
	endif
	$dirty = false
	$autosave_armed = 0
	RebuildBandGrid()
endfunc

; Zero selected gain sliders, or all gains and preamp with no selection.
; Reads band gains, selection flags and control IDs. Retains frequencies and
; selection; updates controls without rebuilding the grid. Marks EQ dirty
; for the existing autosave path. Records one undo snapshot if any target
; gain or preamp changes. Called by Flat; returns no value.
func FlatPreset()
	FinishSliderUndoAction()
	local $flat_selection = false
	for $flat_index = 0 to $band_count - 1
		if $slider_gesture_selected[$flat_index] then $flat_selection = true
	next
	local $index = 0
	while $index < $band_count
		if not $flat_selection or $slider_gesture_selected[$index] then
			if $band_gain[$index] <> 0 then RecordSliderUndo()
			$band_gain[$index] = 0
			if $gain_ctrl[$index] <> 0 then RefreshBandGain($index)
		endif
		$index += 1
	wend
	$dirty = true
	if $flat_selection then return
	if $preamp <> 0 then RecordSliderUndo()
	$preamp = 0
	GUICtrlSetData($preamp_slider, 0)
	GUICtrlSetData($preamp_value, "0.0 dB")
	GUICtrlSetTip($preamp_slider, StringFormat("%.1f dB Preamp", $preamp))
endfunc

func CaptureParametric()
	$param_count = $band_count
	for $i = 0 to $band_count - 1
		$param_freq[$i] = $band_freq[$i]
		$param_gain[$i] = $band_gain[$i]
	next
endfunc

; Sorts band_freq and band_gain pairs in ascending frequency order.
; Reads band_count, updates the arrays, returns no value and writes no settings.
func SortBands()
	for $i = 1 to $band_count - 1
		local $j = $i
		while $j > 0
			if $band_freq[$j - 1] <= $band_freq[$j] then exitloop
			local $f = $band_freq[$j - 1], $g = $band_gain[$j - 1]
			$band_freq[$j - 1] = $band_freq[$j]
			$band_gain[$j - 1] = $band_gain[$j]
			$band_freq[$j] = $f
			$band_gain[$j] = $g
			$j -= 1
		wend
	next
endfunc

; Shows an OK message or a Yes/No question without a Windows message box.
; Receives title, text, initial left/top coordinates, question flag and owner;
; owner=0 uses main_gui. Saved positions override the initial coordinates.
; Initial position is centred at 25% desktop Y; text determines its height.
; Returns IDOK for OK messages, IDYES for Yes, or IDNO for No/Escape/close on
; questions. No is the default answer. Disables the owner until dismissed,
; then restores its GUI context and focus. Saves its position by title in
; the application INI. Called by preset and startup-task messages/questions.
func MessageBox($message_title, $message_text, $message_left=default, $message_top=default, $message_question=false, $message_parent=0)
	if $message_parent = 0 then $message_parent = $main_gui
	local $message_gui = GUICreate($message_title, $MESSAGE_WIDTH, 120, -1, Int(@DesktopHeight * $DIALOG_Y_FRACTION), BitOR($WS_CAPTION, $WS_SYSMENU), -1, $message_parent)
	local $message_text_width = $MESSAGE_WIDTH - $MESSAGE_MARGIN * 2
	local $message_label = GUICtrlCreateLabel($message_text, $MESSAGE_MARGIN, $MESSAGE_MARGIN, $message_text_width, 1, $SS_NOPREFIX)
	local $message_rect = DllStructCreate($tagRECT)
	DllStructSetData($message_rect, "Right", $message_text_width)
	local $message_dc = _WinAPI_GetDC($message_gui)
	local $message_old_font = _WinAPI_SelectObject($message_dc, GUICtrlSendMsg($message_label, $WM_GETFONT, 0, 0))
	_WinAPI_DrawText($message_dc, $message_text, $message_rect, BitOR($DT_CALCRECT, $DT_WORDBREAK, $DT_NOPREFIX))
	_WinAPI_SelectObject($message_dc, $message_old_font)
	_WinAPI_ReleaseDC($message_gui, $message_dc)
	local $message_text_height = DllStructGetData($message_rect, "Bottom")
	GUICtrlSetPos($message_label, $MESSAGE_MARGIN, $MESSAGE_MARGIN, $message_text_width, $message_text_height)
	local $message_button_y = $message_text_height + $MESSAGE_MARGIN * 2
	local $message_height = $message_button_y + $MESSAGE_BUTTON_HEIGHT + $MESSAGE_MARGIN
	local $message_outer = WinGetPos($message_gui), $message_client = WinGetClientSize($message_gui)
	WinMove($message_gui, "", $message_outer[0], $message_outer[1], default, $message_height + $message_outer[3] - $message_client[1])
	local $message_button_x = $MESSAGE_WIDTH - $MESSAGE_MARGIN - $MESSAGE_BUTTON_WIDTH
	local $message_primary_text = "OK", $message_result = $IDOK, $message_yes = 0
	if $message_question then
		$message_primary_text = "No"
		$message_result = $IDNO
		$message_yes = GUICtrlCreateButton("Yes", $message_button_x - $MESSAGE_BUTTON_WIDTH - $MESSAGE_BUTTON_GAP, $message_button_y, $MESSAGE_BUTTON_WIDTH, $MESSAGE_BUTTON_HEIGHT)
	endif
	local $message_default = GUICtrlCreateButton($message_primary_text, $message_button_x, $message_button_y, $MESSAGE_BUTTON_WIDTH, $MESSAGE_BUTTON_HEIGHT)
	GUICtrlSetState($message_default, $GUI_DEFBUTTON)
	local $message_keys[1][2] = [["{ESC}", $message_default]]
	GUISetAccelerators($message_keys, $message_gui)
	GUISetState(@SW_DISABLE, $message_parent)
	LoadDialogPosition("MessageBox_" & $message_title, $message_gui, $message_left, $message_top)
	GUISetState(@SW_SHOW, $message_gui)
	GUICtrlSetState($message_default, $GUI_FOCUS)
	while 1
		local $message_event = GUIGetMsg()
		if $message_event = $GUI_EVENT_CLOSE or $message_event = $message_default then exitloop
		if $message_yes <> 0 and $message_event = $message_yes then
			$message_result = $IDYES
			exitloop
		endif
	wend
	SaveDialogPosition("MessageBox_" & $message_title, $message_gui)
	GUIDelete($message_gui)
	GUISwitch($message_parent)
	GUISetState(@SW_ENABLE, $message_parent)
	WinActivate($message_parent)
	return $message_result
endfunc

; Creates an Input Dialog.
; Gets text input or explicit confirmation in the shared application style.
; Receives title, prompt, initial text, initial left/top coordinates,
; confirmation flag, output-link checkbox flag and its initial checked state.
; Reads main_gui as modal owner; saved positions override initial coordinates.
; OK returns trimmed input, including empty input, or "1" for confirmation,
; with @error=0. Cancel, Escape and close return "" with @error=1. @extended
; reports the link checkbox when offered, otherwise 0. Callers validate the
; returned input. Confirmation defaults to Cancel; text input defaults to OK.
; Saves its position by title in the application INI and restores owner focus.
func InputDialog($input_dialog_title, $input_dialog_prompt, $input_dialog_default="", $input_dialog_left=default, $input_dialog_top=default, $input_dialog_confirm=false, $input_dialog_offer_links=false, $input_dialog_link_default=true)
	local $input_dialog_height = 120
	if $input_dialog_confirm then $input_dialog_height = 104
	local $input_dialog = GUICreate($input_dialog_title, 320, $input_dialog_height, -1, Int(@DesktopHeight * $DIALOG_Y_FRACTION), BitOR($WS_CAPTION, $WS_SYSMENU), -1, $main_gui)
	local $input_dialog_input = 0, $input_dialog_focus = 0
	if $input_dialog_confirm then
		GUICtrlCreateLabel($input_dialog_prompt, 12, 12, 296, $input_dialog_height - 62)
	else
		GUICtrlCreateLabel($input_dialog_prompt, 12, 12, 296, 18)
		$input_dialog_input = GUICtrlCreateInput($input_dialog_default, 12, 36, 296, 24)
	endif
	local $input_dialog_links = 0, $input_dialog_link_selected = 0
	if $input_dialog_offer_links and not $input_dialog_confirm then
		$input_dialog_links = GUICtrlCreateCheckbox("Link current outputs", 12, $input_dialog_height - 38, 124, 26)
		if $input_dialog_link_default then GUICtrlSetState($input_dialog_links, $GUI_CHECKED)
	endif
	local $input_dialog_cancel = GUICtrlCreateButton("Cancel", 140, $input_dialog_height - 38, 80, 26)
	GUICtrlSetResizing(-1, BitOR($GUI_DOCKRIGHT, $GUI_DOCKBOTTOM, $GUI_DOCKSIZE))
	local $input_dialog_ok = GUICtrlCreateButton("OK", 228, $input_dialog_height - 38, 80, 26)
	if $input_dialog_confirm then
		GUICtrlSetState($input_dialog_cancel, $GUI_DEFBUTTON)
		$input_dialog_focus = $input_dialog_cancel
	else
		GUICtrlSetState($input_dialog_ok, $GUI_DEFBUTTON)
		$input_dialog_focus = $input_dialog_input
	endif
	GUICtrlSetResizing(-1, BitOR($GUI_DOCKRIGHT, $GUI_DOCKBOTTOM, $GUI_DOCKSIZE))
	local $input_dialog_keys[1][2] = [["{ESC}", $input_dialog_cancel]]
	GUISetAccelerators($input_dialog_keys, $input_dialog)
	GUISetState(@SW_DISABLE, $main_gui)
	LoadDialogPosition("Input_" & $input_dialog_title, $input_dialog, $input_dialog_left, $input_dialog_top)
	GUISetState(@SW_SHOW, $input_dialog)
	GUICtrlSetState($input_dialog_focus, $GUI_FOCUS)
	if not $input_dialog_confirm then GUICtrlSendMsg($input_dialog_input, $EM_SETSEL, 0, -1)
	local $input_dialog_result = "", $input_dialog_error = 1
	while 1
		local $input_dialog_event = GUIGetMsg()
		if $input_dialog_event = $GUI_EVENT_CLOSE or $input_dialog_event = $input_dialog_cancel then exitloop
		if $input_dialog_event = $input_dialog_ok then
			if $input_dialog_confirm then
				$input_dialog_result = "1"
			else
				$input_dialog_result = StringStripWS(GUICtrlRead($input_dialog_input), $STR_STRIP_ENDS)

			endif
			if $input_dialog_links <> 0 then $input_dialog_link_selected = BitAND(GUICtrlRead($input_dialog_links), $GUI_CHECKED) <> 0
			$input_dialog_error = 0
			exitloop
		endif
	wend
	SaveDialogPosition("Input_" & $input_dialog_title, $input_dialog)
	GUIDelete($input_dialog)
	GUISwitch($main_gui)
	GUISetState(@SW_ENABLE, $main_gui)
	WinActivate($main_gui)
	return SetError($input_dialog_error, $input_dialog_link_selected, $input_dialog_result)
endfunc

; Creates, duplicates or renames a preset while retaining its monitor links.
; Reads preset globals and the INI; saves pending edits before copying or
; renaming metadata and owned monitor/mode sections. Rename changes section
; names, PresetName references and Playback's selected preset in a temporary
; INI beside the original, then replaces the original after all writes succeed.
; Rejects invalid names and section conflicts. Cancel and unchanged names
; write nothing. Loads and activates the result, refreshing controls and EQ.
; Returns no value. New/duplicate buttons and the preset rename menu call it;
; duplicate and rename errors appear in the status label. New presets offer
; checked output linking: copies only Output_<monitor> keys from the source
; metadata after saving the new flat EQ, preserving output-based Swap values.
; The checkbox choice is per dialog and is not saved as a preference.
func OnNewPreset($duplicate=false, $rename=false)
	local $preset_dialog_title = "New preset", $preset_name_default = ""
	if $duplicate then
		$preset_dialog_title = "Duplicate preset"
		$preset_name_default = $preset_name & " copy"
	endif
	if $rename then
		$preset_dialog_title = "Rename preset"
		$preset_name_default = $preset_name
	endif
	local $name = "", $preset_link_outputs = true
	while 1
		$name = InputDialog($preset_dialog_title, "Preset name:", $preset_name_default, default, default, false, not $duplicate and not $rename, $preset_link_outputs)
		if @error then return
		$preset_link_outputs = @extended
		$preset_name_default = $name
		local $preset_name_warning = ""
		local $preset_name_invalid = StringRegExp($name, '[\[\]\r\n|=]', 1)
		if IsArray($preset_name_invalid) then
			local $preset_name_character = $preset_name_invalid[0]
			if $preset_name_character = @CR then $preset_name_character = "carriage return"
			if $preset_name_character = @LF then $preset_name_character = "line break"
			$preset_name_warning = 'You cannot use "' & $preset_name_character & '" in a preset name.'
		elseif $name = "" then
			$preset_name_warning = "Enter a preset name."
		elseif $name = $APP_NAME then
			$preset_name_warning = 'The preset name "' & $APP_NAME & '" is reserved for application settings.'
		endif
		if $preset_name_warning <> "" then
			MessageBox($preset_dialog_title, $preset_name_warning, default, default)
			continueloop
		endif
		exitloop
	wend
	if $rename and $name == $preset_name then return
	if PresetExists($name) and not ($rename and $name = $preset_name) then
		if $duplicate or $rename then
			GUICtrlSetData($status_label, "That preset name already exists: " & $name)
		else
			MessageBox("New preset", "That preset name already exists.", default, default)
		endif
		return
	endif
	if $dirty then SavePreset()
	if $duplicate or $rename then
		local $duplicate_path = GetIniPath()
		local $duplicate_names = IniReadSectionNames($duplicate_path)
		if @error then return
		local $duplicate_plan[$duplicate_names[0] + 1][2], $duplicate_count = 1
		$duplicate_plan[0][0] = $preset_name
		$duplicate_plan[0][1] = $name
		for $duplicate_index = 1 to $duplicate_names[0]
			local $duplicate_section = $duplicate_names[$duplicate_index]
			if IniRead($duplicate_path, $duplicate_section, "PresetName", "") <> $preset_name then continueloop
			if StringLeft($duplicate_section, StringLen($preset_name) + 1) <> $preset_name & "_" then continueloop
			$duplicate_plan[$duplicate_count][0] = $duplicate_section
			$duplicate_plan[$duplicate_count][1] = $name & StringTrimLeft($duplicate_section, StringLen($preset_name))
			$duplicate_count += 1
		next
		for $duplicate_index = 0 to $duplicate_count - 1
			for $duplicate_existing = 1 to $duplicate_names[0]
				if $rename and $duplicate_names[$duplicate_existing] = $duplicate_plan[$duplicate_index][0] then continueloop
				if $duplicate_names[$duplicate_existing] = $duplicate_plan[$duplicate_index][1] then
					GUICtrlSetData($status_label, "Preset name conflicts with saved settings: " & $name)
					return
				endif
			next
		next
		if $rename then
			local $rename_stage = $duplicate_path & ".rename-" & @AutoItPID & ".tmp"
			if not FileCopy($duplicate_path, $rename_stage, $FC_OVERWRITE) then
				GUICtrlSetData($status_label, "Could not prepare preset rename: " & $name)
				return
			endif
			local $rename_saved = true
			for $duplicate_index = 0 to $duplicate_count - 1
				local $rename_source = $duplicate_plan[$duplicate_index][0]
				if $rename_source = $duplicate_plan[$duplicate_index][1] then
					local $rename_intermediate = $rename_source & "_rename_" & @AutoItPID
					for $duplicate_existing = 1 to $duplicate_names[0]
						if $rename_intermediate = $duplicate_names[$duplicate_existing] then
							$rename_intermediate &= "_"
							$duplicate_existing = 0
						endif
					next
					if not IniRenameSection($rename_stage, $rename_source, $rename_intermediate) then
						$rename_saved = false
						exitloop
					endif
					$rename_source = $rename_intermediate
				endif
				if not IniRenameSection($rename_stage, $rename_source, $duplicate_plan[$duplicate_index][1]) then
					$rename_saved = false
					exitloop
				endif
				if IniRead($rename_stage, $duplicate_plan[$duplicate_index][1], "PresetName", "") = $preset_name then
					if not IniWrite($rename_stage, $duplicate_plan[$duplicate_index][1], "PresetName", $name) then
						$rename_saved = false
						exitloop
					endif
				endif
			next
			if $rename_saved and IniRead($rename_stage, "Playback", "Preset", "") = $preset_name then $rename_saved = IniWrite($rename_stage, "Playback", "Preset", $name)
			if $rename_saved and IniRead($rename_stage, $APP_NAME, $PREVIOUS_PRESET_KEY, "") = $preset_name then $rename_saved = IniWrite($rename_stage, $APP_NAME, $PREVIOUS_PRESET_KEY, $name)
			if $rename_saved then
				local $rename_encoding = FileGetEncoding($rename_stage)
				local $rename_text = FileRead($rename_stage)
				if @error then
					$rename_saved = false
				else
					local $rename_file = FileOpen($rename_stage, BitOR($FO_OVERWRITE, $rename_encoding))
					if $rename_file = -1 then
						$rename_saved = false
					else
						$rename_saved = FileWrite($rename_file, StringStripCR($rename_text))
						FileClose($rename_file)
					endif
				endif
			endif
			if $rename_saved then $rename_saved = FileMove($rename_stage, $duplicate_path, $FC_OVERWRITE)
			if not $rename_saved then
				FileDelete($rename_stage)
				GUICtrlSetData($status_label, "Could not save renamed preset: " & $name)
				return
			endif
		else
			for $duplicate_index = 0 to $duplicate_count - 1
				local $duplicate_keys = IniReadSection($duplicate_path, $duplicate_plan[$duplicate_index][0])
				if @error then return
				for $duplicate_key = 1 to $duplicate_keys[0][0]
					if $duplicate_keys[$duplicate_key][0] = "PresetName" then $duplicate_keys[$duplicate_key][1] = $name
				next
				if not IniWriteSection($duplicate_path, $duplicate_plan[$duplicate_index][1], $duplicate_keys) then
					GUICtrlSetData($status_label, "Could not save duplicate preset: " & $name)
					return
				endif
			next
		endif
		LoadPreset($name)
		$autosave_armed = 0
		ActivatePreset()
		if $rename then
			GUICtrlSetData($status_label, "Renamed preset: " & $name)
		else
			GUICtrlSetData($status_label, "Duplicated preset: " & $name)
		endif
		return
	endif
	local $preset_link_keys = 0, $preset_link_path = GetIniPath()
	if $preset_link_outputs then
		$preset_link_keys = IniReadSection($preset_link_path, $preset_name)
		if @error then return
	endif
	ClearBandGrid()
	$preset_name = $name
	$preset_mode = $MODE_PARAMETRIC
	$band_count = UBound($NEW_FREQ)
	$preamp = 0
	$swap = 0
	for $i = 0 to $band_count - 1
		$band_freq[$i] = $NEW_FREQ[$i]
		$band_gain[$i] = 0
	next
	SortBands()
	SavePreset()
	if $preset_link_outputs then
		for $preset_link_index = 1 to $preset_link_keys[0][0]
			if StringLeft($preset_link_keys[$preset_link_index][0], StringLen("Output_")) <> "Output_" then continueloop
			IniWrite($preset_link_path, $name, $preset_link_keys[$preset_link_index][0], $preset_link_keys[$preset_link_index][1])
		next
	endif
	ActivatePreset()
endfunc

; Adds one Parametric band only at an unused frequency within 20-20000 Hz.
; Reads band_freq, band_count, preset_mode and main_gui. Commits pending
; frequency inputs, then suggests a random unused integer Hz value. Invalid
; or duplicate dialog input turns red and disables Add; valid input restores
; its normal colour and enables Add. Accepting appends a zero-gain band,
; sorts and rebuilds the grid, and marks EQ dirty. Cancel, other modes and
; the band limit add nothing. Returns no value. Saves dialog coordinates in
; the application INI, including on Cancel; supplied left/top coordinates
; override the initial position until a position is saved.
func OnAddBand($band_dialog_left=default, $band_dialog_top=default)
	if $preset_mode <> $MODE_PARAMETRIC then return
	if $band_count >= $MAX_PARAM_BANDS then
		GUICtrlSetData($status_label, "Maximum " & $MAX_PARAM_BANDS & " bands. Delete a band before adding another.")
		return
	endif
	ReadParamBoxes()
	local $band_dialog_example = 0
	do
		$band_dialog_example = Random(20, 20000, $BAND_RANDOM_INTEGER)
	until _ArraySearch($band_freq, $band_dialog_example, 0, $band_count - 1) = -1
	local $dialog = GUICreate("Add band", 300, 72, -1, Int(@DesktopHeight * $DIALOG_Y_FRACTION), BitOR($WS_CAPTION, $WS_SYSMENU), -1, $main_gui)
	GUICtrlCreateLabel("Frequency in Hz (20 to 20000):", 12, 12, 276, 18)
	local $freq = GUICtrlCreateCombo("", 12, 36, 100, 24, $CBS_DROPDOWN)
	GUICtrlSetData($freq, "20|25|31|40|50|63|80|100|125|160|200|250|315|400|500|630|800|1000|1250|1600|2000|2500|3150|4000|5000|6300|8000|10000|12500|16000|20000")
	_GUICtrlComboBox_SetEditText($freq, String($band_dialog_example))
	local $cancel = GUICtrlCreateButton("Cancel", 120, 34, 80, 26)
	GUICtrlSetResizing(-1, BitOR($GUI_DOCKRIGHT, $GUI_DOCKBOTTOM, $GUI_DOCKSIZE))
	local $ok = GUICtrlCreateButton("Add", 208, 34, 80, 26, $BS_DEFPUSHBUTTON)
	GUICtrlSetResizing(-1, BitOR($GUI_DOCKRIGHT, $GUI_DOCKBOTTOM, $GUI_DOCKSIZE))
	local $band_dialog_keys[1][2] = [["{ESC}", $cancel]]
	GUISetAccelerators($band_dialog_keys, $dialog)
	GUISetState(@SW_DISABLE, $main_gui)
	LoadDialogPosition("AddBand", $dialog, $band_dialog_left, $band_dialog_top)
	GUISetState(@SW_SHOW, $dialog)
	GUICtrlSetState($freq, $GUI_FOCUS)
	local $value = 0, $band_dialog_last_text = "", $band_dialog_valid = false
	while 1
		local $event = GUIGetMsg()
		if $event = $GUI_EVENT_CLOSE or $event = $cancel then exitloop
		local $text = StringStripWS(GUICtrlRead($freq), $STR_STRIP_ENDS)
		if $text <> $band_dialog_last_text then
			local $band_dialog_frequency = Number($text)
			$band_dialog_valid = StringRegExp($text, '^\d+(\.\d+)?$') and $band_dialog_frequency >= 20 and $band_dialog_frequency <= 20000 and _
				_ArraySearch($band_freq, $band_dialog_frequency, 0, $band_count - 1) = -1
			local $band_dialog_colour = $FREQUENCY_INVALID_COLOUR, $band_dialog_button = $GUI_DISABLE
			if $band_dialog_valid then
				$band_dialog_colour = _WinAPI_GetSysColor($COLOR_WINDOWTEXT)
				$band_dialog_button = $GUI_ENABLE
			endif
			GUICtrlSetColor($freq, $band_dialog_colour)
			GUICtrlSetState($ok, $band_dialog_button)
			$band_dialog_last_text = $text
		endif
		if $event = $ok and $band_dialog_valid then
			$value = Number($text)
			exitloop
		endif
	wend
	SaveDialogPosition("AddBand", $dialog)
	GUIDelete($dialog)
	GUISwitch($main_gui)
	GUISetState(@SW_ENABLE, $main_gui)
	WinActivate($main_gui)
	if $value = 0 then return
	$band_freq[$band_count] = $value
	$band_gain[$band_count] = 0
	$band_count += 1
	SortBands()
	$dirty = true
	RebuildBandGrid()
endfunc

; Removes parametric band $pos; retains other frequency/gain pairs.
; Reads the global arrays and commits pending frequency inputs. Keeps
; at least one band. Records one undo snapshot before removing the band,
; preserves it while rebuilding the grid, and marks the preset dirty.
; Returns no value; invalid positions and non-parametric modes do nothing.
func OnDeleteBand($pos)
	if $preset_mode <> $MODE_PARAMETRIC then return
	if $band_count <= 1 then return
	if $pos < 0 or $pos >= $band_count then return
	ReadParamBoxes()
	FinishSliderUndoAction()
	RecordSliderUndo()
	local $index = $pos
	while $index < $band_count - 1
		$band_freq[$index] = $band_freq[$index + 1]
		$band_gain[$index] = $band_gain[$index + 1]
		$index += 1
	wend
	$band_count -= 1
	$dirty = true
	RebuildBandGrid(true)
endfunc

; Applies the selected named preset to playback and its setup controls.
; Reads preset_name, profile_monitor and [Playback] Preset. Records a
; different, existing playback preset as [@EQ] PreviousPreset, or clears that
; key if the old preset is missing. Writes [Playback] Preset and
; signals the listener. A preset without an Output link remains silent.
; Refreshes the selected monitor's EQ, Output and setup message, or the
; preset controls and grid when no monitor is selected. Returns no value.
; Called after creating, selecting or deleting a named preset.
func ActivatePreset()
	local $activation_path = GetIniPath()
	local $activation_previous = IniRead($activation_path, "Playback", "Preset", "")
	if $activation_previous <> $preset_name then
		if not PresetExists($activation_previous) then $activation_previous = ""
		IniWrite($activation_path, $APP_NAME, $PREVIOUS_PRESET_KEY, $activation_previous)
	endif
	IniWrite($activation_path, "Playback", "Preset", $preset_name)
	SignalListener()
	if $profile_monitor <> "" then
		ShowBinding($profile_monitor)
	else
		RefreshTopControls()
		RebuildBandGrid()
	endif
endfunc

; Enables linking only when the selected monitor needs a different output.
; Reads monitor_list, speaker_list, preset_name and the selected monitor's
; saved Output link through GetIniPath(). Updates apply_button; returns no
; value and writes no settings. Called when the output selection changes,
; after displaying a monitor's binding, and after refreshing the monitors.
; Missing selections and an output matching the saved link disable Link.
func UpdateLinkButton()
	local $link_monitor = MonitorKey()
	local $link_endpoint = SpeakerIdFromName(GUICtrlRead($speaker_list))
	local $link_state = $GUI_DISABLE
	if $link_monitor <> "" and $link_endpoint <> "" then
		local $link_monitor_name = IniRead(GetIniPath(), "Monitors", $link_monitor, "")
		local $link_saved_endpoint = IniRead(GetIniPath(), $preset_name, "Output_" & $link_monitor_name, "")
		if $link_endpoint <> $link_saved_endpoint then $link_state = $GUI_ENABLE
	endif
	GUICtrlSetState($apply_button, $link_state)
endfunc

; Links the selected monitor and preset to the explicitly selected Output.
; Reads both selection controls and preset globals. Missing selections show
; a status message and return without writing a link. Otherwise saves EQ,
; writes Output_<monitor> in [preset], signals or starts the listener and
; refreshes the controls. Returns no value; chooses no fallback Output.
func OnApplyBinding()
	local $monitor = MonitorKey()
	local $endpoint = SpeakerIdFromName(GUICtrlRead($speaker_list))
	if $monitor = "" or $endpoint = "" then
		GUICtrlSetData($status_label, "Select a Monitor and an Output before linking")
		return
	endif
	SavePreset()
	local $path = GetIniPath()
	IniWrite($path, $preset_name, "Output_" & $profile_monitor_name, $endpoint)
	IniWrite($path, "Playback", "Preset", $preset_name)
	SignalListener()
	if not ProcessExists($LISTENER_EXE) then OnStartListener()
	ShowBinding($monitor)
endfunc

; Copies every preset section from a chosen file into the live
; ini file: named preset sections flagged Preset=1 plus profile
; sections carrying a PresetName backlink. Reads section names
; then keys. Returns the count of imported sections. Existing
; presets with the same name update.
func ImportPresets()
	local $file = FileOpenDialog("Import presets", @DesktopDir, "Ini (*.ini)", $FD_FILEMUSTEXIST, "", $main_gui)
	if @error or $file = "" then return 0
	local $names = IniReadSectionNames($file)
	if @error then return 0
	local $path = GetIniPath()
	local $count = 0
	local $index = 1
	while $index <= $names[0]
		if IniRead($file, $names[$index], "Preset", "") = "1" or IniRead($file, $names[$index], "PresetName", "") <> "" then
			local $keys = IniReadSection($file, $names[$index])
			if not @error then
				local $row = 1
				while $row <= $keys[0][0]
					if StringRegExp($keys[$row][0], "(?i)^(Preamp|(Band|Param)[0-9]+_Gain)$") then $keys[$row][1] = CapGain($keys[$row][1])
					IniWrite($path, $names[$index], $keys[$row][0], $keys[$row][1])
					$row += 1
				wend
				$count += 1
			endif
		endif
		$index += 1
	wend
	RefreshTopControls()
	SignalListener()
	return $count
endfunc

; Exports all presets, or only the named preset and its monitor/mode EQ.
; Reads GetIniPath(); a nonempty export_preset selects its metadata section
; and sections with the matching PresetName. The main loop passes preset_name
; for the context menu and no argument for the Export button. The save dialog
; supplies a timestamped filename; invalid filename characters become _.
; Single export saves dirty EQ through SavePreset(), reads dirty and writes
; an LF-only UTF-16LE INI, replacing a destination only after confirmation.
; Returns the section count, 0 on cancellation, or 0 with @error=1 on single
; export failure. Full export retains its existing merge and count behaviour.
func ExportPresets($export_preset="")
	local $export_title = "Export presets", $export_filename = "Export", $export_flags = $FD_PATHMUSTEXIST
	if $export_preset <> "" then
		$export_title = "Export this preset"
		$export_filename = StringRegExpReplace($export_preset, '[\\/:*?"<>|\x00-\x1F]', "_")
		$export_flags = BitOR($export_flags, $FD_PROMPTOVERWRITE)
	endif
	local $file = FileSaveDialog($export_title, @MyDocumentsDir, "Ini (*.ini)", $export_flags, "@EQ " & $export_filename & " " & @YEAR & "-" & @MON & "-" & @MDAY & "_" & @HOUR & @MIN & @SEC & ".ini", $main_gui)
	if @error or $file = "" then return 0
	local $path = GetIniPath()
	if $export_preset <> "" then
		if $file = $path then return SetError(1, 0, 0)
		if $dirty then SavePreset()
	endif
	local $names = IniReadSectionNames($path)
	if @error then return SetError(1, 0, 0)
	local $count = 0, $export_text = ""
	local $index = 1
	while $index <= $names[0]
		local $export_metadata = IniRead($path, $names[$index], "Preset", "") = "1"
		local $export_owner = IniRead($path, $names[$index], "PresetName", "")
		local $export_selected = $export_metadata or $export_owner <> ""
		if $export_preset <> "" then $export_selected = ($export_metadata and $names[$index] = $export_preset) or $export_owner = $export_preset
		if $export_selected then
			local $keys = IniReadSection($path, $names[$index])
			if @error and $export_preset <> "" then return SetError(1, 0, 0)
			if not @error then
				if $export_preset <> "" then $export_text &= "[" & $names[$index] & "]" & @LF
				local $row = 1
				while $row <= $keys[0][0]
					if $export_preset = "" then
						IniWrite($file, $names[$index], $keys[$row][0], $keys[$row][1])
					else
						$export_text &= $keys[$row][0] & "=" & $keys[$row][1] & @LF
					endif
					$row += 1
				wend
				if $export_preset <> "" then $export_text &= @LF
				$count += 1
			endif
		endif
		$index += 1
	wend
	if $export_preset <> "" then
		if $count = 0 then return SetError(1, 0, 0)
		local $export_handle = FileOpen($file, BitOR($FO_OVERWRITE, $FO_UTF16_LE))
		if $export_handle = -1 then return SetError(1, 0, 0)
		local $export_written = FileWrite($export_handle, $export_text)
		local $export_closed = FileClose($export_handle)
		if not $export_written or not $export_closed then return SetError(1, 0, 0)
	endif
	return $count
endfunc

; Starts the C++ listener exe from the @EQ folder, handing
; it the live ini path via --ini so the path is stored in
; GetIniPath() only. Sets $listener_pid, greys Start and
; arms Stop. Warns in the status line when the binary is
; missing so the user runs the build step first.
func OnStartListener()
	local $exe = @ScriptDir & "\" & $LISTENER_EXE
	if not FileExists($exe) then
		GUICtrlSetData($status_label, "Listener binary missing, run build-listener.bat first")
		return
	endif
	if $listener_pid <> 0 and ProcessExists($listener_pid) then return
	if AdoptListener() <> 0 then return
	$listener_pid = Run($exe & ' --ini "' & GetIniPath() & '"', @ScriptDir, @SW_HIDE)
	if @error then
		$listener_pid = 0
		GUICtrlSetData($status_label, "Listener failed to start")
		return
	endif
	GUICtrlSetState($start_button, $GUI_DISABLE)
	GUICtrlSetState($stop_button, $GUI_ENABLE)
	GUICtrlSetData($status_label, "Listener running, pid " & $listener_pid)
endfunc


; Detects listener starts, stops and restarts and updates @EQ's controls.
; Reads LISTENER_EXE and $listener_pid; returns the detected PID, or 0 when
; absent. Stores that PID and updates Start/Stop. With changed_only=true,
; writes controls/status only for a PID change, including a stopped message.
; Startup and Start call with false; the main loop polls with true once per
; second. Detects process existence, not capture or audio-output health.
func AdoptListener($listener_changed_only=false)
	local $listener_detected_pid = ProcessExists($LISTENER_EXE)
	if $listener_changed_only and $listener_detected_pid = $listener_pid then return $listener_pid
	$listener_pid = $listener_detected_pid
	if $listener_pid <> 0 then
		GUICtrlSetState($start_button, $GUI_DISABLE)
		GUICtrlSetState($stop_button, $GUI_ENABLE)
		GUICtrlSetData($status_label, "Listener running, pid " & $listener_pid)
	else
		GUICtrlSetState($start_button, $GUI_ENABLE)
		GUICtrlSetState($stop_button, $GUI_DISABLE)
		if $listener_changed_only then GUICtrlSetData($status_label, "Listener stopped")
	endif
	return $listener_pid
endfunc


; Stops the running listener process. Reads $listener_pid.
; Clears the pid afterwards, greys Stop and rearms Start.
; No effect when not running.
func OnStopListener()
	if $listener_pid <> 0 then ProcessClose($listener_pid)
	$listener_pid = 0
	GUICtrlSetState($start_button, $GUI_ENABLE)
	GUICtrlSetState($stop_button, $GUI_DISABLE)
	GUICtrlSetData($status_label, "Listener stopped")
endfunc


; Formats the About box's elapsed runtime of the Listener process.
; Receives its PID; reads ABOUT_FILETIME_TICKS_PER_SECOND and the About time
; constants. Returns Nd HH:MM:SS from Windows' creation time to current UTC,
; "stopped" for PID 0, or "unavailable" if process times cannot be read.
; Hours range from 00 to 23. Queries once per refresh (every 1s).
func ListenerRuntime($listener_runtime_pid)
	if $listener_runtime_pid = 0 then return "stopped"
	local $listener_times = _WinAPI_GetProcessTimes($listener_runtime_pid)
	if not IsArray($listener_times) then return "unavailable"
	local $listener_created = $listener_times[0]
	local $listener_created_ticks = DllStructCreate("uint64", DllStructGetPtr($listener_created))
	local $listener_now = _Date_Time_GetSystemTimeAsFileTime()
	local $listener_now_ticks = DllStructCreate("uint64", DllStructGetPtr($listener_now))
	local $listener_seconds = Int((DllStructGetData($listener_now_ticks, 1) - DllStructGetData($listener_created_ticks, 1)) / $ABOUT_FILETIME_TICKS_PER_SECOND)
	return StringFormat("%dd %02d:%02d:%02d", Int($listener_seconds / $ABOUT_SECONDS_PER_DAY), Int(Mod($listener_seconds, $ABOUT_SECONDS_PER_DAY) / $ABOUT_SECONDS_PER_HOUR), _
		Int(Mod($listener_seconds, $ABOUT_SECONDS_PER_HOUR) / $ABOUT_SECONDS_PER_MINUTE), Mod($listener_seconds, $ABOUT_SECONDS_PER_MINUTE))
endfunc




; About @EQ
;
; Displays ListenerRuntime() once per second for the current Listener. 
; Clicking the icon toggles the readout.
; Returns true after closing or false if the window cannot be created.
; Saves its left/top coordinates in the INI; 
; supplied coordinates are used until a position is saved.
;
func DoAboutBox($about_left=default, $about_top=default)

	local $about_coord_mode = Opt("GUICoordMode", 1)
	local $about_width = 372
	local $about_height = 169
	local $about_gui = GUICreate(" About " & $APP_NAME & ".. ", $about_width, $about_height, -1, Int(@DesktopHeight * $DIALOG_Y_FRACTION), BitOR($WS_CAPTION, $WS_SYSMENU), $WS_EX_TOPMOST, $main_gui)
	if not $about_gui then
		Opt("GUICoordMode", $about_coord_mode)
		return false
	endif
	GUISetFont(8.5, $FW_NORMAL, $GUI_FONTNORMAL, "Consolas", $about_gui, $CLEARTYPE_QUALITY)
	local $about_icon_path = @ScriptFullPath
	if not @Compiled then $about_icon_path = @ScriptDir & "\Resources\@EQ.ico"
	local $about_icon = GUICtrlCreateIcon($about_icon_path, -1, 13, 3, 48, 48)
	GUICtrlSetTip($about_icon, "Click to toggle the elapsed runtime readout.")
	GUICtrlCreateLabel($APP_NAME & " v" & $VERSION, 72, 17, 270, 18)
	GUICtrlCreateLabel(Chr(169) & " corz.org " & @Year, 72, 32, 270, 18)
	GUICtrlCreateLabel($APP_NAME & " switches your EQ and preamp levels and/or swap stereo channels when you switch monitors, automatically." & @LF &  @LF & _
									"Once set up, no more clicking required." & @LF & @LF & _
									"Do you want to visit the @EQ page at this time?", 15, 54, $about_width - 25, $about_height - 85)
	local $about_runtime = GUICtrlCreateLabel("", 15, $about_height - 25, $about_width - 185, 25)
	GUICtrlSetTip($about_runtime, "Click the @EQ icon to toggle this display.")
	local $about_cancel = GUICtrlCreateButton("Nah", $about_width - 165, $about_height - 27, 75, 20, BitOR($WS_TABSTOP, $BS_FLAT))
	GUICtrlSetTip($about_cancel, "Close the About Box.")
	local $about_ok = GUICtrlCreateButton("Okay", $about_width - 83, $about_height - 27, 75, 20, BitOR($WS_TABSTOP, $BS_FLAT))
	GUICtrlSetTip($about_ok, "Close the About Box and visit corz.org.")
	GUICtrlSetState($about_ok, $GUI_FOCUS)
	TrayItemSetState($tray_about_item, $TRAY_DISABLE)
	GUISetState(@SW_DISABLE, $main_gui)
	LoadDialogPosition("About", $about_gui, $about_left, $about_top)
	GUISetState(@SW_SHOW, $about_gui)
	local $about_show_runtime = true
	local $about_last_second = -1, $about_refresh_timer = TimerInit()
	local $about_visit = false
	while 1
		local $about_event = GUIGetMsg()
		if $about_event = $GUI_EVENT_CLOSE or $about_event = $about_cancel then exitloop
		if $about_event = $about_ok then
			$about_visit = true
			exitloop
		endif
		if $about_event = $about_icon then
			$about_show_runtime = not $about_show_runtime
			if $about_show_runtime then
				GUICtrlSetState($about_runtime, $GUI_SHOW)
			else
				GUICtrlSetState($about_runtime, $GUI_HIDE)
			endif
		endif
		local $about_seconds = Int(TimerDiff($about_refresh_timer) / 1000)
		if $about_seconds <> $about_last_second then
			GUICtrlSetData($about_runtime, "Listener runtime: " & ListenerRuntime(ProcessExists($LISTENER_EXE)))
			$about_last_second = $about_seconds
		endif
	wend
	SaveDialogPosition("About", $about_gui)
	GUIDelete($about_gui)
	GUISwitch($main_gui)
	GUISetState(@SW_ENABLE, $main_gui)
	WinActivate($main_gui)
	TrayItemSetState($tray_about_item, $TRAY_ENABLE)
	Opt("GUICoordMode", $about_coord_mode)
	if $about_visit then ShellExecute($ABOUT_URL)
	return true
endfunc


; Compiler directives.
;

#Region

#pragma compile(AutoItExecuteAllowed, true)
#pragma compile(Compression, 9)

#AutoIt3Wrapper_LogFile="%scriptdir%\wrapper.log"

#AutoIt3Wrapper_Run_Au3Stripper=N
#Au3Stripper_Parameters=/StripOnly /rsln
#AutoIt3Wrapper_UseX64=Y
#AutoIt3Wrapper_UseUpx=N
#AutoIt3Wrapper_Run_AU3Check=Y
#AutoIt3Wrapper_AU3Check_Parameters=-d -w 1 -w 2 -w 3 -w- 4 -w 5 -w 6 -w 7 -v 1
#AutoIt3Wrapper_AU3Check_Stop_OnWarning=N
#AutoIt3Wrapper_Run_Stop_OnError=N
#AutoIt3Wrapper_Res_HiDpi=Y

;	*** YOU MIGHT NEED TO USE FORWARD SLASHES IN RELATIVE PATHS - YMMV!!! **
#AutoIt3Wrapper_Icon=Resources\@EQ.ico

; Free-Form Res Fields.
#AutoIt3Wrapper_Res_Field=Contact|software@corz.org
#AutoIt3Wrapper_Res_Field=Copyright|corz.org
#AutoIt3Wrapper_Res_Field=Instructions|Launch @EQ.exe.
#AutoIt3Wrapper_Res_Field=Long Description|@EQ: Automatic Audio EQ for Windows - switches speakers, channels, preamp and equalisation levels when you switch monitors.
#AutoIt3Wrapper_Res_Field=ProductName|@EQ
#AutoIt3Wrapper_Res_Field=Publisher|corz.org
#AutoIt3Wrapper_Res_Field=Web Page|http://corz.org/
#AutoIt3Wrapper_Res_Field=Compiled|%date% %time%

; Application's resource info.
#AutoIt3Wrapper_Res_Comment=@EQ :: Your speakers follow your screen.. AUTOMATICALLY
; This is the one that shows up in Process Explorer.
#AutoIt3Wrapper_Res_Description=@EQ - automatic EQ when you switch screens, from corz.org
#AutoIt3Wrapper_Res_LegalCopyright=corz.org
#AutoIt3Wrapper_Res_ProductVersion=1

;Build|debug	Build|Beta Release	Build|Public Release
#AutoIt3Wrapper_Res_Field=Build|Beta Release

; Copy latest binaries to app folders.
#AutoIt3Wrapper_Run_Before_Admin=Y
#AutoIt3Wrapper_Run_After_Admin=Y

; Kill my .exe(s) if running. We'll use this new version immediately.
#AutoIt3Wrapper_Run_Before=taskkill /F /IM @EQListener.exe
#AutoIt3Wrapper_Run_Before=taskkill /F /IM @EQ.exe

; #AutoIt3Wrapper_Run_Before=del /f /q  "C:\Program Files\corz\@EQ\@EQListener.exe"

; Build a fresh copy of the Listener in the source directory.
#AutoIt3Wrapper_Run_Before=C:\Users\Dad\Documents\Dev\AutoIt\@EQ\Source\build-listener.bat

; Copy finished binaries to program files folder(s).
#AutoIt3Wrapper_Run_After=move /Y "C:\Program Files\corz\@EQ\@EQ.exe" "C:\Users\Dad\Documents\Dev\AutoIt\@EQ\BackUp\@EQ.backup.exe"
#AutoIt3Wrapper_Run_After=move /Y "C:\Program Files\corz\@EQ\@EQListener.exe" "C:\Users\Dad\Documents\Dev\AutoIt\@EQ\BackUp\@EQListener.backup.exe"

; Copy latest binaries to app folders (overwrites existing binary). 	  Your copy may be somewhere else.
#AutoIt3Wrapper_Run_After=move /Y "%outx64%" "C:\Program Files\corz\@EQ\@EQ.exe"
#AutoIt3Wrapper_Run_After=move /Y "@EQListener.exe" "C:\Program Files\corz\@EQ\@EQListener.exe"

; ; Move latest binaries to distro folder (out of way of source pack).
; #AutoIt3Wrapper_Run_After=move /Y "%outx64%" "%scriptdir%\.\@EQ\@EQ.exe"

; #AutoIt3Wrapper_Run_After=copy "%scriptdir%\Resources\@EQ.ini" "%scriptdir%\.\@EQ\Data\@EQ.ini"
; #AutoIt3Wrapper_Run_After=copy "%scriptdir%\Resources\Strings.ini" "%scriptdir%\.\@EQ\Data\Strings.ini"
; #AutoIt3Wrapper_Run_After=copy "%scriptdir%\Resources\itstory.txt" "%scriptdir%\.\@EQ\itstory.txt"

; ; #AutoIt3Wrapper_Run_After=copy "%scriptdir%/resources/QuickStart.txt" "./@EQ/info/QuickStart.txt"
; ; #AutoIt3Wrapper_Run_After=copy "%scriptdir%/resources/QuickStart.txt" "./@EQ_x64/info/QuickStart.txt"

; ; Backup this version of the script (dropped into backup.zip). So I don't have to remember to.
; #AutoIt3Wrapper_Run_After=copy "%in%" ".\%scriptfile% - %fileversion%.au3"

; ; ; delete temporary script (hmm. maybe not!).

; ; #AutoIt3Wrapper_Run_After=del /f /q .\%scriptfile%_stripped.au3
; #AutoIt3Wrapper_Run_After=move /Y .\%scriptfile%_stripped.au3 ".\%scriptfile% - %fileversion%_stripped.au3"

; ; When you run AutoIt wrapper, compile the script; the version number is automatically increased. Neat! But.
; #AutoIt3Wrapper_Res_FileVersion_AutoIncrement=N

;; BASIC BACKUP:

; Backup this version of the script (dropped into a backup.zip, below). So I don't have to remember to.
#AutoIt3Wrapper_Run_After=copy "%in%" 									".\%scriptfile% - %fileversion%.au3"


; Handy to keep a backup of the stripped version, too, if we made that.
#AutoIt3Wrapper_Run_After=move /Y .\%scriptfile%_stripped.au3 			".\%scriptfile% - %fileversion%_stripped.au3"

;::dev::.
; #AutoIt3Wrapper_Run_After=copy "%outx64%" 								"C:\Program Files\corz\@EQ\@EQ.exe"

; Backup this version of the source files to BackUp.zip.
#AutoIt3Wrapper_Run_After=7z.exe a -mx7 -tzip "..\BackUp\BackUp.zip" ".\%scriptfile% - %fileversion%.au3"
#AutoIt3Wrapper_Run_After=7z.exe a -mx7 -tzip "..\BackUp\BackUp.zip" ".\%scriptfile% - %fileversion%_stripped.au3"

; Note: The 7z program directory is in my %PATH% (System Properties >> Advanced >> Environment Variables).
; Which is why I don't need to supply the full path for this command.

; Finally, remove the (now-zipped) source files.
#AutoIt3Wrapper_Run_After=del /f /q ".\%scriptfile% - %fileversion%.au3"
#AutoIt3Wrapper_Run_After=del /f /q ".\%scriptfile% - %fileversion%_stripped.au3"

; Fire-up the new version.
#AutoIt3Wrapper_Run_After=start "" "C:\Program Files\corz\@EQ\@EQListener.exe"
#AutoIt3Wrapper_Run_After=start "" "C:\Program Files\corz\@EQ\@EQ.exe"

; Enable both directives for a GitHub source publish.
;#AutoIt3Wrapper_Run_After_Admin=N
;#AutoIt3Wrapper_Run_After="C:\UNIX\Python312\python.exe" "C:\Users\Dad\Documents\Scripts\publish-autoit-source.py" "%scriptdir%" at-EQ "%fileversion%"
#EndRegion


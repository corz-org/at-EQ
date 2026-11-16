; DialogPosition 0.1.0
; Stores custom dialog coordinates separately from the main window.
#include-once

; Restores a custom dialog's last position before it becomes visible.
; Reads GetIniPath(), APP_NAME and <name>_Left/<name>_Top keys. Saved numeric
; values take precedence over supplied initial coordinates; default uses
; the window's existing initial coordinate. Moves the window, then applies
; RestoreVisibleWindow() without saving the main window's rectangle so a
; disconnected monitor cannot leave the dialog completely off-screen.
; Returns no value; called after sizing and before showing each custom dialog.
func LoadDialogPosition($dialog_position_name, $dialog_position_window, $dialog_position_left=default, $dialog_position_top=default)
	local $dialog_position_rect = WinGetPos($dialog_position_window)
	if @error then return
	if $dialog_position_left = default then $dialog_position_left = $dialog_position_rect[0]
	if $dialog_position_top = default then $dialog_position_top = $dialog_position_rect[1]
	local $dialog_position_ini = GetIniPath()
	local $dialog_position_saved_left = IniRead($dialog_position_ini, $APP_NAME, $dialog_position_name & "_Left", "")
	local $dialog_position_saved_top = IniRead($dialog_position_ini, $APP_NAME, $dialog_position_name & "_Top", "")
	if StringRegExp($dialog_position_saved_left, "^-?\d+$") then $dialog_position_left = Int($dialog_position_saved_left)
	if StringRegExp($dialog_position_saved_top, "^-?\d+$") then $dialog_position_top = Int($dialog_position_saved_top)
	WinMove($dialog_position_window, "", $dialog_position_left, $dialog_position_top)
	RestoreVisibleWindow($dialog_position_window, false)
endfunc

; Remembers a custom dialog's position for its next opening, including Cancel.
; Reads the supplied window's outer rectangle and GetIniPath()/APP_NAME.
; Writes <name>_Left and <name>_Top in the application's INI section. Failed
; window queries write nothing. Returns no value; called immediately before
; the dialog is deleted. Does not save its size or change the main window.
func SaveDialogPosition($dialog_position_name, $dialog_position_window)
	local $dialog_position_rect = WinGetPos($dialog_position_window)
	if @error then return
	local $dialog_position_ini = GetIniPath()
	IniWrite($dialog_position_ini, $APP_NAME, $dialog_position_name & "_Left", $dialog_position_rect[0])
	IniWrite($dialog_position_ini, $APP_NAME, $dialog_position_name & "_Top", $dialog_position_rect[1])
endfunc

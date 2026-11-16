; StartupTask 0.1.5
; Listener startup task creation and a one-time first-launch question.
#include-once
#include <FileConstants.au3>

global const $STARTUP_TASK_NAME = $APP_NAME & " Startup"
global const $STARTUP_TASK_SECTION = $APP_NAME
global const $STARTUP_TASK_PROMPT_KEY = "StartupPromptDone"

; One-time offer to setup a listener startup item, including declined offers.
; Reads GetIniPath() and writes [@EQ] StartupPromptDone=1 before
; displaying the question. Called after the main window is shown.
; Yes calls CreateListenerStartupTask() (same as tray menu item).
; Failed registration or cancelled UAC does not invoke another offer.
func PromptListenerStartupTask()
	local $startup_ini = GetIniPath()
	if IniRead($startup_ini, $STARTUP_TASK_SECTION, $STARTUP_TASK_PROMPT_KEY, "0") = "1" then return
	if not IniWrite($startup_ini, $STARTUP_TASK_SECTION, $STARTUP_TASK_PROMPT_KEY, "1") then
		MessageBox($APP_NAME, "Unable to save the startup-task prompt setting.", default, default)
		return
	endif
	local $startup_prompt = "Would you like to create a startup task for the " & $APP_NAME & " listener?" & @LF & @LF & _
		"The listener will start automatically when you sign in, with highest privileges. Windows may ask for administrator approval." & @LF & @LF & _
		"You can do this at any time from the system tray: Create " & $STARTUP_TASK_NAME & " Task."
	if MessageBox($APP_NAME, $startup_prompt, default, default, true) = $IDYES then CreateListenerStartupTask()
endfunc

; Creates or replaces this user's elevated listener task at Windows sign-in.
; Reads @ScriptDir, LISTENER_EXE, GetIniPath() and the current user identity.
; Writes a temporary UTF-16 XML definition, calls schtasks with UAC when
; needed, and deletes that temporary file. Returns true after successful
; registration, false for a missing listener, file failure, UAC cancellation
; or nonzero schtasks exit. Reports the result in a parented dialog. Does
; not launch the listener or alter other tasks; called by the tray or offer.
func CreateListenerStartupTask()
	local $startup_exe = @ScriptDir & "\" & $LISTENER_EXE
	if not FileExists($startup_exe) then
		MessageBox($APP_NAME, "Listener binary missing: " & $startup_exe, default, default)
		return false
	endif
	local $startup_user = @LogonDomain & "\" & @UserName
	local $startup_xml = BuildListenerStartupTaskXml($startup_user, $startup_exe, '--ini "' & GetIniPath() & '"', @ScriptDir)
	local $startup_xml_path = @TempDir & "\@EQStartupTask-" & @AutoItPID & ".xml"
	local $startup_file = FileOpen($startup_xml_path, BitOR($FO_UNICODE, $FO_OVERWRITE))
	if $startup_file = -1 then
		MessageBox($APP_NAME, "Unable to create the temporary Task Scheduler definition.", default, default)
		return false
	endif
	local $startup_written = FileWrite($startup_file, $startup_xml)
	FileClose($startup_file)
	if not $startup_written then
		FileDelete($startup_xml_path)
		MessageBox($APP_NAME, "Unable to write the temporary Task Scheduler definition.", default, default)
		return false
	endif
	local $startup_verb = "open"
	if not IsAdmin() then $startup_verb = "runas"
	local $startup_parameters = '/Create /TN "' & $STARTUP_TASK_NAME & '" /XML "' & $startup_xml_path & '" /F'
	local $startup_result = ShellExecuteWait(@SystemDir & "\schtasks.exe", $startup_parameters, @SystemDir, $startup_verb, @SW_HIDE)
	local $startup_launch_error = @error
	FileDelete($startup_xml_path)
	if $startup_launch_error then
		MessageBox($APP_NAME, "The startup task was not created. Administrator approval may have been cancelled.", default, default)
		return false
	endif
	if $startup_result <> 0 then
		MessageBox($APP_NAME, "Windows Task Scheduler could not create the startup task. Error code: " & $startup_result, default, default)
		return false
	endif
	MessageBox($APP_NAME, $STARTUP_TASK_NAME & " was created for " & $startup_user & ". The listener will start at your next sign-in.", default, default)
	return true
endfunc

; Describes one user's listener launch as a Task Scheduler XML definition.
; Receives the Windows user, executable, arguments and working directory.
; Returns XML with escaped text, a user logon
; trigger, interactive highest privileges, no execution time limit and no
; battery restrictions. Repeated launches are ignored while the task runs.
; Called by CreateListenerStartupTask(); performs no file or task operations.
func BuildListenerStartupTaskXml($startup_user, $startup_exe, $startup_arguments, $startup_directory)
	$startup_user = EscapeStartupTaskXml($startup_user)
	return '<?xml version="1.0" encoding="UTF-16"?>' & @LF & _
		'<Task version="1.4" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">' & @LF & _
		'<RegistrationInfo><Author>' & $startup_user & '</Author></RegistrationInfo>' & @LF & _
		'<Triggers><LogonTrigger><Enabled>true</Enabled><UserId>' & $startup_user & '</UserId></LogonTrigger></Triggers>' & @LF & _
		'<Principals><Principal id="Author"><UserId>' & $startup_user & '</UserId><LogonType>InteractiveToken</LogonType>' & _
		'<RunLevel>HighestAvailable</RunLevel></Principal></Principals>' & @LF & _
		'<Settings><MultipleInstancesPolicy>IgnoreNew</MultipleInstancesPolicy><DisallowStartIfOnBatteries>false</DisallowStartIfOnBatteries>' & _
		'<StopIfGoingOnBatteries>false</StopIfGoingOnBatteries><ExecutionTimeLimit>PT0S</ExecutionTimeLimit><Enabled>true</Enabled></Settings>' & @LF & _
		'<Actions Context="Author"><Exec><Command>' & EscapeStartupTaskXml($startup_exe) & '</Command><Arguments>' & _
		EscapeStartupTaskXml($startup_arguments) & '</Arguments><WorkingDirectory>' & EscapeStartupTaskXml($startup_directory) & _
		'</WorkingDirectory></Exec></Actions>' & @LF & '</Task>' & @LF
endfunc

; Escapes literal text for a Task Scheduler XML element.
; Receives unescaped text and returns it with ampersands, angle brackets,
; quotes and apostrophes encoded as XML entities. Called for user-supplied
; identity and path values; reads no globals and performs no file operations.
func EscapeStartupTaskXml($startup_text)
	$startup_text = StringReplace($startup_text, "&", "&amp;")
	$startup_text = StringReplace($startup_text, "<", "&lt;")
	$startup_text = StringReplace($startup_text, ">", "&gt;")
	$startup_text = StringReplace($startup_text, '"', "&quot;")
	return StringReplace($startup_text, "'", "&apos;")
endfunc

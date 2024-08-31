

VDA_PATH := "VirtualDesktopAccessor.dll"
hVirtualDesktopAccessor := DllCall("LoadLibrary", "Str", VDA_PATH, "Ptr")
; Load VirtualDesktopAccessor.dllGetDesktopCountProc := DllCall("GetProcAddress", "Ptr", hVirtualDesktopAccessor, "AStr", "GetDesktopCount", "Ptr")
GoToDesktopNumberProc := DllCall("GetProcAddress", "Ptr", hVirtualDesktopAccessor, "AStr", "GoToDesktopNumber", "Ptr")
MoveWindowToDesktopNumberProc := DllCall("GetProcAddress", "Ptr", hVirtualDesktopAccessor, "AStr", "MoveWindowToDesktopNumber", "Ptr")
GetCurrentDesktopNumber:=DllCall("GetProcAddress", "Ptr", hVirtualDesktopAccessor, "AStr", "GetCurrentDesktopNumber", "Ptr")


; Define hotkeys for desktop navigation in a 3x3 grid ctrl+alt+arrow
^!#Left::MoveDesktop("Left")
^!#Right::MoveDesktop("Right")
^!#Up::MoveDesktop("Up")
^!#Down::MoveDesktop("Down")
^!Left::Movetheapp("Left")
^!Right::Movetheapp("Right")
^!Up::Movetheapp("Up")
^!Down::Movetheapp("Down")





IsInvisibleWin10BackgroundAppWindow(hWindow){
	result := 0
	VarSetCapacity(cloakedVal, A_PtrSize) ; DWMWA_CLOAKED := 14
	hr := DllCall("DwmApi\DwmGetWindowAttribute", "Ptr", hWindow, "UInt", 14, "Ptr", &cloakedVal, "UInt", A_PtrSize)
	if !hr ; returns S_OK (which is zero) on success. Otherwise, it returns an HRESULT error code
	{
		result := NumGet(cloakedVal) ; omitting the "&" performs better
	}
	return result ? true : false
	/*
		DWMWA_CLOAKED: If the window is cloaked, the following values explain why:
		1  The window was cloaked by its owner application (DWM_CLOAKED_APP)
		2  The window was cloaked by the Shell (DWM_CLOAKED_SHELL)
		4  The cloak value was inherited from its owner window (DWM_CLOAKED_INHERITED)
	*/
}




GetAltTabList(){
	; took from https://www.autohotkey.com/boards/viewtopic.php?t=46069
	; if does not work you can try:
	; https://www.autohotkey.com/boards/viewtopic.php?f=76&t=87170&p=383201#p383201
	static WS_EX_TOPMOST :=            0x8 ; sets the Always On Top flag
	static WS_EX_APPWINDOW :=      0x40000 ; provides a taskbar button
	static WS_EX_TOOLWINDOW :=        0x80 ; removes the window from the alt-tab list
	static GW_OWNER := 4

	AltTabList := {}
	windowList := ""
	DetectHiddenWindows, Off ; makes DllCall("IsWindowVisible") unnecessary
	WinGet, windowList, List ; gather a list of running programs
	Loop, %windowList%
	{
		ownerID := windowID := windowList%A_Index%
		Loop
		{ ;If the window we found is opened by another application or "child", let's get the hWnd of the parent
			ownerID := Format("0x{:x}",  DllCall("GetWindow", "UInt", ownerID, "UInt", GW_OWNER))
		} Until !Format("0x{:x}",  DllCall("GetWindow", "UInt", ownerID, "UInt", GW_OWNER))
		ownerID := ownerID ? ownerID : windowID

	; only windows that are not removed from the Alt+Tab list, AND have a taskbar button, will be appended to our list.
		If (Format("0x{:x}", DllCall("GetLastActivePopup", "UInt", ownerID)) = windowID)
		{
			WinGet, es, ExStyle, ahk_id %windowID%
			If (!((es & WS_EX_TOOLWINDOW) && !(es & WS_EX_APPWINDOW)) && !IsInvisibleWin10BackgroundAppWindow(windowID))
			{
				AltTabList.Push(windowID)
			}
		}
	}
	; UNCOMMENT THIS FOR TESTING
	; WinGetClass, class1, % "ahk_id" AltTabList[1]
	; WinGetClass, class2, % "ahk_id" AltTabList[2]
	; WinGetClass, classF, % "ahk_id" AltTabList.pop()
	; msgbox % "Number of Windows: " AltTabList.length() "`nFirst windowID: " class1 "`nSecond windowID: " class2 "`nFinal windowID: " classF
	return AltTabList
}

WindowsBugFix(){ ;*[thone]
	;the next line fixes a bug, you can see the solution reading those:
	;-https://github.com/Ciantic/VirtualDesktopAccessor/issues/4
	;-https://pypi.org/project/pyvda/   (read the end part)
	DllCall("user32\AllowSetForegroundWindow", Int, - 1)
}


; GoToDesktopNumber(num) {
;     global GoToDesktopNumberProc
;     DllCall(GoToDesktopNumberProc, "Int", num, "Int")
   
;     return

; }

fMoveCurrentWindowToDesktop(desktopNumber) {
	WindowsBugFix()
    global MoveWindowToDesktopNumberProc, GoToDesktopNumberProc
    WinGet, activeHwnd, ID, A
    DllCall(MoveWindowToDesktopNumberProc, "Ptr", activeHwnd, "Int", desktopNumber, "Int")
    DllCall(GoToDesktopNumberProc, "Int", desktopNumber)
    
}


MoveOrGotoDesktopNumber(num){
	WindowsBugFix()
	global GoToDesktopNumberProc
	DllCall(GoToDesktopNumberProc, Int, num )
	; the following 3 lines are because Windows still have bugs:
	; sometimes when going to one desktop to another the focus still
	; in the previous window of the previous desktop(dont ask me why...
	; cos windows)
	; SO I have to get the alt tab list of windows and focus the topmost
	; window EVERY time you go to another desktop
	; also, because the following lines auto alt tab when going to an empty
	; desktop  AltTabOnSwitch() its redundant and deprecated!, I didnt deleted it
	; because im lazy(at least I document everything)
	 altTabList := GetAltTabList()
	 lastWindow := altTabList[1]
	 WinActivate, ahk_id %lastWindow%
}
MoveDesktop(name) {
	
	global GetCurrentDesktopNumber
	ran := DllCall(GetCurrentDesktopNumber, "Int")
	if (name = "Left"){
		if ( ran = 0 ){
			num:=ran+0
			MoveOrGotoDesktopNumber(8)
		}
		else{
            ;go to left
			num:=ran+0
			MoveOrGotoDesktopNumber(num - 1)
			
		}
		
	}
	if (name = "Right"){
		if(ran=8){
			num:=ran+0
			MoveOrGotoDesktopNumber(0)
			
		}
		else{
			
            ;go to right
			num:=ran+0
			MoveOrGotoDesktopNumber(num + 1)
		}
		
	}
	if (name = "Up") {
		if (ran != 0 && ran != 1 && ran != 2) {
			num := ran + 0
			MoveOrGotoDesktopNumber(num - 3)
		} else {
			num := ran + 0
			MoveOrGotoDesktopNumber(num + 6)
		}
	}
	
	if (name = "Down") {
		if (ran != 6 && ran != 7 && ran != 8) {
			num := ran + 0
			MoveOrGotoDesktopNumber(num + 3)
		} else {
			num := ran + 0
			MoveOrGotoDesktopNumber(num - 6)
		}
	}
	
}

Movetheapp(name) {
	
	global GetCurrentDesktopNumber
	ran := DllCall(GetCurrentDesktopNumber, "Int")
	if (name = "Left"){
		if ( ran = 0 ){
			num:=ran+0
			fMoveCurrentWindowToDesktop(8)
		}
		else{
            ;go to left
			num:=ran+0
			fMoveCurrentWindowToDesktop(num - 1)
			
		}
		
	}
	if (name = "Right"){
		if(ran=8){
			num:=ran+0
			fMoveCurrentWindowToDesktop(0)
			
		}
		else{
			
            ;go to right
			num:=ran+0
			fMoveCurrentWindowToDesktop(num + 1)
		}
		
	}
	if (name = "Up") {
		if (ran != 0 && ran != 1 && ran != 2) {
			num := ran + 0
			fMoveCurrentWindowToDesktop(num - 3)
		} else {
			num := ran + 0
			fMoveCurrentWindowToDesktop(num + 6)
		}
	}
	
	if (name = "Down") {
		if (ran != 6 && ran != 7 && ran != 8) {
			num := ran + 0
			fMoveCurrentWindowToDesktop(num + 3)
		} else {
			num := ran + 0
			fMoveCurrentWindowToDesktop(num - 6)
		}
	}
	
}








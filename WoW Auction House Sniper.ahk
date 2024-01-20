#SingleInstance, Force
#InstallKeybdHook
#MaxThreadsPerHotkey 2
DetectHiddenWindows, On
SetBatchLines, -1
SetKeyDelay, -1, -1
SetWinDelay, -1
SetControlDelay, -1
SetMouseDelay, -1
SetDefaultMouseSpeed, 0
ListLines Off
#KeyHistory 0
#NoEnv

; Next 3 functions are just a ControlClick replacement that allows us to circumvent whatever changes prevent ControlClick from working BCC->WOTLK
; We also rename the window to 'ROSENWALD' to support this function when we select our target window
; ControlSend code is unchanged and still uses old ID system
ControlClick2(X, Y, WinTitle="", WinText="", ExcludeTitle="", ExcludeText="")  
{  
  hwnd:=ControlFromPoint(X, Y, WinTitle, WinText, cX, cY  
                             , ExcludeTitle, ExcludeText)  
  PostMessage, 0x200, 0, cX&0xFFFF | cY<<16,, ahk_id %hwnd% ; WM_MOUSEMOVE
  PostMessage, 0x201, 0, cX&0xFFFF | cY<<16,, ahk_id %hwnd% ; WM_LBUTTONDOWN  
  PostMessage, 0x202, 0, cX&0xFFFF | cY<<16,, ahk_id %hwnd% ; WM_LBUTTONUP  
}

ControlFromPoint(X, Y, WinTitle="", WinText="", ByRef cX="", ByRef cY="", ExcludeTitle="", ExcludeText="") 
{ 
    static EnumChildFindPointProc=0 
    if !EnumChildFindPointProc 
        EnumChildFindPointProc := RegisterCallback("EnumChildFindPoint","Fast") 
    
    if !(target_window := WinExist(WinTitle, WinText, ExcludeTitle, ExcludeText)) 
        return false 
    
    VarSetCapacity(rect, 16) 
    DllCall("GetWindowRect","uint",target_window,"uint",&rect) 
    VarSetCapacity(pah, 36, 0) 
    NumPut(X + NumGet(rect,0,"int"), pah,0,"int") 
    NumPut(Y + NumGet(rect,4,"int"), pah,4,"int") 
    DllCall("EnumChildWindows","uint",target_window,"uint",EnumChildFindPointProc,"uint",&pah) 
    control_window := NumGet(pah,24) ? NumGet(pah,24) : target_window 
    DllCall("ScreenToClient","uint",control_window,"uint",&pah) 
    cX:=NumGet(pah,0,"int"), cY:=NumGet(pah,4,"int") 
    return control_window 
} 

; Ported from AutoHotkey::script2.cpp::EnumChildFindPoint() 
EnumChildFindPoint(aWnd, lParam) 
{ 
    if !DllCall("IsWindowVisible","uint",aWnd) 
        return true 
    VarSetCapacity(rect, 16) 
    if !DllCall("GetWindowRect","uint",aWnd,"uint",&rect) 
        return true 
    pt_x:=NumGet(lParam+0,0,"int"), pt_y:=NumGet(lParam+0,4,"int") 
    rect_left:=NumGet(rect,0,"int"), rect_right:=NumGet(rect,8,"int") 
    rect_top:=NumGet(rect,4,"int"), rect_bottom:=NumGet(rect,12,"int") 
    if (pt_x >= rect_left && pt_x <= rect_right && pt_y >= rect_top && pt_y <= rect_bottom) 
    { 
        center_x := rect_left + (rect_right - rect_left) / 2 
        center_y := rect_top + (rect_bottom - rect_top) / 2 
        distance := Sqrt((pt_x-center_x)**2 + (pt_y-center_y)**2) 
        update_it := !NumGet(lParam+24) 
        if (!update_it) 
        { 
            rect_found_left:=NumGet(lParam+8,0,"int"), rect_found_right:=NumGet(lParam+8,8,"int") 
            rect_found_top:=NumGet(lParam+8,4,"int"), rect_found_bottom:=NumGet(lParam+8,12,"int") 
            if (rect_left >= rect_found_left && rect_right <= rect_found_right 
                && rect_top >= rect_found_top && rect_bottom <= rect_found_bottom) 
                update_it := true 
            else if (distance < NumGet(lParam+28,0,"double") 
                && (rect_found_left < rect_left || rect_found_right > rect_right 
                 || rect_found_top < rect_top || rect_found_bottom > rect_bottom)) 
                 update_it := true 
        } 
        if (update_it) 
        { 
            NumPut(aWnd, lParam+24) 
            DllCall("RtlMoveMemory","uint",lParam+8,"uint",&rect,"uint",16) 
            NumPut(distance, lParam+28, 0, "double") 
        } 
    } 
    return true 
}

; Generate random number between x-y
RandNum(x,y) 
{
	Random, rand, %x%, %y%
	return rand
}

; Script for anti-afk. Blizzard seems to detect non-movement based stuff (i.e. tapping A/D, jumping, whatever)
; This causes forced-to-login screen situations with no warning. It's obviously not bannable but still strange.
; We need varied behavior as well as making sure we don't out of range the AH NPC...
AntiAfk(ByRef ID, ByRef XPos, ByRef ResetCount) 
{	
	; Firstly we need to interact with NPC
	ControlSend, ahk_parent, {Esc}, ahk_id %ID%
	Sleep 500
	
	; Interacting with NPC clears any other kind of AFK flag so all we have to do is move around but not too far
	; Decide how many movements to make and then make random left and right movements (but remember center position)
	; We also only need to do this to clear real AFK flag (not client displayed one), so not necessary EVERY loop.
	
	; This is solved by counting our overall resets and only moving every so many resets (every 10-15min!)
	ResetFlag := Mod(ResetCount, 4)
	If (ResetFlag = 0) 
	{
		;Tooltip, MoveCharacter, 0, 0
		Random, XMove, 1, 4
		
		Loop, %XMove%
		{							
			; RandNum function is not available here..
			Random, HoldTime, 10, 100
			
			; We can't controlsend downkey, so use global keydelay.
			SetKeyDelay, 10, %HoldTime%
			
			; Select random movement dir.
			Random, MovDir, 0, 1
			
			; But ignore it if we are out of bounds.
			If (XPos > 200) 
			{
				; We moved too far right. 
				MovDir = 1
			}
			
			If (XPos < -200)
			{
				MovDir = 0
			}
			
			; If we have another XMove queued
			If (MovDir = 1) 
			{
				; We should move right (and sub from MA)
				XPos := XPos - HoldTime
				ControlSend, ahk_parent, {d}, ahk_id %ID%
			}
			Else
			{
				; We should move left (and add to MA)
				XPos := XPos + HoldTime
				ControlSend, ahk_parent, {a}, ahk_id %ID%
			}
		}
		
		; Reset to default key delay
		SetKeyDelay, -1, -1
	}
	
	; Open the Auction House (interact with NPC)
	ControlSend, ahk_parent, {F7}, ahk_id %ID%
	Sleep 3000
	
	; Start buyout sniper
	ControlClick2(174, 108, "ROSENWALD")
	
	;Tooltip, RestartSniper, 0, 0
	return
}

; Remove tooltip in top left (on a timer usually)
RemoveToolTip:
	ToolTip
	return

; Select our target window for sending input
^y::
	ID := WinExist("A") 
	WinSetTitle, ahk_id %ID%,, ROSENWALD
	ToolTip, % ID, 0, 0
	SetTimer, RemoveToolTip, -3000 
	Return
	
F5::
	; Our hotkey (F5) toggles loop activity
	Toggle:=!Toggle
	
	; Shows tooltip in top left (0 = inactive, 1 = active)
	ToolTip, % Toggle, 0, 0
	
	; Loop counter vars
	Counter := 0
	ResetTicks := 0
	ResetCount := 0
	
	; Movement tracking
	XPos := 0
	
	While, Toggle
	{
		; If we do not have a reset tick, we either just started the macro
		; Or we just Anti-AFK'd - randomly choose loop count for next antiafk
		If (ResetTicks = 0)
		{	
			Random, ResetTicks, 500, 1000
		}
		
		;ToolTip, %Counter% / %ResetTicks%, 0, 0
		
		; This code clicks the first row and buyout buttons.
		ControlClick2(451, 130, "ROSENWALD")
		Sleep RandNum(40,75)
		ControlClick2(516, 360, "ROSENWALD")
		Sleep RandNum(125,175)
		
		; Keep track of the number of overall loops.
		; Written this way to prevent running AFK code when toggling.
		If (Toggle) 
		{
			Counter++
		}
		
		; We run Anti AFK code every so many loops.
		If (Counter > ResetTicks) 
		{
			;Tooltip, RunAFKCode, 0, 0
			Counter := 0
			ResetTicks := 0
			ResetCount++
			AntiAfk(ID, XPos, ResetCount)
		}
	}
	Return
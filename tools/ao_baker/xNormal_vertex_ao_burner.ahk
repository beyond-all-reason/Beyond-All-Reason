#NoEnv  ; Recommended for performance and compatibility with future AutoHotkey releases.
; #Warn  ; Enable warnings to assist with detecting common errors.
SendMode Input  ; Recommended for new scripts due to its superior speed and reliability.
SetWorkingDir %A_ScriptDir%  ; Ensures a consistent starting directory.

;loop over all files and convert them into .obj files
; done

;run xnormal for all of them
CoordMode, Mouse, Relative
Loop, C:\Users\Flowris\Documents\My Games\Spring\0_dev\BAR-repostuff\Tools\OBJtoS3O_Converter\objects3d_input\*.obj
{
WinActivate, Simple ambient occlusion generator
MouseMove, 60, 60
Click
Send, ^a
Send, {Delete}

Send, %A_LoopFileFullPath%

MouseMove, 41, 262
Click
Send, ^a
Send, {Delete}
SplitPath, A_LoopFileFullPath, ,OVBDir, ,OVBname
OVBFile = %OVBDir%\%OVBNAME%.ovb
Send, %OVBFile%

MouseMove, 550, 550
Click


WinWaitActive, Information, , 30
MouseMove, 220, 140
Click

}
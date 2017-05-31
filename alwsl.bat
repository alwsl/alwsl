@echo off
:: == ignore this =======================================================================================
SETLOCAL EnableDelayedExpansion
for /F "tokens=1,2 delims=#" %%a in ('"prompt #$H#$E#&echo on&for %%b in (1) do rem"') do (set "DEL=%%a")
set fail=call :colbang 0c "fail" & set info=call :colbang 0b "info" & set warn=call :colbang 0e "warn"
:: ======================================================================================================

REM Todo
REM - add user switching


if "%~1" == "update" (
	%fail% "Not yet implemented"
	goto :eof
)

if "%~1" == "user" (
	if not exist "%localappdata%\lxss\rootfs\usr\share\issue" (
		%fail% "alwsl is not installed. Try >alwsl install<."
		goto :eof
	)

	if "%~2" == "" (
		%fail% "user requires a subtask."
		goto :eof
	)

	if "%~2" == "default" (
		REM This doesn't work at all.
		if "%~3" == "" (
			%fail% "No username given to switch to."
			goto :eof
		)

		lxrun /setdefaultuser "%~3"
		goto :eof
	)

	if "%~2" == "remove" (
		REM Untested.
		if "%~3" == "" (
			%fail% "No username given to remove."
			goto :eof
		)

		%info% "Removing %~3 and switching to root."
		lxrun /setdefaultuser "root"
		bash -c "userdel %~3"
		goto :eof
	)
)


if "%~1" == "snapshot" (
	if not exist "%localappdata%\lxss\rootfs\usr\share\issue" (
		%fail% "alwsl is not installed. Try >alwsl install<."
		goto :eof
	)

	if "%~2" == "" (
		%fail% "snapshot requires a subtask"
		goto :eof
	)

	if "%~2" == "list" (
		for /F %%i in ('dir /b "%localappdata%\lxss\snapshots\*"') do (
			echo %%~ni
			goto :eof
		)

		%fail% "There are no snapshots."
		goto :eof
	)

	if "%~2" == "restore" (
		if "%~3" == "" (
			%fail% "No timestamp given for restore."
			goto :eof
		)

		if not exist "%localappdata%\lxss\snapshots\%~3.sfs" (
			%fail% "That snapshot doesn't exist."
			goto :eof
		)

		call :overwritefs "%localappdata%\lxss\snapshots\%~3.sfs"
		call :waitforexit
		call :transpose
	)

	if "%~2" == "restore-sfs" (
		if "%~3" == "" (
			%fail% "No file given for restore."
			goto :eof
		)

		if not exist "%~3" (
			%fail% "That file doesn't exist."
			goto :eof
		)

		call :overwritefs "%~3"
		call :waitforexit
		call :transpose
	)

	if "%~2" == "create" (
		%info% "Creating snapshot..."
		cd "%localappdata%\lxss\snapshots"
		bash -c "mksquashfs / $(date +""%%Y-%%m-%%d_%%H-%%M-%%S"").sfs -b 1048576 -comp xz -Xdict-size 100%% -all-root -e /mnt 2>/dev/null"
		cd "%~dp0"
		goto :eof
	)

	if "%~2" == "remove-all" (
		REM Don't add a choice here, del does that.
		del "%localappdata%\lxss\snapshots\*"
		goto :eof
	)

	if "%~2" == "remove" (
		if "%~3" == "" (
			%fail% "No timestamp given for remove."
			goto :eof
		)

		if not exist "%localappdata%\lxss\snapshots\%~3.sfs" (
			%fail% "That snapshot doesn't exist."
			goto :eof
		)

		del "%localappdata%\lxss\snapshots\%~3.sfs"
		if exist "%localappdata%\lxss\snapshots\%~3.sfs" (
			%fail% "Failed to remove snapshot."
		)
		goto :eof
	)

	goto :eof
)

if "%~1" == "remove" (
	%warn% "This can't be undone."
	choice /M "Proceed and remove rootfs now?"
	if errorlevel 2 goto :eof
	call :purge
	if exist "%localappdata%\lxss\rootfs\usr\share\issue" (
		%fail% "Could not remove alwsl. Try again."
		goto :eof
	)
	%info% "Successfully removed al+wsl."
	goto :eof
)

if "%~1" == "install" (
	FOR /F "tokens=3,* skip=2" %%L IN ('reg query "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock" /v "AllowDevelopmentWithoutDevLicense"') DO (
		if not "%%L" == "0x1" (
			reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock" /v "AllowDevelopmentWithoutDevLicense" /t REG_DWORD /d "0x1"
		)
	)

	if exist "%localappdata%\lxss\sha256" (
		%warn% "There's already a WSL rootfs installed. We need to remove that. If you have data there,"
		%warn% "cancel this and backup your rootfs."
		choice /M "Proceed with alwsl install and remove old rootfs now?"
		if errorlevel 2 goto :eof
	)
	%info% "Cleaning old files."
	call :purge

	%info% "Installing base lxss fs from trusty server image. This will take A WHILE."
	lxrun /install /y  || (
		%warn% "Problem with MWSL!"
		%info% "Make sure, that it is installed and enabled in windows components..."
		%info% "Try this following command in PowerShell:"
		%info% "Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux"
	)
	if not exist "%localappdata%\lxss\root\.bashrc" (
		%fail% "lxrun failed to install Microsoft's rootfs. Try to restart alwsl again. If this"
		%fail% "error persists, check your firewall and AV. If all fails, open a GH issue."
		goto :eof
	)

	bash -c "apt-get -qq update >/dev/null ; apt-get -qq --force-yes install squashfs-tools >/dev/null"

	%info% "Downloading alwsl rootfs (this might take a while)..."
	bitsadmin /RAWRETURN /transfer alwsl /download /priority FOREGROUND "https://cdn.xorable.org/alwsl.sfs" "%~dp0alwsl.sfs"
	If Not Exist "%~dp0alwsl.sfs" (
		%fail% "Err, download failed. Try again (and check your firewall/AV settings)."
		goto :eof
	)

	call :overwritefs "%~dp0alwsl.sfs"
	call :waitforexit
	call :transpose

	%info% "Checking installation success..."
	if not exist "%localappdata%\lxss\rootfs\usr\share\issue" (
		%fail% "Installation failed. Bash is still ubuntu. Try again."
		goto :eof
	)

	mkdir "%localappdata%\lxss\snapshots"

	%info% "Renaming shortcut."
	del "%USERPROFILE%\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Bash on Ubuntu on Windows.lnk" > nul
	:: TODO : Replace internet resource via embed icon file? I'am just leave it here for maintain developers. Special thanks for a guys from github!
	bitsadmin /RAWRETURN /transfer alwsl /download /priority FOREGROUND "https://cdn.xorable.org/archlinux.ico" "%localappdata%\lxss\archlinux.ico"
	call :create_shortcut "%USERPROFILE%\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\"
	del /Q "%~dp0*.sfs" 2> nul
	del /Q "%~dp0checksum" 2> nul

	%info% "All done. Have fun! And open an issue for any ... issue you run into!"
	choice /M "Do you want to start bash now?"
	if errorlevel 2 goto :eof
	bash -c "cat /usr/share/issue" & bash
	goto :eof
)

echo\
%info% "alwsl - install and manage archlinux as the WSL distro"
%warn% "IMPORTANT: Read what NOT to do in alwsl at git.io/alwsl. alwsl is a non-standard distribution"
%warn% "and therefore not supported at the archlinux BBS. Ask for support at the above URL only."
echo\
echo Usage: alwsl task [subtask] [arg]
echo\
echo List of tasks:
echo\
echo install                Install alwsl from scratch. Implies remove task.
echo\
echo remove                 Uninstall WSL completely.
echo\
echo snapshot               Create and manage snapshots of the root file system. This does not include the /home of ANY
echo                        user (not even root). Create a snapshot if you think you're about to do something stupid and
echo                        need a way to get back to a working system.
echo     create             Capture the current rootfs.
echo     remove TIME        Delete snapshot TIME.
echo     list               List all available snapshots.
echo     remove-all         Delete all snapshots.
echo     restore TIME       Reset rootfs to TIME.
echo     restore-sfs SFS    Replace rootfs with third-party squashfs SFS. UNSUPPORTED.
echo\
echo user                   Manage the user which hosts bash.
echo     remove             Delete this user account and switch default to root.
echo     default USER       Switch default to USER (you did remember to add them to sudoers, right?).
echo\
echo update                 Check for and perform an update for the base alwsl rootfs. This will undo any changes you've
echo                        made not in a /home directory. You might want to create a snapshot before doing this.

goto :eof

:overwritefs
set wrfs=%~1
set wrfs=%wrfs:~3%
set wrfs=%wrfs:\=/%
set mountpoint=/mnt/%cd:~0,1%/
set "_UCASE=ABCDEFGHIJKLMNOPQRSTUVWXYZ"
set "_LCASE=abcdefghijklmnopqrstuvwxyz"
for /l %%a in (0,1,25) do (
	call set "_FROM=%%_UCASE:~%%a,1%%
	call set "_TO=%%_LCASE:~%%a,1%%
	call set "mountpoint=%%mountpoint:!_FROM!=!_TO!%%
)
set mountpoint=%mountpoint%%wrfs%
%info% "Copying rootfs to temporary extraction destination."
bash -c "cd && mkdir -p rootfs-temp && cd rootfs-temp && cp \"%mountpoint%\" ."
%info% "Unsquashing rootfs."
bash -c "cd && cd rootfs-temp && unsquashfs -f -x -d . %~n1.sfs 2>/dev/null"
goto :eof

:transpose
timeout /t 5 /nobreak >nul
%info% "Transforming..."
move "%localappdata%\lxss\rootfs" "%localappdata%\lxss\rootfs-backup"
move "%localappdata%\lxss\root\rootfs-temp" "%localappdata%\lxss\rootfs"
move "%localappdata%\lxss\rootfs-backup" "%localappdata%\lxss\rootfs\tmp"
bash -c "cd / ; rm *.sfs ; rm -rf tmp ; mkdir -p tmp"
goto :eof

:waitforexit
if exist "%localappdata%\lxss\temp" (
	goto :waitforexit
)
goto :eof

:purge
del /Q "%~dp0*.sfs" 2> nul
del /Q "%USERPROFILE%\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\ArchLinux.lnk" 2> nul
del /Q "%~dp0checksum" 2> nul
lxrun /uninstall /full /y > nul
goto :eof

:colbang
echo off&set "b=%~n0 (%~2)"
<nul set /p ".=%DEL%">"%b%"
findstr /v /a:%1 /R "^$" "%b%" nul&del "%b%">nul 2>&1&echo : %~3
goto :eof

:create_shortcut
(
echo -----BEGIN CERTIFICATE-----
echo TAAAAAEUAgAAAAAAwAAAAAAAAEb7AggAIAAAALEIDfh79NEBFxuvoZP50QFXfbGh
echo k/nRAQAcAQAAAAAAAQAAAFQGAAAAAAAAAAAAADkBFAAfUOBP0CDqOmkQotgIACsw
echo MJ0ZAC9DOlwAAAAAAAAAAAAAAAAAAAAAAAAAVgAxAAAAAAAUSbB0EABXaW5kb3dz
echo AEAACQAEAO++E0k5ixRJsHQuAAAAyQEAAAAAUAAAAAAAAAAAAAAAAAAAADdqFAFX
echo AGkAbgBkAG8AdwBzAAAAFgBaADEAAAAAABVJTUQQAFN5c3RlbTMyAABCAAkABADv
echo vhNJOYsVSU1ELgAAAPkBAAAAABcAAAAAAAAAAAAAAAAAAAB6URwBUwB5AHMAdABl
echo AG0AMwAyAAAAGABaADIAABwBABJJIqggAGJhc2guZXhlAABCAAkABADvvgxJo0sS
echo SSKoLgAAAADHCwAAAAIAAAAAAPMAAAAAAAAAAACpahMAYgBhAHMAaAAuAGUAeABl
echo AAAAGAAAAEsAAAAcAAAAAQAAABwAAAAtAAAAAAAAAEoAAAARAAAAAwAAADLXYEwQ
echo AAAAAEM6XFdpbmRvd3NcU3lzdGVtMzJcYmFzaC5leGUAADEALgAuAFwALgAuAFwA
echo LgAuAFwALgAuAFwALgAuAFwALgAuAFwALgAuAFwALgAuAFwAVwBpAG4AZABvAHcA
echo cwBcAFMAeQBzAHQAZQBtADMAMgBcAGIAYQBzAGgALgBlAHgAZQAVACUAcwB5AHMA
echo dABlAG0AcgBvAG8AdAAlAFwAUwB5AHMAdABlAG0AMwAyAAEAfgAhACUAbABvAGMA
echo YQBsAGEAcABwAGQAYQB0AGEAJQBcAGwAeABzAHMAXABhAHIAYwBoAGwAaQBuAHUA
echo eAAuAGkAYwBvABAAAAAFAACgJQAAAN0AAAAcAAAACwAAoHdOwRrnAl1Ot0Qusa5R
echo mLfdAAAAYAAAAAMAAKBYAAAAAAAAAGRhbGVrAAAAAAAAAAAAAAAkPbRiR4o2TKiR
echo FNzMraJQr9G6bgZm5hGu02Btx4GgUiQ9tGJHijZMqJEU3MytolCv0bpuBmbmEa7T
echo YG3HgaBSFAMAAAEAAKAlc3lzdGVtcm9vdCVcU3lzdGVtMzJcYmFzaC5leGUAAAAA
echo AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
echo AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
echo AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
echo AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
echo AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACUAcwB5AHMAdABlAG0A
echo cgBvAG8AdAAlAFwAUwB5AHMAdABlAG0AMwAyAFwAYgBhAHMAaAAuAGUAeABlAAAA
echo AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
echo AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
echo AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
echo AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
echo AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
echo AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
echo AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
echo AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
echo AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
echo AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA9AgAACQAAoFkAAAAxU1BT7TC92kMA
echo iUen+NATpHNmIj0AAABkAAAAAB8AAAAWAAAAUwB5AHMAdABlAG0AMwAyACAAKABD
echo ADoAXABXAGkAbgBkAG8AdwBzACkAAAAAAAAAjQAAADFTUFPiilhGvEw4Q7v8E5Mm
echo mG3OcQAAAAQAAAAAHwAAAC8AAABTAC0AMQAtADUALQAyADEALQAzADgAOAA0ADEA
echo NQA3ADEAMQA0AC0AMwA1ADAAMgA2ADMAOQA5ADEANQAtADQAMAA0ADEAMwA4ADkA
echo OAA5ADMALQAxADAAMAAxAAAAAAAAAAAAqQAAADFTUFMw8SW370caEKXxAmCMnuus
echo JQAAAAoAAAAAHwAAAAkAAABiAGEAcwBoAC4AZQB4AGUAAAAAABUAAAAPAAAAAEAA
echo AAAAXaL4e/TRARUAAAAMAAAAABUAAAAAHAEAAAAAACkAAAAEAAAAAB8AAAAMAAAA
echo QQBwAHAAbABpAGMAYQB0AGkAbwBuAAAAFQAAAA4AAAAAQAAAAFd9saGT+dEBAAAA
echo AGkAAAAxU1BTpmpjKD2V0hG11gDAT9kY0E0AAAAeAAAAAB8AAAAdAAAAQwA6AFwA
echo VwBpAG4AZABvAHcAcwBcAFMAeQBzAHQAZQBtADMAMgBcAGIAYQBzAGgALgBlAHgA
echo ZQAAAAAAAAAAADkAAAAxU1BTsRZtRK2NcEinSEAupD14jB0AAABoAAAAAEgAAABS
echo 7Al1AAAAAAAAUB8AAAAAAAAAAAAAAAAAAAAA
echo -----END CERTIFICATE-----
)>file.tmp
certutil -decode file.tmp "%~1ArchLinux.lnk" >nul
del file.tmp
goto :eof
:: =====================================================================================================

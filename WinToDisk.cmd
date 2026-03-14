@echo off

:: 1. ADMIN
echo.
fsutil dirty query %systemdrive% >nul 2>&1
if errorlevel 1 (
    REM Not admin, so elevate
    echo Requesting Administrator privileges...
    powershell -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)

setlocal EnableExtensions EnableDelayedExpansion
title WinToDisk - Install Windows to Another Disk [UEFI/GPT or BIOS/MBR]

::=================================================
:: 2.1 DRIVE LETTER CONFIGURATION (EDIT IF NEEDED)
::=================================================
:: System Boot Partition Letter.
set "ESP=Y"
:: Windows Partition Letter.
set "WIN=W"
:: Recovery Partition Letter.
set "REC=U"
::===================================================
:: 2.2 PARTITION SIZE CONFIGURATION (EDIT IF NEEDED)
::===================================================
:: EFI System Partition (ESP) Size in MB, UEFI-GPT Only.
set "ESP_SIZE=300"
:: Microsoft Reserved Partition (MSR) Size in MB, UEFI-GPT Only.
set "MSR_SIZE=16"
:: Recovery Partition Size in MB, Both UEFI-GPT and BIOS-MBR.
set "REC_SIZE=1026"
:: System Reserved Partition Size in MB, BIOS-MBR Only.
set "SRP_SIZE=500"
:: NOTE: Windows Partition Size will take the rest of the space, UEFI-GPT and BIOS-MBR.
::======================================================================================

:: 2.3 DRIVE LETTER CHECK
echo.
echo Checking drive letter availability...
set "CONFLICT=0"
for %%A in ("%ESP%" "%WIN%" "%REC%") do (
    if not "%%~A"=="" (
        if exist %%~A:\ (
            echo.
            echo [ERROR] Drive letter %%~A: is currently in use.
            set "CONFLICT=1"
        )
    )
)

if "%CONFLICT%"=="1" (
    echo.
    echo [CRITICAL] One or more drive letters are taken. Edit the script "Right-Click > Edit in Notepad" and change "2.1 DRIVE LETTER CONFIGURATION".
    pause
    exit /b
)

echo.
echo [OK] All required drive letters are available.

:: 3. IMAGE DETECTION
:input_setup
echo.
echo ==================================================
echo             IMAGE AND DRIVE CONFIGURATION
echo ==================================================
echo Enter Drive Letter (e.g. E) or Full Path (e.g. C:\Images\install.wim)
set /p USERPATH="Input: "
set "USERPATH=%USERPATH:"=%"
set "IMG="

if exist "%USERPATH%" (
    echo "%USERPATH%" | findstr /i ".wim .esd" >nul && set "IMG=%USERPATH%"
)

if not defined IMG (
    for %%F in (install.wim install.esd) do (
        if exist "%USERPATH%:\sources\%%F" set "IMG=%USERPATH%:\sources\%%F"
        if exist "%USERPATH%:\%%F"         set "IMG=%USERPATH%:\%%F"
        if exist "%USERPATH%\sources\%%F"  set "IMG=%USERPATH%\sources\%%F"
        if exist "%USERPATH%\%%F"          set "IMG=%USERPATH%\%%F"
    )
)

if not defined IMG (
    echo.
    echo [ERROR] No .wim or .esd found in that location.
    pause
    goto input_setup
)

echo.
echo [INFO] Found Image: "%IMG%"

dism /Get-WimInfo /WimFile:"%IMG%" > "%temp%\wiminfo.txt"
type "%temp%\wiminfo.txt" | findstr /C:"Index" /C:"Name" /C:"Description" /C:"Architecture"
del "%temp%\wiminfo.txt"

set "MAX_INDEX=0"
for /f "tokens=2 delims=: " %%A in ('dism /Get-WimInfo /WimFile:"%IMG%" ^| findstr "Index"') do (
    set "MAX_INDEX=%%A"
)

echo.
echo Valid Index range: 1 to %MAX_INDEX%
echo Enter Index Number of the edition you want to install.

:get_index
set "INDEX="
set /p INDEX="Index: "

if not defined INDEX (
    echo [ERROR] You must enter an index number.
    goto :get_index
)

set /a "NUM_CHECK=INDEX"
if not "!NUM_CHECK!"=="!INDEX!" (
    echo [ERROR] Input must be a number.
    goto :get_index
)

if %INDEX% LSS 1 (
    echo [ERROR] Index cannot be less than 1.
    goto :get_index
)
if %INDEX% GTR %MAX_INDEX% (
    echo [ERROR] Index %INDEX% does not exist. Maximum is %MAX_INDEX%.
    goto :get_index
)

echo [OK] Index %INDEX% selected.

:: 4. DISK SELECTION
:select_disk
echo.
echo ==================================================
echo               AVAILABLE PHYSICAL DISKS
echo ==================================================

for /f %%D in ('powershell -Command "(Get-Partition | Where-Object IsBoot -eq $true | Get-Disk).Number"') do set SYSTEMDISK=%%D

set "AVAILDISKS="
for /f %%D in ('powershell -Command "Get-Disk | Select-Object -ExpandProperty Number"') do (
    set "AVAILDISKS=!AVAILDISKS! %%D"
)

powershell -Command "Get-Disk | Select-Object Number, FriendlyName, @{Name='Size(GB)';Expression={'{0:N2}' -f ($_.Size/1GB)}} | Format-Table -AutoSize"

echo ==================================================
echo Available Disks: !AVAILDISKS!
echo System Disk: %SYSTEMDISK% ^(PROTECTED^)
echo ==================================================
echo Enter Targeted Disk Number (e.g., 1)
set /p DISKNUM="Disk: "

if not defined DISKNUM (
    echo [ERROR] You must enter a disk number.
    pause
    goto :select_disk
)

if "%DISKNUM%"=="%SYSTEMDISK%" (
    echo [ERROR] Disk %DISKNUM% is your system disk. Cannot select.
    pause
    goto :select_disk
)

set "FOUND=0"
for %%X in (!AVAILDISKS!) do (
    if "%%X"=="%DISKNUM%" set FOUND=1
)

if !FOUND! == 0 (
    echo [ERROR] Disk %DISKNUM% does not exist or is not available.
    pause
    goto :select_disk
)

echo [SUCCESS] Selected Disk: %DISKNUM%

:: 5. FIRMWARE SELECTION
:firmware_choice
echo.
echo ==================================================
echo             BOOT MODE SELECTION
echo ==================================================
set "DETECTED=BIOS"
bcdedit | find /i "path" | find /i "efi" >nul && set "DETECTED=UEFI"

echo [SYSTEM REPORT] Your current system is running in: %DETECTED% mode.
echo.
echo Select target Boot Mode for Disk %DISKNUM%:
echo [1] UEFI (GPT) - Recommended for modern PCs
echo [2] BIOS (MBR) - For older PCs / Legacy mode
echo.
set /p CHOICE="Selection (1 or 2): "

if "%CHOICE%"=="1" (
    set "FW=UEFI"
    goto :confirm_firmware
) else if "%CHOICE%"=="2" (
    set "FW=BIOS"
    goto :confirm_firmware
) else (
    echo [ERROR] Invalid selection. Please enter 1 or 2.
    pause
    goto :firmware_choice
)

:confirm_firmware
echo ============================================================
echo   WARNING: ALL DATA ON DISK %DISKNUM% WILL BE ERASED.
echo   Target Boot Mode: %FW%
echo ============================================================
set /p CONFIRM="Type Y to confirm (or N to cancel): "

if /i "%CONFIRM%"=="Y" (
    goto :start_partitioning
) else if /i "%CONFIRM%"=="N" (
    goto :select_disk
) else (
    echo [ERROR] Invalid input. Please type Y or N.
    pause
    goto :confirm_firmware
)

:: 6. DISKPART: PARTITIONING
:start_partitioning
echo.
echo [INFO] Partitioning Disk %DISKNUM% for %FW%...

(
    echo select disk %DISKNUM%
    echo clean
) | diskpart

if /i "%FW%"=="UEFI" (
    echo [INFO] Setting up UEFI/GPT layout...
    (
        echo select disk %DISKNUM%
        echo convert gpt
    ) | diskpart
    
    timeout /t 5 /nobreak >nul

    (echo select disk %DISKNUM% & echo list partition) | diskpart | findstr /i "Partition 1" >nul
    
    if %errorlevel% equ 0 (
        echo [INFO] Partition 1 found after conversion. Deleting...
        (
            echo select disk %DISKNUM%
            echo select partition 1
            echo delete partition override
        ) | diskpart >nul 2>&1
    ) else (
        echo [INFO] No partitions found. Proceeding...
    )
    
    timeout /t 5 /nobreak >nul

    (
        echo select disk %DISKNUM%
        echo create partition efi size=%ESP_SIZE%
        echo format fs=fat32 label="System"
        echo assign letter=%ESP%
        echo create partition msr size=%MSR_SIZE%
        echo create partition primary
        echo shrink desired=%REC_SIZE%
        echo format fs=ntfs quick label="Windows"
        echo assign letter=%WIN%
        echo create partition primary
        echo format fs=ntfs quick label="Recovery"
        echo set id=de94bba4-06d1-4d40-a16a-bfd50179d6ac
        echo gpt attributes=0x8000000000000001
        echo assign letter=%REC%
        echo list partition
    ) | diskpart
) else (
    echo [INFO] Setting up BIOS/MBR layout...
    (
        echo select disk %DISKNUM%
        echo convert mbr
        echo create partition primary size=%SRP_SIZE%
        echo format fs=ntfs quick label="System"
        echo assign letter=%ESP%
        echo active
        echo create partition primary
        echo shrink desired=%REC_SIZE%
        echo format quick fs=ntfs label="Windows"
        echo assign letter=%WIN%
        echo create partition primary
        echo format fs=ntfs quick label="Recovery"
        echo set id=27
        echo assign letter=%REC%
        echo list partition
    ) | diskpart
)

echo [INFO] Waiting for volumes to mount...
timeout /t 5 /nobreak >nul

:: 7. APPLY IMAGE
echo.
echo [INFO] Applying Image to %WIN%:\...
dism /Apply-Image /ImageFile:"%IMG%" /Index:%INDEX% /ApplyDir:%WIN%:\
if %errorlevel% neq 0 (
    echo [ERROR] DISM failed. Aborting.
    pause
)

:: 8. BOOTLOADER
echo.
echo [INFO] Writing %FW% Boot Files...
bcdboot %WIN%:\Windows /s %ESP%: /f %FW%
if %errorlevel% neq 0 (
    echo [ERROR] BCDBOOT failed. Aborting.
    pause
)

:: 9. RECOVERY CONFIGURATION
echo.
echo ====================================================
echo   CONFIGURING Windows Recovery Environment (WinRE)
echo ====================================================
set "RECPART="

echo [INFO] Finding Recovery partition on Disk %DISKNUM%...

for /f "usebackq tokens=*" %%P in (`powershell -NoProfile -Command "Get-Partition -DiskNumber %DISKNUM% | Where-Object { $_.GptType -eq '{de94bba4-06d1-4d40-a16a-bfd50179d6ac}' -or $_.MbrType -eq 0x27 } | Select-Object -ExpandProperty PartitionNumber"`) do set "RECPART=%%P"

if "%RECPART%"=="" (
    echo [ERROR] No Recovery partition found on Disk %DISKNUM%!
    echo [SKIP] Skipping Recovery configuration...
) else (
    echo [SUCCESS] Found Recovery Partition at Index: %RECPART%!
    echo [INFO] Configuring Recovery Environment...

    timeout /t 5 /nobreak >nul
    reagentc /disable
    :: "%WIN%:\Windows\System32\reagentc" /disable /target "%WIN%:\Windows"
    timeout /t 5 /nobreak >nul

    if not exist "%REC%:\Recovery\WindowsRE" (
        mkdir "%REC%:\Recovery\WindowsRE"
    )

    if exist "%WIN%:\Windows\System32\Recovery\ReAgent.xml" (
        del /f /q "%WIN%:\Windows\System32\Recovery\ReAgent.xml"
    )

    if exist "%WIN%:\Windows\System32\Recovery\Winre.wim" (
        echo [INFO] Copying Winre.wim to Recovery partition...
        xcopy /h /y /r "%WIN%:\Windows\System32\Recovery\Winre.wim" "%REC%:\Recovery\WindowsRE\" >nul
    ) else (
        echo [ERROR] Winre.wim not found in System32! Recovery setup may fail.
    )

    "%WIN%:\Windows\System32\reagentc" /setreimage /path "%REC%:\Recovery\WindowsRE" /target "%WIN%:\Windows"

    timeout /t 5 /nobreak >nul
    reagentc /enable
    :: "%WIN%:\Windows\System32\reagentc" /enable /target "%WIN%:\Windows"
    timeout /t 5 /nobreak >nul
)

:: 10. FINISHING
echo.
echo [INFO] Cleaning up temporary drive letters...
(   
    echo select disk %DISKNUM%
    echo select volume %REC%
    echo remove letter %REC%
    echo select volume %ESP%
    echo remove letter %ESP%
) | diskpart

echo.
echo =============================================================
echo Installation SUCCESSFUL. boot from Disk %DISKNUM% (%FW% mode)
echo =============================================================
echo Press any key to exit...
endlocal
pause >nul
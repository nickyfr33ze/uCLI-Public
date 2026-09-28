REM Add options for selective upgrades
color 0A
title Windows Package Manager Utility
@echo off
:menu
cls
echo =============================================
echo        WINGET PACKAGE MANAGER UTILITY
echo =============================================
echo 1. Check for updates
echo 2. Update all packages
echo 3. Search for a package
echo 4. Install a package
echo 5. List installed packages
echo 6. Remove a package
echo 7. Exit
echo.
set /p choice=Enter your choice (1-7): 
if "%choice%"=="1" goto check
if "%choice%"=="2" goto updateall
if "%choice%"=="3" goto search
if "%choice%"=="4" goto install
if "%choice%"=="5" goto list
if "%choice%"=="6" goto remove
if "%choice%"=="7" goto end
echo Invalid choice. Please try again.
timeout /t 2 >nul
goto menu

:check
cls
echo [*] Checking for updates...
winget update
pause
goto menu

:updateall
cls
echo [*] Updating all packages...
winget upgrade --all
echo [*] All programs updated.
pause
goto menu

:search
cls
set /p searchterm=Enter package name to search: 
winget search %searchterm%
pause
goto menu

:install
cls
set /p pkgname=Enter package name to install: 
winget install %pkgname%
pause
goto menu

:list
cls
echo [*] Listing installed packages...
winget list
pause
goto menu

:remove
cls
set /p pkgname=Enter package name to remove: 
winget uninstall %pkgname%
pause
goto menu

:end
cls
echo Thank you for using the Windows Package Manageer Utility.cls
echo Exiting...
timeout /t 2 >nul
exit /b 0

@echo off
setlocal enabledelayedexpansion

@rem only for interactive debugging
set _DEBUG=0

@rem #########################################################################
@rem ## Environment setup

set _EXITCODE=0

call :env
if not %_EXITCODE%==0 goto end

call :args %*
if not %_EXITCODE%==0 goto end

@rem #########################################################################
@rem ## Main

set _PYTHON_PATH=
set _GIT_PATH=

if %_HELP%==1 (
    call :help
    exit /b !_EXITCODE!
)
@rem Required for Pandoc filters written in Python (eg. pandoc-include)
call :python3
if not %_EXITCODE%==0 goto end

call :pandoc
if not %_EXITCODE%==0 goto end

call :rsvg_convert
if not %_EXITCODE%==0 goto end

call :texlive
if not %_EXITCODE%==0 goto end

call :git
if not %_EXITCODE%==0 goto end

goto end

@rem #########################################################################
@rem ## Subroutines

@rem output parameters: _DEBUG_LABEL, _ERROR_LABEL, _WARNING_LABEL
:env
set _BASENAME=%~n0
set "_ROOT_DIR=%~dp0"

call :env_colors
set _DEBUG_LABEL=%_NORMAL_BG_CYAN%[%_BASENAME%]%_RESET%
set _ERROR_LABEL=%_STRONG_FG_RED%Error%_RESET%:
set _WARNING_LABEL=%_STRONG_FG_YELLOW%Warning%_RESET%:
goto :eof

:env_colors
@rem ANSI colors in standard Windows 10 shell
@rem see https://gist.github.com/mlocati/#file-win10colors-cmd
set _RESET=[0m
set _BOLD=[1m
set _UNDERSCORE=[4m
set _INVERSE=[7m

@rem normal foreground colors
set _NORMAL_FG_BLACK=[30m
set _NORMAL_FG_RED=[31m
set _NORMAL_FG_GREEN=[32m
set _NORMAL_FG_YELLOW=[33m
set _NORMAL_FG_BLUE=[34m
set _NORMAL_FG_MAGENTA=[35m
set _NORMAL_FG_CYAN=[36m
set _NORMAL_FG_WHITE=[37m

@rem normal background colors
set _NORMAL_BG_BLACK=[40m
set _NORMAL_BG_RED=[41m
set _NORMAL_BG_GREEN=[42m
set _NORMAL_BG_YELLOW=[43m
set _NORMAL_BG_BLUE=[44m
set _NORMAL_BG_MAGENTA=[45m
set _NORMAL_BG_CYAN=[46m
set _NORMAL_BG_WHITE=[47m

@rem strong foreground colors
set _STRONG_FG_BLACK=[90m
set _STRONG_FG_RED=[91m
set _STRONG_FG_GREEN=[92m
set _STRONG_FG_YELLOW=[93m
set _STRONG_FG_BLUE=[94m
set _STRONG_FG_MAGENTA=[95m
set _STRONG_FG_CYAN=[96m
set _STRONG_FG_WHITE=[97m

@rem strong background colors
set _STRONG_BG_BLACK=[100m
set _STRONG_BG_RED=[101m
set _STRONG_BG_GREEN=[102m
set _STRONG_BG_YELLOW=[103m
set _STRONG_BG_BLUE=[104m
goto :eof

@rem input parameter: %*
:args
set _BASH=0
set _HELP=0
set _VERBOSE=0
set __N=0
:args_loop
set "__ARG=%~1"
if not defined __ARG goto args_done

if "%__ARG:~0,1%"=="-" (
    @rem option
    if "%__ARG%"=="-bash" ( set _BASH=1
    ) else if "%__ARG%"=="-debug" ( set _DEBUG=1
    ) else if "%__ARG%"=="-verbose" ( set _VERBOSE=1
    ) else (
        echo %_ERROR_LABEL% Unknown option %__ARG% 1>&2
        set _EXITCODE=1
        goto args_done
    )
) else (
    @rem subcommand
    if "%__ARG%"=="help" ( set _HELP=1
    ) else (
        echo %_ERROR_LABEL% Unknown subcommand %__ARG% 1>&2
        set _EXITCODE=1
        goto args_done
    )
    set /a __N+=1
)
shift
goto :args_loop
:args_done
if %_DEBUG%==1 (
    echo %_DEBUG_LABEL% Options    : _BASH=%_BASH% _VERBOSE=%_VERBOSE% 1>&2
    echo %_DEBUG_LABEL% Subcommands: _HELP=%_HELP% 1>&2
)
goto :eof

:help
if %_VERBOSE%==1 (
    set __BEG_P=%_STRONG_FG_CYAN%
    set __BEG_O=%_STRONG_FG_GREEN%
    set __BEG_N=%_NORMAL_FG_YELLOW%
    set __END=%_RESET%
) else (
    set __BEG_P=
    set __BEG_O=
    set __BEG_N=
    set __END=
)
echo Usage: %__BEG_O%%_BASENAME% { ^<option^> ^| ^<subcommand^> }%__END%
echo.
echo   %__BEG_P%Options:%__END%
echo     %__BEG_O%-bash%__END%       start Git bash shell instead of Windows command prompt
echo     %__BEG_O%-debug%__END%      show commands executed by this script
echo     %__BEG_O%-verbose%__END%    display environment settings
echo.
echo   %__BEG_P%Subcommands:%__END%
echo     %__BEG_O%help%__END%        display this help message
goto :eof

@rem output parameters: _PYTHON_HOME, _PYTHON_PATH
:python3
set _PYTHON_HOME=
set _PYTHON_PATH=

set __PYTHON_CMD=
for /f %%f in ('where python.exe 2^>NUL') do set "__PYTHON_CMD=%%f"
if defined __PYTHON_CMD (
    if %_DEBUG%==1 echo %_DEBUG_LABEL% Using path of Python executable found in PATH 1>&2
    @rem keep _PYTHON_PATH undefined since executable already in path
    goto :eof
) else if defined PYTHON_HOME (
    set "_PYTHON_HOME=%PYTHON_HOME%"
    if %_DEBUG%==1 echo %_DEBUG_LABEL% Using environment variable PYTHON_HOME 1>&2
) else (
    set __PATH=c:\opt
    for /f %%f in ('dir /ad /b "!__PATH!\python-3*" 2^>NUL') do set "_PYTHON_HOME=!__PATH!\%%f"
    if not defined _PYTHON_HOME (
        set "__PATH=%ProgramFiles%"
        for /f "delims=" %%f in ('dir /ad /b "!__PATH!\python-3*" 2^>NUL') do set "_PYTHON_HOME=!__PATH!\%%f"
    )
)
if not exist "%_PYTHON_HOME%\python.exe" (
    echo %_ERROR_LABEL% Python executable not found ^(%_PYTHON_HOME%^) 1>&2
    set _EXITCODE=1
    goto :eof
)
set "_PYTHON_PATH=%_PYTHON_HOME%"
set __PANDOC_INCLUDE=0
if exist "%_PYTHON_HOME%\Scripts\" (
    set "_PYTHON_PATH=!_PYTHON_PATH!;%_PYTHON_HOME%\Scripts"
    if exist "%_PYTHON_HOME%\Scripts\pandoc-include.exe" set __PANDOC_INCLUDE=1
)
@rem user scripts (pip install --user <pkg>, ie. pandoc-include)
for /f "tokens=1,*" %%u in ('%_PYTHON_HOME%\python.exe --version') do (
    for /f "delims=. tokens=1,2,*" %%x in ("%%v") do (
        set "__USER_SCRIPTS_DIR=%APPDATA%\Python\Python%%x%%y\Scripts"
    )
)
if exist "%__USER_SCRIPTS_DIR%" (
    set "_PYTHON_PATH=!_PYTHON_PATH!;%__USER_SCRIPTS_DIR%"
    if exist "%__USER_SCRIPTS_DIR%\pandoc-include.exe" set __PANDOC_INCLUDE=1
)
if %__PANDOC_INCLUDE%==0 (
    echo %_ERROR_LABEL% Executable pandoc-include.exe not found 1>&2
    set _EXITCODE=1
    goto :eof
)
goto :eof

@rem output parameter: _PANDOC_HOME
:pandoc
set _PANDOC_HOME=

set __PANDOC_CMD=
for /f %%f in ('where pandoc.exe 2^>NUL') do set "__PANDOC_CMD=%%f"
if defined __PANDOC_CMD (
    if %_DEBUG%==1 echo %_DEBUG_LABEL% Using path of pandoc executable found in PATH 1>&2
    for %%i in ("%__PANDOC_CMD%") do set "_PANDOC_HOME=%%~dpi"
    goto :eof
) else if defined PANDOC_HOME (
    set "_PANDOC_HOME=%PANDOC_HOME%"
    if %_DEBUG%==1 echo %_DEBUG_LABEL% Using environment variable PANDOC_HOME 1>&2
) else (
    set __PATH=C:\opt
    for /f %%f in ('dir /ad /b "!__PATH!\pandoc-2*" 2^>NUL') do set "_PANDOC_HOME=!__PATH!\%%f"
    if not defined _PANDOC_HOME (
        set "__PATH=%ProgramFiles%"
        for /f "delims=" %%f in ('dir /ad /b "!__PATH!\pandoc-2*" 2^>NUL') do set "_PANDOC_HOME=!__PATH!\%%f"
    )
)
if not exist "%_PANDOC_HOME%\pandoc.exe" (
    echo %_ERROR_LABEL% Pandoc executable not found ^(%_PANDOC_HOME%^) 1>&2
    set _EXITCODE=1
    goto :eof
)
goto :eof

@rem output parameter: _RSVG_CONVERT_HOME
:rsvg_convert
set _RSVG_CONVERT_HOME=

set __RSVG_CONVERT_CMD=
if defined __RSVG_CONVERT_CMD (
    for %%i in ("%__RSVG_CONVERT_CMD%") do set "_RSVG_CONVERT_HOME=%%~dpi"
    if %_DEBUG%==1 echo %_DEBUG_LABEL% Using path of rsvg-convert executable found in PATH 1>&2
    for %%i in ("%__RSVG_CONVERT_CMD%") do set "_RSVG_CONVERT_HOME=%%~dpi"
    goto :eof
) else if defined RSVG_CONVERT_HOME (
    set "_RSVG_CONVERT_HOME=%RSVG_CONVERT_HOME%"
    if %_DEBUG%==1 echo %_DEBUG_LABEL% Using environment variable PANDOC_HOME 1>&2
) else (
    set __PATH=C:\opt
    for /f %%f in ('dir /ad /b "!__PATH!\rsvg-convert-*" 2^>NUL') do set "_RSVG_CONVERT_HOME=!__PATH!\%%f"
    if not defined _RSVG_CONVERT_HOME (
        set "__PATH=%ProgramFiles%"
        for /f "delims=" %%f in ('dir /ad /b "!__PATH!\rsvg-convert-*" 2^>NUL') do set "_RSVG_CONVERT_HOME=!__PATH!\%%f"
    )
)
if not exist "%_RSVG_CONVERT_HOME%\rsvg-convert.exe" (
    echo %_ERROR_LABEL% rsvg-convert executable not found ^(%_RSVG_CONVERT_HOME%^) 1>&2
    set _EXITCODE=1
    goto :eof
)
goto :eof

@rem output parameter: _TEXLIVE_HOME
:texlive
set _TEXLIVE_HOME=

set __PDFLATEX_CMD=
for /f %%f in ('where lualatex.exe 2^>NUL') do set "__PDFLATEX_CMD=%%f"
if defined __PDFLATEX_CMD (
    if %_DEBUG%==1 echo %_DEBUG_LABEL% Using path of lualatex executable found in PATH 1>&2
    for %%i in ("%__PDFLATEX_CMD%") do set "__TEXLIVE_WIN32_DIR=%%~dpi"
    for %%f in ("!__TEXLIVE_WIN32_DIR!\..") do set "_TEXLIVE_HOME=%%~dpf"
    goto :eof
) else if defined TEXLIVE_HOME (
    set "_TEXLIVE_HOME=%TEXLIVE_HOME%"
    if %_DEBUG%==1 echo %_DEBUG_LABEL% Using environment variable TEXLIVE_HOME 1>&2
) else (
    set __PATH=C:\opt\texlive
    for /f %%f in ('dir /ad /b "!__PATH!\20*" 2^>NUL') do set "_TEXLIVE_HOME=!__PATH!\%%f"
    if not defined _TEXLIVE_HOME (
        set "__PATH=%ProgramFiles%\texlive"
        for /f "delims=" %%f in ('dir /ad /b "!__PATH!\20*" 2^>NUL') do set "_TEXLIVE_HOME=!__PATH!\%%f"
    )
)
if not exist "%_TEXLIVE_HOME%\bin\win32\lualatex.exe" (
    echo %_ERROR_LABEL% lualatex executable not found ^(%_TEXLIVE_HOME%^) 1>&2
    set _EXITCODE=1
    goto :eof
)
goto :eof

@rem output parameter(s): _GIT_HOME, _GIT_PATH
:git
set _GIT_HOME=
set _GIT_PATH=

set __GIT_CMD=
for /f %%f in ('where git.exe 2^>NUL') do set "__GIT_CMD=%%f"
if defined __GIT_CMD (
    if %_DEBUG%==1 echo %_DEBUG_LABEL% Using path of Git executable found in PATH 1>&2
    for %%i in ("%__GIT_CMD%") do set "__GIT_BIN_DIR=%%~dpi"
    for %%f in ("!__GIT_BIN_DIR!\.") do set "_GIT_HOME=%%~dpf"
    @rem Executable git.exe is present both in bin\ and \mingw64\bin\
    if not "!_GIT_HOME:mingw=!"=="!_GIT_HOME!" (
        for %%f in ("!_GIT_HOME!\.") do set "_GIT_HOME=%%~dpf"
    )
    goto :git_check
) else if defined GIT_HOME (
    set "_GIT_HOME=%GIT_HOME%"
    if %_DEBUG%==1 echo %_DEBUG_LABEL% Using environment variable GIT_HOME 1>&2
) else (
    set __PATH=C:\opt
    if exist "!__PATH!\Git\" ( set _GIT_HOME=!__PATH!\Git
    ) else (
        for /f %%f in ('dir /ad /b "!__PATH!\Git*" 2^>NUL') do set "_GIT_HOME=!__PATH!\%%f"
        if not defined _GIT_HOME (
            set "__PATH=%ProgramFiles%"
            for /f %%f in ('dir /ad /b "!__PATH!\Git*" 2^>NUL') do set "_GIT_HOME=!__PATH!\%%f"
        )
    )
)
:git_check
if not exist "%_GIT_HOME%\bin\git.exe" (
    echo %_ERROR_LABEL% Git executable not found ^(%_GIT_HOME%^) 1>&2
    set _EXITCODE=1
    goto :eof
)
set "_GIT_PATH=;%_GIT_HOME%\bin;%_GIT_HOME%\mingw64\bin;%_GIT_HOME%\usr\bin"
goto :eof

:print_env
set __VERBOSE=%1
set "__VERSIONS_LINE1=  "
set "__VERSIONS_LINE2=  "
set __WHERE_ARGS=
where /q "%PANDOC_HOME%:pandoc.exe"
if %ERRORLEVEL%==0 (
    for /f "tokens=1,*" %%i in ('"%PANDOC_HOME%\pandoc.exe" --version 2^>^&1 ^| findstr /b pandoc') do set "__VERSIONS_LINE1=%__VERSIONS_LINE1% pandoc %%j,"
    set __WHERE_ARGS=%__WHERE_ARGS% "%PANDOC_HOME%:pandoc.exe"
)
where /q "%RSVG_CONVERT_HOME%:rsvg-convert.exe"
if %ERRORLEVEL%==0 (
    for /f "tokens=1,2,*" %%i in ('"%RSVG_CONVERT_HOME%\rsvg-convert.exe" --version 2^>^&1') do set "__VERSIONS_LINE1=%__VERSIONS_LINE1% rsvg-convert %%k,"
    set __WHERE_ARGS=%__WHERE_ARGS% "%RSVG_CONVERT_HOME%:rsvg-convert.exe"
)
where /q "%TEXLIVE_HOME%\bin\win32:lualatex.exe"
if %ERRORLEVEL%==0 (
    for /f "tokens=1-4,*" %%i in ('"%TEXLIVE_HOME%\bin\win32\lualatex.exe" --version 2^>^&1 ^| findstr Version') do set "__VERSIONS_LINE1=%__VERSIONS_LINE1% lualatex %%m,"
    set __WHERE_ARGS=%__WHERE_ARGS% "%TEXLIVE_HOME%\bin\win32:lualatex.exe"
)
where /q "%GIT_HOME%\bin:git.exe"
if %ERRORLEVEL%==0 (
    for /f "usebackq tokens=1,2,*" %%i in (`"%GIT_HOME%\bin\git.exe" --version`) do set "__VERSIONS_LINE2=%__VERSIONS_LINE2% git %%k,"
    set __WHERE_ARGS=%__WHERE_ARGS% "%GIT_HOME%\bin:git.exe"
)
where /q "%GIT_HOME%\usr\bin:diff.exe"
if %ERRORLEVEL%==0 (
   for /f "tokens=1-3,*" %%i in ('"%GIT_HOME%\usr\bin\diff.exe" --version ^| findstr diff') do set "__VERSIONS_LINE4=%__VERSIONS_LINE4% diff %%l,"
    set __WHERE_ARGS=%__WHERE_ARGS% "%GIT_HOME%\usr\bin:diff.exe"
)
where /q "%GIT_HOME%\bin:bash.exe"
if %ERRORLEVEL%==0 (
    for /f "usebackq tokens=1-3,4,*" %%i in (`"%GIT_HOME%\bin\bash.exe" --version ^| findstr bash`) do set "__VERSIONS_LINE2=%__VERSIONS_LINE2% bash %%l"
    set __WHERE_ARGS=%__WHERE_ARGS% "%GIT_HOME%\bin:bash.exe"
)
echo Tool versions:
echo %__VERSIONS_LINE1%
echo %__VERSIONS_LINE2%
if %__VERBOSE%==1 if defined __WHERE_ARGS (
    @rem if %_DEBUG%==1 echo %_DEBUG_LABEL% where %__WHERE_ARGS%
    echo Tool paths: 1>&2
    for /f "tokens=*" %%p in ('where %__WHERE_ARGS%') do echo    %%p 1>&2
    echo Environment variables: 1>&2
    if defined GIT_HOME echo    "GIT_HOME=%GIT_HOME%" 1>&2
	if defined JAVA_HOME echo    "JAVA_HOME=%JAVA_HOME%" 1>&2
    if defined PANDOC_HOME echo    "PANDOC_HOME=%PANDOC_HOME%" 1>&2
    if defined RSVG_CONVERT_HOME echo    "RSVG_CONVERT_HOME=%RSVG_CONVERT_HOME%" 1>&2
    if defined SCALA3_HOME echo    "SCALA3_HOME=%SCALA3_HOME%" 1>&2
    if defined TEXLIVE_HOME echo    "TEXLIVE_HOME=%TEXLIVE_HOME%" 1>&2
)
goto :eof

@rem #########################################################################
@rem ## Cleanups

:end
endlocal & (
    if %_EXITCODE%==0 (
        if not defined CALIBRE_HOME set "CALIBRE_HOME=%_CALIBRE_HOME%"
        if not defined GIT_HOME set "GIT_HOME=%_GIT_HOME%"
		if not defined JAVA_HOME set "JAVA_HOME=%_JAVA_HOME%"
		if not defined MIKTEX_HOME set "MIKTEX_HOME=%_MIKTEX_HOME%"
        if not defined MMD_HOME set "MMD_HOME=%_MMD_HOME%"
        if not defined PANDOC_HOME set "PANDOC_HOME=%_PANDOC_HOME%"
        if not defined RSVG_CONVERT_HOME set "RSVG_CONVERT_HOME=%_RSVG_CONVERT_HOME%"
        if not defined SCALA3_HOME set "SCALA3_HOME=%_SCALA3_HOME%"
        if not defined TEXLIVE_HOME set "TEXLIVE_HOME=%_TEXLIVE_HOME%"
        set "PATH=%PATH%%_PYTHON_PATH%%_GIT_PATH%;%~dp0bin"
        call :print_env %_VERBOSE%
        if %_BASH%==1 (
            if %_DEBUG%==1 echo %_DEBUG_LABEL% %_GIT_HOME%\usr\bin\bash.exe --login 1>&2
            cmd.exe /c "%_GIT_HOME%\usr\bin\bash.exe --login"
        )
    )
    if %_DEBUG%==1 echo %_DEBUG_LABEL% _EXITCODE=%_EXITCODE% 1>&2
    for /f "delims==" %%i in ('set ^| findstr /b "_"') do set %%i=
)

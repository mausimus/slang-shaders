@echo off 
setlocal EnableExtensions DisableDelayedExpansion

set "search=../shaders_slang/"
set "replace="

set "textFile=*.slangp"
set "rootDir=."

for /R "%rootDir%" %%j in ("%textFile%") do (
    for /f "delims=" %%i in ('type "%%~j" ^& break ^> "%%~j"') do (
        set "line=%%i"
        setlocal EnableDelayedExpansion
        set "line=!line:%search%=%replace%!"
        >>"%%~j" echo(!line!
        endlocal
    )
)

endlocal
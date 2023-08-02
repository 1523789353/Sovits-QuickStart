@echo off
set "script=%~0"
set "args=%*"
call :main %*
exit /b %ErrorLevel%

:main
    call :activate
    if not "%ErrorLevel%" == "0" (
        echo=激活虚拟环境失败
        pause
        exit 1
    )
    :: 套一层start, 避免提示"终止批处理操作吗(Y/N)?"
    start "" /b cmd /k
exit /b 0

:activate <激活虚拟环境>
    :: 如果已经激活, 则不再激活
    if "%__ACTIVATE__%" == "0" exit /b 0
    :: 环境变量
    set "HUGGINGFACE_TOKEN=hf_put-your-token-here"
    set "CUDA_HOME=D:/Devtool/Cuda/V12.2"
    set "CUDA_PATH=%CUDA_HOME%"
    :: 尝试激活虚拟环境, 并改变flag
    cd /d "%~dp0"
    2>nul >nul call venv/Scripts/activate.bat
    set "__ACTIVATE__=%ErrorLevel%"
exit /b %__ACTIVATE__%

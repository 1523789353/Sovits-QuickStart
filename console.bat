@echo off
set "script=%~0"
set "args=%*"
call :main %*
exit /b %ErrorLevel%

:main
    call :activate
    if not "%ErrorLevel%" == "0" (
        echo=�������⻷��ʧ��
        pause
        exit 1
    )
    :: ��һ��start, ������ʾ"��ֹ�����������(Y/N)?"
    start "" /b cmd /k
exit /b 0

:activate <�������⻷��>
    :: ����Ѿ�����, ���ټ���
    if "%__ACTIVATE__%" == "0" exit /b 0
    :: ��������
    set "HUGGINGFACE_TOKEN=hf_put-your-token-here"
    set "CUDA_HOME=D:/Devtool/Cuda/V12.2"
    set "CUDA_PATH=%CUDA_HOME%"
    :: ���Լ������⻷��, ���ı�flag
    cd /d "%~dp0"
    2>nul >nul call venv/Scripts/activate.bat
    set "__ACTIVATE__=%ErrorLevel%"
exit /b %__ACTIVATE__%

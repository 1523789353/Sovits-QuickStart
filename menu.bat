@echo off
set "script=%~0"
set "args=%*"
:: 尝试激活虚拟环境
call :activate
call :main %*
exit /b %ErrorLevel%

:main <主函数-菜单>
    cd /d "%~dp0"
    cls
    echo=1. 安装 Python 虚拟环境
    echo=2. 安装/更新 Pytorch+SoVits+DeepFilterNet
    echo=3. 查看环境信息(显卡Cuda信息)
    echo=4. 预处理-分割音频
    echo=5. 预处理-音频重采样
    echo=6. 预处理-生成配置
    echo=7. 预处理-生成hubert与f0
    echo=8. 训练AI模型
    echo=9. 训练cluster模型
    echo=Q. 清理文件(注意备份)
    echo=W. 启动GUI(进行音频推断)
    echo=E. 后处理-消除电音
    echo=R. 退出
    :: 如果有参数, 则自动选择
    if "%~1" == "" (
        choice /c 123456789QWER /n /m "请选择操作:"
    ) else (
        echo %~1 | choice /c 123456789QWER /n /m "请选择操作:"
    )
    cls
    if "%ErrorLevel%" == "1" call :setup
    if "%ErrorLevel%" == "2" call :update
    if "%ErrorLevel%" == "3" call :status
    if "%ErrorLevel%" == "4" call :pre-split
    if "%ErrorLevel%" == "5" call :pre-resample
    if "%ErrorLevel%" == "6" call :pre-config
    if "%ErrorLevel%" == "7" call :pre-hubert
    if "%ErrorLevel%" == "8" call :train
    if "%ErrorLevel%" == "9" call :train-cluster
    if "%ErrorLevel%" == "10" svc clean
    if "%ErrorLevel%" == "11" start "" /b /wait svcg
    if "%ErrorLevel%" == "12" call :deep-filter
    if "%ErrorLevel%" == "13" exit /b 0
    :: 上个命令执行失败时, 暂停显示错误信息
    if not "%ErrorLevel%" == "0" pause
goto :main


:: ===== 内置函数 =====
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
    if not "%__ACTIVATE__%" == "0" (
        echo 注意: 尝试激活虚拟环境失败!
        echo .
    )
exit /b %__ACTIVATE__%

:is_dir
    2>nul >nul dir /a:d "%~1"
exit /b %ErrorLevel%

:is_admin <检查管理员权限>
    2>nul >nul fsutil dirty query %systemdrive%
exit /b %ErrorLevel%

:elevate <请求管理员权限>
    cls
    echo=请求管理员权限...
    start "" /b /wait mshta vbscript:createobject^("shell.application"^).shellexecute^("cmd","/c %script% %* %args%","","runas",1^)^(window.close^)
exit /b 0



:: ===== 功能 =====
:setup <安装 Python 虚拟环境>
    echo=========================================
    echo=安装 Python 虚拟环境
    echo=========================================
    call :is_admin
    if not "%ErrorLevel%" == "0" (
        call :elevate 1
        exit 0
    )
    cd /d "%~dp0"
    :: 如果没有虚拟环境, 则创建虚拟环境
    call :is_dir venv
    if not "%ErrorLevel%" == "0" (
        py -3.10 -m venv venv
        call :activate
    )
    call :update
    cd /d "%~dp0"
    cmd /c status.bat
exit /b 0

:update <安装/更新 Pytorch+SoVits+DeepFilterNet>
    echo=========================================
    echo=安装/更新 Pytorch+SoVits+DeepFilterNet
    echo=========================================
    set "retcode=0"
    py -m pip install -U pip setuptools wheel
    set /a "retcode+=%ErrorLevel%"
    pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu118
    set /a "retcode+=%ErrorLevel%"
    pip install -U so-vits-svc-fork
    set /a "retcode+=%ErrorLevel%"
    pip install deepfilternet SoundFile sox
    set /a "retcode+=%ErrorLevel%"
exit /b %retcode%

:status
    cmd /c status.bat
exit /b 0

:pre-split <预处理-分割音频>
    echo=========================================
    echo=预处理-分割音频(pre-split)
    echo=========================================
    set /p "input_dir=请输入目录路径:"
    svc pre-split -i %input_dir%
exit /b %ErrorLevel%

:pre-resample
    echo=========================================
    echo=预处理-重采样(pre-resample)
    echo=========================================
    svc pre-resample
exit /b %ErrorLevel%


:pre-config
    echo=========================================
    echo=预处理-配置(pre-config)
    echo=========================================
    svc pre-config
exit /b %ErrorLevel%

:pre-hubert
    echo=========================================
    echo=预处理-生成Hubert与f0(pre-hubert)
    echo=========================================
    svc pre-hubert
exit /b %ErrorLevel%

:train <训练AI模型>
    echo=========================================
    echo=训练AI模型(train)
    echo=按 Ctrl+C 终止训练, 建议至少训练 1000 Epochs 以上
    echo=========================================
    svc train -t
exit /b %ErrorLevel%

:train-cluster <训练Cluster模型>
    echo=========================================
    echo=训练Cluster模型(train-cluster)
    echo=========================================
    svc train-cluster
exit /b %ErrorLevel%

:deep-filter
    set /p "input=导入音频路径:"
    set /p "output=导出目录路径:"
    deepFilter %input% -o %output%
exit /b

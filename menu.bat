@echo off
set "script=%~0"
set "args=%*"
:: ���Լ������⻷��
call :activate
call :main %*
exit /b %ErrorLevel%

:main <������-�˵�>
    cd /d "%~dp0"
    cls
    echo=1. ��װ Python ���⻷��
    echo=2. ��װ/���� Pytorch+SoVits+DeepFilterNet
    echo=3. �鿴������Ϣ(�Կ�Cuda��Ϣ)
    echo=4. Ԥ����-�ָ���Ƶ
    echo=5. Ԥ����-��Ƶ�ز���
    echo=6. Ԥ����-��������
    echo=7. Ԥ����-����hubert��f0
    echo=8. ѵ��AIģ��
    echo=9. ѵ��clusterģ��
    echo=Q. �����ļ�(ע�ⱸ��)
    echo=W. ����GUI(������Ƶ�ƶ�)
    echo=E. ����-��������
    echo=R. �˳�
    :: ����в���, ���Զ�ѡ��
    if "%~1" == "" (
        choice /c 123456789QWER /n /m "��ѡ�����:"
    ) else (
        echo %~1 | choice /c 123456789QWER /n /m "��ѡ�����:"
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
    :: �ϸ�����ִ��ʧ��ʱ, ��ͣ��ʾ������Ϣ
    if not "%ErrorLevel%" == "0" pause
goto :main


:: ===== ���ú��� =====
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
    if not "%__ACTIVATE__%" == "0" (
        echo ע��: ���Լ������⻷��ʧ��!
        echo .
    )
exit /b %__ACTIVATE__%

:is_dir
    2>nul >nul dir /a:d "%~1"
exit /b %ErrorLevel%

:is_admin <������ԱȨ��>
    2>nul >nul fsutil dirty query %systemdrive%
exit /b %ErrorLevel%

:elevate <�������ԱȨ��>
    cls
    echo=�������ԱȨ��...
    start "" /b /wait mshta vbscript:createobject^("shell.application"^).shellexecute^("cmd","/c %script% %* %args%","","runas",1^)^(window.close^)
exit /b 0



:: ===== ���� =====
:setup <��װ Python ���⻷��>
    echo=========================================
    echo=��װ Python ���⻷��
    echo=========================================
    call :is_admin
    if not "%ErrorLevel%" == "0" (
        call :elevate 1
        exit 0
    )
    cd /d "%~dp0"
    :: ���û�����⻷��, �򴴽����⻷��
    call :is_dir venv
    if not "%ErrorLevel%" == "0" (
        py -3.10 -m venv venv
        call :activate
    )
    call :update
    cd /d "%~dp0"
    cmd /c status.bat
exit /b 0

:update <��װ/���� Pytorch+SoVits+DeepFilterNet>
    echo=========================================
    echo=��װ/���� Pytorch+SoVits+DeepFilterNet
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

:pre-split <Ԥ����-�ָ���Ƶ>
    echo=========================================
    echo=Ԥ����-�ָ���Ƶ(pre-split)
    echo=========================================
    set /p "input_dir=������Ŀ¼·��:"
    svc pre-split -i %input_dir%
exit /b %ErrorLevel%

:pre-resample
    echo=========================================
    echo=Ԥ����-�ز���(pre-resample)
    echo=========================================
    svc pre-resample
exit /b %ErrorLevel%


:pre-config
    echo=========================================
    echo=Ԥ����-����(pre-config)
    echo=========================================
    svc pre-config
exit /b %ErrorLevel%

:pre-hubert
    echo=========================================
    echo=Ԥ����-����Hubert��f0(pre-hubert)
    echo=========================================
    svc pre-hubert
exit /b %ErrorLevel%

:train <ѵ��AIģ��>
    echo=========================================
    echo=ѵ��AIģ��(train)
    echo=�� Ctrl+C ��ֹѵ��, ��������ѵ�� 1000 Epochs ����
    echo=========================================
    svc train -t
exit /b %ErrorLevel%

:train-cluster <ѵ��Clusterģ��>
    echo=========================================
    echo=ѵ��Clusterģ��(train-cluster)
    echo=========================================
    svc train-cluster
exit /b %ErrorLevel%

:deep-filter
    set /p "input=������Ƶ·��:"
    set /p "output=����Ŀ¼·��:"
    deepFilter %input% -o %output%
exit /b

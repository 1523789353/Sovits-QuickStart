""" 2>nul
@echo off
cls
:: Python 脚本必须为UTF-8编码
:: 而batch脚本必须为GBK(GB-2312)编码
:: 只好牺牲batch脚本的中文了
call :activate
if not "%ErrorLevel%" == "0" (
    echo=Activate virtual environment failed!!!
    pause
    exit 1
)
set "retcode=0"
py %0 %*
set /a "retcode+=%ErrorLevel%"
echo=
nvidia-smi
set /a "retcode+=%ErrorLevel%"
pause
exit /b %retcode%

:activate
    :: 如果已经激活, 则不再激活
    if "%__ACTIVATE__%" == "0" exit /b 0
    :: 环境变量
    set "CUDA_HOME=D:/Devtool/Cuda/V12.2"
    set "CUDA_PATH=%CUDA_HOME%"
    :: 尝试激活虚拟环境, 并改变flag
    cd /d "%~dp0"
    2>nul >nul call venv/Scripts/activate.bat
    set "__ACTIVATE__=%ErrorLevel%"
exit /b %__ACTIVATE__%


"""
import torch


def main():
    # Cuda 信息
    cuda_info = "\n".join([
        "CUDA 可用: {}",
        "CUDA 版本: {}"
    ]).format(
        torch.cuda.is_available(),
        torch.version.cuda,
    )
    print(cuda_info)
    # 设备信息
    count = torch.cuda.device_count()
    current = torch.cuda.current_device()
    for i in range(count):
        props = torch.cuda.get_device_properties(i)
        current = " (当前)" if i == current else ""
        memory = props.total_memory / (1 << 30)
        device_info = "\n".join([
            "CUDA 设备 [{}]:",
            "    名称: {}{}",
            "    总显存: {:.2f} GB"
        ]).format(i, props.name, current, memory)
        print(device_info)


if __name__ == "__main__":
    main()

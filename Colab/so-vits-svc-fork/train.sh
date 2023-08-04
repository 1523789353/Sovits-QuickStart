#!/bin/env bash

# 环境变量 sovits = "/Data/My Drive/so-vits-svc-fork"
model_dir="${sovits}/logs/44k"
# 允许强制退出(0: 允许, 1: 不允许)
allow_force_exit=0

# 导入 colorful.sh (控制台染色)
. ./colorful.sh



log_level="info,warn,error"
# 打印日志函数, 添加进程和时间戳信息, 并且在前面添加新行(避免与svc输出混合)
function log() {
    printf "\n[$(SGR front_purple)Packer$(SGR)][$(SGR front_green)$(date '+%Y-%m-%d %H:%M:%S')$(SGR)]$*\n"
}
function log_debug() {
    if [[ ! "${log_level}" =~ "debug" ]]; then
        return
    fi
    log "[$(SGR front_cyan)Debug$(SGR)]: " "$@"
}
function log_info() {
    if [[ ! "${log_level}" =~ "info" ]]; then
        return
    fi
    log "[$(SGR front_blue)Info$(SGR)]: " "$@"
}
function log_warn() {
    if [[ ! "${log_level}" =~ "warn" ]]; then
        return
    fi
    log "[$(SGR front_yellow)Warn$(SGR)]: " "$@"
}
function log_error() {
    if [[ ! "${log_level}" =~ "error" ]]; then
        return
    fi
    log "[$(SGR front_red)Error$(SGR)]: " "$@" >/dev/stderr
}
# 打印进度条, 注意输出都不会附带 换行/回车 (方便添加前后缀)
function log_prog() {
    # 当前百分比
    percent=$1
    bar_length=$(($percent / 2))

    # 打印进度条前框, 以及文本染色
    printf "[$(SGR front_green back_green)"
    for ((j = 0; j < $bar_length; j++)); do
        # 打印#号, 以应对终端不支持染色, 或进度条写入文件
        printf "#"
    done
    #清除染色
    printf "$(SGR front_black back_black)"
    for ((j = $bar_length; j < 50; j++)); do
        printf " "
    done
    # 打印进度条后框, 以及打印百分比
    printf "$(SGR)] [$(SGR front_purple)%3d%%$(SGR)]" $percent
}
# 休眠进度条(每秒更新)
function sleep_prog() {
    # 时长
    duration=$1
    shift 1
    # 进度条消息处理函数(打印函数), 及其参数
    msg_handler=$@

    # 打印进度条
    for ((i = 0; i <= $duration; i++)); do
        percent=$((100 * $i / $duration))

        # 打印进度条
        if [ -n "${msg_handler}" ]; then
            ${msg_handler} "$(log_prog $percent)"
        else
            # 从行首开始, 打印进度条
            printf "\r"
            log_prog $percent
        fi

        # 最后一次不休眠
        if [ $i -lt $duration ]; then
            # 每秒更新一次
            sleep 1
        fi
    done
    # 手动换行
    printf "\n"
}



# 获取当前模型版本
function get_last_ver() {
    last_ver=0
    for ver in $(ls "${model_dir}" | grep -oE "[0-9]+"); do
        if [ $ver -gt $last_ver ]; then
            last_ver=$ver
        fi
    done
    printf $last_ver
}

# 获取目标模型版本
function get_target_vet() {
    last_ver=$(get_last_ver)
    # target_ver取最近且大于等于它的500倍数
    printf $((($last_ver + 499) / 500 * 500))
}

# 打包模型
function pack() {
    pack_ver=$1
    allow_force_exit=1

    d_file="${model_dir}/D_${pack_ver}.pth"
    g_file="${model_dir}/G_${pack_ver}.pth"
    k_file="${model_dir}/kmeans.pt"
    output_dir="${sovits}/pack_${pack_ver}"
    output_file="${sovits}/pack_${pack_ver}.7z"

    log_info "开始打包$(SGR front_yellow)${pack_ver}$(SGR)版本模型..."

    # 创建目录
    mkdir -p "${output_dir}/"

    if [[ ! -f "${d_file}" && ! -f "${g_file}" ]]; then
        log_error "$(SGR front_red)模型文件不存在, 打包失败$(SGR)"
        return 1
    fi

    # Step1: 训练并移动Cluster模型
    svc train-cluster
    mv "${k_file}" "${output_dir}/kmeans_${pack_ver}.pt"

    # Step2: 拷贝模型
    cp "${d_file}" "${output_dir}/"
    cp "${g_file}" "${output_dir}/"

    # Step3: 删除旧压缩文件, 压缩打包
    if [ -f "${output_file}" ]; then
        rm -rf "${output_file}"
    fi
    7za a -t7z -m0=lzma -mx=9 -mfb=64 -md=32m -ms=on "${output_file}" "${output_dir}/"

    # 删除打包目录
    rm -rf "${output_dir}/"

    allow_force_exit=0

    log_info "打包$(SGR front_yellow)${pack_ver}$(SGR)版本模型完成"
}

function resume_pack() {
    pack_ver=$1
    allow_force_exit=1

    # 备份所有模型
    model_bak="${sovits}/logs/44k_bak"
    mv "${model_dir}/*" "${model_bak}/"
    # 仅保留打包版本模型
    mkdir -p "${model_dir}/"
    mv "${model_bak}/D_${pack_ver}.pth" "${model_dir}/"
    mv "${model_bak}/G_${pack_ver}.pth" "${model_dir}/"
    # 打包指定版本
    pack $pack_ver
    # 恢复所有模型
    mv "${model_dir}/D_${pack_ver}.pth" "${model_bak}/"
    mv "${model_dir}/G_${pack_ver}.pth" "${model_bak}/"
    rm -rf "${model_dir}/"
    mv "${model_bak}/" "${model_dir}/"

    allow_force_exit=0
}

function checkout() {
    log_info "检查打包事务..."
    # 检查未正常结束的打包事务
    for dir_name in $(find "${sovits}/" -maxdepth 1 -name "pack_*" -type d | grep -oE "pack_[0-9]+"); do
        # 未正常结束打包的版本
        ver=$(printf "${dir_name}" | grep -oE "[0-9]+")

        # 跳过不包含版本号的目录, 以及0版本
        if [[ -z "${ver}" || "${ver}" == "0" ]]; then
            continue
        fi

        # 目录绝对路径
        dir_path="${sovits}/${dir_name}"

        log_info "找到$(SGR front_yellow)${ver}$(SGR)版本的打包文件夹\"${dir_path}/\""

        d_file="${model_dir}/D_${ver}.pth"
        g_file="${model_dir}/G_${ver}.pth"
        if [[ -f "${d_file}" && -f "${g_file}" ]]; then
            log_info "找到$(SGR front_yellow)${ver}$(SGR)版本的模型文件, 将继续打包..."
            resume_pack $ver
        else
            log_warn "模型文件不存在"
            log_warn "尝试删除\"${dir_path}/\"文件夹来清除警告"
        fi
    done
}

# 监听模型更新
function listen() {
    target_ver=$(get_target_vet)

    # 0版本不打包, 初始从500起
    if [ "${target_ver}" == "0" ]; then
        target_ver=500
    fi

    d_file="${model_dir}/D_${target_ver}.pth"
    g_file="${model_dir}/G_${target_ver}.pth"

    # 等待模型更新
    until [[ -f "${d_file}" && -f "${g_file}" ]]; do
        log_info "目标版本$(SGR front_yellow)${target_ver}$(SGR), 等待模型更新..."
        sleep 5s
    done
    # 休眠5s，等待模型保存
    sleep 5s

    # 立即打包
    pack $target_ver
}

svc_pid=0

function main() {
    log_warn "注意, Colab运行时可能需要连按三下停止键才能终止进程"

    # 检查未完成的打包事务
    checkout

    # 训练模型
    log_info "$(SGR front_green)开始训练模型...$(SGR)"
    # 后台训练模型
    svc train &

    scv_pid=$!

    # 循环打包
    while true; do
        listen
        # 冷却60s, 防止连续打包
        # 调用sleep_prog, 并把输出移交给log_info函数, 类似 log_info "冷却中... " "<进度条>"
        sleep_prog 60 "log_info" "冷却中... "
    done
}

function on_exit() {
    if [ "${allow_force_exit}" == 0 ]; then
        # 允许强制退出
        log_warn "收到退出信号, 终止进程(状态码: $?)"
        if [ "${svc_pid}" != "0" ]; then
            kill -9 ${svc_pid}
        fi
        exit 0
    else
        # 不允许强制退出
        log_error "$(SGR front_red)收到退出信号, 但现仍有重要任务, 请耐心等待...$(SGR)"
    fi
}

# 异常退出, debug时启用
set -e
# 退出时执行on_exit函数
trap 'on_exit' EXIT SIGINT SIGTERM
# 执行主函数
main "$@"

#!/bin/env bash

# 环境变量 sovits = "/Data/My Drive/so-vits-svc-fork"
model_dir="${sovits}/logs/44k"

function color() {
    font_color=$1
    bg_color=$2

    builder="\033["
    case "${bg_color}" in
        "black") builder+="40;";;
        "red") builder+="41;";;
        "green") builder+="42;";;
        "yellow") builder+="43;";;
        "blue") builder+="44;";;
        "purple") builder+="45;";;
        "cyan") builder+="46;";;
        "white") builder+="47;";;
        *) builder+="0;";;
    esac
    case "${font_color}" in
        "black") builder+="30m";;
        "red") builder+="31m";;
        "green") builder+="32m";;
        "yellow") builder+="33m";;
        "blue") builder+="34m";;
        "purple") builder+="35m";;
        "cyan") builder+="36m";;
        "white") builder+="37m";;
        *) builder+="0m";;
    esac
    echo -en "${builder}"
}

# 打印日志函数, 前面添加新行(避免多线程问题), 并且添加进程和时间戳信息
function log() {
    echo -e "\n[$(color "purple")Packer$(color)][$(color "green")$(date '+%Y-%m-%d %H:%M:%S')$(color)]$*"
}
function log_info() {
    log "[$(color "cyan")Info$(color)]: " "$@"
}
function log_warn() {
    log "[$(color "yellow")Warn$(color)]: " "$@"
}
function log_error() {
    log "[$(color "red")Error$(color)]: " "$@" > /dev/stderr
}


# 获取当前模型版本
function getLastVersion() {
    last_ver=0
    for ver in $(ls "${model_dir}" | grep -oE "[0-9]+"); do
        if [ $ver -gt $last_ver ]; then
            last_ver=$ver
        fi
    done
    echo -n $last_ver
}

# 获取目标模型版本
function getTargetVersion() {
    last_ver=$(getLastVersion)
    # target_ver取最近且大于等于它的500倍数
    echo -n $((($last_ver + 499) / 500 * 500))
}

# 打包模型
function pack() {
    pack_ver=$1

    d_file="${model_dir}/D_${pack_ver}.pth"
    g_file="${model_dir}/G_${pack_ver}.pth"
    k_file="${model_dir}/kmeans.pt"
    output_dir="${sovits}/pack_${pack_ver}"
    output_file="${sovits}/pack_${pack_ver}.7z"

    log_info "开始打包$(color "yellow")${pack_ver}$(color)版本模型..."

    # 创建目录
    mkdir -p "${output_dir}"

    if [[ ! -f "${d_file}" && ! -f "${g_file}" ]]; then
        log_error "$(color "red")模型文件不存在, 打包失败$(color)"
        return 1
    fi

    # Step1: 训练并移动Cluster模型
    svc train-cluster
    mv "${k_file}" "${output_dir}/kmeans_${target_ver}.pt"

    # Step2: 拷贝模型
    cp "${d_file}" "${output_dir}/"
    cp "${g_file}" "${output_dir}/"

    # Step3: 删除旧压缩文件, 压缩打包
    if [ -f "${output_file}" ]; then
        rm -rf "${output_file}"
    fi
    7za a -t7z -m0=lzma -mx=9 -mfb=64 -md=32m -ms=on "${output_file}" "${output_dir}"

    # 删除打包目录
    if [ $? -eq 0 ]; then
        rm -rf "${output_dir}"
    fi

    log_info "打包$(color "yellow")${pack_ver}$(color)版本模型完成"
}

function resume_pack() {
    pack_ver=$1

    # 备份所有模型
    model_bak="${sovits}/logs/44k_bak"
    mv $model_dir $model_bak
    # 仅拷贝打包版本模型
    mkdir -p $model_dir
    mv "${model_bak}/D_${pack_ver}.pth" "${model_dir}/"
    mv "${model_bak}/G_${pack_ver}.pth" "${model_dir}/"
    # 打包指定版本
    pack $pack_ver
    # 恢复所有模型
    rm -rf $model_dir
    mv $model_bak $model_dir
}

function checkout() {
    log_info "检查打包事务..."
    # 检查未正常结束的打包事务
    for dir_name in $(find "${sovits}" -maxdepth 1 -name "pack_*" -type d); do
        # 未正常结束打包的版本
        ver=$(echo $dir_name | grep -oE "[0-9]+")
        # 跳过不包含版本号的目录, 以及0版本
        if [[ -n "${ver}" || "${ver}" == "0" ]]; then
            continue;
        fi

        # 目录绝对路径
        dir_path="${sovits}/${dir_name}"

        # 检查目录中的kmeans_*文件, 如果不存在则...
        if [ ! -f "${dir_path}/kmeans_${ver}.pt" ]; then
            d_file="${model_dir}/D_${ver}.pth"
            g_file="${model_dir}/G_${ver}.pth"
            if [[ -f "${d_file}" && -f "${g_file}" ]]; then
                # 中断于Step1, 重新打包
                log_info "找到$(color "yellow")${ver}$(color)版本的打包文件夹, 将继续打包..."
                resume_pack $ver
            else
                log_warn "找到$(color "yellow")${ver}$(color)版本的打包文件夹, 但是模型文件不存在"
                log_warn "尝试删除${dir_path}文件夹来清除警告"
            fi
        fi
    done
}

# 监听模型更新
function listen() {
    target_ver=$(getTargetVersion)

    # 0版本不打包, 初始从500起
    if [ "${target_ver}" == "0" ]; then
        target_ver=500
    fi

    d_file="${model_dir}/D_${target_ver}.pth"
    g_file="${model_dir}/G_${target_ver}.pth"

    # 等待模型更新
    until [[ -f "${d_file}" && -f "${g_file}" ]]; do
        log_info "目标版本$(color "yellow")${target_ver}$(color), 等待模型更新..."
        sleep 5s
    done
    # 休眠5s，等待模型保存
    sleep 5s

    # 立即打包
    pack $target_ver
}

function main() {
    # 检查未完成的打包事务
    checkout

    # 训练模型
    log_info "$(color "green")开始训练模型...$(color)"
    svc train & : # 后台运行

    # 循环打包
    while true; do
        listen
        for i in {1..12}; do
            log_info "冷却中...($(color "yellow")$((i * 5))s$(color)/$(color "red")60s$(color))"
            sleep 5s
        done
    done
}

trap 'log_info "收到退出信号, 终止进程(状态码: $?)"; exit' EXIT SIGINT SIGTERM
main "$@"

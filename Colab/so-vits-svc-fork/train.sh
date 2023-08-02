# 环境变量 sovits = "/Data/My Drive/so-vits-svc-fork"
model_dir="${sovits}/logs/44k"

# 打印日志函数, 前后添加新行, 并且添加进程和时间戳信息
function log() {
    echo -e "\n[打包进程][$(date '+%Y-%m-%d %H:%M:%S')]: $*"
}

# 获取最新模型版本
function getLastVersion() {
    last_ver=0
    for ver in $(ls "${model_dir}" | grep -oE "[0-9]+"); do
        if [ $ver -gt $last_ver ]; then
            last_ver=$ver
        fi
    done
    echo $last_ver
}

# 获取目标模型版本
function getTargetVersion() {
    last_ver=$(getLastVersion)
    # target_ver取最近且大于等于它的500倍数
    echo $((($last_ver + 499) / 500 * 500))
}

# 打包模型
function pack() {
    pack_ver=$1

    d_file="${model_dir}/D_${pack_ver}.pth"
    g_file="${model_dir}/G_${pack_ver}.pth"
    k_file="${model_dir}/kmeans.pt"
    output_dir="${sovits}/pack_${pack_ver}"
    output_file="${sovits}/pack_${pack_ver}.7z"

    log "开始打包${pack_ver}版本模型..."

    # 创建目录
    mkdir -p "${output_dir}"

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

# 监听模型更新
function listen() {
    target_ver=$(getTargetVersion)

    d_file="${model_dir}/D_${target_ver}.pth"
    g_file="${model_dir}/G_${target_ver}.pth"

    # 等待模型更新
    until [[ -f "${d_file}" && -f "${g_file}" ]]; do
        log "目标版本 ${target_ver}, 等待模型更新..."
        sleep 5s
    done
    # 休眠5s，等待模型保存
    sleep 5s

    # 立即打包
    if [ "${target_ver}" != "0" ]; then
        pack $target_ver
    fi
}

function main() {
    # 检查未正常结束的打包事务
    for dir_name in $(find "${sovits}" -maxdepth 1 -name "pack_*" -type d); do
        # 目录绝对路径
        dir_path="${sovits}/${dir_name}"
        # 未正常结束打包的版本
        ver=$(echo $dir_name | grep -oE "[0-9]+")
        if [[ -n "${ver}" || "${ver}" == "0" ]]; then
            continue;
        fi

        # 检查目录中的kmeans_*文件, 如果不存在则...
        if [ ! -f "${dir_path}/kmeans_${ver}.pt" ]; then
            d_file="${model_dir}/D_${ver}.pth"
            g_file="${model_dir}/G_${ver}.pth"
            if [[ -f "${d_file}" && -f "${g_file}" ]]; then
                # 中断于Step1, 重新打包
                log "找到${ver}版本的打包文件夹, 将继续打包..."
                resume_pack $ver
            else
                # 中断于Step2, 重新打包
                log "找到${ver}版本的打包文件夹, 但是模型文件不存在, 跳过"
            fi
        fi
    done

    # 训练模型
    log "开始训练模型..."
    svc train & : # 后台运行

    # 循环打包
    while true; do
        listen
        for i in {1..12}; do
            log "冷却中...($((i * 5))s/60s)"
            sleep 5s
        done
    done
}

main "$@"

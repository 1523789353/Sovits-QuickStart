# sovits = "/Disk/"
function pack() {
    target_version=0
    model_dir="${sovits}/logs/44k"
    for ver in $(ls "${model_dir}" | grep -oE "[0-9]+"); do
        if [ $ver -gt $target_version ]; then
            target_version=$ver
        fi
    done

    # target_version取最近且大于等于它的500倍数
    target_version=$((($target_version + 499) / 500 * 500))
    d_file="${model_dir}/D_${target_version}.pth"
    g_file="${model_dir}/G_${target_version}.pth"
    k_file="${model_dir}/kmeans.pt"
    output_dir="${sovits}/history_${target_version}"
    output_file="${sovits}/history_${target_version}.7z"

    # 等待模型更新
    until [[ -f "${d_file}" && -f "${g_file}" ]]; do
        echo -e "\n\n[打包进程]: 目标版本 ${target_version} Epoch, 等待模型更新...\n\n"
        sleep 5s
    done
    # 休眠5s，等待模型保存
    sleep 5s

    # 创建目录
    mkdir -p "${output_dir}"

    # 训练-cluster模型
    svc train-cluster
    # 移动模型
    mv "${k_file}" "${output_dir}/kmeans_${target_version}.pt"

    # 拷贝模型
    cp "${d_file}" "${output_dir}/"
    cp "${g_file}" "${output_dir}/"

    if [ -f "${output_file}" ]; then
        rm -rf "${output_file}"
    fi
    # 压缩保存
    7za a -t7z -m0=lzma -mx=9 -mfb=64 -md=32m -ms=on "${output_file}" "${output_dir}"

    if [ $? -eq 0 ]; then
        rm -rf "${output_dir}"
    fi
}
while true; do
    pack
    for i in {1..12}; do
        echo -e "\n\n[打包进程]: 冷却中...($((i*5))s/60s)\n\n"
        sleep 5s
    done
done

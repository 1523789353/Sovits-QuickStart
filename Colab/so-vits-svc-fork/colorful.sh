#!/bin/env bash

# see: https://en.wikipedia.org/wiki/ANSI_escape_code#SGR_(Select_Graphic_Rendition)_parameters
function SGR() {
    styles=($@)
    codes=""

    declare -A map
    # 0 重置所有属性
    map["reset"]=0
    map["bold"]=1
    map["dim"]=2
    map["italic"]=3
    map["underline"]=4
    map["slow_blink"]=5
    map["rapid_blink"]=6
    map["reverse"]=7
    map["hidden"]=8
    map["strikethrough"]=9
    # 10~20 字体
    map["reset_bold"]=21
    map["reset_dim"]=22
    map["reset_italic"]=23
    map["reset_underline"]=24
    map["reset_blink"]=25
    # 26 字体间距 不清楚有没有用于终端
    map["reset_reverse"]=27
    map["reset_hidden"]=28
    map["reset_strikethrough"]=29
    map["front_black"]=30
    map["front_red"]=31
    map["front_green"]=32
    map["front_yellow"]=33
    map["front_blue"]=34
    map["front_purple"]=35
    map["front_cyan"]=36
    map["front_white"]=37
    # 38 前景色-深色 256 色
    map["front_default"]=39
    map["back_black"]=40
    map["back_red"]=41
    map["back_green"]=42
    map["back_yellow"]=43
    map["back_blue"]=44
    map["back_purple"]=45
    map["back_cyan"]=46
    map["back_white"]=47
    # 48 背景色-深色 256 色
    map["back_default"]=49
    # 50 禁用字体间距
    map["frame"]=51
    map["encircle"]=52
    map["overline"]=53
    map["frame_off"]=54
    map["encircle_off"]=54
    map["overline_off"]=55
    # 56, 57 未定义
    # 58 下划线颜色 不符合标准
    # 59 默认下划线颜色
    # 60 表意文字下划线或右侧线
    # 61 表意文字双下划线或双右侧线
    # 62 表意文字上划线或左侧线
    # 63 表意文字双上划线或双左侧线
    # 64 表意文字上下划线或左右侧线
    # 65 清除表意文字属性[60...64]
    # 66~72 未定义
    # 73 上标
    # 74 下标
    # 75 清除上下标 [73, 74]
    # 76~78 未定义
    # 79 斜体和粗体
    # 80~89 未定义
    map["front_gray"]=90
    map["front_light_red"]=91
    map["front_light_green"]=92
    map["front_light_yellow"]=93
    map["front_light_blue"]=94
    map["front_light_purple"]=95
    map["front_light_cyan"]=96
    map["front_light_white"]=97
    # 98 前景色-浅色 256 色
    # 99~109 未定义
    map["back_gray"]=100
    map["back_light_red"]=101
    map["back_light_green"]=102
    map["back_light_yellow"]=103
    map["back_light_blue"]=104
    map["back_light_purple"]=105
    map["back_light_cyan"]=106
    map["back_light_white"]=107
    # 108 背景色-浅色 256 色
    # 109~119 未定义

    for ((index = 0; index < ${#styles[*]}; index++)); do
        style="${styles[$index]}"
        code="${map["${style}"]}"

        if [ -z "${code}" ]; then
            log_warn "SGR: unknown style: ${style}"
            continue
        fi

        codes+="${code};"
    done

    if [ -z "${codes}" ]; then
        codes="${map["reset"]};"
    fi

    # Colab终端牙口不好, 解析不了以;结尾的codes, 所以去掉最后一个;
    printf "\033[${codes::-1}m"
}

# Todo: 前景与后景的256染色

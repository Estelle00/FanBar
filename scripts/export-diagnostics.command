#!/bin/zsh
set -eu
script_directory="$(cd "$(dirname "$0")" && pwd)"
for app_path in "${script_directory}/../.." "${script_directory}/FanBar.app" "${script_directory}/../FanBar.app" "/Applications/FanBar.app"; do
    if [[ -x "${app_path}/Contents/MacOS/FanBarDiagnostics" ]]; then
        "${app_path}/Contents/MacOS/FanBarDiagnostics"
        print "按回车关闭 / Press Return to close"
        read -r
        exit 0
    fi
done
print "未找到新版 FanBar。请把本工具放在 FanBar.app 旁边后重试。"
print "Place this tool next to the updated FanBar.app and try again."
read -r
exit 1

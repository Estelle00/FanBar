#!/bin/zsh
set -euo pipefail

project_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "${project_root}"

app_path="${1:-${project_root}/dist/FanBar.app}"
if [[ ! -d "${app_path}" ]]; then
    print -u2 "Missing app bundle: ${app_path}"
    print -u2 "Run scripts/package-app.sh first."
    exit 1
fi

version="$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" \
    "${app_path}/Contents/Info.plist")"
output_path="${FANBAR_DMG_OUTPUT:-${project_root}/dist/FanBar-${version}.dmg}"
if [[ "${output_path}" != /* ]]; then
    output_path="${project_root}/${output_path}"
fi
volume_name="FanBar ${version}"
temporary_root="$(mktemp -d)"
trap 'rm -rf "${temporary_root}"' EXIT

background_path="${project_root}/Assets/DMG/FanBar-dmg-background.tiff"
window_width=660
window_height=400
rm -f "${output_path}"
ditto "${app_path}" "${temporary_root}/FanBar.app"
if command -v create-dmg >/dev/null 2>&1; then
    # create-dmg lays out the window (background, icon positions, Applications link).
    # Its own drop link replaces the manual symlink used by the fallback below.
    create-dmg \
        --volname "${volume_name}" \
        --background "${background_path}" \
        --window-pos 200 120 \
        --window-size "${window_width}" "${window_height}" \
        --icon-size 128 \
        --icon "FanBar.app" 180 200 \
        --hide-extension "FanBar.app" \
        --app-drop-link 480 200 \
        --no-internet-enable \
        "${output_path}" \
        "${temporary_root}"
else
    # CI must never ship the plain layout silently; 0.6.2 did because the
    # runners lacked create-dmg. Local builds may still fall back.
    if [[ "${CI:-}" == "true" ]]; then
        print -u2 "create-dmg is required in CI to build the DMG background layout."
        exit 1
    fi
    print -u2 "create-dmg not found; building a plain DMG without the background."
    # A simple native layout remains reliable across light/dark mode and macOS versions.
    ln -s /Applications "${temporary_root}/Applications"
    hdiutil create \
        -volname "${volume_name}" \
        -srcfolder "${temporary_root}" \
        -format UDZO \
        -ov \
        "${output_path}"
fi

dmg_identity="${FANBAR_DMG_SIGN_IDENTITY:-${FANBAR_SIGN_IDENTITY:-Developer ID Application: JiangLin He (64S5F787T9)}}"
if [[ "${dmg_identity}" == "-" ]]; then
    # Local packages still need an ad-hoc container signature because the
    # repository's DMG gate verifies both the image and the nested app.
    codesign --force --sign - "${output_path}"
else
    codesign --force --timestamp --sign "${dmg_identity}" "${output_path}"
fi
codesign --verify --verbose=2 "${output_path}"

hdiutil verify "${output_path}"
print "Built ${output_path}"

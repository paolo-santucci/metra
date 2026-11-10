#!/usr/bin/env bash
set -euo pipefail

# Download and install the Android emulator + a system image, and create an AVD
# for Métra.
#
# Companion to tools/setup-environment.sh: that script bootstraps the whole
# toolchain and can install the emulator with --with-emulator. This one is the
# narrow, re-runnable path — safe to run on an SDK that is already set up, and
# safe to run again after a partial download.
#
# Requires an Android command-line-tools SDK (ANDROID_HOME), curl and ~8 GB free.
# KVM is strongly recommended: without /dev/kvm the emulator falls back to
# software emulation and is barely usable.

DEFAULT_PREFIX="${HOME}/.local/share/metra-sdk"

API=36
TAG=google_apis
ABI=x86_64
AVD_NAME=metra-api36
DEVICE=pixel_6
DRY_RUN=false
RECREATE=false
BOOT=false
HEADLESS=false
ACCEPT_LICENSES=true

usage() {
    cat <<'EOF'
Usage: bash tools/install-android-emulator.sh [options]

Download and install the Android emulator and a system image into an existing
command-line-tools SDK, then create an AVD.

  --sdk PATH            Android SDK root (default: $ANDROID_HOME,
                        $ANDROID_SDK_ROOT, then ~/.local/share/metra-sdk/Android)
  --api N               System image API level (default: 36)
  --tag TAG             System image tag: google_apis | default | google_apis_playstore
                        (default: google_apis)
  --abi ABI             System image ABI: x86_64 | arm64-v8a (default: x86_64)
  --avd NAME            AVD name (default: metra-api36)
  --device PROFILE      AVD hardware profile (default: pixel_6)
  --boot                Start the AVD after creating it and wait for boot
  --headless            With --boot: run the emulator with -no-window
  --recreate            Delete and recreate the AVD if it already exists
  --no-accept-licenses  Skip non-interactive Android SDK license acceptance
  --dry-run             Print the commands without running them
  -h, --help            Show this help

Prints the exact commands to boot the emulator, run Métra on it, and capture
help screenshots. Existing AVDs are left untouched unless --recreate is given.
EOF
}

info() { printf '%s\n' "$*"; }
warn() { printf 'Warning: %s\n' "$*" >&2; }
fail() { printf 'Error: %s\n' "$*" >&2; exit 1; }

run() {
    printf '+ '; printf '%q ' "$@"; printf '\n'
    if ! "$DRY_RUN"; then "$@"; fi
}

parse_options() {
    while (($#)); do
        case "$1" in
            --sdk)
                (($# >= 2)) && [[ -n "$2" && "$2" != --* ]] || fail '--sdk requires a path'
                SDK=$2; shift 2 ;;
            --api)
                (($# >= 2)) && [[ "$2" =~ ^[0-9]+(\.[0-9]+)?$ ]] || fail '--api requires a number'
                API=$2; shift 2 ;;
            --tag)
                (($# >= 2)) || fail '--tag requires a value'
                TAG=$2; shift 2 ;;
            --abi)
                (($# >= 2)) || fail '--abi requires a value'
                ABI=$2; shift 2 ;;
            --avd)
                (($# >= 2)) && [[ -n "$2" && "$2" != --* ]] || fail '--avd requires a name'
                AVD_NAME=$2; shift 2 ;;
            --device)
                (($# >= 2)) || fail '--device requires a profile'
                DEVICE=$2; shift 2 ;;
            --boot) BOOT=true; shift ;;
            --headless) HEADLESS=true; shift ;;
            --recreate) RECREATE=true; shift ;;
            --no-accept-licenses) ACCEPT_LICENSES=false; shift ;;
            --dry-run) DRY_RUN=true; shift ;;
            -h|--help) usage; exit 0 ;;
            *) fail "Unknown option: $1 (try --help)" ;;
        esac
    done
}

resolve_sdk() {
    if [[ -z ${SDK:-} ]]; then
        SDK=${ANDROID_HOME:-${ANDROID_SDK_ROOT:-}}
    fi
    if [[ -z ${SDK:-} ]]; then
        SDK="${DEFAULT_PREFIX}/Android"
        [[ -d $SDK ]] || fail "No Android SDK found. Pass --sdk PATH, set ANDROID_HOME, or run tools/setup-environment.sh first."
    fi
    [[ $SDK == /* ]] || fail 'SDK path must be absolute'
    [[ -d $SDK ]] || fail "Android SDK not found at $SDK"

    # Newest installed command-line-tools release wins (20.0 today).
    local candidate
    candidate=$(find "$SDK/cmdline-tools" -maxdepth 3 -type f -name sdkmanager -perm -u+x 2>/dev/null | sort -V | tail -n 1 || true)
    [[ -n $candidate ]] || fail "sdkmanager not found under $SDK/cmdline-tools — install Android command-line tools first."
    SDKMANAGER=$candidate
    AVDMANAGER="$(dirname -- "$SDKMANAGER")/avdmanager"
    [[ -x $AVDMANAGER ]] || fail "avdmanager not found next to $SDKMANAGER"
    ADB="$SDK/platform-tools/adb"
    EMULATOR="$SDK/emulator/emulator"
    IMAGE="system-images;android-${API};${TAG};${ABI}"
}

check_host() {
    [[ $(uname -s) == Linux ]] || fail 'The Android emulator here targets Linux only. iOS simulators require macOS.'
    if [[ $(uname -m) != x86_64 && $ABI == x86_64 ]]; then
        fail "Host is $(uname -m) but --abi is x86_64; pass --abi arm64-v8a on ARM hosts."
    fi
    if [[ ! -e /dev/kvm ]]; then
        warn '/dev/kvm is missing: the emulator will run without hardware acceleration and be very slow.'
        warn 'On a distrobox host, pass the device through (docker/podman: --device /dev/kvm) and check kvm support.'
    elif [[ ! -r /dev/kvm || ! -w /dev/kvm ]]; then
        warn "/dev/kvm is not readable/writable by $(id -un); add the user to the kvm group or fix its permissions."
    else
        info "Hardware acceleration: /dev/kvm available"
    fi
    if [[ $BOOT == true && $HEADLESS == false && -z ${DISPLAY:-} && -z ${WAYLAND_DISPLAY:-} ]]; then
        warn 'No DISPLAY/WAYLAND_DISPLAY detected; falling back to --headless.'
        HEADLESS=true
    fi
    local available_gb
    available_gb=$(df -Pk "$SDK" | awk 'NR==2 {printf "%d", $4/1024/1024}')
    if ((available_gb < 8)); then
        warn "Only ${available_gb} GB free under $SDK; the system image needs roughly 8 GB."
    fi
}

accept_licenses() {
    "$ACCEPT_LICENSES" || { info 'Skipping license acceptance (--no-accept-licenses).'; return 0; }
    if "$DRY_RUN"; then
        run "$SDKMANAGER" --sdk_root="$SDK" --licenses
        return 0
    fi
    local statuses
    set +e
    yes | "$SDKMANAGER" --sdk_root="$SDK" --licenses
    statuses=("${PIPESTATUS[@]}")
    set -e
    [[ ${statuses[1]} == 0 ]] || fail 'Android license acceptance failed'
}

install_packages() {
    local -a packages=('platform-tools' 'emulator' "platforms;android-${API}" "$IMAGE")
    # --sdk_root keeps sdks installed next to the manager even when ANDROID_HOME is stale.
    run "$SDKMANAGER" --sdk_root="$SDK" "${packages[@]}"
}

list_avds() {
    "$AVDMANAGER" list avd -c 2>/dev/null || true
}

report_broken_avds() {
    local broken output
    output=$("$AVDMANAGER" list avd 2>&1 || true)
    broken=$(sed -n '/could not be loaded/,$p' <<<"$output" | sed -n 's/^ *Name: //p' || true)
    if [[ -n $broken ]]; then
        warn "Some existing AVDs cannot be loaded (broken config.ini): $(tr '\n' ' ' <<<"$broken")"
        warn "Remove or recreate them under ${ANDROID_USER_HOME:-${XDG_CONFIG_HOME:-$HOME/.config}/.android}/avd/"
    fi
}

avd_config_path() {
    local root
    for root in \
        "${ANDROID_AVD_HOME:-}" \
        "${ANDROID_USER_HOME:+${ANDROID_USER_HOME}/avd}" \
        "${XDG_CONFIG_HOME:+${XDG_CONFIG_HOME}/.android/avd}" \
        "$HOME/.android/avd" \
        "${XDG_CONFIG_HOME:+${XDG_CONFIG_HOME}/avd}"; do
        [[ -n $root && -f "${root}/${AVD_NAME}.avd/config.ini" ]] || continue
        printf '%s\n' "${root}/${AVD_NAME}.avd/config.ini"
        return 0
    done
    return 0
}

create_avd() {
    local existing
    existing=$(list_avds)
    if grep -qx "$AVD_NAME" <<<"$existing"; then
        if "$RECREATE"; then
            info "Recreating AVD $AVD_NAME"
            run "$AVDMANAGER" delete avd --name "$AVD_NAME"
        else
            info "AVD $AVD_NAME already exists — leaving it untouched (use --recreate to replace it)."
            return 0
        fi
    fi
    run "$AVDMANAGER" create avd --name "$AVD_NAME" --package "$IMAGE" --device "$DEVICE" <<<'no'
}

tune_avd() {
    "$DRY_RUN" && return 0
    local config
    config=$(avd_config_path)
    [[ -n $config ]] || return 0
    # Hardware keyboard: without it Flutter text entry (the Archivio search
    # field) needs on-screen taps instead of `adb shell input text`.
    grep -q '^hw.keyboard=' "$config" \
        && sed -i 's/^hw\.keyboard=.*/hw.keyboard=yes/' "$config" \
        || printf 'hw.keyboard=yes\n' >>"$config"
    grep -q '^hw\.ramSize=' "$config" || printf 'hw.ramSize=2048\n' >>"$config"
}

boot_emulator() {
    "$BOOT" || return 0
    if "$DRY_RUN"; then
        run "$EMULATOR" -avd "$AVD_NAME" -no-boot-anim
        return 0
    fi
    local -a args=(-avd "$AVD_NAME" -no-boot-anim -no-audio -no-snapshot)
    if "$HEADLESS"; then args+=(-no-window); fi
    if [[ ! -e /dev/kvm ]]; then args+=(-accel off); fi
    info 'Starting the emulator in the background…'
    nohup "$EMULATOR" "${args[@]}" >/tmp/metra-emulator.log 2>&1 &
    local pid=$!
    info "Emulator PID ${pid}; log: /tmp/metra-emulator.log"

    "$ADB" start-server >/dev/null 2>&1 || true
    info 'Waiting for the device to appear (up to 5 minutes)…'
    local waited=0
    until [[ $("$ADB" devices 2>/dev/null | awk '$2=="device"' | wc -l) -gt 0 ]]; do
        ((waited += 5))
        ((waited >= 300)) && fail "Emulator did not appear within 5 minutes — see /tmp/metra-emulator.log"
        sleep 5
    done
    info 'Waiting for the boot to complete…'
    until [[ $("$ADB" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r') == 1 ]]; do
        ((waited += 5))
        ((waited >= 600)) && fail 'Emulator boot did not complete within 10 minutes'
        sleep 5
    done
    info "Boot complete: $("$ADB" devices | awk 'NR==2 {print $1}')"
    if ! kill -0 "$pid" 2>/dev/null; then
        warn 'The emulator process is no longer running; check /tmp/metra-emulator.log'
    fi
}

print_next_steps() {
    local device
    device=$("$ADB" devices 2>/dev/null | awk 'NR==2 {print $1}' || true)
    device=${device:-emulator-5554}
    cat <<EOF

Emulator ready: $EMULATOR
AVD          : $AVD_NAME  (API $API, $TAG, $ABI)

Boot it (foreground, with a window):
  "$EMULATOR" -avd $AVD_NAME -no-boot-anim -no-audio -no-snapshot

Or headless, e.g. for scripted screenshots:
  "$EMULATOR" -avd $AVD_NAME -no-window -no-audio -no-snapshot -gpu host
  # Use -gpu host (not swiftshader*): in a container the host SwiftShader JIT
  # cannot allocate executable memory and the emulator segfaults on boot.

Run Métra on it:
  flutter devices
  flutter run -d $device \\
    --dart-define=DROPBOX_APP_KEY=\$DROPBOX_APP_KEY \\
    --dart-define=GOOGLE_OAUTH_CLIENT_ID=\$GOOGLE_OAUTH_CLIENT_ID

Capture a help screenshot (IT timeline, the deferred TASK-22):
  "$ADB" exec-out screencap -p > docs/assets/archive-timeline-it.png

Stop it:
  "$ADB" emu kill

If commands are not on PATH, source the SDK environment first:
  source "$SDK/env.sh"   # written by tools/setup-environment.sh, when present
EOF
}

main() {
    parse_options "$@"
    resolve_sdk
    check_host
    info "Android SDK  : $SDK"
    info "System image : $IMAGE"
    info "AVD          : $AVD_NAME ($DEVICE)"
    report_broken_avds
    accept_licenses
    install_packages
    [[ -x $EMULATOR ]] || "$DRY_RUN" || fail "Emulator binary missing after install: $EMULATOR"
    create_avd
    tune_avd
    boot_emulator
    "$DRY_RUN" && { info 'Dry run complete.'; exit 0; }
    print_next_steps
}

main "$@"

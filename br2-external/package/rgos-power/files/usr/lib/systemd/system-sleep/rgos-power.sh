#!/bin/bash
# systemd sleep hook (runs as root): picks the suspend mode, mutes the codec
# and the power LED, and arms the suspend watchdog RTC alarm. Settings
# (system-level, from /etc/rgos/power.conf): suspend_mode, suspend_mute_dac,
# suspend_led_off, suspend_poweroff_min.
set -u

conf() { rgos-power-conf "$@"; }
rtc=/sys/class/rtc/rtc0
wd_file=/run/rgos-suspend-watchdog
leds_file=/run/rgos-suspend-leds

# --- pre suspend -------------------------------------------------------------
pre() {
    # Suspend mode: auto = deep when the firmware provides it, else s2idle.
    mode="$(conf suspend_mode auto)"
    if [[ -r /sys/power/mem_sleep ]]; then
        if grep -qw deep /sys/power/mem_sleep && { [[ "${mode}" == auto ]] || [[ "${mode}" == deep ]]; }; then
            echo deep > /sys/power/mem_sleep 2>/dev/null || true
        else
            [[ "${mode}" == deep ]] && \
                logger -t rgos-power "deep suspend requested but not available; using s2idle"
            echo s2idle > /sys/power/mem_sleep 2>/dev/null || true
        fi
    fi

    # Mute the codec DAC: no pop in the headphones when the amplifier
    # rails drop
    if [[ "$(conf suspend_mute_dac 1)" == 1 ]]; then
        amixer -q -c 0 sset DAC off >/dev/null 2>&1 || true
    fi

    # Power LED off while asleep (looks asleep; restore on resume)
    rm -f "${leds_file}"
    if [[ "$(conf suspend_led_off 1)" == 1 ]]; then
        for led in green:power red:status; do
            p=/sys/class/leds/${led}/brightness
            if [[ -w "${p}" ]]; then
                echo "${led} $(cat "${p}")" >>"${leds_file}"
                echo 0 >"${p}" 2>/dev/null || true
            fi
        done
    fi

    # Suspend watchdog: arm an RTC alarm to wake us for a clean poweroff.
    # Never touch an alarm somebody else set (e.g. a test or the user).
    rm -f "${wd_file}"
    mins="$(conf suspend_poweroff_min 0)"
    if [[ "${mins}" =~ ^[1-9][0-9]*$ && -w "${rtc}/wakealarm" && "$(cat "${rtc}/wakealarm" 2>/dev/null || echo 0)" == 0 ]]; then
        alarm=$(( $(date +%s) + mins * 60 ))
        echo 0 > "${rtc}/wakealarm"
        echo "${alarm}" > "${rtc}/wakealarm" 2>/dev/null || true
        echo "${alarm}" > "${wd_file}"
    fi
}

# --- post suspend ------------------------------------------------------------
post() {
    # Codec and LED back
    amixer -q -c 0 sset DAC on >/dev/null 2>&1 || true
    if [[ -r "${leds_file}" ]]; then
        while read -r led val; do
            p=/sys/class/leds/${led}/brightness
            [[ -w "${p}" ]] && echo "${val}" >"${p}" 2>/dev/null || true
        done <"${leds_file}"
        rm -f "${leds_file}"
    fi

    # Watchdog: clear our alarm; if it is what woke us, power off cleanly
    if [[ -r "${wd_file}" ]]; then
        wd="$(cat "${wd_file}")"
        rm -f "${wd_file}"
        [[ -w "${rtc}/wakealarm" ]] && echo 0 > "${rtc}/wakealarm" 2>/dev/null || true
        if (( $(date +%s) >= wd - 2 )); then
            logger -t rgos-power "suspend watchdog fired after ${wd}: powering off"
            systemctl --no-block poweroff
        fi
    fi
}

case "${1:-}" in
    pre)  pre ;;
    post) post ;;
    *)    exit 0 ;;
esac

#!/bin/sh
# plasma-shutdown-watchdog — DEF-95 workaround. PLASMA SESSION ONLY.
# org.kde.Shutdown (/usr/bin/plasma-shutdown) activates but never powers off on
# managarm (no session teardown / no logind handoff — DEF-95). `systemctl
# poweroff` DOES work (reaches systemd-shutdown -> DEF-79 poweroff watchdog ->
# clean ACPI S5). This watches the session bus for the *committed* Shut Down /
# Restart call the button makes and forces the working systemd path after a
# short grace, so the button actually powers the machine off.
#
# Plasma-only by construction: shipped in /etc/xdg/autostart with OnlyShowIn=KDE
# (other DEs skip the entry; weston does not read XDG autostart) AND this guard.
[ "$XDG_CURRENT_DESKTOP" = "KDE" ] || exit 0
GRACE=${PLASMA_SHUTDOWN_WATCHDOG_GRACE:-6}
mark() { logger -t plasma-shutdown-watchdog "$1" 2>/dev/null; echo "plasma-shutdown-watchdog: $1" > /dev/kmsg 2>/dev/null; }
mark "armed (grace=${GRACE}s, session=$XDG_CURRENT_DESKTOP)"
dbus-monitor --session "interface='org.kde.Shutdown'" 2>/dev/null | while read -r line; do
	case "$line" in
		*member=logoutAndShutdown*) act=poweroff ;;
		*member=logoutAndReboot*)   act=reboot ;;
		*) continue ;;
	esac
	mark "org.kde.Shutdown.$act seen -> forcing systemctl $act in ${GRACE}s (DEF-95 stall workaround)"
	( sleep "$GRACE"; systemctl "$act" ) &
done

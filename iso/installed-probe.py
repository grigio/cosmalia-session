#!/usr/bin/env python3
"""Verify the system installed by Calamares boots from disk."""
import os
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from qga import Qga
from vmctl import Hmp

RESULT = sys.argv[1]
QGA = os.path.join(RESULT, "installed-qga.sock")
MONITOR = os.path.join(RESULT, "installed-monitor.sock")


def main():
    report = open(os.path.join(RESULT, "installed-report.txt"), "w")

    def say(*a):
        msg = " ".join(str(x) for x in a)
        print(msg, flush=True)
        report.write(msg + "\n")
        report.flush()

    qga = None
    deadline = time.time() + 240
    while time.time() < deadline:
        try:
            q = Qga(sock=QGA)
            q.run("echo READY", timeout=10)
            qga = q
            break
        except Exception:
            time.sleep(3)

    hmp = Hmp(MONITOR)
    shot = os.path.join(RESULT, "installed-desktop.ppm")
    hmp.cmd(f"screendump {shot}", 2.0)
    say(f"=== installed desktop screenshot: {shot} "
        f"({os.path.getsize(shot) if os.path.exists(shot) else 0} bytes) ===")

    if qga is None:
        say("WARNING: QEMU Guest Agent unavailable in installed system")
        report.close()
        return
    say("=== QEMU Guest Agent ready ===")

    checks = [
        ("booted from disk", "findmnt -n -o SOURCE /; grep -o 'root=UUID=[^ ]*' /proc/cmdline"),
        ("cmdline", "cat /proc/cmdline"),
        ("os release", "grep -E '^(NAME|PRETTY_NAME|ID)=' /etc/os-release"),
        ("fstab", "grep -v '^#' /etc/fstab | grep -v '^$' | head -6"),
        ("boot files on ESP", "ls -lh /boot/vmlinuz* /boot/initramfs* 2>&1 | head -6"),
        ("limine config", "cat /boot/limine.conf 2>/dev/null || cat /efi/limine.conf 2>/dev/null"),
        ("greetd", "systemctl is-active greetd; cat /etc/greetd/config.toml"),
        ("users", "getent passwd | grep -E '^(root|greeter|test)' | cut -d: -f1,3,6"),
        ("live sudoers removed", "ls /etc/sudoers.d/99-liveuser 2>&1 || echo REMOVED"),
        ("initramfs preset", "grep -E 'PRESETS|kver' /etc/mkinitcpio.d/linux-cachyos.preset"),
        ("desktop processes", "pgrep -a 'cosmic-comp|noctalia|greetd' | head -6 || true"),
        ("packages", "pacman -Q cosmalia-session cosmic-comp-traffic noctalia limine 2>/dev/null"),
    ]
    for label, command in checks:
        say(f"--- {label} ---")
        say(qga.run(command, timeout=30).strip())
    report.close()


if __name__ == "__main__":
    main()

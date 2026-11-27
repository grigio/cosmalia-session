#!/usr/bin/env python3
"""Verify the integrated CachyOS installer inside the live VM and start it.

Uses QEMU Guest Agent (available in the ISO) for reliable in-guest output.
"""
import os
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from qga import Qga
from vmctl import Hmp

RESULT = sys.argv[1]


def main():
    report = open(os.path.join(RESULT, "installer-report.txt"), "w")

    def say(*a):
        msg = " ".join(str(x) for x in a)
        print(msg, flush=True)
        report.write(msg + "\n")
        report.flush()

    # Give the guest agent time to appear after boot.
    qga = None
    deadline = time.time() + 180
    while time.time() < deadline:
        try:
            qga = Qga()
            qga.run("echo READY")
            break
        except Exception:
            time.sleep(2)
    if qga is None:
        say("ERROR: QEMU Guest Agent did not become available")
        report.close()
        return
    say("=== QEMU Guest Agent ready ===")

    checks = [
        ("installer packages", "pacman -Q cachyos-calamares-next limine qt6-wayland efibootmgr dosfstools btrfs-progs 2>/dev/null"),
        ("installer launcher", "ls -l /usr/local/bin/cosmalia-installer /usr/local/bin/cosmalia-postinstall"),
        ("desktop entry", "head -6 /usr/share/applications/cosmalia-installer.desktop"),
        ("calamares sequence", "grep -E '^  - (welcome|partition|unpackfs|bootloader|displaymanager|initcpio|shellprocess@cosmalia)' /etc/calamares/settings.conf"),
        ("unpackfs source", "grep -E 'source:|sourcefs:|destination:' /etc/calamares/modules/unpackfs.conf"),
        ("bootloader", "grep -E 'efiBootLoader|kernelParams' /etc/calamares/modules/bootloader.conf"),
        ("branding", "grep -E 'productName|bootloaderEntryName' /usr/share/calamares/branding/cosmalia/branding.desc"),
        ("boost compatibility", "ls -l /usr/lib/libboost_*.so.1.91.0 2>/dev/null | head -6"),
        ("calamares libs", "ldd /usr/lib/libcalamares.so.3.4 | grep 'not found' || echo ALL_LIBS_OK"),
        ("installer binary", "calamares --version 2>&1 | head -2"),
        ("live squashfs", "ls -lh /run/archiso/bootmnt/cosmalia/x86_64/airootfs.sfs"),
        ("target disk", "lsblk -o NAME,SIZE,TYPE /dev/vda | head -6"),
    ]
    for label, command in checks:
        say(f"--- {label} ---")
        say(qga.run(command).strip())

    say("=== launching Calamares in the live Wayland session ===")
    say(qga.run(
        'wl=$(basename "$(ls /run/user/1000/wayland-* 2>/dev/null | head -1)"); '
        'echo "WAYLAND=$wl"; '
        'nohup env XDG_RUNTIME_DIR=/run/user/1000 WAYLAND_DISPLAY="$wl" '
        'QT_QPA_PLATFORM=wayland calamares -D5 >/tmp/calamares.log 2>&1 & '
        'echo "LAUNCHED=$!"; sleep 12; pgrep -a calamares || echo NOT_RUNNING'
    ).strip())
    say("--- calamares log tail ---")
    say(qga.run("tail -12 /tmp/calamares.log").strip())

    hmp = Hmp(os.path.join(RESULT, "monitor.sock"))
    shot = os.path.join(RESULT, "installer-welcome.ppm")
    hmp.cmd(f"screendump {shot}", 2.0)
    say(f"=== installer screenshot: {shot} ({os.path.getsize(shot) if os.path.exists(shot) else 0} bytes) ===")
    report.close()


if __name__ == "__main__":
    main()

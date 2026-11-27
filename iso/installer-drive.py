#!/usr/bin/env python3
"""Drive the Calamares wizard in the test VM (1024x768 framebuffer)."""
import os
import subprocess
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
RESULT = sys.argv[1] if len(sys.argv) > 1 else "test-results/installer"
# QEMU absolute pointer coordinates scale to the 1024x768 framebuffer.
SX, SY = 32, 42.7


def qga(*args):
    return subprocess.run([sys.executable, os.path.join(HERE, "qga.py"), RESULT, *map(str, args)],
                          capture_output=True, text=True).stdout.strip()


def vmctl(*args):
    return subprocess.run([sys.executable, os.path.join(HERE, "vmctl.py"), RESULT, *map(str, args)],
                          capture_output=True, text=True).stdout.strip()


def click(x, y, pause=1.0):
    out = qga("click", int(x * SX), int(y * SY))
    time.sleep(pause)
    return out


def typ(text, pause=0.15):
    vmctl("type", text)
    time.sleep(pause)


def shot(name):
    subprocess.run([sys.executable, os.path.join(HERE, "vmctl.py"), RESULT, "screenshot", name],
                   capture_output=True, text=True)
    subprocess.run(["magick", os.path.join(RESULT, f"{name}.ppm"), os.path.join(RESULT, f"{name}.png")],
                   capture_output=True, text=True)


def main():
    print("welcome -> location:", click(882, 589))
    print("location -> keyboard:", click(882, 589))
    print("keyboard -> partition:", click(882, 589))
    print("select erase disk:", click(20, 188))
    print("partition -> users:", click(882, 589))
    # Users form
    click(105, 172); typ("test user")
    click(105, 230); typ("testuser")
    click(105, 288); typ("cosmaliatest")
    click(105, 346); typ("testpass123")
    click(315, 346); typ("testpass123")
    shot("drive-users")
    print("users -> summary:", click(882, 589))
    shot("drive-summary")
    print("summary -> confirm:", click(882, 659, pause=2))
    print("confirm install:", click(562, 448, pause=3))
    shot("drive-installing")
    print("started; polling installation...")
    for i in range(40):
        time.sleep(6)
        out = qga("run", "lsblk -o NAME,SIZE,FSTYPE,MOUNTPOINT /dev/vda | tail -n +2; "
                         "grep -c 'onInstallationFailed' /tmp/calamares.log || true")
        if "failed" in out.lower() or "Installation failed" in out:
            print(out)
            break
        if i % 5 == 0:
            print(f"[{i * 6}s]", out.replace("\n", " | "))
    print("final:", qga("run", "grep -iE 'installation failed|installed system configured' /tmp/calamares.log | tail -3"))


if __name__ == "__main__":
    main()

"""Captura pantallas de acceso AMG de MotoAMG."""
from __future__ import annotations

import re
import subprocess
import time
from pathlib import Path

ADB = Path.home() / "AppData/Local/Android/Sdk/platform-tools/adb.exe"
OUT = Path(r"d:\Proyectos\flutter\MotoAMG\assets\help")
DUMP = Path.home() / "AppData/Local/Temp/uidump_moto.xml"
TMP = Path.home() / "AppData/Local/Temp/moto_shot.png"
PKG = "es.albertomaestre.motoamg"
ACTIVITY = f"{PKG}/.MainActivity"

OUT.mkdir(parents=True, exist_ok=True)


def adb(*args, timeout=60):
    return subprocess.run([str(ADB), *args], capture_output=True, timeout=timeout)


def dump_ui() -> str:
    adb("shell", "rm", "-f", "/sdcard/uidump.xml")
    adb("shell", "uiautomator", "dump", "/sdcard/uidump.xml")
    adb("pull", "/sdcard/uidump.xml", str(DUMP))
    return DUMP.read_text(encoding="utf-8", errors="ignore")


def nodes(xml: str | None = None):
    xml = xml or dump_ui()
    found = []
    for m in re.finditer(r"<node [^>]*>", xml):
        tag = m.group(0)
        text = re.search(r'text="([^"]*)"', tag)
        desc = re.search(r'content-desc="([^"]*)"', tag)
        bounds = re.search(r'bounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"', tag)
        label = (desc.group(1) if desc else "") or (text.group(1) if text else "")
        label = label.replace("&#10;", "\n").split("\n")[0].strip()
        if not label or not bounds:
            continue
        x1, y1, x2, y2 = map(int, bounds.groups())
        found.append((label, (x1 + x2) // 2, (y1 + y2) // 2))
    return found


def labels() -> list[str]:
    return [n[0] for n in nodes()]


def tap_exact(want: str) -> bool:
    for text, x, y in nodes():
        if text == want:
            adb("shell", "input", "tap", str(x), str(y))
            time.sleep(1.05)
            return True
    return False


def tap_has(substr: str) -> bool:
    matches = sorted(
        [(t, x, y) for t, x, y in nodes() if substr in t],
        key=lambda m: len(m[0]),
    )
    if not matches:
        print("NO TAP", substr)
        return False
    text, x, y = matches[0]
    print("TAP", text[:70])
    adb("shell", "input", "tap", str(x), str(y))
    time.sleep(1.1)
    return True


def swipe_up() -> None:
    adb("shell", "input", "swipe", "540", "1900", "540", "700", "280")
    time.sleep(0.55)


def shot(name: str) -> None:
    dest = OUT / name
    if TMP.exists():
        TMP.unlink()
    subprocess.run(f'"{ADB}" exec-out screencap -p > "{TMP}"', shell=True, check=True)
    data = TMP.read_bytes()
    if data[:8] != b"\x89PNG\r\n\x1a\n":
        data = data.replace(b"\r\n", b"\n")
    dest.write_bytes(data)
    print("saved", name, dest.stat().st_size)


def back() -> None:
    adb("shell", "input", "keyevent", "4")
    time.sleep(0.75)


def dismiss_system_dialogs() -> None:
    for _ in range(5):
        ls = set(labels())
        for cand in (
            "While using the app",
            "While using",
            "Solo esta vez",
            "Permitir",
            "Allow",
            "Mientras se usa la app",
            "Mientras usas la app",
        ):
            if cand in ls and tap_exact(cand):
                time.sleep(0.35)
                break
        else:
            return


def skip_permissions() -> None:
    if not any("Prepara" in x for x in labels()):
        return
    if "Permitir ubicación" in labels():
        tap_exact("Permitir ubicación")
        dismiss_system_dialogs()
    if "Permitir notificaciones" in labels():
        tap_exact("Permitir notificaciones")
        dismiss_system_dialogs()
    for _ in range(5):
        if "Continuar" in labels() and tap_exact("Continuar"):
            break
        swipe_up()
    dismiss_system_dialogs()
    time.sleep(0.9)


def capture_privacy_docs() -> None:
    tap_has("Leer política de privacidad")
    time.sleep(0.9)
    shot("04_motoamg_privacidad.png")
    back()
    time.sleep(0.5)
    tap_has("Leer términos de uso")
    time.sleep(0.9)
    shot("41_motoamg_condiciones.png")
    back()
    time.sleep(0.5)


def main() -> None:
    adb("shell", "input", "keyevent", "3")
    time.sleep(0.3)
    adb("shell", "am", "force-stop", "com.google.android.calendar")
    adb("shell", "pm", "clear", PKG)
    time.sleep(0.6)
    adb("shell", "am", "start", "-n", ACTIVITY)
    time.sleep(3.2)

    dismiss_system_dialogs()
    skip_permissions()
    print("after perm:", labels()[:12])

    if any("Privacidad y condiciones" in x for x in labels()):
        capture_privacy_docs()
        tap_has("He leído y acepto")
        time.sleep(0.35)
        tap_exact("Aceptar y continuar") or tap_has("Aceptar y continuar")
        time.sleep(1.0)

    print("login:", labels()[:12])
    shot("02_motoamg_login.png")

    tap_has("Crear cuenta")
    time.sleep(0.9)
    print("privacy reg:", labels()[:12])
    capture_privacy_docs()
    tap_has("He leído y acepto")
    time.sleep(0.4)
    tap_exact("Aceptar y continuar") or tap_has("Aceptar y continuar")
    time.sleep(1.2)

    print("register options:", labels()[:12])
    shot("42_motoamg_crear_cuenta.png")
    tap_has("Usuario y contraseña")
    time.sleep(1.0)
    shot("43_motoamg_registro_usuario.png")
    print("done")


if __name__ == "__main__":
    main()

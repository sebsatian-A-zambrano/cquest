"""Plays the first RPG chapter in Chrome, with real code execution."""
import json
import os
import re
import sys
from pathlib import Path
from playwright.sync_api import sync_playwright, expect

URL = os.environ.get("CQUEST_TEST_URL", "http://127.0.0.1:8765/")
shots = Path(sys.argv[1]) if len(sys.argv) > 1 else None
CHROME = Path(r"C:\Program Files\Google\Chrome\Application\chrome.exe")

with sync_playwright() as pw:
    browser = pw.chromium.launch(executable_path=str(CHROME) if CHROME.exists() else None)
    page = browser.new_page(viewport={"width":1440,"height":1000})
    page.set_default_timeout(8500)
    errors = []
    page.on("pageerror", lambda err: errors.append(str(err)))

    def title(target):
        target.goto(URL, wait_until="networkidle")
        target.locator("flt-semantics-placeholder").press("Enter")
        expect(target.get_by_role("button", name=re.compile("La noche sin faros"))).to_be_visible()

    def click(name, target=page):
        control = target.get_by_role("button", name=name).first
        expect(control).to_be_in_viewport(timeout=10000)
        target.wait_for_timeout(340)
        control.click(force=True)
        target.wait_for_timeout(310)

    def text(value, timeout=8000):
        expect(page.get_by_text(value, exact=True).first).to_be_visible(timeout=timeout)

    def screenshot(target, file):
        if shots:
            target.screenshot(path=shots / f"cquest-rpg-{file}.png")

    title(page)
    screenshot(page,"inicio")
    click(re.compile("La noche sin faros"))
    text("Embarcadero de Sal")
    screenshot(page,"escenario")
    page.keyboard.press("w")
    page.keyboard.press("w")
    page.keyboard.press("e")
    text("Ayudar a asegurar el muelle")
    screenshot(page,"dialogo")
    click("Ayudar a asegurar el muelle")
    click("Voy en camino")
    click("Escuchar eco de la noche")
    click("Guardar en la bitácora")
    click("Usar consola del faro")
    expect(page.get_by_role("group",name=re.compile("La consola necesita el suministro"))).to_be_visible()
    click("Abrir cofre de Cristal de la rompiente")
    expect(page.get_by_role("group",name=re.compile("Esta reserva se queda para la otra ruta"))).to_be_visible()
    click("Abrir cofre de Paquete del muelle")
    click("Ir a la consola")
    click("Usar consola del faro")
    text("Consola del faro")
    screenshot(page,"consola")
    editor = page.get_by_role("textbox",name=re.compile("faro.algo"))
    editor.click(force=True)
    page.keyboard.press("Control+a")
    page.keyboard.insert_text("inicio { entero a,b; leer(a); leer(b); mostrar(a*b+2); }")
    click("Ejecutar y comprobar")
    text("¡Faro encendido!",30000)
    click("Volver al escenario")
    click("Volver al camino")
    text("Cruza el puente y acércate al arco de luz.")
    screenshot(page,"puente")
    click("Cruzar arco de luz")
    click("Cruzar al siguiente mundo")
    text("Cisternas del Vigía")
    route = json.loads(page.evaluate("localStorage.getItem('cquest.rpg.world.alg-1')"))
    assert route["choice"] == 0 and route["repaired"] and route["memory"] and route["finished"], route
    title(page)
    click(re.compile("La noche sin faros"))
    text("Cisternas del Vigía")
    mobile = browser.new_page(viewport={"width":390,"height":844}, is_mobile=True, has_touch=True, device_scale_factor=1)
    title(mobile)
    click(re.compile("La red de latón"), mobile)
    expect(mobile.get_by_text("La Forja de Latón", exact=True)).to_be_visible()
    click("Arriba", mobile)
    click("Arriba", mobile)
    expect(mobile.get_by_text("Habla con Nico.", exact=True)).to_be_visible()
    screenshot(mobile,"movil")
    assert not errors, errors
    print("Verified keyboard, route supplies, optional echo, code repair, crossing, saved progress and mobile C campaign.")

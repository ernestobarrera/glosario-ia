#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
Lee los filtros de IA de pubmed-filters antes de cada render.

La busqueda en PubMed del pie de cada ficha tiene dos piezas: la dinamica, el
termino ingles de la ficha, y la estatica, un filtro de pubmed-filters (el
especifico por defecto, el sensible en las fichas donde el especifico no
devuelve nada). Los filtros NO se copian a mano en este repositorio: si se
copiaran, las mejoras que reciban en su repositorio no llegarian nunca aqui.
Este script los descarga de su fuente (la clave `busqueda-pubmed.filtros` de
_quarto.yml) y deja cada consulta en pubmed-filtro-<clave>.txt, que lee
filters/pubmed.lua.

Cada pubmed-filtro-<clave>.txt se versiona a proposito, por dos motivos:

- es la red de seguridad: si GitHub no responde, el render sigue con la ultima
  version conocida y lo dice, en vez de publicar fichas sin busqueda;
- es el rastro: solo se reescribe cuando la consulta cambia, de modo que un
  cambio del filtro aparece como un diff revisable en el siguiente render local.

La consulta se extrae con el mismo contrato que scripts/parse-filter.mjs de
pubmed-filters: se corta en la linea EXACTA del marcador de metadatos, se
descartan las lineas vacias y las comentadas, y el resto se une con espacios.
Por eso su sha256 coincide con el `query_sha256` que da el MCP pubmed-exact.

Se ejecuta solo como pre-render de Quarto. A mano:
    python herramientas/filtro_pubmed.py
"""

import hashlib
import sys
import urllib.request
from datetime import date
from pathlib import Path

try:
    import yaml
except ImportError:
    sys.exit("Falta PyYAML: pip install pyyaml")

RAIZ = Path(__file__).resolve().parent.parent
MARCADOR = "@@@FILTER_METADATA@@@"
PREFIJO = "[busqueda-pubmed]"


def configuracion():
    proyecto = yaml.safe_load((RAIZ / "_quarto.yml").read_text(encoding="utf-8"))
    cfg = proyecto.get("busqueda-pubmed") or {}
    for clave in ("repositorio", "rama", "filtros"):
        if not cfg.get(clave):
            sys.exit(f"{PREFIJO} falta busqueda-pubmed.{clave} en _quarto.yml")
    for nombre, filtro in cfg["filtros"].items():
        if not (filtro or {}).get("ruta"):
            sys.exit(f"{PREFIJO} falta busqueda-pubmed.filtros.{nombre}.ruta en _quarto.yml")
    return cfg


def instantanea(clave):
    return RAIZ / f"pubmed-filtro-{clave}.txt"


def extraer_consulta(texto):
    """Mismo contrato que parseFilter() de pubmed-filters/scripts/parse-filter.mjs."""
    lineas = texto.splitlines()
    fin = next((i for i, l in enumerate(lineas) if l.strip() == MARCADOR), len(lineas))
    cuerpo = [l.strip() for l in lineas[:fin] if l.strip() and not l.lstrip().startswith("#")]
    return " ".join(cuerpo)


def sha_instantanea(ruta):
    if not ruta.exists():
        return None
    for linea in ruta.read_text(encoding="utf-8").splitlines():
        if linea.startswith("# sha256:"):
            return linea.split(":", 1)[1].strip()
    return None


def actualizar(cfg, clave, ruta_filtro):
    destino = instantanea(clave)
    origen = f"https://raw.githubusercontent.com/{cfg['repositorio']}/{cfg['rama']}/{ruta_filtro}"
    vista = f"https://github.com/{cfg['repositorio']}/blob/{cfg['rama']}/{ruta_filtro}"

    try:
        with urllib.request.urlopen(origen, timeout=20) as respuesta:
            texto = respuesta.read().decode("utf-8")
    except Exception as error:  # red caida, 404, limite de GitHub...
        if destino.exists():
            print(f"{PREFIJO} AVISO: no se pudo leer {origen} ({error}); "
                  f"se usa la ultima version conocida de {destino.name}.")
            return
        sys.exit(f"{PREFIJO} no se pudo leer {origen} ({error}) y no hay instantanea previa.")

    consulta = extraer_consulta(texto)
    if not consulta:
        sys.exit(f"{PREFIJO} {origen} no contiene ninguna consulta: se conserva la anterior.")

    huella = hashlib.sha256(consulta.encode("utf-8")).hexdigest()
    if huella == sha_instantanea(destino):
        print(f"{PREFIJO} {clave}: sin cambios (sha256 {huella[:12]}).")
        return

    destino.write_text(
        "# GENERADO por herramientas/filtro_pubmed.py antes de cada render. No editar a mano.\n"
        f"# Fuente: {vista}\n"
        f"# sha256: {huella}\n"
        f"# Vigente desde: {date.today().isoformat()}\n"
        f"{consulta}\n",
        encoding="utf-8",
        newline="\n",
    )
    print(f"{PREFIJO} {clave}: actualizado desde {vista} (sha256 {huella[:12]}).")


def main():
    cfg = configuracion()
    for clave, filtro in cfg["filtros"].items():
        actualizar(cfg, clave, filtro["ruta"])


if __name__ == "__main__":
    main()

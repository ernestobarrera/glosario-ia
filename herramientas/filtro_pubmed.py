#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
Lee el filtro de IA de pubmed-filters antes de cada render.

La busqueda en PubMed del pie de cada ficha tiene dos piezas: la dinamica, el
termino ingles de la ficha, y la estatica, un filtro de pubmed-filters. El
filtro NO se copia a mano en este repositorio: si se copiara, las mejoras que
reciba en su repositorio no llegarian nunca aqui. Este script lo descarga de su
fuente (la clave `busqueda-pubmed` de _quarto.yml) y deja la consulta en
pubmed-filtro.txt, que lee filters/pubmed.lua.

pubmed-filtro.txt se versiona a proposito, por dos motivos:

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
INSTANTANEA = RAIZ / "pubmed-filtro.txt"
MARCADOR = "@@@FILTER_METADATA@@@"
PREFIJO = "[busqueda-pubmed]"


def configuracion():
    proyecto = yaml.safe_load((RAIZ / "_quarto.yml").read_text(encoding="utf-8"))
    cfg = proyecto.get("busqueda-pubmed") or {}
    for clave in ("repositorio", "rama", "ruta"):
        if not cfg.get(clave):
            sys.exit(f"{PREFIJO} falta busqueda-pubmed.{clave} en _quarto.yml")
    return cfg


def extraer_consulta(texto):
    """Mismo contrato que parseFilter() de pubmed-filters/scripts/parse-filter.mjs."""
    lineas = texto.splitlines()
    fin = next((i for i, l in enumerate(lineas) if l.strip() == MARCADOR), len(lineas))
    cuerpo = [l.strip() for l in lineas[:fin] if l.strip() and not l.lstrip().startswith("#")]
    return " ".join(cuerpo)


def sha_instantanea():
    if not INSTANTANEA.exists():
        return None
    for linea in INSTANTANEA.read_text(encoding="utf-8").splitlines():
        if linea.startswith("# sha256:"):
            return linea.split(":", 1)[1].strip()
    return None


def main():
    cfg = configuracion()
    origen = f"https://raw.githubusercontent.com/{cfg['repositorio']}/{cfg['rama']}/{cfg['ruta']}"
    vista = f"https://github.com/{cfg['repositorio']}/blob/{cfg['rama']}/{cfg['ruta']}"

    try:
        with urllib.request.urlopen(origen, timeout=20) as respuesta:
            texto = respuesta.read().decode("utf-8")
    except Exception as error:  # red caida, 404, limite de GitHub...
        if INSTANTANEA.exists():
            print(f"{PREFIJO} AVISO: no se pudo leer {origen} ({error}); "
                  f"se usa la ultima version conocida de {INSTANTANEA.name}.")
            return
        sys.exit(f"{PREFIJO} no se pudo leer {origen} ({error}) y no hay instantanea previa.")

    consulta = extraer_consulta(texto)
    if not consulta:
        sys.exit(f"{PREFIJO} {origen} no contiene ninguna consulta: se conserva la anterior.")

    huella = hashlib.sha256(consulta.encode("utf-8")).hexdigest()
    if huella == sha_instantanea():
        print(f"{PREFIJO} filtro sin cambios (sha256 {huella[:12]}).")
        return

    INSTANTANEA.write_text(
        "# GENERADO por herramientas/filtro_pubmed.py antes de cada render. No editar a mano.\n"
        f"# Fuente: {vista}\n"
        f"# sha256: {huella}\n"
        f"# Vigente desde: {date.today().isoformat()}\n"
        f"{consulta}\n",
        encoding="utf-8",
        newline="\n",
    )
    print(f"{PREFIJO} filtro actualizado desde {vista} (sha256 {huella[:12]}).")


if __name__ == "__main__":
    main()

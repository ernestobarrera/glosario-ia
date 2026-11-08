#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
Comprueba contra NCBI el descriptor MeSH y la busqueda en PubMed de cada ficha.

Es el paso de cierre de una ficha para su termino ingles (esquema.yml,
busqueda_pubmed) y la revision periodica de sus rutas. Hace tres cosas:

1. Verifica que cada `mesh` declarado es un encabezado MeSH que existe. Un
   descriptor inventado o mal escrito no da error en PubMed: lo descarta en
   silencio y la busqueda sigue con el resto.
2. Con --sugerir, en las fichas con mesh "ninguno", dice si el termino ingles
   lleva ya a un descriptor. Solo sugiere: decidir si es el mismo concepto es
   humano (Hallucination lleva a Hallucinations, el sintoma psiquiatrico).
3. Decide la RUTA de filtro de cada busqueda, midiendolas TAL COMO QUEDARON EN
   EL HTML (data-consulta-<clave>, que escribe filters/pubmed.lua): no las
   reconstruye, para que la regla tenga una sola implementacion.
     - especifico, por defecto;
     - sensible, si el especifico no devuelve nada (posible falso negativo);
     - oculta, si tampoco el sensible devuelve nada.
   Las que no usan la ruta por defecto se registran en pubmed-rutas.txt con la
   fecha y los recuentos de la decision: es la memoria de revision. En cada
   pasada se revisan todas, y una ficha vuelve al especifico en cuanto da
   resultados con el. Una consulta que PubMed no ejecuta tal como esta escrita
   es un error.

Necesita red y un `quarto render` previo. No forma parte de validar.ps1, que
funciona sin conexion. Cuando cambien rutas, hay que volver a renderizar.

Uso:
    python herramientas/comprobar_pubmed.py                 # todas las fichas
    python herramientas/comprobar_pubmed.py --ficha subajuste
    python herramientas/comprobar_pubmed.py --sugerir

No envia datos personales: solo las consultas y tool=glosario-ia.
"""

import argparse
import html
import json
import re
import sys
import time
import urllib.parse
import urllib.request
from datetime import date
from pathlib import Path

try:
    import yaml
except ImportError:
    sys.exit("Falta PyYAML: pip install pyyaml")

RAIZ = Path(__file__).resolve().parent.parent
TERMINOS = RAIZ / "terminos"
SITIO = RAIZ / "_site" / "terminos"
RUTAS = RAIZ / "pubmed-rutas.txt"
EUTILS = "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/"
PAUSA = 0.36  # sin clave de API, NCBI admite 3 peticiones por segundo
POR_DEFECTO, ALTERNATIVA, OCULTA = "especifico", "sensible", "oculta"

_ultima = [0.0]


def eutils(util, **params):
    params.setdefault("retmode", "json")
    params["tool"] = "glosario-ia"
    cuerpo = urllib.parse.urlencode(params).encode("utf-8")
    ultimo_error = None
    for intento in range(5):
        espera = PAUSA - (time.time() - _ultima[0])
        if espera > 0:
            time.sleep(espera)
        try:
            with urllib.request.urlopen(EUTILS + util, data=cuerpo, timeout=40) as r:
                _ultima[0] = time.time()
                return json.loads(r.read().decode("utf-8"))
        except Exception as error:  # 429 por exceso de ritmo, cortes de red
            _ultima[0] = time.time()
            ultimo_error = error
            time.sleep(1.5 * (intento + 1))
    raise RuntimeError(f"NCBI no respondio a {util}: {ultimo_error}")


def frontmatter(ruta):
    return yaml.safe_load(ruta.read_text(encoding="utf-8").split("---", 2)[1])


def descriptor(termino):
    """Descriptor al que PubMed lleva un termino, o None. Mira tambien el singular."""
    variantes = [termino]
    if termino.endswith("s") and not termino.endswith(("ss", "is", "us")):
        variantes.append(termino[:-1])
    for variante in variantes:
        ids = eutils("esearch.fcgi", db="mesh", term=f'"{variante}"[MeSH Terms]', retmax=3)
        ids = ids["esearchresult"]["idlist"]
        if not ids:
            continue
        r = eutils("esummary.fcgi", db="mesh", id=ids[0])["result"][ids[0]]
        if r.get("ds_meshui", "").startswith("D"):
            arboles = [x.get("treenum", "") for x in r.get("ds_idxlinks", [])]
            return r["ds_meshterms"][0], arboles
    return None


def consultas_renderizadas(slug):
    """Las dos consultas que filters/pubmed.lua dejo en el HTML de la ficha."""
    ruta = SITIO / f"{slug}.html"
    if not ruta.exists():
        return None
    bloque = re.search(r'<div class="busqueda-pubmed"([^>]*)>', ruta.read_text(encoding="utf-8"))
    if not bloque:
        return None
    consultas = {}
    for clave in (POR_DEFECTO, ALTERNATIVA):
        m = re.search(rf'\sdata-consulta-{clave}="([^"]*)"', bloque.group(1))
        if m:
            consultas[clave] = html.unescape(m.group(1))
    return consultas if len(consultas) == 2 else None


def medir(consulta, slug, errores):
    r = eutils("esearch.fcgi", db="pubmed", term=consulta, retmax=0)["esearchresult"]
    total = int(r.get("count", 0))
    avisos = r.get("warninglist") or {}
    descartado = (avisos.get("phrasesignored") or []) + (avisos.get("quotedphrasesnotfound") or [])
    if r.get("errorlist") and any(r["errorlist"].values()):
        errores.append(f"{slug}: PubMed devolvio errores {r['errorlist']}")
    elif descartado and total > 0:
        errores.append(f"{slug}: PubMed descarto {descartado}; la busqueda no se ejecuta como esta escrita")
    return total


def leer_rutas():
    """{slug: (ruta, linea)} de las fichas que no usan la ruta por defecto."""
    rutas = {}
    if RUTAS.exists():
        for linea in RUTAS.read_text(encoding="utf-8").splitlines():
            m = re.match(r"^\s*([a-z0-9-]+)\s+([a-z]+)", linea)
            if m and not linea.lstrip().startswith("#"):
                rutas[m.group(1)] = (m.group(2), linea.rstrip())
    return rutas


def escribir_rutas(rutas):
    RUTAS.write_text(
        "# GENERADO por herramientas/comprobar_pubmed.py. No editar a mano.\n"
        "# Ruta de filtro de la busqueda en PubMed de las fichas que NO usan la de\n"
        "# por defecto (especifico):\n"
        "#   sensible  el especifico no devolvia nada y el sensible si (posible falso negativo)\n"
        "#   oculta    ninguno de los dos devolvia nada; el enlace se oculta\n"
        "# Cada linea guarda cuando y con que recuentos se decidio. La herramienta las\n"
        "# revisa todas en cada pasada: una ficha vuelve al especifico en cuanto da\n"
        "# resultados con el, y entonces sale de esta lista.\n"
        + "".join(f"{rutas[s][1]}\n" for s in sorted(rutas)),
        encoding="utf-8",
        newline="\n",
    )


def main():
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("--ficha", help="comprobar solo esta ficha (slug)")
    parser.add_argument("--sugerir", action="store_true",
                        help="en las fichas con mesh 'ninguno', buscar si hay descriptor")
    args = parser.parse_args()

    if not SITIO.exists():
        sys.exit("No hay _site: ejecuta 'quarto render' antes.")

    rutas_fichas = sorted(TERMINOS.glob("*.qmd"))
    if args.ficha:
        rutas_fichas = [r for r in rutas_fichas if r.stem == args.ficha]
        if not rutas_fichas:
            sys.exit(f"No existe la ficha '{args.ficha}'.")

    hoy = date.today().isoformat()
    anteriores = leer_rutas()
    nuevas = dict(anteriores)
    errores, sugerencias, medidas = [], [], 0
    for ruta in rutas_fichas:
        slug = ruta.stem
        meta = frontmatter(ruta)
        ingles, mesh = meta.get("ingles"), meta.get("mesh")
        if not ingles or not mesh:
            errores.append(f"{slug}: faltan ingles o mesh")
            continue

        if mesh != "ninguno":
            hallado = descriptor(mesh)
            if not hallado or hallado[0] != mesh:
                errores.append(f"{slug}: mesh '{mesh}' no es un encabezado MeSH"
                               + (f" (PubMed lleva a '{hallado[0]}')" if hallado else ""))
        elif args.sugerir:
            hallado = descriptor(ingles)
            if hallado:
                sugerencias.append(f"{slug}: '{ingles}' lleva a '{hallado[0]}' {hallado[1][:3]}"
                                   " -> ¿mismo concepto, ni mas amplio ni con otro sentido?")

        consultas = consultas_renderizadas(slug)
        if not consultas:
            errores.append(f"{slug}: no hay busqueda en _site; renderiza antes")
            continue
        medidas += 1
        n_esp = medir(consultas[POR_DEFECTO], slug, errores)
        if n_esp > 0:
            nuevas.pop(slug, None)
            print(f"{slug:40} especifico {n_esp:>7}", flush=True)
            continue
        n_sens = medir(consultas[ALTERNATIVA], slug, errores)
        decision = ALTERNATIVA if n_sens > 0 else OCULTA
        print(f"{slug:40} especifico {n_esp:>7}  sensible {n_sens:>7}  -> {decision}", flush=True)
        if anteriores.get(slug, (None,))[0] != decision:
            nuevas[slug] = (decision, f"{slug} {decision}  # {hoy} · especifico {n_esp} · sensible {n_sens}")

    if nuevas != anteriores:
        escribir_rutas(nuevas)
        for s in sorted(set(nuevas) | set(anteriores)):
            antes = anteriores.get(s, (POR_DEFECTO,))[0]
            despues = nuevas.get(s, (POR_DEFECTO,))[0]
            if antes != despues:
                print(f"RUTA {s}: {antes} -> {despues}")
        print(f"Actualizado {RUTAS.name}: vuelve a renderizar para aplicarlo.")

    for s in sugerencias:
        print(f"SUGERENCIA {s}")
    resumen = {POR_DEFECTO: 0, ALTERNATIVA: 0, OCULTA: 0}
    for r in nuevas.values():
        resumen[r[0]] = resumen.get(r[0], 0) + 1
    print(f"\n{medidas} busquedas medidas · rutas: sensible {resumen[ALTERNATIVA]}, "
          f"oculta {resumen[OCULTA]}, el resto especifico.")
    if errores:
        print("\nERRORES:")
        for e in errores:
            print(f"  - {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()

#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
Comprueba contra NCBI el descriptor MeSH y la busqueda en PubMed de cada ficha.

Es el paso de cierre de una ficha para su termino ingles (esquema.yml,
busqueda_pubmed). Hace tres cosas:

1. Verifica que cada `mesh` declarado es un encabezado MeSH que existe. Un
   descriptor inventado o mal escrito no da error en PubMed: lo descarta en
   silencio y la busqueda sigue con el resto.
2. Con --sugerir, en las fichas con mesh "ninguno", dice si el termino ingles
   lleva ya a un descriptor. Solo sugiere: decidir si es el mismo concepto es
   humano (Hallucination lleva a Hallucinations, el sintoma psiquiatrico).
3. Mide cada busqueda TAL COMO QUEDO EN EL HTML (atributo data-consulta que
   escribe filters/pubmed.lua): no la reconstruye, para que solo haya una
   implementacion de la regla. Las que no devuelven nada van a
   pubmed-sin-resultados.txt, y su enlace se oculta en el siguiente render.
   Una consulta que PubMed no ejecuta tal como esta escrita es un error.

Necesita red y un `quarto render` previo. No forma parte de validar.ps1, que
funciona sin conexion.

Uso:
    python herramientas/comprobar_pubmed.py                 # todas las fichas
    python herramientas/comprobar_pubmed.py --ficha k-medias
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
SIN_RESULTADOS = RAIZ / "pubmed-sin-resultados.txt"
FILTRO = RAIZ / "pubmed-filtro.txt"
EUTILS = "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/"
PAUSA = 0.36  # sin clave de API, NCBI admite 3 peticiones por segundo

_ultima = [0.0]


def eutils(util, **params):
    params.setdefault("retmode", "json")
    params["tool"] = "glosario-ia"
    cuerpo = urllib.parse.urlencode(params).encode("utf-8")
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


def consulta_renderizada(slug):
    ruta = SITIO / f"{slug}.html"
    if not ruta.exists():
        return None
    m = re.search(r'<div class="busqueda-pubmed"[^>]*\sdata-consulta="([^"]*)"', ruta.read_text(encoding="utf-8"))
    return html.unescape(m.group(1)) if m else None


def leer_lista():
    if not SIN_RESULTADOS.exists():
        return set()
    return {l.strip() for l in SIN_RESULTADOS.read_text(encoding="utf-8").splitlines()
            if l.strip() and not l.startswith("#")}


def sha_filtro():
    for linea in FILTRO.read_text(encoding="utf-8").splitlines():
        if linea.startswith("# sha256:"):
            return linea.split(":", 1)[1].strip()[:12]
    return "?"


def escribir_lista(slugs):
    SIN_RESULTADOS.write_text(
        "# GENERADO por herramientas/comprobar_pubmed.py. No editar a mano.\n"
        f"# Fichas cuya busqueda en PubMed no devolvia resultados el {date.today().isoformat()},\n"
        f"# con el filtro de sha256 {sha_filtro()}. En ellas filters/pubmed.lua oculta el enlace:\n"
        "# un enlace que lleva a «No results» ensena a ignorar todos los demas.\n"
        + "".join(f"{s}\n" for s in sorted(slugs)),
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

    rutas = sorted(TERMINOS.glob("*.qmd"))
    if args.ficha:
        rutas = [r for r in rutas if r.stem == args.ficha]
        if not rutas:
            sys.exit(f"No existe la ficha '{args.ficha}'.")

    errores, sugerencias, vacias, medidas = [], [], set(), set()
    for ruta in rutas:
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

        consulta = consulta_renderizada(slug)
        if not consulta:
            errores.append(f"{slug}: no hay busqueda en _site; renderiza antes")
            continue
        r = eutils("esearch.fcgi", db="pubmed", term=consulta, retmax=0)["esearchresult"]
        total = int(r.get("count", 0))
        avisos = r.get("warninglist") or {}
        descartado = (avisos.get("phrasesignored") or []) + (avisos.get("quotedphrasesnotfound") or [])
        if r.get("errorlist") and any(r["errorlist"].values()):
            errores.append(f"{slug}: PubMed devolvio errores {r['errorlist']}")
        elif descartado and total > 0:
            errores.append(f"{slug}: PubMed descarto {descartado}; la busqueda no se ejecuta como esta escrita")
        medidas.add(slug)
        if total == 0:
            vacias.add(slug)
        print(f"{slug:40} {total:>7}", flush=True)

    anterior = leer_lista()
    nueva = (anterior - medidas) | vacias
    if nueva != anterior:
        escribir_lista(nueva)
        for s in sorted(nueva - anterior):
            print(f"OCULTA desde hoy (sin resultados): {s}")
        for s in sorted(anterior - nueva):
            print(f"VISIBLE de nuevo (ya tiene resultados): {s}")
        print(f"Actualizado {SIN_RESULTADOS.name}: vuelve a renderizar para aplicarlo.")

    for s in sugerencias:
        print(f"SUGERENCIA {s}")
    print(f"\n{len(medidas)} busquedas medidas, {len(nueva & medidas)} sin resultados.")
    if errores:
        print("\nERRORES:")
        for e in errores:
            print(f"  - {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()

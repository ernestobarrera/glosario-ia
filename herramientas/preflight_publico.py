#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
Preflight de publicacion: impide que datos privados lleguen a un repo publico.

Revisar a mano una vez no es una garantia. Esto corre siempre: antes de portar
nada del laboratorio al repositorio publico, y en CI en cada pull request.

Dos capas (ver patrones-privados.yml):
  - estructurales: formas (rutas locales, ids de Drive, tokens, correos). Se
    pueden publicar sin revelar nada, asi que viajan al repo publico.
  - literales: valores concretos. Publicarlos seria publicar lo que protegen,
    asi que solo se evaluan cuando el archivo de patrones los trae, es decir
    desde el laboratorio.

Inspecciona el arbol de trabajo y, con --historial, tambien todos los blobs
que existieron en el repositorio: el contenido retirado de un arbol sigue
descargable con un clone.

Dos usos reales, y ninguno es "escanear el laboratorio": ahi los datos
privados son legitimos y el informe seria puro ruido.

  1) Auditar el repositorio publico, desde el lab, con las dos capas:
     python herramientas/preflight_publico.py RUTA_PUBLICO --destino-publico --historial

  2) Comprobar en CI, con la capa publica, dentro del propio repo publico:
     python herramientas/preflight_publico.py . --patrones patrones-publicos.yml          --destino-publico --historial
     (requiere actions/checkout con fetch-depth: 0, o el historial estara vacio)

  Y para regenerar la capa publica tras tocar los patrones:
     python herramientas/preflight_publico.py . --emitir-publicos patrones-publicos.yml

Salida: 0 sin hallazgos, 1 con hallazgos o rutas prohibidas rastreadas.
"""

import argparse
import re
import subprocess
import sys
from fnmatch import fnmatch
from pathlib import Path

try:
    import yaml
except ImportError:
    sys.exit("Falta PyYAML: pip install pyyaml")

POR_DEFECTO = Path(__file__).resolve().parent.parent / "patrones-privados.yml"
BINARIAS = {".png", ".jpg", ".jpeg", ".gif", ".webp", ".pdf", ".woff", ".woff2",
            ".ttf", ".otf", ".ico", ".zip", ".gz", ".mp4", ".webm"}


def cargar(ruta):
    cfg = yaml.safe_load(Path(ruta).read_text(encoding="utf-8"))
    reglas = []
    for r in cfg.get("estructurales") or []:
        reglas.append((r["id"], re.compile(r["patron"]), r["motivo"], "estructural",
                       bool(r.get("requiere_mayuscula"))))
    for r in cfg.get("literales") or []:
        reglas.append((r["id"], re.compile(re.escape(r["valor"]), re.I),
                       r["motivo"], "literal", False))
    excepciones = [(e["patron_id"], e["archivo"], bool(e.get("solo_historial")))
                   for e in cfg.get("excepciones") or []]
    ignorar = cfg.get("ignorar_rutas") or []
    prohibidas = cfg.get("rutas_prohibidas") or []
    return reglas, excepciones, ignorar, prohibidas


def exento(pid, nombre, excepciones):
    for p, a, solo_hist in excepciones:
        if p != pid:
            continue
        # Una excepcion marcada solo_historial NO cubre el archivo vivo: sirve
        # para un blob que ya no esta en el arbol y no se puede retirar sin
        # reescribir el historial.
        es_hist = nombre.startswith("[historial] ")
        if solo_hist and not es_hist:
            continue
        if nombre.endswith(a):
            return True
    return False


def revisar(texto, nombre, reglas, excepciones):
    hallazgos = []
    for pid, patron, motivo, capa, requiere_mayuscula in reglas:
        if exento(pid, nombre, excepciones):
            continue
        for n, linea in enumerate(texto.splitlines(), 1):
            m = patron.search(linea)
            if m:
                muestra = m.group(0)
                if requiere_mayuscula and not any(c.isupper() for c in muestra):
                    continue
                # No se vuelca el valor completo de un literal en el informe.
                if capa == "literal" and len(muestra) > 12:
                    muestra = muestra[:6] + "…" + muestra[-4:]
                hallazgos.append((nombre, n, pid, motivo, capa, muestra))
                break
    return hallazgos


def emitir_publicos(origen, destino):
    """Deriva la capa estructural, que es la unica publicable.

    Se genera en vez de mantenerse a mano para que no existan dos listas de
    patrones que puedan divergir: si se anade una forma nueva, aparece en
    ambos lados o en ninguno.
    """
    cfg = yaml.safe_load(Path(origen).read_text(encoding="utf-8"))
    if not cfg.get("estructurales"):
        sys.exit("El archivo de origen no tiene capa estructural")

    # Solo viajan las excepciones de patrones estructurales. Las de la capa
    # privada nombran categorías que no deben aparecer en un repo público.
    ids_publicos = {r["id"] for r in cfg["estructurales"]}
    excepciones = [e for e in (cfg.get("excepciones") or [])
                   if e["patron_id"] in ids_publicos]

    salida = {
        "version": cfg.get("version", 1),
        "estructurales": cfg["estructurales"],
        "excepciones": excepciones,
        "ignorar_rutas": cfg.get("ignorar_rutas") or [],
        "rutas_prohibidas": cfg.get("rutas_prohibidas") or [],
    }
    cabecera = (
        "# GENERADO por herramientas/preflight_publico.py --emitir-publicos.\n"
        "# NO EDITAR A MANO: deriva de la lista completa, que vive en el\n"
        "# laboratorio y contiene ademas una capa de valores literales que no\n"
        "# puede publicarse. Aqui solo hay FORMAS, que no revelan ningun dato.\n\n"
    )
    Path(destino).write_text(
        cabecera + yaml.safe_dump(salida, allow_unicode=True, sort_keys=False),
        encoding="utf-8")
    print(f"{destino}: {len(salida['estructurales'])} patrones estructurales")
    print("  capa literal excluida a proposito")
    return 0


def git(repo, *args):
    return subprocess.run(["git", "-C", str(repo), *args],
                          capture_output=True, text=True, errors="replace").stdout


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("repo")
    ap.add_argument("--patrones", default=str(POR_DEFECTO))
    ap.add_argument("--historial", action="store_true",
                    help="revisa tambien los blobs de todo el historial")
    ap.add_argument("--destino-publico", action="store_true",
                    help="aplica rutas_prohibidas: el repo inspeccionado es un "
                         "destino publico y hay archivos que no deben estar "
                         "rastreados ahi. En el laboratorio esos mismos "
                         "archivos son legitimos, por eso no es el defecto")
    ap.add_argument("--emitir-publicos", metavar="RUTA",
                    help="deriva el archivo de patrones sin la capa literal, "
                         "para que viaje al repo publico")
    args = ap.parse_args()

    if args.emitir_publicos:
        return emitir_publicos(args.patrones, args.emitir_publicos)

    repo = Path(args.repo).resolve()
    if not repo.exists():
        sys.exit(f"No existe: {repo}")

    reglas, excepciones, ignorar, prohibidas = cargar(args.patrones)
    capas = sorted({r[3] for r in reglas})
    hallazgos = []

    # --- arbol de trabajo ---------------------------------------------------
    archivos = [l for l in git(repo, "ls-files").splitlines() if l.strip()]
    if not archivos:
        archivos = [str(p.relative_to(repo)) for p in repo.rglob("*") if p.is_file()]

    # --- rutas prohibidas ----------------------------------------------------
    # Comprobacion estructural, previa e independiente del escaneo de
    # contenido: hay archivos que no deben estar rastreados aqui, tengan
    # dentro lo que tengan. El export del documento de origen es el caso claro:
    # su contenido no incluye ningun dato privado, asi que un escaneo de
    # contenido no lo detendria nunca; lo que hay que prohibir es su presencia.
    prohibidos = []
    for rel in (archivos if args.destino_publico else []):
        norm = rel.replace("\\", "/")
        for patron in prohibidas:
            if fnmatch(norm, patron) or fnmatch(Path(norm).name, patron):
                prohibidos.append((rel, patron))
                break

    revisados = 0
    for rel in archivos:
        if any(rel.replace("\\", "/").startswith(i.rstrip("/")) or
               f"/{i.rstrip('/')}/" in f"/{rel}".replace("\\", "/")
               for i in ignorar):
            continue
        ruta = repo / rel
        if ruta.suffix.lower() in BINARIAS or not ruta.exists():
            continue
        try:
            texto = ruta.read_text(encoding="utf-8", errors="replace")
        except OSError:
            continue
        revisados += 1
        hallazgos += revisar(texto, rel, reglas, excepciones)

    # --- historial -----------------------------------------------------------
    blobs = 0
    if args.historial:
        objetos = [l.split(maxsplit=1) for l in
                   git(repo, "rev-list", "--objects", "--all").splitlines() if l.strip()]
        for partes in objetos:
            sha = partes[0]
            nombre = partes[1] if len(partes) > 1 else sha[:8]
            if Path(nombre).suffix.lower() in BINARIAS:
                continue
            if git(repo, "cat-file", "-t", sha).strip() != "blob":
                continue
            contenido = git(repo, "cat-file", "-p", sha)
            if not contenido:
                continue
            blobs += 1
            hallazgos += revisar(contenido, f"[historial] {nombre}",
                                 reglas, excepciones)

    # --- informe -------------------------------------------------------------
    print(f"Preflight de publicacion — {repo.name}")
    print(f"  patrones: {len(reglas)} ({', '.join(capas)})"
          + (f" | rutas prohibidas: {len(prohibidas)}"
             if args.destino_publico else " | rutas: no comprobadas"))
    print(f"  archivos revisados: {revisados}" +
          (f" | blobs de historial: {blobs}" if args.historial else
           " | historial NO revisado (usa --historial)"))

    if prohibidos:
        print(f"\nRUTAS PROHIBIDAS RASTREADAS ({len(prohibidos)}):")
        for rel, patron in prohibidos:
            print(f"  {rel}   (coincide con '{patron}')")
        print("  Este archivo no debe estar versionado en este repositorio.")

    if not hallazgos and not prohibidos:
        print("\nSIN HALLAZGOS: no se detectan datos privados.")
        return 0

    if prohibidos and not hallazgos:
        return 1

    print(f"\nHALLAZGOS ({len(hallazgos)}):")
    for nombre, n, pid, motivo, capa, muestra in hallazgos:
        print(f"  {nombre}:{n}")
        print(f"      [{capa}/{pid}] {motivo} -> {muestra}")
    print("\nNo publiques hasta resolverlos. Si alguno es un falso positivo,")
    print("declaralo en la seccion 'excepciones' de patrones-privados.yml con")
    print("su motivo; no lo silencies sin dejar constancia.")
    return 1


if __name__ == "__main__":
    sys.exit(main())

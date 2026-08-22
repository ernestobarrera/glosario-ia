#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
Deriva esquema.lock.yml a partir de esquema.yml.

esquema.yml es anidado y esta escrito para que lo lea una persona.
validar.ps1 tiene un lector YAML plano deliberadamente simple. En vez de
escribir un parser YAML en PowerShell, se emite este derivado plano.

El lock lleva el hash de esquema.yml: si alguien edita el esquema y no
regenera el lock, el validador lo detecta y falla. El derivado no puede
quedarse atras en silencio.

Uso:
    python herramientas/esquema_lock.py
"""

import hashlib
import sys
from datetime import date
from pathlib import Path

try:
    import yaml
except ImportError:
    sys.exit("Falta PyYAML: pip install pyyaml")

RAIZ = Path(__file__).resolve().parent.parent
ESQUEMA = RAIZ / "esquema.yml"
LOCK = RAIZ / "esquema.lock.yml"


def main():
    texto = ESQUEMA.read_text(encoding="utf-8")
    esquema = yaml.safe_load(texto)
    # Hash sobre el texto con finales de linea normalizados: si se calculara
    # sobre bytes crudos, un editor que cambie CRLF por LF marcaria el lock
    # como obsoleto sin que el modelo haya cambiado.
    normalizado = texto.replace("\r\n", "\n").replace("\r", "\n")
    huella = hashlib.sha256(normalizado.encode("utf-8")).hexdigest()[:16]

    orden, obligatorias, recomendadas = [], [], []
    for sec in esquema["secciones"]:
        titulo = sec["titulo"]
        orden.append(titulo)
        (obligatorias if sec.get("obligatorio") else recomendadas).append(titulo)
        for sub in sec.get("subsecciones", []) or []:
            orden.append(sub["titulo"])
            (obligatorias if sub.get("obligatorio") else recomendadas).append(sub["titulo"])

    lineas = [
        "# GENERADO por herramientas/esquema_lock.py — NO EDITAR A MANO.",
        "# Deriva de esquema.yml, que es la fuente de verdad del modelo de datos.",
        "# Si editas esquema.yml, regenera este archivo o el validador fallara.",
        "",
        f"generado: {date.today().isoformat()}",
        f"esquema-sha: {huella}",
        "",
        "# Orden exigido en el cuerpo de la ficha.",
        "secciones-orden:",
    ]
    lineas += [f'  - "{t}"' for t in orden]
    lineas += ["", "# Su ausencia es un error de validacion.", "secciones-obligatorias:"]
    lineas += [f'  - "{t}"' for t in obligatorias]
    lineas += ["", "# Su ausencia se avisa pero no bloquea.", "secciones-recomendadas:"]
    lineas += [f'  - "{t}"' for t in recomendadas] or ["  []"]
    lineas.append("")

    LOCK.write_text("\n".join(lineas), encoding="utf-8")
    print(f"esquema.lock.yml escrito (sha {huella})")
    print(f"  {len(obligatorias)} obligatorias, {len(recomendadas)} recomendadas")


if __name__ == "__main__":
    main()

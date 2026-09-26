#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
Cifras de la lamina del Atlas «Como elige la siguiente palabra».

Los logits son inventados: la lamina ilustra el procedimiento, no un modelo
real. Lo que si es exacto es el calculo: softmax con temperatura, recorte
top-k y top-p, y renormalizacion. Cualquier cifra impresa en la lamina o en
su pagina debe salir de este script.

Criterios con los que se eligieron los logits (un decimal):
- en cada panel, los porcentajes enteros suman exactamente 100;
- el nucleo top-p del paso abierto no roza el umbral (78 % con tres
  candidatos, casi 92 % con cuatro);
- bajar la temperatura no hace subir a ningun candidato no dominante, para
  que la imagen no muestre un efecto que exigiria explicacion aparte (la
  ficha de temperatura lo explica).

Uso:
    python herramientas/atlas_decodificacion.py
"""

import math
import sys

# Un paso abierto (muchas continuaciones plausibles) y uno concentrado.
# Vocabulario reducido a seis candidatos; las palabras son tokens enteros
# por simplicidad.
ABIERTO = ("El paciente refiere dolor ___",
           ["torácico", "abdominal", "lumbar", "de", "en", "cervical"],
           [2.0, 1.6, 1.4, 1.0, 0.0, -0.3])
CONCENTRADO = ("Se le toma la tensión ___",
               ["arterial", "y", "en", "cada", "al", "otra"],
               [6.0, 2.5, 2.0, 1.8, 1.4, 1.2])
TEMPERATURAS = (0.5, 1.0, 1.5)
K = 3
P = 0.9


def softmax(logits, t=1.0):
    m = max(logits)
    e = [math.exp((x - m) / t) for x in logits]
    s = sum(e)
    return [x / s for x in e]


def orden(p):
    return sorted(range(len(p)), key=lambda i: -p[i])


def renormaliza(p, conservar):
    s = sum(p[i] for i in conservar)
    return [p[i] / s if i in conservar else 0.0 for i in range(len(p))]


def top_k(p, k):
    return renormaliza(p, set(orden(p)[:k]))


def top_p(p, umbral):
    conservar, acumulada = [], 0.0
    for i in orden(p):
        conservar.append(i)
        acumulada += p[i]
        if acumulada >= umbral:
            break
    return renormaliza(p, set(conservar)), len(conservar), acumulada


def pct(p):
    return [round(100 * x) for x in p]


def fila(tokens, p, exacto=False):
    if exacto:
        return "  ".join(f"{t} {100 * x:.2f}" for t, x in zip(tokens, p))
    return "  ".join(f"{t} {v} %" for t, v in zip(tokens, pct(p)))


def informe(paso):
    contexto, tokens, logits = paso
    print(f"\n=== «{contexto}»")
    print("logits:", "  ".join(f"{t} {z:+.1f}" for t, z in zip(tokens, logits)))
    errores = []
    for t in TEMPERATURAS:
        p = softmax(logits, t)
        print(f"T = {t}:  {fila(tokens, p)}   (suma {sum(pct(p))})")
        if sum(pct(p)) != 100:
            errores.append(f"T={t} no suma 100")
    p = softmax(logits)
    print("exacto T = 1:", fila(tokens, p, exacto=True))
    acumulada = 0.0
    for i in orden(p):
        acumulada += p[i]
        print(f"    {tokens[i]:10s} {100 * p[i]:6.2f} %   acumulada {100 * acumulada:6.2f} %")
    pk = top_k(p, K)
    print(f"top-k (k = {K}), renormalizado: {fila(tokens, pk)}   (suma {sum(pct(pk))})")
    pp, n, masa = top_p(p, P)
    print(f"top-p (p = {P}): {n} candidato(s), masa {100 * masa:.2f} %; "
          f"renormalizado: {fila(tokens, pp)}   (suma {sum(pct(pp))})")
    for nombre, q in (("top-k", pk), ("top-p", pp)):
        if sum(pct(q)) != 100:
            errores.append(f"{nombre} no suma 100")
    return errores


def main():
    errores = informe(ABIERTO) + informe(CONCENTRADO)
    if errores:
        print("\nERROR:", "; ".join(errores))
        return 1
    return 0


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    sys.exit(main())

# Cómo editar el glosario

Hay tres formas de contribuir. En todas, el cambio debe ser pequeño, trazable
y limitado a contenido ya curado.

## 1. Desde la web de GitHub

1. Abra la ficha en `terminos/`.
2. Pulse el icono de edición.
3. Cambie solo lo necesario y explique el motivo.
4. Proponga el cambio en una rama y abra un pull request.
5. Espere la validación editorial y técnica antes de fusionarlo.

Esta vía sirve para correcciones breves. Para una ficha nueva o cambios de
bibliografía, es preferible trabajar en local.

## 2. Desde VS Code

1. Clone el repositorio y abra su carpeta en VS Code.
2. Instale Quarto 1.9.38 y, de forma opcional, su extensión para VS Code.
3. Ejecute `quarto preview` y abra la dirección local.
4. Edite un único archivo `.qmd` dentro de `terminos/`.
5. Ejecute `.\validar.ps1` y `quarto render`.
6. Revise el diff y abra un pull request.

El editor de texto Markdown es la vía canónica. El editor visual puede usarse
si funciona correctamente en el equipo, pero el diff resultante debe seguir
siendo legible y no debe reformatear la ficha completa.

## 3. Delegar una propuesta a un agente

Entregue al agente:

- el término y el objetivo del cambio;
- las fuentes que deben conservarse o verificarse;
- la instrucción de no modificar otras fichas ni la configuración;
- la obligación de ejecutar el validador y mostrar el diff;
- la petición de detenerse antes de publicar o fusionar.

Un agente puede preparar el cambio, pero no sustituye la revisión humana. No
debe inventar referencias, alterar citekeys existentes ni incorporar
contenido no revisado desde documentos de trabajo.

## Crear una ficha

Copie una ficha cercana y mantenga este frontmatter:

```yaml
---
title: "Nombre del término"
sinonimos:
  - "Sinónimo o sigla"
description: "Definición breve que funciona como entradilla."
categories:
  - "Categoría controlada"
date-modified: 2026-07-24
estado: borrador
tipo: concepto
---
```

El nombre del archivo es el slug canónico. `aliases` se reserva exclusivamente
para redirects estáticos y sus valores terminan en `.html`. Las categorías,
los estados y los tipos permitidos están en `taxonomia.yml`.

El cuerpo conserva siempre:

1. definición ampliada;
2. aplicaciones;
3. limitaciones;
4. ejemplos;
5. relacionados, con enlaces internos;
6. referencias.

## Citas y bibliografía

Use `[@citekey]` en la ficha y añada la referencia completa a
`references.bib`. Priorice DOI, PMID o una URL institucional estable. No
cambie ni elimine un citekey existente sin comprobar todas sus citas y
verificar la referencia.

Las referencias provisionales deben declararse como tales en sus notas. La
integración futura con Zotero y Better BibTeX se evaluará por separado; no es
un requisito para una corrección sencilla.

## Validación

En PowerShell:

```powershell
quarto render
.\validar.ps1
```

El validador comprueba el esquema de metadatos, la taxonomía, fechas,
sinónimos renderizados, citekeys, enlaces internos, slugs, aliases y
artefactos del documento de trabajo. Un cambio no está listo si alguna
comprobación falla.

Una vez activada la publicación, los cambios aceptados en `main` generarán el
sitio mediante GitHub Actions. La activación inicial de Pages requiere una
decisión humana independiente.

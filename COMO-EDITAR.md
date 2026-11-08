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
  - "English term"
ingles: "english term"
mesh: "ninguno"
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

## Término inglés, MeSH y búsqueda en PubMed

Cada ficha declara su término inglés y su descriptor MeSH **antes de darla por
cerrada**. Con ellos se pinta «ingl. *término*» bajo el título y se compone la
búsqueda en PubMed del pie de la ficha. La regla completa está en
`esquema.yml`, apartado `busqueda_pubmed`.

- `ingles`: señala cuál de los términos ya declarados, el título o un
  sinónimo, es la forma inglesa de la literatura. Si no está, añádala antes a
  `sinonimos`. Escríbala en minúscula de diccionario, salvo nombres propios,
  siglas y nombres de producto, y en su forma desarrollada, no la sigla.
- `mesh`: el descriptor MeSH del mismo concepto, o `"ninguno"`. Rechace el que
  coincide en nombre pero no en sentido y el que es más amplio que el término.

Al cerrar la ficha, después de `quarto render`:

```powershell
python herramientas/comprobar_pubmed.py --ficha <slug> --sugerir
```

La herramienta verifica contra NCBI que el descriptor existe, sugiere uno si
la ficha dice `"ninguno"` y el término lleva ya a alguno (decidir si es el
mismo concepto es humano), y elige la ruta de la búsqueda: el filtro
específico por defecto; el sensible si con el específico no hay resultados;
y, si tampoco con el sensible, el enlace se oculta. Las fichas fuera de la
ruta por defecto quedan en `pubmed-rutas.txt` con la fecha y los recuentos de
la decisión. Si cambia alguna ruta, vuelva a renderizar. Ejecútela sin
`--ficha` cuando cambie un filtro y en la revisión periódica: una ficha vuelve
al específico en cuanto da resultados con él.

Los filtros no se editan aquí: viven en `pubmed-filters` y
`herramientas/filtro_pubmed.py` los lee antes de cada render. Si cambian, el
render local deja el cambio en `pubmed-filtro-especifico.txt` o
`pubmed-filtro-sensible.txt` como un diff revisable.

## Recorridos

«Empieza aquí» y los demás recorridos se escriben en `recorridos.yml`, no en su
página. Cada paso lleva el slug de la ficha y una frase que dice por qué va en
ese lugar; el título y el enlace salen de la propia ficha. Para cambiar el orden
se mueve un paso; para añadir una ficha, una línea `- ficha:` con su `porque:`.
Escriba `id` y `ficha` sin comillas: el validador rechaza otras formas.

Un recorrido nuevo necesita además una página con el nombre de su `id`, que
reserve el sitio con un bloque `::: {.recorrido recorrido="<id>"}` cerrado con
`:::`, y un enlace desde la portada. Si una ficha no existe o un paso no tiene
`porque`, el sitio no se genera.

## Guía de uso

Los pasos de la guía «Cómo se usa» se escriben en `guia.yml`, en dos partes: la
de la portada (dónde buscar), que termina llevando a una ficha al azar de
«Empieza aquí», y la de las fichas (cómo se lee una ficha). Cada paso lleva
`titulo`, `texto` y, si señala algo de la página, un `destino` entre comillas
con la forma `"#id"` o `".clase"`. El validador comprueba que ese destino existe
en la portada o en cada una de las fichas; si al cambiar una plantilla o una
sección desaparece, la validación falla. La guía no se abre sola: se abre con el
icono de interrogación de la barra o con `?tour=1` al final de la dirección.

## Citas y bibliografía

Use `[@citekey]` en la ficha y añada la referencia completa a
`references.bib`. Priorice DOI, PMID o una URL institucional estable. No
cambie ni elimine un citekey existente sin comprobar todas sus citas y
verificar la referencia.

Las referencias provisionales deben declararse como tales en sus notas. La
integración futura con Zotero y Better BibTeX se evaluará por separado; no es
un requisito para una corrección sencilla.

Cuando se aporte una referencia nueva, se comprueba primero la fuente original
y su relevancia editorial. Si añade evidencia o un ejemplo importante, se
incorpora a `references.bib` con un citekey estable y se cita desde el término
existente que mejor la contextualice; puede enlazarse desde más de una ficha
solo si respalda afirmaciones materiales diferentes. Una referencia aislada no
obliga a crear un término nuevo ni a modificar una ficha si no aporta contenido
sustantivo. Toda ficha modificada actualiza su `date-modified`.

## Validación

En PowerShell:

```powershell
quarto render
.\validar.ps1
```

El validador comprueba el esquema de metadatos, la taxonomía, fechas,
sinónimos renderizados, término inglés, búsqueda en PubMed (con el filtro
literal), citekeys, enlaces internos, slugs, aliases, recorridos y artefactos
del documento de trabajo. Un cambio no está listo si alguna
comprobación falla.

Una vez activada la publicación, los cambios aceptados en `main` generarán el
sitio mediante GitHub Actions. La activación inicial de Pages requiere una
decisión humana independiente.

# Informe del piloto — Glosario IA

Fecha de cierre técnico: 2026-07-24  
Checkpoint: CP2  
Constructor: Codex  
Dirección y revisión: Claude  
Decisión GO/NO-GO: Ernesto

## Resumen ejecutivo

El piloto demuestra que **Quarto website** resuelve bien la publicación del
glosario: 13 fichas estructuradas, índices derivados del frontmatter, búsqueda
en español, redirects, bibliografía, diseño móvil y validación determinista.
El render completo y el validador pasan en limpio.

Sin embargo, se ha reproducido un **criterio de corte previsto en el acta**:
el editor visual oficial de Quarto queda en blanco en VS Code sobre Windows.
El fallo se reproduce tanto con una ficha del piloto y el proyecto abierto
correctamente como con un QMD mínimo independiente. El modo fuente, el CLI y
el render funcionan; `quarto check` declara correcta la instalación.

Por tanto, mi recomendación técnica es:

- **GO para el modelo de publicación** (website, fichas, listings, búsqueda,
  redirects y validación).
- **NO-GO provisional para migrar todo el glosario con el flujo editorial
  acordado**, mientras el editor visual en VS Code sea un requisito.
- No se cambia de stack en este piloto. Corresponde a Ernesto decidir si se
  investiga/corrige la compatibilidad de VS Code o si se activa la comparación
  acotada con MyST prevista en el acta.

## Alcance construido

Se han migrado 13 conceptos:

1. Agente de IA (incluye IA agéntica)
2. Inteligencia artificial general (AGI)
3. Alucinación
4. Aprendizaje automático
5. Aprendizaje profundo
6. Explicabilidad
7. Inteligencia artificial generativa
8. Modelo de lenguaje grande (LLM)
9. Model Context Protocol (MCP)
10. Procesamiento del lenguaje natural
11. Generación aumentada por recuperación (RAG)
12. Sesgo algorítmico
13. Transformer

No se ha creado ninguna ficha de herramienta, producto u organización.

El proyecto incluye:

- website Quarto, no book;
- portada con tarjetas;
- índice A–Z canónico como tabla de dos columnas, filtro y una sola página;
- índice temático por categorías;
- búsqueda global;
- una ficha por término;
- sinónimos visibles e indexables generados desde frontmatter;
- redirects estáticos mediante `aliases`;
- bibliografía BibTeX y CSL Vancouver;
- taxonomía controlada;
- validador PowerShell determinista;
- configuración canónica del Markdown;
- disclaimer global y en portada.

## Convención editorial aplicada

Las claves interpretadas por Quarto conservan su nombre:

```yaml
title:
description:
categories:
aliases:
date-modified:
```

Las claves propias quedan en español y sin tildes:

```yaml
sinonimos:
estado: borrador | revisada
tipo: concepto | herramienta | tecnica | organizacion
```

Reglas adicionales:

- `aliases` contiene solo rutas de redirect terminadas en `.html`;
- el slug deriva del nombre del archivo;
- `date-modified` es la fecha real de revisión del contenido y no puede estar
  en el futuro;
- cada ficha tiene entre una y tres categorías controladas;
- «Aplicaciones sanitarias» se reserva a términos específicamente sanitarios;
- todas las fichas comparten las mismas secciones y enlazan sus relacionados.

La adenda de CP1 quedó aplicada por completo: se eliminaron `slug`,
`also-known-as` y `status`; se añadieron `sinonimos`, `estado` y `tipo`; el
índice A–Z pasó a tabla densa; y se incorporaron los dos disclaimers literales.

## Bibliografía

`references.bib` contiene 16 entradas provisionales, todas marcadas como tales,
porque no se facilitó un export Better BibTeX de Zotero. Se resolvieron por
DOI, PubMed o fuente primaria.

Ocho entradas incluyen PMID verificado:

- Lee et al., *Benefits, Limits, and Risks of GPT-4 as an AI Chatbot for
  Medicine* — PMID 36988602.
- Topol, *High-performance medicine* — PMID 30617339.
- LeCun, Bengio y Hinton, *Deep learning* — PMID 26017442.
- Esteva et al., *Dermatologist-level classification of skin cancer* — PMID
  28117445.
- Amann et al., *Explainability for artificial intelligence in healthcare* —
  PMID 33256715.
- Singhal et al., *Large language models encode clinical knowledge* — PMID
  37438534.
- Wu et al., *Deep learning in clinical natural language processing* — PMID
  31794016.
- Obermeyer et al., *Dissecting racial bias in an algorithm used to manage the
  health of populations* — PMID 31649194.

Zotero no estaba ejecutándose y no se encontró el directorio de datos local
predeterminado. No se modificó Zotero. La inserción desde Zotero no pudo
evaluarse porque el editor visual falla antes de abrir el selector de citas.

## Checklist de verificación

| Prueba | Resultado | Evidencia |
|---|---|---|
| Render completo | **Pasa** | Quarto renderiza 16/16 entradas y crea `_site/index.html`. |
| Validador determinista | **Pasa** | 13 fichas, 16 citekeys, 13 slugs, 19 aliases; sinónimos, fechas, taxonomía, secciones y enlaces correctos. |
| Redirect de IA agéntica | **Pasa** | `/terminos/ia-agentica.html` se genera y redirige a `agente-de-ia.html`. |
| Sinónimos buscables | **Pasa** | `Agentic AI` aparece en `search.json` y devuelve «Agente de IA». |
| Búsqueda sin tilde | **Pasa** | `alucinacion` devuelve «Alucinación» como primer resultado; la consulta con tilde produce el mismo primer resultado. |
| Ciclo editar→refresco | **Pasa** | Una edición de ficha existente se reflejó en 3,42 s; su reversión, en 3,54 s. |
| Alta de término nuevo | **Pasa con fricción** | Rama creada 09:23:15 y commit completo 09:25:38: 2 min 23 s. Render tras reinicio: 14,24 s. |
| Descubrimiento de archivo nuevo | **Fricción** | El preview abierto no descubrió una ficha nueva tras 30,07 s; fue necesario reiniciar el preview o renderizar todo. |
| Editor visual VS Code | **Falla — criterio de corte** | El comando oficial abre un panel vacío, reproducido con la ficha AGI y con un QMD mínimo. |
| Inserción de cita y diff visual | **No evaluable** | No se puede editar ni abrir el selector de citas en el panel vacío. |
| Móvil y accesibilidad | **Pasa objetivo** | Lighthouse móvil: portada 95 y A–Z 96 en accesibilidad. |
| pa11y complementario | **Deuda menor** | 16 errores en portada y 4 en A–Z, concentrados en controles/ARIA y contraste generados por el tema. |
| Contribución externa simulada | **Pasa en variante local** | Rama `prueba/contribucion-glosario`, commit `b604241`; un archivo, 47 líneas, sin remoto. |
| Rollback | **Pasa exacto** | Rama `prueba/rollback-glosario`; commit `25ba87f`, revert `3e000c7`; fuente y HTML recuperan los hashes previos. |
| Líneas rojas | **Pasa** | Sin push, Pages, PDF/EPUB, repos remotos, cambios en Docs/Zotero/sitio público, skills ni subagentes. |

## Evidencia del validador

```text
VALIDACION CORRECTA
  Fichas: 13
  Citekeys: 16
  Slugs derivados y unicos: 13
  Aliases unicos y generados: 19
  Sinonimos renderizados e indexados: OK
  Fechas, taxonomia, enlaces y secciones: OK
```

El script comprueba:

- frontmatter obligatorio;
- ausencia de campos obsoletos;
- filename/slug canónico y único;
- salida HTML canónica;
- categorías, estado y tipo dentro de `taxonomia.yml`;
- fechas válidas y no futuras;
- redirects generados, únicos y sin colisiones;
- secciones obligatorias y en orden;
- ausencia de artefactos del export;
- citekeys citados existentes;
- enlaces internos válidos;
- igualdad entre `sinonimos` y la línea renderizada;
- presencia de cada sinónimo en `search.json`;
- rango de 12 a 15 fichas.

## Prueba del editor visual: criterio de corte

Entorno:

- Windows;
- VS Code 1.130.0;
- extensión oficial `quarto.quarto` 1.135.0;
- Quarto 1.9.38;
- Pandoc 3.8.3;
- Chrome 150.0.7871.129.

Procedimiento:

1. Se abrió la raíz `glosario-ia-piloto` en una instancia aislada de VS Code.
2. La extensión oficial se activó y detectó Quarto 1.9.38.
3. La ficha AGI se abrió correctamente en modo fuente.
4. Se ejecutó `Quarto: Edit in Visual Mode`.
5. Tras 15 s, el área de edición seguía totalmente vacía.
6. Se repitió el ensayo con un QMD mínimo independiente y ocurrió lo mismo.
7. `quarto check` informó instalación y render básico correctos.

Antes del ensayo se añadió temporalmente:

```diff
+editor: visual
```

Guardar desde el modo fuente no produjo reformateo adicional. No existe un
diff atribuible al editor visual porque este nunca llegó a cargar; el campo
temporal se retiró y el árbol quedó limpio.

El síntoma es compatible con incidencias previas del editor de VS Code, por
ejemplo [quarto-dev/quarto#325](https://github.com/quarto-dev/quarto/issues/325),
pero este piloto no diagnostica todavía la causa raíz.

Conclusión: el editor visual es **inusable en este entorno concreto**. Se activa
el criterio de corte definido en el acta. No se ha cambiado de stack.

## Accesibilidad y móvil

Lighthouse en viewport móvil:

- portada: 95/100;
- índice A–Z: 96/100.

La tabla A–Z de dos columnas no provoca desbordamiento horizontal. El objetivo
≥90 se cumple.

pa11y se ejecutó como comprobación complementaria y detectó deuda técnica en
elementos generados por Quarto/Bootstrap:

- foco dentro de contenedores `aria-hidden`;
- estructura ARIA del botón de navegación;
- contraste del selector de orden;
- orden de encabezados en portada.

No se corrigió esta deuda porque requeriría intervenir en salida o componentes
generados y no impide cumplir el umbral acordado. Debe reexaminarse antes de
publicar.

## Contribución externa simulada

Se usó la variante local permitida por el encargo, sin tocar el remoto:

- rama: `prueba/contribucion-glosario`;
- commit: `b604241 Añade una ficha mediante contribución simulada`;
- diff contra `master`: una ficha nueva, 47 líneas;
- validador con la ficha temporal: 14 fichas, resultado correcto.

La prueba demuestra que una contribución aislada puede revisarse como un PR.
No se abrió un PR real ni se usó el editor web de GitHub porque las líneas
rojas prohíben acciones remotas sin autorización.

## Rollback

Se creó la rama local `prueba/rollback-glosario`:

1. `25ba87f Añade un marcador temporal de rollback`.
2. Render correcto en 15,75 s.
3. `3e000c7 Revert "Añade un marcador temporal de rollback"`.
4. Nuevo render correcto en 13,61 s.
5. Validador correcto.

Comparación:

```text
index.qmd antes/después:
D29D6259A7662B2D2FFA972A9B05A5E78F88719F7E6A98573B086A5DEE96C1CA

_site/index.html antes/después:
9726AAE7F8169F50126993864D4CAB774C9BFBB88B3A1BCCF5916B8A490D2179
```

Los dos hashes coinciden exactamente.

## Fricciones observadas

1. **Editor visual bloqueante.** Es la única fricción que activa un criterio de
   corte y deja sin probar la inserción visual de citas/Zotero.
2. **Archivos nuevos no detectados por el preview.** Las ediciones de ficheros
   existentes refrescan rápido, pero una ficha nueva exige reiniciar o lanzar
   un render completo.
3. **Accesibilidad generada.** Lighthouse cumple; pa11y revela deuda en
   componentes del tema.
4. **Bibliografía aún provisional.** Antes de publicación debe sustituirse por
   una colección Zotero/Better BibTeX con citekeys estables.
5. **Curación mayor que infraestructura.** La plataforma ya automatiza índices
   y validaciones; la revisión conceptual y bibliográfica seguirá siendo el
   coste principal.

## Mejoras de claridad propuestas, no implementadas

Siguiendo la directriz de proponer antes de ampliar:

1. Añadir solo cuando aporte valor una breve subsección editorial «Qué no
   significa», para conceptos que se confunden con términos próximos.
2. Explicar en una página editorial qué significan `borrador`, `revisada` y
   `date-modified`; no cargar cada ficha con esa explicación.
3. Para futuros términos específicamente sanitarios, añadir una fecha de
   revisión bibliográfica separada de la revisión de estilo.
4. Antes de publicar, valorar un enlace único «Sugerir una corrección» hacia
   una plantilla de issue; no se ha creado porque implicaría definir el flujo
   remoto.

## Preguntas para Claude y Ernesto

1. ¿Es el editor visual en VS Code un requisito duro para el GO? Si lo es, el
   resultado del piloto es NO-GO provisional.
2. ¿Se dedica una prueba corta a aislar la incompatibilidad
   VS Code/extensión/Quarto o se pasa directamente al micro-piloto MyST
   previsto como plan B?
3. Si se acepta edición Markdown en modo fuente, ¿sigue teniendo sentido
   Quarto como plataforma pese a perder la ventaja editorial visual?
4. ¿Qué licencia, nombre/posicionamiento y URL canónica tendrá el recurso?
5. ¿Debe el glosario posicionarse como general con contexto sanitario o como
   glosario de IA para profesionales sanitarios?
6. ¿Cuándo se sustituye la bibliografía provisional por la colección Zotero
   dedicada y quién custodia sus citekeys?

## Estado final y reversibilidad

`master` contendrá siete commits locales del piloto, incluido este informe, y
quedará siete commits por delante de `origin/master`. No se ha hecho push.

Quedan dos ramas locales de evidencia:

- `prueba/contribucion-glosario`;
- `prueba/rollback-glosario`.

El piloto sigue siendo reversible: toda la implementación está contenida en
`glosario-ia-piloto/`, salvo esas ramas y los commits locales del mismo repo.
No se ha publicado nada.

## Adenda de preparación para CP3 — 24 de julio de 2026

Claude y Ernesto resolvieron el criterio de corte del editor visual: el modo
fuente Markdown queda como vía canónica y Quarto continúa como plataforma. El
contenido público se ha preparado como copia limpia, separada del documento de
trabajo completo y sin los directorios `fuente/`, `_site/` ni `.quarto/`.

Antes del push fundacional se aplicaron estos cambios:

- corrección de la comprobación determinista de artefactos en `validar.ps1` y
  prueba negativa reproducible;
- portada con jerarquía de encabezados controlada desde una plantilla de
  listing propia;
- identidad, URL canónica y enlaces de edición/incidencias del repositorio;
- licencia CC BY 4.0 para el contenido original, gobernanza editorial,
  instrucciones de edición y plantillas de incidencias;
- workflow de GitHub Pages fijado a Quarto 1.9.38.

La verificación final de la copia pública obtuvo:

- Lighthouse accesibilidad: 100/100 en portada y 100/100 en A–Z;
- pa11y con axe/WCAG 2 AA: un aviso `landmark-unique` en la navegación de la
  portada y una incidencia `color-contrast` «needs further review» en el
  selector nativo de A–Z;
- comprobación móvil a 390 px: ancho total 390 px, sin desplazamiento
  horizontal, tabla de 339 px y las 13 fichas visibles.

La deuda restante procede de componentes generados por Bootstrap/Quarto. En el
selector de A–Z se comprobó manualmente el estilo calculado: texto `#18343d`
sobre blanco, por lo que la incidencia de axe es compatible con la
indeterminación del estilo nativo del control. No se parchea el HTML generado,
porque desaparecería en el siguiente render y dificultaría el mantenimiento.

GitHub Pages no se activa en esta fase. El workflow puede compilar el sitio,
pero su despliegue debe permanecer bloqueado hasta el OK humano de CP3.

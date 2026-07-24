# Glosario de IA para profesionales sanitarios

Glosario web de conceptos de inteligencia artificial explicado para
profesionales sanitarios, con aplicaciones, limitaciones, ejemplos,
relaciones y referencias verificables.

## Estado

El proyecto está en fase de prototipo editorial. Solo contiene fichas
seleccionadas y revisadas de forma incremental; una ficha marcada como
`borrador` no equivale a contenido validado ni a recomendación profesional.
El sitio público se activará después de superar su revisión previa.

El repositorio no contiene el documento de trabajo completo ni borradores
pendientes de curación. El contenido nuevo entra únicamente después de una
revisión editorial y bibliográfica mínima.

## Consultar y citar

La dirección prevista del sitio es:

<https://ernestobarrera.github.io/glosario-ia/>

Cita sugerida:

> Barrera E. *Glosario de IA para profesionales sanitarios*. 2026. Disponible
> en: https://ernestobarrera.github.io/glosario-ia/ (consulta: fecha de
> acceso).

Cada ficha muestra su fecha de última revisión de contenido. Las referencias
bibliográficas se identifican con citekeys estables en `references.bib`.

## Contribuir

Puede proponer un término o comunicar un error mediante las plantillas de
incidencias del repositorio. Para editar una ficha, consulte
[COMO-EDITAR.md](COMO-EDITAR.md). Los criterios de revisión y el contrato de
trabajo humano-agente están en [EDITORIAL.md](EDITORIAL.md).

Antes de proponer un cambio:

1. Mantenga el esquema y las secciones de la ficha.
2. Aporte una fuente primaria o institucional cuando la afirmación lo
   requiera.
3. Ejecute `.\validar.ps1` y compruebe que el sitio se renderiza con Quarto.
4. No añada material clínico identificable, exportaciones de trabajo ni
   contenido de terceros sin permiso.

## Tecnología

El sitio es un proyecto Quarto de tipo `website`. Los índices A–Z y temático
se generan desde los metadatos de las fichas. La búsqueda, los sinónimos y las
relaciones internas se verifican antes de publicar.

## Licencia

Los textos originales se ofrecen bajo
[Creative Commons Atribución 4.0 Internacional](LICENSE). Las obras citadas,
marcas y materiales de terceros conservan sus propios derechos.

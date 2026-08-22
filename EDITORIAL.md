# Política editorial

## Propósito y alcance

El glosario explica conceptos de inteligencia artificial para profesionales
sanitarios sin convertirlos en recomendaciones clínicas. Busca claridad,
utilidad práctica y trazabilidad de las fuentes.

Solo se publica contenido curado. Los documentos de trabajo, exportaciones
completas y fichas aún no verificadas permanecen fuera de este repositorio.

## Revisión incremental

Cada ficha avanza de forma independiente:

- `borrador`: estructura completa y fuentes iniciales, pendiente de revisión;
- `revisada`: contenido y bibliografía examinados por una persona;
- `date-modified`: fecha real de la última revisión de contenido.

La etiqueta `revisada` no garantiza vigencia indefinida. Las herramientas,
técnicas y organizaciones pueden necesitar ciclos de revisión más breves que
los conceptos.

## Fuentes

1. Las afirmaciones técnicas o sanitarias relevantes deben enlazar una fuente
   primaria, una revisión solvente o una institución reconocida.
2. Las referencias bibliográficas se verifican por DOI, PubMed o la fuente
   original antes de consolidarlas.
3. No se inventan referencias ni se usa una cita que no respalde la
   afirmación asociada.
4. No se cambia, reutiliza ni elimina un citekey sin verificar sus apariciones
   y la identidad bibliográfica.
5. Toda ficha incluye una subsección de aplicaciones sanitarias. El ángulo
   sanitario no es una categoría que se asigna a unos pocos términos: es una
   obligación de todas las fichas.

## Contrato humano-agente

El trabajo puede repartirse entre asistentes de IA, con estas reglas:

1. Una persona define el encargo, decide en los checkpoints y aprueba la
   publicación.
2. Un único constructor modifica un archivo o una unidad de trabajo cada vez.
3. Un segundo agente puede revisar, tensionar o reproducir las pruebas, pero
   no edita en paralelo los mismos archivos.
4. Todo contenido generado por IA queda sujeto a revisión humana, validación
   determinista y comprobación de fuentes.
5. Los agentes se detienen ante un cambio de alcance, licencia, plataforma,
   publicación o datos sensibles.
6. Las propuestas de radar bibliográfico son entradas para revisión: nunca se
   incorporan automáticamente al glosario.

## Criterios de una ficha

Una ficha debe:

- usar el frontmatter y la taxonomía controlada del proyecto;
- ofrecer una definición breve y otra ampliada coherentes;
- separar aplicaciones, limitaciones y ejemplos;
- enlazar términos relacionados existentes;
- distinguir hechos, ejemplos e incertidumbres;
- evitar lenguaje promocional y afirmaciones clínicas no respaldadas;
- pasar `validar.ps1` y el render de Quarto.

## Flujo de cambios

1. Se propone un término o error mediante una incidencia.
2. Se crea una rama con una única unidad editorial.
3. El constructor edita, verifica las fuentes y ejecuta las pruebas.
4. Otra persona o agente revisa el diff.
5. La persona responsable decide si fusionar.
6. La publicación automática solo ocurre después del gate humano y de tener
   GitHub Pages expresamente habilitado.

## Licencia y atribución

Los textos originales se publican bajo CC BY 4.0. Las obras citadas conservan
sus derechos y se usan con atribución y dentro de los límites legales
aplicables. No se copian tablas, figuras ni fragmentos extensos de terceros
sin una licencia o permiso compatible.

## Mantenimiento futuro

Quedan fuera de la publicación fundacional y requieren una decisión posterior:

- evaluar Zotero y Better BibTeX solo si el flujo puede automatizarse sin
  regenerar los citekeys existentes;
- migrar por lotes nuevas fichas ya revisadas;
- enlazar el recurso desde el sitio principal;
- formalizar un radar editorial y bibliográfico.

Ninguno de estos flujos puede publicar o modificar referencias de forma
automática.

-- Búsqueda en PubMed al pie de cada ficha.
--
-- Por que existe: casi toda la literatura clinica sobre IA esta en ingles, y
-- quien lee «Sobreajuste» tiene que buscar «overfitting». Este filtro le deja
-- la busqueda hecha, con dos piezas:
--
--   - la DINAMICA, de la ficha: su termino ingles (`ingles`) en titulo o
--     resumen y, si lo tiene, su descriptor MeSH verificado (`mesh`);
--   - la ESTATICA, comun a todas: un filtro de pubmed-filters que acota al
--     dominio de la IA. No vive aqui: herramientas/filtro_pubmed.py lo lee de
--     su repositorio antes de cada render y lo deja en pubmed-filtro.txt, asi
--     que si el filtro mejora, las 149 busquedas mejoran con el.
--
-- La composicion sigue el contrato de pubmed-filters (scripts/parse-filter.mjs,
-- compose): «(tema) AND (filtro)», o «(tema) NOT ...» si el filtro es de
-- exclusion. Componerlo con AND por defecto devolveria justo lo excluido.
--
-- Las fichas listadas en pubmed-sin-resultados.txt llevan el bloque oculto: un
-- enlace que lleva a «No results» enseña a ignorar todos los demas. El bloque se
-- emite igual, oculto, para que herramientas/comprobar_pubmed.py pueda volver a
-- medir esa busqueda y devolverla cuando ya tenga resultados.

local INSTANTANEA = "pubmed-filtro.txt"
local SIN_RESULTADOS = "pubmed-sin-resultados.txt"

local function raizProyecto()
  if quarto and quarto.project and quarto.project.directory then
    return quarto.project.directory
  end
  return "."
end

-- Igual que atlas.lua: Quarto pasa a pandoc una copia temporal, y el slug real
-- solo se conserva en el nombre del archivo de salida.
local function slugDeSalida()
  if not PANDOC_STATE or not PANDOC_STATE.output_file then
    return nil
  end
  return PANDOC_STATE.output_file:match("([^\\/]+)%.html$")
end

local function leerLineas(ruta)
  local archivo = io.open(ruta, "r")
  if not archivo then
    return nil
  end
  local lineas = {}
  for linea in archivo:lines() do
    table.insert(lineas, (linea:gsub("\r$", "")))
  end
  archivo:close()
  return lineas
end

-- La consulta es la unica linea que no es comentario.
local function consultaDelFiltro(raiz)
  local lineas = leerLineas(raiz .. "/" .. INSTANTANEA)
  if not lineas then
    return nil, nil
  end
  local consulta, fuente = nil, nil
  for _, linea in ipairs(lineas) do
    local f = linea:match("^#%s*Fuente:%s*(%S+)")
    if f then
      fuente = f
    elseif linea ~= "" and not linea:match("^#") then
      consulta = linea
    end
  end
  return consulta, fuente
end

local function fichasSinResultados(raiz)
  local conjunto = {}
  for _, linea in ipairs(leerLineas(raiz .. "/" .. SIN_RESULTADOS) or {}) do
    local slug = linea:match("^%s*([%w%-]+)%s*$")
    if slug then
      conjunto[slug] = true
    end
  end
  return conjunto
end

-- Termino en titulo o resumen. Truncado al final para recoger plurales
-- («large language model*»), salvo en siglas y nombres con mayusculas internas
-- (ReAct, AutoML: truncar «react*» traeria «reaction») y en palabras cortas. Una
-- forma en plural se recorta a su raiz: «Reward models» -> «Reward model*».
local function enTituloOResumen(termino)
  local ultima = termino:match("(%S+)$") or termino
  local _, mayusculas = ultima:gsub("%u", "")
  local letras = ultima:gsub("[^%a]", "")
  if mayusculas >= 2 or #letras < 4 then
    return '"' .. termino .. '"[tiab]'
  end
  local raiz = termino
  if ultima:match("s$") and not ultima:match("[siuao]s$") then
    raiz = termino:sub(1, -2)
  end
  return '"' .. raiz .. '*"[tiab]'
end

local function componer(tema, filtro)
  if filtro:match("^%s*[Nn][Oo][Tt]%s") then
    return "(" .. tema .. ") " .. filtro
  end
  return "(" .. tema .. ") AND (" .. filtro .. ")"
end

local function codificar(texto)
  return (texto:gsub("[^%w%-%._~]", function(c)
    return string.format("%%%02X", string.byte(c))
  end))
end

-- «desde 2022» sale del propio filtro, no de este archivo: si el filtro cambia
-- su ventana temporal, la nota no puede quedarse diciendo otra cosa.
local function anioDeCorte(filtro)
  return filtro:match('"(%d%d%d%d)/%d%d/%d%d"%s*%[[Pp][Dd][Aa][Tt]%]')
end

function Pandoc(doc)
  local meta = doc.meta
  if not meta.ingles then
    return doc
  end

  local raiz = raizProyecto()
  local slug = slugDeSalida()
  local filtro, fuente = consultaDelFiltro(raiz)
  if not filtro then
    error("pubmed.lua: falta " .. INSTANTANEA .. "; ejecuta herramientas/filtro_pubmed.py")
  end

  local ingles = pandoc.utils.stringify(meta.ingles)
  local mesh = meta.mesh and pandoc.utils.stringify(meta.mesh) or "ninguno"
  local tema = enTituloOResumen(ingles)
  if mesh ~= "ninguno" then
    tema = tema .. ' OR "' .. mesh .. '"[Mesh]'
  end
  local consulta = componer(tema, filtro)
  local enlace = "https://pubmed.ncbi.nlm.nih.gov/?term=" .. codificar(consulta)

  local cfg = meta["busqueda-pubmed"] or {}
  local nombre = cfg.nombre and pandoc.utils.stringify(cfg.nombre) or "filtro de IA"

  local termino = pandoc.Span({ pandoc.Str(ingles) }, pandoc.Attr("", { "ingles-termino" }, { lang = "en" }))
  local principal = pandoc.Para({
    pandoc.Strong({ pandoc.Str("En PubMed:") }),
    pandoc.Space(),
    pandoc.Link(
      { pandoc.Str("Buscar"), pandoc.Space(), termino, pandoc.Space(), pandoc.Str("en"), pandoc.Space(), pandoc.Str("PubMed") },
      enlace, "", pandoc.Attr("", { "busqueda-pubmed-enlace" })
    )
  })

  local nota = {
    pandoc.Str("Búsqueda abierta y no revisada: el término en título o resumen"),
  }
  if mesh ~= "ninguno" then
    table.insert(nota, pandoc.Str(", o el descriptor MeSH «" .. mesh .. "»,"))
  end
  table.insert(nota, pandoc.Space())
  table.insert(nota, pandoc.Str("acotado con el"))
  table.insert(nota, pandoc.Space())
  local textoFiltro = { pandoc.Str(nombre) }
  if fuente then
    table.insert(nota, pandoc.Link(textoFiltro, fuente))
  else
    table.insert(nota, pandoc.Span(textoFiltro))
  end
  table.insert(nota, pandoc.Space())
  table.insert(nota, pandoc.Str("de pubmed-filters"))
  local anio = anioDeCorte(filtro)
  if anio then
    table.insert(nota, pandoc.Str(" (publicaciones desde " .. anio .. ")"))
  end
  table.insert(nota, pandoc.Str(". Puede omitir trabajos relevantes."))

  local atributos = { ["data-consulta"] = consulta }
  if slug and fichasSinResultados(raiz)[slug] then
    atributos.hidden = ""
  end

  local bloque = pandoc.Div({
    principal,
    pandoc.Div({ pandoc.Para(nota) }, pandoc.Attr("", { "busqueda-pubmed-nota" }))
  }, pandoc.Attr("", { "busqueda-pubmed" }, atributos))

  -- Justo despues de la bibliografia; si no la hubiera, al final.
  for indice, bloqueDoc in ipairs(doc.blocks) do
    if bloqueDoc.t == "Div" and bloqueDoc.identifier == "refs" then
      table.insert(doc.blocks, indice + 1, bloque)
      return doc
    end
  end
  table.insert(doc.blocks, bloque)
  return doc
end

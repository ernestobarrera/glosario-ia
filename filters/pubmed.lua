-- Búsqueda en PubMed al pie de cada ficha.
--
-- Por que existe: casi toda la literatura clinica sobre IA esta en ingles, y
-- quien lee «Sobreajuste» tiene que buscar «overfitting». Este filtro le deja
-- la busqueda hecha, con dos piezas:
--
--   - la DINAMICA, de la ficha: su termino ingles (`ingles`) en titulo o
--     resumen y, si lo tiene, su descriptor MeSH verificado (`mesh`);
--   - la ESTATICA, comun: un filtro de pubmed-filters que acota al dominio de
--     la IA. No vive aqui: herramientas/filtro_pubmed.py lo lee de su
--     repositorio antes de cada render y lo deja en pubmed-filtro-<clave>.txt,
--     asi que si el filtro mejora, las busquedas mejoran con el.
--
-- Dos rutas de filtro, registradas en pubmed-rutas.txt por
-- herramientas/comprobar_pubmed.py:
--
--   - especifico, por defecto;
--   - sensible, en las fichas en las que el especifico no devuelve nada: ahi el
--     riesgo es el falso negativo, y vale mas un poco de ruido que ningun
--     resultado;
--   - oculta, si tampoco el sensible devuelve nada: un enlace que lleva a «No
--     results» ensena a ignorar todos los demas.
--
-- El bloque lleva SIEMPRE las dos consultas en data-consulta-<clave>, tambien
-- cuando va oculto: la herramienta las mide tal como quedaron aqui, sin
-- reconstruirlas, y asi la regla tiene una sola implementacion.
--
-- La composicion sigue el contrato de pubmed-filters (scripts/parse-filter.mjs,
-- compose): «(tema) AND (filtro)», o «(tema) NOT ...» si el filtro es de
-- exclusion. Componerlo con AND por defecto devolveria justo lo excluido.

local RUTAS = "pubmed-rutas.txt"
local POR_DEFECTO = "especifico"
local ALTERNATIVA = "sensible"

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
local function leerFiltro(raiz, clave)
  local lineas = leerLineas(raiz .. "/pubmed-filtro-" .. clave .. ".txt")
  if not lineas then
    error("pubmed.lua: falta pubmed-filtro-" .. clave .. ".txt; ejecuta herramientas/filtro_pubmed.py")
  end
  local filtro = {}
  for _, linea in ipairs(lineas) do
    local fuente = linea:match("^#%s*Fuente:%s*(%S+)")
    if fuente then
      filtro.fuente = fuente
    elseif linea ~= "" and not linea:match("^#") then
      filtro.consulta = linea
    end
  end
  if not filtro.consulta then
    error("pubmed.lua: pubmed-filtro-" .. clave .. ".txt no contiene ninguna consulta")
  end
  return filtro
end

-- «slug ruta  # comentario»; una ficha que no aparece usa la ruta por defecto.
local function rutaDe(raiz, slug)
  for _, linea in ipairs(leerLineas(raiz .. "/" .. RUTAS) or {}) do
    local s, ruta = linea:match("^%s*([%w%-]+)%s+(%a+)")
    if s == slug then
      return ruta
    end
  end
  return POR_DEFECTO
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

local function nombreDe(meta, clave)
  local cfg = meta["busqueda-pubmed"]
  local filtros = cfg and cfg.filtros
  local f = filtros and filtros[clave]
  if f and f.nombre then
    return pandoc.utils.stringify(f.nombre)
  end
  return "filtro " .. clave .. " de IA"
end

function Pandoc(doc)
  local meta = doc.meta
  if not meta.ingles then
    return doc
  end

  local raiz = raizProyecto()
  local slug = slugDeSalida()
  local ruta = slug and rutaDe(raiz, slug) or POR_DEFECTO
  local claveActiva = (ruta == ALTERNATIVA) and ALTERNATIVA or POR_DEFECTO

  local ingles = pandoc.utils.stringify(meta.ingles)
  local mesh = meta.mesh and pandoc.utils.stringify(meta.mesh) or "ninguno"
  local tema = enTituloOResumen(ingles)
  if mesh ~= "ninguno" then
    tema = tema .. ' OR "' .. mesh .. '"[Mesh]'
  end

  local filtros = {
    [POR_DEFECTO] = leerFiltro(raiz, POR_DEFECTO),
    [ALTERNATIVA] = leerFiltro(raiz, ALTERNATIVA)
  }
  local consultas = {}
  for clave, filtro in pairs(filtros) do
    consultas[clave] = componer(tema, filtro.consulta)
  end
  local activo = filtros[claveActiva]
  local enlace = "https://pubmed.ncbi.nlm.nih.gov/?term=" .. codificar(consultas[claveActiva])

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
  local textoFiltro = { pandoc.Str(nombreDe(meta, claveActiva)) }
  if activo.fuente then
    table.insert(nota, pandoc.Link(textoFiltro, activo.fuente))
  else
    table.insert(nota, pandoc.Span(textoFiltro))
  end
  table.insert(nota, pandoc.Space())
  table.insert(nota, pandoc.Str("de pubmed-filters"))
  local anio = anioDeCorte(activo.consulta)
  if anio then
    table.insert(nota, pandoc.Str(" (publicaciones desde " .. anio .. ")"))
  end
  if claveActiva == ALTERNATIVA then
    table.insert(nota, pandoc.Str(". Con el filtro específico no había resultados: el sensible recoge más trabajos, también más ruido."))
  else
    table.insert(nota, pandoc.Str(". Puede omitir trabajos relevantes."))
  end

  local atributos = {
    ["data-ruta"] = ruta,
    ["data-consulta"] = consultas[claveActiva],
    ["data-consulta-" .. POR_DEFECTO] = consultas[POR_DEFECTO],
    ["data-consulta-" .. ALTERNATIVA] = consultas[ALTERNATIVA]
  }
  if ruta == "oculta" then
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

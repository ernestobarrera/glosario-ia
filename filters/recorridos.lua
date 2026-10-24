-- Los recorridos, desde recorridos.yml.
--
-- Por que existe: la lista de cada recorrido vivia escrita a mano en su pagina,
-- con el titulo de cada ficha copiado. El orden y el porque de cada paso son
-- decision editorial y su sitio es recorridos.yml; el titulo y el enlace son de
-- la ficha y se leen de ella, de modo que renombrar una ficha no deja texto viejo.
--
-- Solo actua sobre un bloque que lo pida con el atributo `recorrido`:
--   ::: {.empieza-aqui recorrido="empieza-aqui"}
--   :::
-- Sustituye su contenido por la lista y quita el atributo, asi que la clase del
-- bloque —y con ella su estilo— sigue siendo la que escribe la pagina. Fuera de
-- esos bloques no toca nada.
--
-- Un recorrido o una ficha que no existen, o un paso sin su porque, detienen el
-- render con un error que dice cual: una lista con un hueco callado es peor que
-- no publicar. Se detiene saliendo del proceso, no con error(): Quarto registra
-- el error de un filtro y sigue, escribe la pagina con el hueco y termina bien
-- (medido con Quarto 1.9.38), asi que el CI la habria publicado.
-- validar.ps1 comprueba ademas que cada enlace sale renderizado.

local recorridos = nil
local titulos = {}

local function detener(mensaje)
  io.stderr:write("ERROR (filters/recorridos.lua) " .. mensaje .. "\n")
  os.exit(1)
end

local function raiz()
  if quarto and quarto.project and quarto.project.directory then
    return quarto.project.directory
  end

  return "."
end

-- recorridos.yml se lee como el bloque de metadatos de un documento vacio: asi
-- lo interpreta pandoc con su propio lector de YAML, y cada `porque` llega ya
-- como texto en linea de Markdown, con cursivas si las lleva.
local function leerRecorridos()
  local porId = {}
  local archivo = io.open(raiz() .. "/recorridos.yml", "r")

  if not archivo then
    detener("recorridos.yml: no existe y una pagina pide un recorrido")
  end

  local texto = archivo:read("*a")
  archivo:close()

  local doc = pandoc.read("---\n" .. texto .. "\n---\n", "markdown")

  for _, recorrido in ipairs(doc.meta.recorridos or {}) do
    porId[pandoc.utils.stringify(recorrido.id)] = recorrido
  end

  return porId
end

-- El titulo se lee del frontmatter de la ficha, la misma fuente que usan los
-- listados. Una ficha sin titulo se trata como inexistente.
local function tituloDe(slug)
  if titulos[slug] ~= nil then
    return titulos[slug]
  end

  local ficha = io.open(raiz() .. "/terminos/" .. slug .. ".qmd", "r")

  if not ficha then
    return nil
  end

  local dentro = false
  local titulo = nil

  for linea in ficha:lines() do
    if linea:match("^%-%-%-%s*$") then
      if dentro then
        break
      end
      dentro = true
    elseif dentro then
      titulo = linea:match('^title:%s*"(.-)"%s*$') or linea:match("^title:%s*(.-)%s*$")

      if titulo then
        break
      end
    end
  end

  ficha:close()
  titulos[slug] = titulo
  return titulo
end

local function paso(idRecorrido, datos)
  local slug = pandoc.utils.stringify(datos.ficha)
  local titulo = tituloDe(slug)

  if not titulo then
    detener("recorridos.yml: el recorrido '" .. idRecorrido .. "' enlaza la ficha inexistente '" .. slug .. "'")
  end

  -- Sin porque, el paso saldria como "Titulo: " con los dos puntos colgando.
  if not datos.porque or pandoc.utils.stringify(datos.porque) == "" then
    detener("recorridos.yml: el recorrido '" .. idRecorrido .. "' no dice por que va la ficha '" .. slug .. "'")
  end

  local enLinea = pandoc.Inlines({ pandoc.Link(titulo, "terminos/" .. slug .. ".qmd"), pandoc.Str(":"), pandoc.Space() })
  enLinea:extend(datos.porque or {})

  return { pandoc.Plain(enLinea) }
end

-- La misma forma que produce el Markdown `1.` escrito a mano: decimal y punto.
local function lista(idRecorrido, pasos, desde)
  local elementos = {}

  for _, datos in ipairs(pasos or {}) do
    table.insert(elementos, paso(idRecorrido, datos))
  end

  return pandoc.OrderedList(elementos, pandoc.ListAttributes(desde, "Decimal", "Period")), #elementos
end

function Div(el)
  local id = el.attributes["recorrido"]

  if not id then
    return nil
  end

  recorridos = recorridos or leerRecorridos()
  local recorrido = recorridos[id]

  if not recorrido then
    detener("recorridos.yml: no declara el recorrido '" .. id .. "' que pide la pagina")
  end

  local bloques = {}

  if recorrido.etapas then
    -- Cada etapa abre con su pregunta y la numeracion sigue de una a la otra:
    -- el lector ve un solo recorrido partido en tramos, no varias listas.
    -- El identificador de cada etapa se pone aqui: un encabezado creado por un
    -- filtro no recibe el automatico del lector, y sin el, su ancla sale vacia.
    local siguiente = 1

    for numero, etapa in ipairs(recorrido.etapas) do
      table.insert(bloques, pandoc.Header(3, etapa.pregunta, pandoc.Attr("etapa-" .. numero, { "etapa" })))
      local bloque, cuantos = lista(id, etapa.pasos, siguiente)
      table.insert(bloques, bloque)
      siguiente = siguiente + cuantos
    end
  else
    local bloque = lista(id, recorrido.pasos, 1)
    table.insert(bloques, bloque)
  end

  el.attributes["recorrido"] = nil
  el.content = bloques
  return el
end

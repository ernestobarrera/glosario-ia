-- Distintivos de estado y tipo al principio de la ficha.
--
-- Por que existe: `estado` y `tipo` son campos obligatorios del esquema, pero
-- Quarto no los lleva al HTML, asi que ninguna hoja de estilo puede mostrarlos.
-- Sin este filtro, quien lee una ficha no sabe si esta ante un borrador. La
-- fecha de revision si la emite Quarto, en el bloque de metadatos del titulo.
--
-- Se ejecuta despues de sinonimos.lua y tambien inserta en la posicion 1, de
-- modo que los distintivos quedan por encima de la linea de sinonimos.

local estado = nil
local tipo = nil

function Meta(meta)
  estado = nil
  tipo = nil

  if meta.estado then
    estado = pandoc.utils.stringify(meta.estado)
  end

  if meta.tipo then
    tipo = pandoc.utils.stringify(meta.tipo)
  end

  return meta
end

local function distintivo(texto, clase)
  local clases = { "distintivo" }

  if clase then
    table.insert(clases, clase)
  end

  return pandoc.Span({ pandoc.Str(texto) }, pandoc.Attr("", clases))
end

function Pandoc(doc)
  if not estado and not tipo then
    return doc
  end

  local contenido = {}

  if estado then
    table.insert(contenido, distintivo(estado, "distintivo-" .. estado))
  end

  if tipo then
    if #contenido > 0 then
      table.insert(contenido, pandoc.Space())
    end

    table.insert(contenido, distintivo(tipo))
  end

  local linea = pandoc.Div(
    { pandoc.Plain(contenido) },
    pandoc.Attr("", { "estado-ficha" })
  )

  table.insert(doc.blocks, 1, linea)
  return doc
end

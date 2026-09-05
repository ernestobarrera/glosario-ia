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
local fecha = nil

local MESES = {
  "ene", "feb", "mar", "abr", "may", "jun",
  "jul", "ago", "sep", "oct", "nov", "dic"
}

-- Quarto entrega la fecha ya escrita en castellano ("22 de agosto de 2026"),
-- no en ISO, asi que se abrevia el mes para que quepa en un distintivo. Si el
-- valor no tiene la forma esperada se deja tal cual: mas vale una fecha fea
-- que una fecha inventada.
local ABREVIA = {
  enero = "ene", febrero = "feb", marzo = "mar", abril = "abr",
  mayo = "may", junio = "jun", julio = "jul", agosto = "ago",
  septiembre = "sep", setiembre = "sep", octubre = "oct",
  noviembre = "nov", diciembre = "dic"
}

local function fechaLegible(valor)
  local anio, mes, dia = valor:match("^(%d%d%d%d)-(%d%d)-(%d%d)$")

  if anio then
    return string.format("revisada %d %s %s", tonumber(dia), MESES[tonumber(mes)], anio)
  end

  local diaTexto, mesTexto, anioTexto = valor:match("^(%d+) de (%a+) de (%d%d%d%d)$")

  if diaTexto and ABREVIA[mesTexto:lower()] then
    return string.format("revisada %s %s %s", diaTexto, ABREVIA[mesTexto:lower()], anioTexto)
  end

  return "revisada " .. valor
end

function Meta(meta)
  estado = nil
  tipo = nil
  fecha = nil

  if meta["date-modified"] then
    fecha = fechaLegible(pandoc.utils.stringify(meta["date-modified"]))
  end

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

  -- La fecha viaja aqui porque el bloque de metadatos de Quarto gastaba dos
  -- filetes y una fila entera para una sola linea; el dato importa, el marco no.
  if fecha then
    if #contenido > 0 then
      table.insert(contenido, pandoc.Space())
    end

    table.insert(contenido, distintivo(fecha))
  end

  local linea = pandoc.Div(
    { pandoc.Plain(contenido) },
    pandoc.Attr("", { "estado-ficha" })
  )

  table.insert(doc.blocks, 1, linea)
  return doc
end

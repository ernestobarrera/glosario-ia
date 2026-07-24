local sinonimos = {}

function Meta(meta)
  sinonimos = {}

  if meta.sinonimos then
    for _, sinonimo in ipairs(meta.sinonimos) do
      table.insert(sinonimos, pandoc.utils.stringify(sinonimo))
    end
  end

  return meta
end

function Pandoc(doc)
  if #sinonimos == 0 then
    return doc
  end

  local contenido = {
    pandoc.Strong({ pandoc.Str("Sinónimos:") }),
    pandoc.Space()
  }

  for indice, sinonimo in ipairs(sinonimos) do
    if indice > 1 then
      table.insert(contenido, pandoc.Space())
      table.insert(contenido, pandoc.Str("·"))
      table.insert(contenido, pandoc.Space())
    end

    table.insert(contenido, pandoc.Str(sinonimo))
  end

  local linea = pandoc.Div(
    { pandoc.Para(contenido) },
    pandoc.Attr("", { "sinonimos" })
  )

  table.insert(doc.blocks, 1, linea)
  return doc
end

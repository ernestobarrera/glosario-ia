-- Linea de sinonimos y termino ingles de la ficha.
--
-- `ingles` no es un termino nuevo: SENALA cual de los ya declarados (el titulo
-- o uno de `sinonimos`) es la forma inglesa que trae la literatura. Se compara
-- sin distinguir mayusculas, para que `ingles` lleve la grafia de diccionario
-- («overfitting») aunque el sinonimo se escriba como entrada («Overfitting»).
-- Por eso el buscador, el indice A-Z y el control de colisiones no cambian:
-- siguen leyendo `sinonimos`.
--
-- Donde se ve:
--   - bajo el titulo, en la ranura de subtitulo del title block: «ingl.» y el
--     termino en cursiva, con lang="en" para que un lector de pantalla lo
--     pronuncie en ingles. Si el titulo ya es el termino ingles, no se pinta;
--   - en la linea de sinonimos, NO: un equivalente en otra lengua no es un
--     sinonimo, y ya se lee arriba.
--
-- Pero el subtitulo NO entra en search.json. Si el termino ingles saliera de la
-- linea de sinonimos, el buscador dejaria de encontrar la ficha por el. Se queda
-- en el HTML, dentro de .sinonimo-ingles, que styles.css oculta: indexado,
-- comprobado por validar.ps1 y sin leerse dos veces. Si era el unico sinonimo,
-- la linea entera lleva data-solo-ingles y se oculta.

local sinonimos = {}
local inglesSinonimo = nil

local function iguales(a, b)
  return a ~= nil and b ~= nil and a:lower() == b:lower()
end

function Meta(meta)
  sinonimos = {}
  inglesSinonimo = nil

  local titulo = meta.title and pandoc.utils.stringify(meta.title) or ""
  local ingles = meta.ingles and pandoc.utils.stringify(meta.ingles) or nil

  if meta.sinonimos then
    for _, sinonimo in ipairs(meta.sinonimos) do
      local texto = pandoc.utils.stringify(sinonimo)
      table.insert(sinonimos, texto)
      if not inglesSinonimo and iguales(texto, ingles) and not iguales(titulo, ingles) then
        inglesSinonimo = texto
      end
    end
  end

  if ingles and not iguales(titulo, ingles) then
    meta.subtitle = pandoc.Inlines({
      pandoc.Span({ pandoc.Str("ingl.") }, pandoc.Attr("", { "ingles-etiqueta" })),
      pandoc.Space(),
      pandoc.Span({ pandoc.Str(ingles) }, pandoc.Attr("", { "ingles-termino" }, { lang = "en" }))
    })
  end

  return meta
end

local function separador()
  return { pandoc.Space(), pandoc.Str("·"), pandoc.Space() }
end

function Pandoc(doc)
  if #sinonimos == 0 then
    return doc
  end

  local contenido = {
    pandoc.Strong({ pandoc.Str("Sinónimos:") }),
    pandoc.Space()
  }
  local visibles = 0

  for indice, sinonimo in ipairs(sinonimos) do
    local esIngles = (sinonimo == inglesSinonimo)
    local trozo = {}

    -- El separador viaja con el termino oculto para que no queden dos «·»
    -- seguidos: delante si no es el primero; detras si lo es y hay mas.
    if indice > 1 then
      for _, x in ipairs(separador()) do table.insert(trozo, x) end
    end
    table.insert(trozo, pandoc.Str(sinonimo))
    if esIngles and indice == 1 and #sinonimos > 1 then
      for _, x in ipairs(separador()) do table.insert(trozo, x) end
    end

    if esIngles then
      table.insert(contenido, pandoc.Span(trozo, pandoc.Attr("", { "sinonimo-ingles" })))
    else
      -- Si el anterior era el ingles en primera posicion, su separador ya va
      -- dentro del span oculto: este no lleva el suyo.
      if indice == 2 and sinonimos[1] == inglesSinonimo then
        trozo = { pandoc.Str(sinonimo) }
      end
      visibles = visibles + 1
      for _, x in ipairs(trozo) do table.insert(contenido, x) end
    end
  end

  -- Un atributo y no una clase: validar.ps1 localiza la linea por su clase
  -- exacta, y la linea tiene que seguir existiendo para el buscador.
  local atributos = {}
  if visibles == 0 then
    atributos["data-solo-ingles"] = "1"
  end

  local linea = pandoc.Div(
    { pandoc.Para(contenido) },
    pandoc.Attr("", { "sinonimos" }, atributos)
  )

  table.insert(doc.blocks, 1, linea)
  return doc
end

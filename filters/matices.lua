-- Matiz de tema en las etiquetas de categoria de la ficha.
--
-- Por que existe: en los listados, cada etiqueta de categoria lleva el manejador
-- que dispara el filtro nativo, y ese manejador contiene un token estable que
-- CSS puede casar; asi se tiñen en styles.css sin tocar el markup. En la ficha
-- no hay nada de eso: Quarto emite <div class="quarto-category">Nombre</div>,
-- sin atributo alguno, y CSS no sabe seleccionar por el texto de un elemento.
-- Sin este filtro, la ficha seria el unico sitio del sitio donde el color de
-- tema no puede llegar, que es justo el defecto que la fase 2 viene a corregir.
--
-- Que hace: las categorias llegan aqui en el mismo orden en el que Quarto las
-- pinta, asi que basta una regla por posicion. No declara ningun color ni ningun
-- numero de tono: solo nombra la variable --h-<categoria> que ya define
-- styles.css, que sigue siendo la unica tabla de tonos del proyecto.

local ACENTOS = {
  ["\195\161"] = "a", ["\195\169"] = "e", ["\195\173"] = "i",
  ["\195\179"] = "o", ["\195\186"] = "u", ["\195\188"] = "u",
  ["\195\177"] = "n",
  ["\195\129"] = "a", ["\195\137"] = "e", ["\195\141"] = "i",
  ["\195\147"] = "o", ["\195\154"] = "u", ["\195\156"] = "u",
  ["\195\145"] = "n"
}

-- Mismo slug que calcula la plantilla de la portada con normalize("NFD"), pero
-- sobre bytes: Lua no conoce Unicode, asi que las letras acentuadas de la
-- taxonomia se sustituyen por su equivalente sin marca.
local function slug(texto)
  local plano = texto:gsub("\195[\128-\191]", function(par)
    return ACENTOS[par] or par
  end)

  plano = plano:lower()
  plano = plano:gsub("[^a-z0-9]+", "-")
  plano = plano:gsub("^%-+", ""):gsub("%-+$", "")
  return plano
end

function Meta(meta)
  if not meta.categories then
    return meta
  end

  local reglas = {}

  for posicion, categoria in ipairs(meta.categories) do
    local nombre = slug(pandoc.utils.stringify(categoria))

    if nombre ~= "" then
      -- El 192 de reserva evita que una categoria sin tono deje la etiqueta sin
      -- color; validar.ps1 comprueba que ninguna llegue a necesitarlo.
      table.insert(reglas, string.format(
        "#title-block-header .quarto-category:nth-child(%d){--h:var(--h-%s,192)}",
        posicion,
        nombre
      ))
    end
  end

  if #reglas == 0 then
    return meta
  end

  local estilo = pandoc.RawBlock(
    "html",
    "<style>\n" .. table.concat(reglas, "\n") .. "\n</style>"
  )

  local cabecera = meta["header-includes"]

  if cabecera == nil then
    cabecera = pandoc.MetaList({})
  elseif cabecera.t ~= "MetaList" then
    cabecera = pandoc.MetaList({ cabecera })
  end

  cabecera:insert(pandoc.MetaBlocks({ estilo }))
  meta["header-includes"] = cabecera

  return meta
end

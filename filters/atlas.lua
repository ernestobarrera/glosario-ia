-- Enlaza cada ficha con las laminas del Atlas que la citan.
--
-- Por que existe: una lamina ya enlaza a sus fichas relacionadas dentro de su
-- propia prosa ("La idea conecta la alineacion, los agentes de IA..."), pero
-- la relacion solo se ve desde el Atlas. Una ficha no sabe que existe una
-- lamina que la usa. En vez de anadir un campo de frontmatter que habria que
-- mantener a mano en paralelo a esos enlaces -y que podria desincronizarse de
-- ellos, el mismo problema que tuvo la etiqueta manual del Atlas-, este
-- filtro deriva la relacion leyendo los enlaces que ya existen en atlas/*.qmd.
--
-- Solo actua sobre documentos de terminos/: para cualquier otro (index,
-- temas, indice-az, la propia pagina de una lamina) comprueba que existe un
-- archivo terminos/<slug>.qmd y si no, no hace nada.
--
-- PANDOC_STATE.input_files no sirve para identificar el documento: Quarto pasa
-- a pandoc una copia temporal con nombre generado, no el .qmd original.
-- PANDOC_STATE.output_file si conserva el slug real (Quarto lo fija con el
-- nombre de salida antes de invocar pandoc), asi que la identidad del
-- documento se lee de ahi.

local function raizProyecto()
  if quarto and quarto.project and quarto.project.directory then
    return quarto.project.directory
  end

  return "."
end

local function sluglDeSalida()
  if not PANDOC_STATE or not PANDOC_STATE.output_file then
    return nil
  end

  return PANDOC_STATE.output_file:match("([^\\/]+)%.html$")
end

local function esFicha(raiz, slug)
  if not slug then
    return false
  end

  local archivo = io.open(raiz .. "/terminos/" .. slug .. ".qmd", "r")

  if not archivo then
    return false
  end

  archivo:close()
  return true
end

-- Lee el titulo del frontmatter de una lamina sin depender de un parser YAML:
-- el mismo enfoque de linea a linea que ya usan temas.lua y matices.lua para
-- no anadir una dependencia solo para esto.
local function tituloDeLamina(ruta)
  local archivo = io.open(ruta, "r")

  if not archivo then
    return nil
  end

  local titulo = nil

  for linea in archivo:lines() do
    local capturado = linea:match('^title:%s*"(.-)"%s*$')

    if capturado then
      titulo = capturado
      break
    end
  end

  archivo:close()
  return titulo
end

-- Laminas cuya prosa enlaza a esta ficha, en el orden en que aparecen los
-- archivos en atlas/. Cada entrada es { slug = "...", titulo = "..." }.
local function laminasQueEnlazan(raiz, slugFicha)
  local carpeta = raiz .. "/atlas"
  local ok, archivos = pcall(pandoc.system.list_directory, carpeta)
  local encontradas = {}

  if not ok or not archivos then
    return encontradas
  end

  local patron = "%(%.%./terminos/" .. slugFicha:gsub("%-", "%%-") .. "%.qmd%)"

  table.sort(archivos)

  for _, nombre in ipairs(archivos) do
    if nombre:match("%.qmd$") then
      local ruta = carpeta .. "/" .. nombre
      local archivo = io.open(ruta, "r")

      if archivo then
        local contenido = archivo:read("a")
        archivo:close()

        if contenido:match(patron) then
          table.insert(encontradas, {
            slug = nombre:gsub("%.qmd$", ""),
            titulo = tituloDeLamina(ruta) or nombre
          })
        end
      end
    end
  end

  return encontradas
end

function Pandoc(doc)
  local raiz = raizProyecto()
  local slugFicha = sluglDeSalida()

  if not esFicha(raiz, slugFicha) then
    return doc
  end

  local laminas = laminasQueEnlazan(raiz, slugFicha)

  if #laminas == 0 then
    return doc
  end

  local contenido = {
    pandoc.Strong({ pandoc.Str("En el Atlas visual:") }),
    pandoc.Space()
  }

  for indice, lamina in ipairs(laminas) do
    if indice > 1 then
      table.insert(contenido, pandoc.Space())
      table.insert(contenido, pandoc.Str("·"))
      table.insert(contenido, pandoc.Space())
    end

    table.insert(contenido, pandoc.Link(
      { pandoc.Str(lamina.titulo) },
      "../atlas/" .. lamina.slug .. ".html"
    ))
  end

  table.insert(doc.blocks, pandoc.Div(
    { pandoc.Para(contenido) },
    pandoc.Attr("", { "atlas-relacionado" })
  ))

  return doc
end

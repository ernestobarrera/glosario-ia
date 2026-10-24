-- La guia de uso, desde guia.yml.
--
-- Por que existe: los pasos de la guia son decision editorial y su sitio es
-- guia.yml, como el de los recorridos es recorridos.yml. Este filtro lleva a
-- cada pagina solo la guia que le toca —la de la portada a index, la de la
-- ficha a cada terminos/*.qmd— y a las demas no les anade nada: en ellas, el
-- icono de la barra lleva a la guia de la portada sin necesidad de script.
--
-- Emite los pasos como JSON dentro de la pagina, con el texto ya convertido de
-- Markdown a HTML, y declara assets/guia.js como dependencia: Quarto lo copia a
-- site_libs y escribe la ruta relativa correcta en cada pagina, tambien en las
-- de terminos/.
--
-- Una guia mal formada detiene el render, por el mismo motivo que en
-- recorridos.lua: Quarto registra el error de un filtro y sigue, y el CI habria
-- publicado la pagina con la guia rota. Que cada destino exista en el HTML lo
-- comprueba validar.ps1 despues del render: aqui todavia no hay HTML.

local function detener(mensaje)
  io.stderr:write("ERROR (filters/guia.lua) " .. mensaje .. "\n")
  os.exit(1)
end

local function raiz()
  if quarto and quarto.project and quarto.project.directory then
    return quarto.project.directory
  end

  return "."
end

local function existe(ruta)
  local archivo = io.open(ruta, "r")

  if not archivo then
    return false
  end

  archivo:close()
  return true
end

local function texto(valor)
  if valor == nil then
    return ""
  end

  return pandoc.utils.stringify(valor)
end

-- Que guia toca a este documento. No sirve PANDOC_STATE.output_file, que usa
-- atlas.lua: trae solo el nombre («index.html»), y la portada tiene que
-- distinguirse de cualquier otro index de una subcarpeta. quarto.doc.input_file
-- trae la ruta completa del .qmd original; se compara relativa a la raiz.
local function normalizar(ruta)
  return (ruta:gsub("\\", "/"):lower())
end

local function paginaActual()
  local entrada = quarto and quarto.doc and quarto.doc.input_file

  if not entrada then
    return nil
  end

  local prefijo = normalizar(raiz()) .. "/"
  entrada = normalizar(entrada)

  if entrada:sub(1, #prefijo) ~= prefijo then
    return nil
  end

  local relativa = entrada:sub(#prefijo + 1)

  if relativa == "index.qmd" then
    return "portada"
  end

  if relativa:match("^terminos/[^/]+%.qmd$") then
    return "ficha"
  end

  return nil
end

-- La pagina a la que apunta vuelve-a tiene que existir y tener guia: un enlace
-- «Ver la parte 1» que abre una pagina sin guia promete lo que no hay.
local function paginaDe(ruta)
  if ruta == "index" then
    return "portada"
  end

  local slug = ruta:match("^terminos/([^/]+)$")

  if slug and existe(raiz() .. "/terminos/" .. slug .. ".qmd") then
    return "ficha"
  end

  return nil
end

-- guia.yml y recorridos.yml se leen como el bloque de metadatos de un documento
-- vacio, igual que en recorridos.lua: cada texto llega ya como Markdown en linea.
local function leerYaml(nombre)
  local archivo = io.open(raiz() .. "/" .. nombre, "r")

  if not archivo then
    detener(nombre .. ": no existe")
  end

  local contenido = archivo:read("*a")
  archivo:close()
  return pandoc.read("---\n" .. contenido .. "\n---\n", "markdown").meta
end

-- Las fichas de un recorrido, en pasos sueltos o repartidas en etapas: la misma
-- forma que lee filters/recorridos.lua.
local function fichasDeRecorrido(idGuia, idRecorrido)
  for _, recorrido in ipairs(leerYaml("recorridos.yml").recorridos or {}) do
    if texto(recorrido.id) == idRecorrido then
      local slugs = {}
      local tramos = { recorrido.pasos or {} }

      for _, etapa in ipairs(recorrido.etapas or {}) do
        table.insert(tramos, etapa.pasos or {})
      end

      for _, pasos in ipairs(tramos) do
        for _, paso in ipairs(pasos) do
          local slug = texto(paso.ficha)

          if not existe(raiz() .. "/terminos/" .. slug .. ".qmd") then
            detener("guia.yml: la guia '" .. idGuia .. "' continua en el recorrido '" .. idRecorrido .. "', que enlaza la ficha inexistente '" .. slug .. "'")
          end

          table.insert(slugs, slug)
        end
      end

      if #slugs == 0 then
        detener("guia.yml: la guia '" .. idGuia .. "' continua en el recorrido '" .. idRecorrido .. "', que no tiene fichas")
      end

      return slugs
    end
  end

  detener("guia.yml: la guia '" .. idGuia .. "' continua en el recorrido '" .. idRecorrido .. "', que no existe")
end

local function enHtml(inlines)
  local html = pandoc.write(pandoc.Pandoc({ pandoc.Plain(inlines) }), "html")
  return (html:gsub("%s+$", ""))
end

local function prepararGuia(guia, pagina)
  local id = texto(guia.id)
  local datos = { id = id, pagina = pagina, rotulo = texto(guia.rotulo), pasos = {} }

  if datos.rotulo == "" then
    detener("guia.yml: la guia '" .. id .. "' no tiene rotulo")
  end

  for numero, paso in ipairs(guia.pasos or {}) do
    local titulo = texto(paso.titulo)
    local destino = paso.destino and texto(paso.destino) or nil

    if titulo == "" then
      detener("guia.yml: el paso " .. numero .. " de la guia '" .. id .. "' no tiene titulo")
    end

    if texto(paso.texto) == "" then
      detener("guia.yml: el paso '" .. titulo .. "' de la guia '" .. id .. "' no tiene texto")
    end

    if destino and not destino:match("^[#.][%w_-]+$") then
      detener("guia.yml: el destino '" .. destino .. "' del paso '" .. titulo .. "' no es \"#id\" ni \".clase\"")
    end

    table.insert(datos.pasos, { titulo = titulo, destino = destino, texto = enHtml(paso.texto) })
  end

  if #datos.pasos == 0 then
    detener("guia.yml: la guia '" .. id .. "' no tiene pasos")
  end

  local recorrido = guia["continua-en-recorrido"] and texto(guia["continua-en-recorrido"]) or nil

  if recorrido then
    if texto(guia["continua-texto"]) == "" then
      detener("guia.yml: la guia '" .. id .. "' tiene continua-en-recorrido sin continua-texto")
    end

    datos.continua = { fichas = fichasDeRecorrido(id, recorrido), texto = texto(guia["continua-texto"]) }
  end

  local vuelveA = guia["vuelve-a"] and texto(guia["vuelve-a"]) or nil

  if vuelveA then
    local destino = paginaDe(vuelveA)

    if not destino then
      detener("guia.yml: la guia '" .. id .. "' vuelve a '" .. vuelveA .. "', que no existe o no tiene guia")
    end

    if texto(guia["vuelve-texto"]) == "" then
      detener("guia.yml: la guia '" .. id .. "' tiene vuelve-a sin vuelve-texto")
    end

    datos.vuelve = { href = vuelveA .. ".html?tour=1", pagina = destino, texto = texto(guia["vuelve-texto"]) }
  end

  return datos
end

function Pandoc(doc)
  local pagina = paginaActual()

  if not pagina then
    return nil
  end

  local elegida = nil

  for _, guia in ipairs(leerYaml("guia.yml").guias or {}) do
    if texto(guia.pagina) == pagina then
      elegida = prepararGuia(guia, pagina)
    end
  end

  if not elegida then
    return nil
  end

  -- «</» dentro de una cadena cerraria el <script> antes de tiempo.
  local json = pandoc.json.encode(elegida):gsub("</", "<\\/")

  quarto.doc.add_html_dependency({
    name = "guia-de-uso",
    version = "1",
    scripts = { { path = "../assets/guia.js", afterBody = true } },
  })
  quarto.doc.include_text("after-body", '<script type="application/json" id="guia-datos">' .. json .. "</script>")

  return nil
end

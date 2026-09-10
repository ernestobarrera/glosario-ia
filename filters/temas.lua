-- La frase y el recuento de cada tema, en la pagina de Temas.
--
-- Por que existe: las nueve frases son contenido editorial y su sitio es
-- taxonomia.yml, junto a la categoria que describen. Si ademas se escribieran en
-- temas.qmd habria dos originales del mismo texto y nada garantizaria que digan
-- lo mismo. Este filtro las lee de la taxonomia y las inserta bajo el epigrafe
-- de su seccion, de modo que la pagina las muestra sin poseerlas.
--
-- Solo actua en documentos que lo pidan con 'frases-de-tema: true' en el
-- frontmatter: sin esa marca no toca nada, asi que una ficha que algun dia
-- tuviera un epigrafe llamado como una categoria no se ve afectada.
--
-- El epigrafe manda: su texto tiene que ser exactamente el nombre de la
-- categoria, que es lo mismo que exige el 'include: categories' del listado de
-- esa seccion. Si no coincide, la seccion se queda sin frase y validar.ps1 lo
-- dice, en vez de publicar una seccion muda.
--
-- El recuento vuelve porque al agrupar desaparecio la barra lateral que lo
-- llevaba —«Aprendizaje automatico (39)»—, y saber cuantas fichas tiene un tema
-- antes de entrar en el es parte de lo que la pagina sirve. Se cuenta leyendo el
-- frontmatter de las fichas, no se escribe a mano, y viaja DENTRO del epigrafe
-- para que el sumario lateral lo herede sin ningun trabajo extra. validar.ps1
-- comprueba que cada numero coincide con las fichas que declaran esa categoria.

local activo = false
local frases = {}
local recuentos = {}

local function leerTaxonomia()
  local raiz = "."

  if quarto and quarto.project and quarto.project.directory then
    raiz = quarto.project.directory
  end

  local archivo = io.open(raiz .. "/taxonomia.yml", "r")

  if not archivo then
    return
  end

  local dentro = false

  for linea in archivo:lines() do
    if linea:match("^frases:%s*$") then
      dentro = true
    elseif dentro then
      -- Fin del bloque: cualquier clave de primer nivel que venga despues.
      if linea:match("^%S") then
        dentro = false
      else
        local categoria, frase = linea:match('^%s+"(.-)":%s*"(.-)"%s*$')

        if categoria then
          frases[categoria] = frase
        end
      end
    end
  end

  archivo:close()
end

-- Dos pasadas explicitas y en este orden. Dentro de un mismo filtro, pandoc
-- recorre los bloques ANTES que los metadatos, asi que un unico filtro leeria la
-- marca del frontmatter despues de haber pasado ya por todos los epigrafes y no
-- insertaria ninguna frase. Costo un render entenderlo.
-- Cuenta las fichas de cada categoria leyendo su frontmatter. Es el mismo dato
-- que el listado de la seccion filtra por su cuenta, contado aparte: si los dos
-- caminos discreparan, el validador lo dice.
local function contarFichas()
  local raiz = "."

  if quarto and quarto.project and quarto.project.directory then
    raiz = quarto.project.directory
  end

  local carpeta = raiz .. "/terminos"
  local ok, archivos = pcall(pandoc.system.list_directory, carpeta)

  if not ok or not archivos then
    return
  end

  for _, nombre in ipairs(archivos) do
    if nombre:match("%.qmd$") then
      local ficha = io.open(carpeta .. "/" .. nombre, "r")

      if ficha then
        local enCategorias = false

        for linea in ficha:lines() do
          if linea:match("^categories:%s*$") then
            enCategorias = true
          elseif enCategorias then
            local categoria = linea:match('^%s+%-%s+"(.-)"%s*$') or linea:match("^%s+%-%s+(.-)%s*$")

            if categoria then
              recuentos[categoria] = (recuentos[categoria] or 0) + 1
            else
              -- Cualquier linea que no sea un elemento de la lista cierra el bloque.
              enCategorias = false
            end
          end
        end

        ficha:close()
      end
    end
  end
end

local function leerMarca(meta)
  activo = meta["frases-de-tema"] == true

  if activo then
    leerTaxonomia()
    contarFichas()
  end

  return meta
end

local function ponerFrase(elemento)
  if not activo or elemento.level ~= 2 then
    return nil
  end

  local frase = frases[pandoc.utils.stringify(elemento.content)]

  if not frase then
    return nil
  end

  local nombre = pandoc.utils.stringify(elemento.content)
  local cuantas = recuentos[nombre]

  if cuantas then
    elemento.content:insert(pandoc.Space())
    elemento.content:insert(pandoc.Span(
      { pandoc.Str(tostring(cuantas)) },
      pandoc.Attr("", { "recuento-tema" })
    ))
  end

  -- Se lee como markdown y no como texto plano para que la frase pueda llevar
  -- una cursiva o unas comillas sin acabar escapada en el HTML.
  return {
    elemento,
    pandoc.Div(
      pandoc.read(frase, "markdown").blocks,
      pandoc.Attr("", { "frase-de-tema" })
    )
  }
end

return {
  { Meta = leerMarca },
  { Header = ponerFrase }
}

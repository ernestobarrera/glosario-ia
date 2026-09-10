-- La frase de cada tema, desde la taxonomia hasta la pagina de Temas.
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

local activo = false
local frases = {}

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
local function leerMarca(meta)
  activo = meta["frases-de-tema"] == true

  if activo then
    leerTaxonomia()
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

[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
$raiz = Split-Path -Parent $MyInvocation.MyCommand.Path
$carpetaTerminos = Join-Path $raiz "terminos"
$carpetaSitio = Join-Path $raiz "_site"
$errores = [System.Collections.Generic.List[string]]::new()
$avisos = [System.Collections.Generic.List[string]]::new()

function Quitar-Comillas {
  param([string]$Valor)

  $resultado = $Valor.Trim()
  if (
    $resultado.Length -ge 2 -and
    (
      ($resultado.StartsWith('"') -and $resultado.EndsWith('"')) -or
      ($resultado.StartsWith("'") -and $resultado.EndsWith("'"))
    )
  ) {
    return $resultado.Substring(1, $resultado.Length - 2)
  }

  return $resultado
}

function Leer-YamlPlano {
  param([string]$Texto)

  $datos = @{}
  $claveActual = $null

  foreach ($linea in ($Texto -split "\r?\n")) {
    if ($linea -match "^\s*#") {
      continue
    }

    if ($linea -match "^([A-Za-z0-9-]+):\s*(.*)$") {
      $claveActual = $Matches[1]
      $valor = $Matches[2]
      if ([string]::IsNullOrWhiteSpace($valor)) {
        $datos[$claveActual] = [System.Collections.Generic.List[string]]::new()
      }
      else {
        $datos[$claveActual] = Quitar-Comillas $valor
      }
      continue
    }

    if ($null -ne $claveActual -and $linea -match "^\s+-\s+(.+?)\s*$") {
      if ($datos[$claveActual] -isnot [System.Collections.Generic.List[string]]) {
        $datos[$claveActual] = [System.Collections.Generic.List[string]]::new()
      }
      $datos[$claveActual].Add((Quitar-Comillas $Matches[1]))
    }
  }

  return $datos
}

function Leer-Ficha {
  param([System.IO.FileInfo]$Archivo)

  $texto = Get-Content -LiteralPath $Archivo.FullName -Encoding UTF8 -Raw
  $coincidencia = [regex]::Match(
    $texto,
    "\A---\s*\r?\n(?<yaml>[\s\S]*?)\r?\n---\s*\r?\n(?<body>[\s\S]*)"
  )

  if (-not $coincidencia.Success) {
    $errores.Add("$($Archivo.Name): frontmatter ausente o mal delimitado")
    return $null
  }

  return [pscustomobject]@{
    Archivo = $Archivo
    Meta = Leer-YamlPlano $coincidencia.Groups["yaml"].Value
    Cuerpo = $coincidencia.Groups["body"].Value
    Texto = $texto
  }
}

function Registrar-Error {
  param([string]$Mensaje)
  $errores.Add($Mensaje)
}

function Registrar-Aviso {
  param([string]$Mensaje)
  $avisos.Add($Mensaje)
}

$taxonomia = Leer-YamlPlano (
  Get-Content -LiteralPath (Join-Path $raiz "taxonomia.yml") -Encoding UTF8 -Raw
)
$categoriasPermitidas = @($taxonomia["categories"])

# Las frases de tema son un mapa y el lector plano de arriba solo entiende listas,
# asi que se leen aparte. Son contenido editorial: viven en taxonomia.yml junto a
# la categoria que describen y filters/temas.lua las lleva a la pagina de Temas.
$frasesTema = @{}
$textoTaxonomia = Get-Content -LiteralPath (Join-Path $raiz "taxonomia.yml") -Encoding UTF8 -Raw
# Comillas simples: entre dobles, PowerShell tomaria el $(...) del regex por
# una subexpresion suya.
$bloqueFrases = [regex]::Match($textoTaxonomia, '(?ms)^frases:\s*?$(?<cuerpo>.*?)(?=^\S|\z)')
if ($bloqueFrases.Success) {
  foreach ($linea in [regex]::Matches($bloqueFrases.Groups["cuerpo"].Value, '(?m)^\s+"(?<categoria>[^"]+)":\s*"(?<frase>[^"]*)"\s*$')) {
    $frasesTema[$linea.Groups["categoria"].Value] = $linea.Groups["frase"].Value
  }
}
$estadosPermitidos = @($taxonomia["estados"])
$tiposPermitidos = @($taxonomia["tipos"])

if (
  $categoriasPermitidas.Count -eq 0 -or
  $estadosPermitidos.Count -eq 0 -or
  $tiposPermitidos.Count -eq 0
) {
  Registrar-Error "taxonomia.yml: faltan categories, estados o tipos"
}

# Sistema de color de tema.
#
# El tono de cada categoria se declara una sola vez, en styles.css, y lo leen
# tres consumidores: la plantilla de la portada, la regla de los listados y
# filters/matices.lua para la ficha. Aqui se comprueba que la tabla cubre la
# taxonomia y que los tres siguen enganchados. Hasta la fase 2 el color existia
# solo en la portada, asi que esta comprobacion tambien es la que impide que
# vuelva a encogerse sin que nada avise.
function Slug-Categoria {
  param([string]$Valor)

  $plano = [string]::Join("", (
    $Valor.Normalize([Text.NormalizationForm]::FormD).ToCharArray() | Where-Object {
      [Globalization.CharUnicodeInfo]::GetUnicodeCategory($_) -ne
        [Globalization.UnicodeCategory]::NonSpacingMark
    }
  ))
  $plano = [Globalization.CultureInfo]::InvariantCulture.TextInfo.ToLower($plano)
  return ([regex]::Replace($plano, "[^a-z0-9]+", "-")).Trim("-")
}

# El token que Quarto pone en el manejador de cada etiqueta de categoria de un
# listado: base64(encodeURIComponent(categoria)). Se recalcula aqui en vez de
# copiarlo, de modo que si Quarto cambiara el mecanismo la validacion lo dice.
function Token-Categoria {
  param([string]$Valor)

  return [Convert]::ToBase64String(
    [Text.Encoding]::UTF8.GetBytes([Uri]::EscapeDataString($Valor))
  )
}

$rutaEstilos = Join-Path $raiz "styles.css"
$estilos = Get-Content -LiteralPath $rutaEstilos -Encoding UTF8 -Raw
$tokensTaxonomia = @{}

foreach ($categoria in $categoriasPermitidas) {
  $slugCategoria = Slug-Categoria $categoria
  $token = Token-Categoria $categoria
  $tokensTaxonomia[$token] = $categoria

  if ($estilos.IndexOf("--h-$slugCategoria" + ":", [StringComparison]::Ordinal) -lt 0) {
    Registrar-Error "styles.css: la categoria '$categoria' no tiene tono '--h-$slugCategoria'"
  }
}

$rutaPlantilla = Join-Path (Join-Path $raiz "templates") "listado-portada.ejs.md"
if (-not (Test-Path -LiteralPath $rutaPlantilla)) {
  Registrar-Error "falta templates/listado-portada.ejs.md"
}
else {
  $plantillaPortada = Get-Content -LiteralPath $rutaPlantilla -Encoding UTF8 -Raw
  if ($plantillaPortada.IndexOf("var(--h-", [StringComparison]::Ordinal) -lt 0) {
    Registrar-Error (
      "listado-portada.ejs.md: ya no lee la tabla de tonos de styles.css; " +
      "la portada volveria a llevar su propia tabla de matices"
    )
  }
}

$rutaFiltroMatices = Join-Path (Join-Path $raiz "filters") "matices.lua"
if (-not (Test-Path -LiteralPath $rutaFiltroMatices)) {
  Registrar-Error "falta filters/matices.lua: la ficha se quedaria sin color de tema"
}

$bib = Get-Content -LiteralPath (Join-Path $raiz "references.bib") -Encoding UTF8 -Raw
$clavesBib = @{}
foreach ($coincidencia in [regex]::Matches($bib, "(?m)^@\w+\s*\{\s*([^,\s]+)\s*,")) {
  $clave = $coincidencia.Groups[1].Value
  if ($clavesBib.ContainsKey($clave)) {
    Registrar-Error "references.bib: citekey duplicado '$clave'"
  }
  else {
    $clavesBib[$clave] = $true
  }
}

if ($clavesBib.Count -eq 0) {
  Registrar-Error "references.bib: no se detectaron entradas bibliograficas"
}

$camposObligatorios = @(
  "title",
  "aliases",
  "sinonimos",
  "description",
  "categories",
  "date-modified",
  "estado",
  "tipo"
)
# El modelo de datos NO se codifica aqui: vive en esquema.yml y llega por
# esquema.lock.yml. Un modelo anterior escrito a mano permitio que faltaran dos
# de los siete campos del documento de origen sin que el validador detectara la
# omision.
$rutaLock = Join-Path $raiz "esquema.lock.yml"
$rutaEsquema = Join-Path $raiz "esquema.yml"

if (-not (Test-Path -LiteralPath $rutaLock)) {
  Registrar-Error "falta esquema.lock.yml: ejecuta 'python herramientas/esquema_lock.py'"
}

$lock = Leer-YamlPlano (Get-Content -LiteralPath $rutaLock -Encoding UTF8 -Raw)
$seccionesOrden = @($lock["secciones-orden"])
$seccionesObligatorias = @($lock["secciones-obligatorias"])
$seccionesRecomendadas = @($lock["secciones-recomendadas"])

# Guarda de obsolescencia: si esquema.yml cambio y nadie regenero el lock,
# el validador estaria comprobando un modelo viejo. Falla en vez de mentir.
# Se normalizan los finales de linea antes de calcular el hash: si no, un
# editor que cambie CRLF por LF marcaria el lock como obsoleto sin que el
# modelo de datos haya cambiado.
$textoEsquema = (Get-Content -LiteralPath $rutaEsquema -Encoding UTF8 -Raw) -replace "`r`n", "`n" -replace "`r", "`n"
$sha = [Security.Cryptography.SHA256]::Create()
try {
  $shaEsquema = [BitConverter]::ToString(
    $sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($textoEsquema))
  ).Replace("-", "").ToLower().Substring(0, 16)
}
finally {
  $sha.Dispose()
}
if ($lock["esquema-sha"] -ne $shaEsquema) {
  Registrar-Error (
    "esquema.lock.yml esta obsoleto (lock: $($lock['esquema-sha']), esquema: $shaEsquema). " +
    "Ejecuta 'python herramientas/esquema_lock.py'"
  )
}

if ($seccionesObligatorias.Count -eq 0) {
  Registrar-Error "esquema.lock.yml: no se leyeron secciones obligatorias"
}
$aliasVistos = @{}
$slugVistos = @{}
$fichas = @()

foreach ($archivo in Get-ChildItem -LiteralPath $carpetaTerminos -Filter "*.qmd" -File | Sort-Object Name) {
  $ficha = Leer-Ficha $archivo
  if ($null -eq $ficha) {
    continue
  }
  $fichas += $ficha
  $meta = $ficha.Meta
  $nombre = $archivo.Name
  $slug = $archivo.BaseName

  foreach ($campo in $camposObligatorios) {
    if (-not $meta.ContainsKey($campo)) {
      Registrar-Error "$nombre`: falta el campo '$campo'"
    }
  }

  foreach ($campoObsoleto in @("slug", "status", "also-known-as")) {
    if ($meta.ContainsKey($campoObsoleto)) {
      Registrar-Error "$nombre`: conserva el campo obsoleto '$campoObsoleto'"
    }
  }

  if ($slug -notmatch "^[a-z0-9]+(?:-[a-z0-9]+)*$") {
    Registrar-Error "$nombre`: el nombre no es un slug canonico"
  }
  if ($slugVistos.ContainsKey($slug)) {
    Registrar-Error "$nombre`: slug/filename duplicado '$slug'"
  }
  else {
    $slugVistos[$slug] = $true
  }

  $salidaCanonica = Join-Path $carpetaSitio "terminos\$slug.html"
  if (-not (Test-Path -LiteralPath $salidaCanonica)) {
    Registrar-Error "$nombre`: no existe la salida canonica terminos/$slug.html"
  }

  $categorias = @($meta["categories"])
  if ($categorias.Count -lt 1 -or $categorias.Count -gt 3) {
    Registrar-Error "$nombre`: debe tener entre 1 y 3 categorias"
  }
  foreach ($categoria in $categorias) {
    if ($categoria -notin $categoriasPermitidas) {
      Registrar-Error "$nombre`: categoria no controlada '$categoria'"
    }
  }

  if ($meta["estado"] -notin $estadosPermitidos) {
    Registrar-Error "$nombre`: estado no permitido '$($meta["estado"])'"
  }
  if ($meta["tipo"] -notin $tiposPermitidos) {
    Registrar-Error "$nombre`: tipo no permitido '$($meta["tipo"])'"
  }

  $fecha = [datetime]::MinValue
  $fechaValida = [datetime]::TryParseExact(
    [string]$meta["date-modified"],
    "yyyy-MM-dd",
    [Globalization.CultureInfo]::InvariantCulture,
    [Globalization.DateTimeStyles]::None,
    [ref]$fecha
  )
  if (-not $fechaValida) {
    Registrar-Error "$nombre`: date-modified no sigue YYYY-MM-DD"
  }
  elseif ($fecha.Date -gt (Get-Date).Date) {
    Registrar-Error "$nombre`: date-modified esta en el futuro"
  }

  $aliases = @($meta["aliases"])
  if ($aliases.Count -eq 0) {
    Registrar-Error "$nombre`: aliases debe incluir al menos un redirect"
  }
  foreach ($alias in $aliases) {
    $aliasNormalizado = ([string]$alias).Replace("\", "/").ToLowerInvariant()
    if ($aliasNormalizado -notmatch "^/terminos/[a-z0-9-]+\.html$") {
      Registrar-Error "$nombre`: alias no canonico '$alias'"
    }
    if ($aliasVistos.ContainsKey($aliasNormalizado)) {
      Registrar-Error "$nombre`: alias duplicado '$alias'"
    }
    else {
      $aliasVistos[$aliasNormalizado] = $nombre
    }
    if ($aliasNormalizado -eq "/terminos/$slug.html") {
      Registrar-Error "$nombre`: un alias coincide con su ruta canonica"
    }

    $rutaAlias = Join-Path $carpetaSitio $aliasNormalizado.TrimStart("/").Replace("/", "\")
    if (-not (Test-Path -LiteralPath $rutaAlias)) {
      Registrar-Error "$nombre`: no se genero el redirect '$alias'"
    }
  }

  $sinonimos = @($meta["sinonimos"])
  if ($sinonimos.Count -eq 0) {
    Registrar-Error "$nombre`: sinonimos debe contener al menos un valor"
  }

  if ($ficha.Texto -match "<!--\s*end list\s*-->") {
    Registrar-Error "$nombre`: conserva un artefacto '<!-- end list -->'"
  }

  $ultimaPosicion = -1
  foreach ($seccion in $seccionesOrden) {
    $posicion = $ficha.Cuerpo.IndexOf($seccion, [StringComparison]::Ordinal)
    if ($posicion -lt 0) {
      if ($seccionesObligatorias -contains $seccion) {
        Registrar-Error "$nombre`: falta la seccion '$seccion'"
      }
      elseif ($seccionesRecomendadas -contains $seccion) {
        Registrar-Aviso "$nombre`: sin la seccion recomendada '$seccion'"
      }
      continue
    }
    if ($posicion -le $ultimaPosicion) {
      Registrar-Error "$nombre`: la seccion '$seccion' esta fuera de orden"
    }
    else {
      $ultimaPosicion = $posicion
    }
  }

  foreach ($cita in [regex]::Matches($ficha.Cuerpo, "(?<![\w.])@([A-Za-z0-9_:.+-]+)")) {
    $claveCitada = $cita.Groups[1].Value
    if (-not $clavesBib.ContainsKey($claveCitada)) {
      Registrar-Error "$nombre`: citekey inexistente '$claveCitada'"
    }
  }

  foreach ($enlace in [regex]::Matches($ficha.Cuerpo, "\]\(([^)#]+\.qmd)(?:#[^)]+)?\)")) {
    $destinoRelativo = $enlace.Groups[1].Value
    $destino = [IO.Path]::GetFullPath((Join-Path $archivo.DirectoryName $destinoRelativo))
    if (-not (Test-Path -LiteralPath $destino)) {
      Registrar-Error "$nombre`: enlace interno roto '$destinoRelativo'"
    }
  }

  $htmlCanonico = Join-Path $carpetaSitio "terminos\$slug.html"
  if (Test-Path -LiteralPath $htmlCanonico) {
    $html = Get-Content -LiteralPath $htmlCanonico -Encoding UTF8 -Raw
    # El estado tiene que llegar al HTML. Es campo obligatorio del esquema, pero
    # Quarto no lo emite: lo pone filters/estado.lua. Sin esta comprobacion, si
    # el filtro deja de aplicarse, las fichas dejan de decir que son borradores
    # y nada falla.
    if ($html.IndexOf('<div class="estado-ficha">', [StringComparison]::Ordinal) -lt 0) {
      Registrar-Error "$nombre`: no se renderizo la linea de estado"
    }
    else {
      $marcaEstado = 'distintivo-' + [string]$meta["estado"]
      if ($html.IndexOf($marcaEstado, [StringComparison]::Ordinal) -lt 0) {
        Registrar-Error "$nombre`: el estado '$($meta["estado"])' no aparece en el HTML"
      }
    }

    $bloqueSinonimos = [regex]::Match(
      $html,
      '<div class="sinonimos"[^>]*>(?<contenido>[\s\S]*?)</div>'
    )
    if (-not $bloqueSinonimos.Success) {
      Registrar-Error "$nombre`: la linea de sinonimos no esta renderizada"
    }
    else {
      $textoSinonimos = [regex]::Replace(
        $bloqueSinonimos.Groups["contenido"].Value,
        "<[^>]+>",
        " "
      )
      $textoSinonimos = [Net.WebUtility]::HtmlDecode($textoSinonimos)
      $textoSinonimos = [regex]::Replace($textoSinonimos, "\s+", " ").Trim()
      $prefijoSinonimos = "^Sin" + [char]0x00F3 + "nimos:\s*"
      $separadorSinonimos = "\s*" + [char]0x00B7 + "\s*"
      $textoSinonimos = $textoSinonimos -replace $prefijoSinonimos, ""
      $sinonimosRenderizados = @($textoSinonimos -split $separadorSinonimos)
      if (($sinonimosRenderizados -join "`n") -cne ($sinonimos -join "`n")) {
        Registrar-Error "$nombre`: sinonimos renderizados distintos del frontmatter"
      }
    }

    # Matiz de tema en la cabecera de la ficha. Lo emite filters/matices.lua,
    # porque el title block de Quarto no da ningun asidero a CSS: sin el filtro
    # las etiquetas volverian al gris de antes de la fase 2 y nada fallaria.
    # Se comprueba posicion a posicion, que es como el filtro las escribe.
    $posicionCategoria = 1
    foreach ($categoria in $categorias) {
      $reglaEsperada = (
        "#title-block-header .quarto-category:nth-child($posicionCategoria)" +
        "{--h:var(--h-" + (Slug-Categoria $categoria) + ",192)}"
      )
      if ($html.IndexOf($reglaEsperada, [StringComparison]::Ordinal) -lt 0) {
        Registrar-Error "$nombre`: la categoria '$categoria' no recibe matiz en la cabecera"
      }
      $posicionCategoria++
    }
  }
}

foreach ($alias in $aliasVistos.Keys) {
  $slugAlias = [IO.Path]::GetFileNameWithoutExtension($alias)
  if ($slugVistos.ContainsKey($slugAlias)) {
    Registrar-Error "$($aliasVistos[$alias]): el alias '$alias' colisiona con una ficha canonica"
  }
}

$searchPath = Join-Path $carpetaSitio "search.json"
if (-not (Test-Path -LiteralPath $searchPath)) {
  Registrar-Error "_site/search.json no existe; ejecuta primero quarto render"
}
else {
  $search = Get-Content -LiteralPath $searchPath -Encoding UTF8 -Raw
  foreach ($ficha in $fichas) {
    foreach ($sinonimo in @($ficha.Meta["sinonimos"])) {
      if ($search.IndexOf([string]$sinonimo, [StringComparison]::OrdinalIgnoreCase) -lt 0) {
        Registrar-Error "$($ficha.Archivo.Name): el sinonimo '$sinonimo' no aparece en search.json"
      }
    }
  }
}

# Columnas de busqueda declaradas frente al HTML realmente emitido.
#
# filter-ui hace que Quarto genere searchColumns con la forma 'listing-<campo>',
# pero quien emite esas clases es la plantilla del listado. Un campo que la
# plantilla no pinta deja la columna muerta: el filtro no encuentra nada y nada
# falla. Ocurrio con 'sinonimos' en las tres paginas de listado, con los sinonimos
# correctamente indexados en search.json -lo que la comprobacion anterior ya
# verificaba- y el filtro de la pagina sin encontrarlos. Indexado y filtrable no
# son lo mismo, y hasta ahora solo se comprobaba lo primero.
$columnasComprobadas = 0
foreach ($pagina in @("index.html", "indice-az.html", "temas.html")) {
  $rutaListado = Join-Path $carpetaSitio $pagina
  if (-not (Test-Path -LiteralPath $rutaListado)) {
    Registrar-Error "$pagina`: no existe la salida del listado"
    continue
  }

  $htmlListado = Get-Content -LiteralPath $rutaListado -Encoding UTF8 -Raw

  # Solo tiene sentido comprobarlo donde hay caja de filtro. Sin filter-ui,
  # Quarto emite igualmente unas searchColumns por defecto que incluyen campos
  # no renderizados (listing-author, listing-image): columnas muertas que no
  # enganan a nadie porque no hay filtro que las use. Visto en el ensayo de
  # temas agrupados del 2026-09-05.
  if ($htmlListado.IndexOf('class="search form-control"', [StringComparison]::Ordinal) -lt 0) {
    continue
  }

  $declaradas = [regex]::Match($htmlListado, 'searchColumns:\s*\[(?<columnas>[^\]]*)\]')
  if (-not $declaradas.Success) {
    Registrar-Aviso "$pagina`: el listado no declara columnas de busqueda"
    continue
  }

  foreach ($columna in ($declaradas.Groups["columnas"].Value -split ",")) {
    $clase = $columna.Trim().Trim('"')
    if ([string]::IsNullOrWhiteSpace($clase)) {
      continue
    }

    $patronClase = 'class="[^"]*\b' + [regex]::Escape($clase) + '\b'
    if ($htmlListado -notmatch $patronClase) {
      Registrar-Error (
        "$pagina`: la columna de busqueda '$clase' no aparece en el HTML; " +
        "el filtro de la pagina no puede encontrarla"
      )
    }
    else {
      $columnasComprobadas++
    }
  }
}

# Guardian dormido: las etiquetas de categoria de un listado nativo.
#
# Hoy no las pinta ninguna pagina —la portada usa plantilla propia, Temas agrupa
# por secciones y el A-Z es un indice—, asi que esto no dice nada y no gasta
# atencion. Si alguna vista vuelve a emitirlas, despierta: esas etiquetas no
# llevan ningun atributo que diga de que categoria son, y la unica forma de
# teñirlas sin tocar el markup es casar el token del manejador que dispara el
# filtro nativo, base64(encodeURIComponent(categoria)). El token se recalcula
# aqui, no se copia, de modo que tambien detecta que Quarto haya cambiado el
# mecanismo. Sin esto, una cuadricula reintroducida saldria gris y nadie lo
# sabria hasta mirarla.
foreach ($pagina in @("index.html", "indice-az.html", "temas.html")) {
  $rutaPagina = Join-Path $carpetaSitio $pagina
  if (-not (Test-Path -LiteralPath $rutaPagina)) {
    continue
  }

  $htmlPagina = Get-Content -LiteralPath $rutaPagina -Encoding UTF8 -Raw

  foreach ($emitido in ([regex]::Matches($htmlPagina, "quartoListingCategory\('(?<token>[^']+)'\)") |
      ForEach-Object { $_.Groups["token"].Value } | Sort-Object -Unique)) {
    if (-not $tokensTaxonomia.ContainsKey($emitido)) {
      Registrar-Error (
        "$pagina`: el token de categoria '$emitido' no corresponde a ninguna categoria " +
        "de la taxonomia; esa etiqueta no podria recibir su matiz"
      )
      continue
    }

    $selector = '[onclick*="(' + "'" + $emitido + "'" + ')"]'
    if ($estilos.IndexOf($selector, [StringComparison]::Ordinal) -lt 0) {
      Registrar-Error (
        "$pagina`: vuelve a haber etiquetas de categoria de un listado nativo " +
        "('$($tokensTaxonomia[$emitido])') y styles.css no tiene regla de matiz para su token; " +
        "saldrian grises"
      )
    }
  }
}

# El indice A-Z: una entrada por ficha y una remision por cada sinonimo.
#
# Que el sinonimo este en search.json -lo comprueba el bloque de arriba- solo
# dice que el buscador lo encuentra. Aqui se comprueba lo otro: que ademas se VE,
# en su letra, remitiendo a su ficha. Las remisiones no son fichas y no las
# produce ningun listado: las arma templates/indice-az.ejs.md, asi que si esa
# plantilla se rompe el indice seguiria valiendo como lista de terminos y nadie
# lo notaria.
$rutaIndice = Join-Path $carpetaSitio "indice-az.html"
if (-not (Test-Path -LiteralPath $rutaIndice)) {
  Registrar-Error "indice-az.html: no existe la salida del indice"
}
else {
  $htmlIndice = Get-Content -LiteralPath $rutaIndice -Encoding UTF8 -Raw
  $remisionesEsperadas = 0

  foreach ($ficha in $fichas) {
    foreach ($sinonimo in @($ficha.Meta["sinonimos"])) {
      $remisionesEsperadas++
      $marca = 'az-remision">' + [string]$sinonimo + '<'
      if ($htmlIndice.IndexOf($marca, [StringComparison]::Ordinal) -lt 0) {
        Registrar-Error (
          "$($ficha.Archivo.Name): el sinonimo '$sinonimo' no tiene remision en el indice A-Z"
        )
      }
    }
  }

  $entradasIndice = ([regex]::Matches($htmlIndice, 'class="az-entrada')).Count
  $entradasEsperadas = $fichas.Count + $remisionesEsperadas

  if ($entradasIndice -ne $entradasEsperadas) {
    Registrar-Error (
      "indice-az.html: el indice tiene $entradasIndice entradas y se esperaban " +
      "$entradasEsperadas ($($fichas.Count) fichas y $remisionesEsperadas remisiones)"
    )
  }

  if (($htmlIndice.IndexOf('class="az-rail"', [StringComparison]::Ordinal)) -lt 0) {
    Registrar-Error "indice-az.html: falta el rail alfabetico"
  }
}

# La pagina de Temas, seccion a seccion.
#
# Son nueve listados independientes, uno por categoria. Dos cosas pueden
# estropearse en silencio: que una categoria se quede sin su frase -y la seccion
# salga muda- y que el 'include: categories' de una seccion deje de casar y esa
# seccion aparezca vacia o incompleta sin que el render se queje. Lo segundo se
# comprueba contra el recuento real de pertenencias de las fichas.
$htmlTemas = Get-Content -LiteralPath (Join-Path $carpetaSitio "temas.html") -Encoding UTF8 -Raw
$pertenencias = @{}

foreach ($ficha in $fichas) {
  foreach ($categoria in @($ficha.Meta["categories"])) {
    if ($pertenencias.ContainsKey($categoria)) {
      $pertenencias[$categoria]++
    }
    else {
      $pertenencias[$categoria] = 1
    }
  }
}

$fichasEnSecciones = 0

foreach ($categoria in $categoriasPermitidas) {
  if (-not $frasesTema.ContainsKey($categoria)) {
    Registrar-Error "taxonomia.yml: la categoria '$categoria' no tiene frase en el bloque 'frases'"
  }
  elseif ([string]::IsNullOrWhiteSpace($frasesTema[$categoria])) {
    Registrar-Error "taxonomia.yml: la frase de la categoria '$categoria' esta vacia"
  }
  elseif ($htmlTemas.IndexOf($frasesTema[$categoria], [StringComparison]::Ordinal) -lt 0) {
    Registrar-Error (
      "temas.html: la frase de '$categoria' no llego a la pagina; " +
      "revisa filters/temas.lua y que el epigrafe se llame igual que la categoria"
    )
  }

  # El recuento del epigrafe. Lo cuenta filters/temas.lua leyendo el frontmatter
  # de las fichas, por un camino distinto del que usa el listado para filtrar la
  # seccion; aqui se comprueba que los dos dan lo mismo. Un numero que se queda
  # atras es peor que no tener numero: se sigue leyendo y ya no es verdad.
  $esperadasCategoria = 0
  if ($pertenencias.ContainsKey($categoria)) {
    $esperadasCategoria = $pertenencias[$categoria]
  }

  $epigrafe = [regex]::Match(
    $htmlTemas,
    'data-anchor-id="' + [regex]::Escape((Slug-Categoria $categoria)) + '"[^>]*>(?<contenido>[\s\S]*?)</h2>'
  )

  if (-not $epigrafe.Success) {
    Registrar-Error "temas.html: la categoria '$categoria' no tiene epigrafe de seccion"
  }
  else {
    $recuento = [regex]::Match($epigrafe.Groups["contenido"].Value, 'recuento-tema">(?<n>\d+)<')

    if (-not $recuento.Success) {
      Registrar-Error (
        "temas.html: el epigrafe de '$categoria' no muestra su recuento de fichas"
      )
    }
    elseif ([int]$recuento.Groups["n"].Value -ne $esperadasCategoria) {
      Registrar-Error (
        "temas.html: el epigrafe de '$categoria' dice $($recuento.Groups["n"].Value) fichas " +
        "y las fichas declaran $esperadasCategoria"
      )
    }
  }

  $slugCategoria = Slug-Categoria $categoria
  $inicio = $htmlTemas.IndexOf("id=""listing-t-$slugCategoria""", [StringComparison]::Ordinal)

  if ($inicio -lt 0) {
    Registrar-Error "temas.html: la categoria '$categoria' no tiene su seccion 'listing-t-$slugCategoria'"
    continue
  }

  $fin = $htmlTemas.IndexOf("</section>", $inicio, [StringComparison]::Ordinal)
  if ($fin -lt 0) {
    $fin = $htmlTemas.Length
  }

  $seccion = $htmlTemas.Substring($inicio, $fin - $inicio)
  $enSeccion = ([regex]::Matches($seccion, 'class="quarto-post')).Count
  $fichasEnSecciones += $enSeccion
  if ($enSeccion -ne $esperadasCategoria) {
    Registrar-Error (
      "temas.html: la seccion '$categoria' muestra $enSeccion fichas y las fichas declaran $esperadasCategoria"
    )
  }
}

# Colision de identidad entre fichas.
#
# Hasta ahora solo se comprobaba la unicidad de slug y de alias. Los sinonimos
# y los titulos no se cruzaban, asi que dos fichas podian reclamar el mismo
# termino y la validacion pasaba en limpio. En este corpus eso no es
# hipotetico: el documento de origen trae 12 pares del tipo
# "Backpropagation (Retropropagacion)" / "Retropropagacion (Backpropagation)",
# invisibles a un dedupe por cadena exacta.
function Normalizar-Identidad {
  param([string]$Valor)

  $plano = [string]::Join("", (
    [Globalization.CultureInfo]::InvariantCulture.TextInfo.ToLower($Valor).Normalize(
      [Text.NormalizationForm]::FormD
    ).ToCharArray() | Where-Object {
      [Globalization.CharUnicodeInfo]::GetUnicodeCategory($_) -ne
        [Globalization.UnicodeCategory]::NonSpacingMark
    }
  ))
  $plano = [regex]::Replace($plano, "\([^)]*\)", " ")
  $plano = [regex]::Replace($plano, "[^a-z0-9\s]", " ")
  return [regex]::Replace($plano, "\s+", " ").Trim()
}

$identidades = @{}
foreach ($ficha in $fichas) {
  $nombre = $ficha.Archivo.Name
  $reclamos = @($ficha.Meta["title"]) + @($ficha.Meta["sinonimos"])
  foreach ($reclamo in ($reclamos | Where-Object { $_ })) {
    $clave = Normalizar-Identidad ([string]$reclamo)
    if ([string]::IsNullOrWhiteSpace($clave)) {
      continue
    }
    if ($identidades.ContainsKey($clave) -and $identidades[$clave] -ne $nombre) {
      Registrar-Error (
        "colision de identidad '$reclamo': reclamada por $($identidades[$clave]) y por $nombre"
      )
    }
    else {
      $identidades[$clave] = $nombre
    }
  }
}

if ($errores.Count -gt 0) {
  Write-Host "VALIDACION FALLIDA ($($errores.Count) errores)" -ForegroundColor Red
  foreach ($errorValidacion in $errores) {
    Write-Host "  - $errorValidacion" -ForegroundColor Red
  }
  exit 1
}

Write-Host "VALIDACION CORRECTA" -ForegroundColor Green
Write-Host "  Fichas: $($fichas.Count)"
Write-Host "  Citekeys: $($clavesBib.Count)"
Write-Host "  Slugs derivados y unicos: $($slugVistos.Count)"
Write-Host "  Aliases unicos y generados: $($aliasVistos.Count)"
Write-Host "  Identidades sin colision (titulo + sinonimos): $($identidades.Count)"
Write-Host "  Sinonimos renderizados e indexados: OK"
Write-Host "  Columnas de filtro presentes en el HTML: $columnasComprobadas"
Write-Host "  Matiz de tema en portada, listados y ficha: $($categoriasPermitidas.Count) categorias"
Write-Host "  Temas: $($categoriasPermitidas.Count) secciones con frase, recuento y $fichasEnSecciones pertenencias"
Write-Host "  Indice A-Z: $entradasIndice entradas, con remision para cada sinonimo"
Write-Host "  Estado renderizado: OK"
Write-Host "  Fechas, taxonomia, enlaces y citas: OK"
Write-Host "  Modelo de datos: esquema.lock.yml sha $($lock['esquema-sha']) ($($seccionesObligatorias.Count) secciones obligatorias)"

if ($avisos.Count -gt 0) {
  Write-Host ""
  Write-Host "AVISOS ($($avisos.Count))" -ForegroundColor Yellow
  foreach ($aviso in $avisos) {
    Write-Host "  - $aviso" -ForegroundColor Yellow
  }
}

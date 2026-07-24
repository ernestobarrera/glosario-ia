[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
$raiz = Split-Path -Parent $MyInvocation.MyCommand.Path
$carpetaTerminos = Join-Path $raiz "terminos"
$carpetaSitio = Join-Path $raiz "_site"
$errores = [System.Collections.Generic.List[string]]::new()

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

$taxonomia = Leer-YamlPlano (
  Get-Content -LiteralPath (Join-Path $raiz "taxonomia.yml") -Encoding UTF8 -Raw
)
$categoriasPermitidas = @($taxonomia["categories"])
$estadosPermitidos = @($taxonomia["estados"])
$tiposPermitidos = @($taxonomia["tipos"])

if (
  $categoriasPermitidas.Count -eq 0 -or
  $estadosPermitidos.Count -eq 0 -or
  $tiposPermitidos.Count -eq 0
) {
  Registrar-Error "taxonomia.yml: faltan categories, estados o tipos"
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
$oAguda = [char]0x00F3
$seccionesObligatorias = @(
  "## Definici${oAguda}n ampliada",
  "## Aplicaciones",
  "### Generales",
  "### Sanitarias",
  "## Limitaciones",
  "## Ejemplos",
  "## Relacionados",
  "## Referencias"
)
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
  foreach ($seccion in $seccionesObligatorias) {
    $posicion = $ficha.Cuerpo.IndexOf($seccion, [StringComparison]::Ordinal)
    if ($posicion -lt 0) {
      Registrar-Error "$nombre`: falta la seccion '$seccion'"
    }
    elseif ($posicion -le $ultimaPosicion) {
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

if ($fichas.Count -lt 12 -or $fichas.Count -gt 15) {
  Registrar-Error "El piloto debe contener entre 12 y 15 fichas; contiene $($fichas.Count)"
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
Write-Host "  Sinonimos renderizados e indexados: OK"
Write-Host "  Fechas, taxonomia, enlaces y secciones: OK"

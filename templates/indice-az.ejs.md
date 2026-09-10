```{=html}
<%
// El indice A-Z: las fichas y, ademas, una remision por cada sinonimo en la
// letra que le toca —«Overfitting → Sobreajuste» en la O—.
//
// Por que lo construye la plantilla y no el listado nativo, medido en el ensayo
// del 2026-09-10: un listado por letra si es posible -include admite comodin
// sobre el titulo-, pero no da las remisiones. Una lista de includes no hace OR,
// asi que titulo y sinonimo no caben en el mismo listado; y la plantilla no
// recibe ni template-params ni el id del listado al que sirve, asi que un
// listado de sinonimos por letra no sabria que sinonimo rotular.
//
// Lo que si funciona es esto: la plantilla recibe todos los items, arma las
// entradas, las ordena y las emite PLANAS. Las filas siguen siendo los hijos
// directos de .list, que es lo unico que el filtrado nativo exige, y por eso el
// filtro alcanza tambien a las remisiones. La letra de cabecera viaja dentro de
// la primera entrada de su letra, no como hermana, para no ser un hijo mas.
const inicial = (texto) => {
  const letra = texto.trim().charAt(0).normalize("NFD").charAt(0).toUpperCase();
  // Quarto no coloca las iniciales acentuadas en su letra; aqui se normalizan
  // antes de agrupar, de modo que «Índice de Rand ajustado» cae en la I.
  return letra >= "A" && letra <= "Z" ? letra : "#";
};

const entradas = [];

for (const item of items) {
  entradas.push({
    clave: item.title,
    tipo: "ficha",
    titulo: item.title,
    descripcion: item.description,
    path: item.path,
    sinonimos: item.sinonimos || []
  });

  for (const sinonimo of (item.sinonimos || [])) {
    entradas.push({
      clave: sinonimo,
      tipo: "remision",
      titulo: item.title,
      path: item.path
    });
  }
}

entradas.sort((a, b) => a.clave.localeCompare(b.clave, "es", { sensitivity: "base" }));

const letras = [...new Set(entradas.map((entrada) => inicial(entrada.clave)))];
let letraAbierta = null;
%>
<nav class="az-rail" aria-label="Ir a una letra">
<% for (const letra of letras) { %><a href="#letra-<%= letra.toLowerCase() %>"><%= letra %></a><% } %>
</nav>
<div class="list az-lista">
<% for (const entrada of entradas) {
     const letra = inicial(entrada.clave);
     const abreLetra = letra !== letraAbierta;
     if (abreLetra) { letraAbierta = letra; } %>
  <div class="az-entrada<%= abreLetra ? ' az-abre-letra' : '' %>"<%= abreLetra ? ' id="letra-' + letra.toLowerCase() + '"' : '' %>>
    <% if (abreLetra) { %><span class="az-letra" aria-hidden="true"><%= letra %></span><% } %>
    <% if (entrada.tipo === "ficha") { %>
      <span class="listing-title"><a href="<%- entrada.path %>"><%= entrada.titulo %></a></span>
      <span class="listing-sinonimos"><%= entrada.sinonimos.join(' · ') %></span>
      <span class="listing-description"><%= entrada.descripcion %></span>
    <% } else { %>
      <span class="listing-sinonimos az-remision"><%= entrada.clave %></span>
      <span class="visually-hidden">, véase </span>
      <span class="az-flecha" aria-hidden="true">→</span>
      <span class="listing-title"><a href="<%- entrada.path %>"><%= entrada.titulo %></a></span>
    <% } %>
  </div>
<% } %>
</div>
```

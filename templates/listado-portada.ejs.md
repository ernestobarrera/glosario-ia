```{=html}
<div class="glosario-card-grid list">
<%
// Matiz por tema. Una sola saturacion y una sola luminosidad para los nueve:
// solo gira el tono, de modo que el color signifique la categoria en lugar de
// decorar. El valor viaja como --h y styles.css calcula texto, fondo y borde.
//
// Esta tabla debe cubrir TODAS las categorias de taxonomia.yml. validar.ps1
// comprueba que no falte ninguna: si se anade una categoria y no se le asigna
// matiz, la validacion falla en vez de pintarla en silencio del color por defecto.
const matices = {
  "Fundamentos": 192,
  "Aprendizaje automático": 252,
  "Arquitecturas": 322,
  "Modelos de lenguaje": 34,
  "Procesamiento del lenguaje": 162,
  "Recuperación de información": 212,
  "Seguridad y riesgos": 6,
  "Ética y gobernanza": 288,
  "IA agéntica": 104
};

const matiz = (item) => {
  const primera = item.categories ? item.categories[0] : undefined;
  return matices[primera] !== undefined ? matices[primera] : 192;
};

const inicial = (titulo) => titulo.trim().charAt(0).normalize("NFD").charAt(0).toUpperCase();
%>
<% for (const item of items) { %>
  <article class="glosario-card-item" <%= metadataAttrs(item) %>>
    <a href="<%- item.path %>" class="glosario-card-link" style="--h: <%= matiz(item) %>">
      <div class="glosario-card-cabecera">
        <span class="glosario-monograma" aria-hidden="true"><%= inicial(item.title) %></span>
        <h3 class="no-anchor glosario-card-title listing-title"><%= item.title %></h3>
      </div>
      <p class="glosario-card-description listing-description"><%= item.description %></p>
      <% if (item.sinonimos) { %>
      <p class="glosario-card-sinonimos listing-sinonimos"><%= item.sinonimos.join(" · ") %></p>
      <% } %>
      <% if (item.categories) { %>
      <div class="glosario-card-categorias listing-categories">
        <% for (const categoria of item.categories) { %>
        <span class="listing-category"><%= categoria %></span>
        <% } %>
      </div>
      <% } %>
    </a>
  </article>
<% } %>
</div>
```

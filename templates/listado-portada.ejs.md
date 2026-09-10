```{=html}
<div class="glosario-card-grid list">
<%
// Matiz por tema. El tono ya no se declara aqui: la tabla unica vive en
// styles.css como --h-<categoria en slug>, y esta plantilla solo nombra la
// variable que le corresponde a la primera categoria de la ficha. Antes habia
// una tabla de nueve numeros en este archivo y el color solo existia en la
// portada; ahora los tres sitios que pintan una categoria leen la misma tabla.
//
// Si una categoria nueva no tuviera tono, var() caeria en el 192 de reserva en
// lugar de romper el color. validar.ps1 comprueba que eso no llegue a pasar.
const slug = (categoria) => categoria
  .normalize("NFD")
  .replace(/[̀-ͯ]/g, "")
  .toLowerCase()
  .replace(/[^a-z0-9]+/g, "-")
  .replace(/^-|-$/g, "");

const matiz = (categoria) => `var(--h-${slug(categoria)}, 192)`;

// El monograma toma el tema principal de la ficha, que es la identidad de la
// tarjeta; cada etiqueta toma el suyo, porque una ficha de dos temas llevaba
// las dos etiquetas del color de la primera y eso decia algo que no es cierto.
const matizPrincipal = (item) => {
  const primera = item.categories ? item.categories[0] : undefined;
  return primera ? matiz(primera) : "192";
};

const inicial = (titulo) => titulo.trim().charAt(0).normalize("NFD").charAt(0).toUpperCase();
%>
<% for (const item of items) { %>
  <article class="glosario-card-item" <%= metadataAttrs(item) %>>
    <a href="<%- item.path %>" class="glosario-card-link" style="--h: <%= matizPrincipal(item) %>">
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
        <span class="listing-category" style="--h: <%= matiz(categoria) %>"><%= categoria %></span>
        <% } %>
      </div>
      <% } %>
    </a>
  </article>
<% } %>
</div>
```

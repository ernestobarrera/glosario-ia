```{=html}
<div class="glosario-card-grid list">
<% for (const item of items) { %>
  <article class="glosario-card-item" <%= metadataAttrs(item) %>>
    <a href="<%- item.path %>" class="glosario-card-link">
      <h3 class="no-anchor glosario-card-title listing-title"><%= item.title %></h3>
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

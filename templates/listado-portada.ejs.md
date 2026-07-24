```{=html}
<div class="glosario-card-grid list">
<% for (const item of items) { %>
  <article class="glosario-card-item" <%= metadataAttrs(item) %>>
    <a href="<%- item.path %>" class="glosario-card-link">
      <h3 class="no-anchor glosario-card-title listing-title"><%= item.title %></h3>
      <p class="glosario-card-description listing-description"><%= item.description %></p>
    </a>
  </article>
<% } %>
</div>
```

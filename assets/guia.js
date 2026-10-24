// Guia de uso: muestra los pasos de guia.yml que filters/guia.lua deja en la
// pagina como JSON (#guia-datos).
//
// Nunca se abre sola. La abren dos cosas: el icono de la barra, que aqui se
// intercepta para no recargar la pagina, y ?tour=1 en la direccion, que es lo
// que se comparte con quien llega por primera vez. Por eso no guarda nada en el
// navegador: no hay que recordar quien la vio.
//
// La guia de la portada termina llevando a una ficha al azar con ?desde=portada;
// la de la ficha, abierta asi, no ofrece volver a la parte que se acaba de ver.
//
// Un paso cuyo destino no se ve en esta pantalla se salta. Que el destino exista
// lo garantiza validar.ps1; que se vea depende del ancho, y eso solo se sabe aqui.
(function () {
  "use strict";

  const nodoDatos = document.getElementById("guia-datos");

  if (!nodoDatos) {
    return;
  }

  const guia = JSON.parse(nodoDatos.textContent);
  const parametros = new URLSearchParams(window.location.search);
  const sinMovimiento = window.matchMedia("(prefers-reduced-motion: reduce)").matches;

  let pasos = [];
  let indice = 0;
  let velo = null;
  let foco = null;
  let tarjeta = null;
  let destinoActual = null;
  let focoPrevio = null;
  let marco = 0;

  function visible(el) {
    if (!el || el.getClientRects().length === 0) {
      return false;
    }

    return getComputedStyle(el).visibility !== "hidden";
  }

  // Una seccion entera puede medir mas que la pantalla; se ilumina su epigrafe.
  function zonaDe(el) {
    if (el.tagName === "SECTION") {
      return el.querySelector("h1, h2, h3, h4, h5, h6") || el;
    }

    return el;
  }

  function destinoDe(paso) {
    if (!paso.destino) {
      return null;
    }

    const el = document.querySelector(paso.destino);
    return visible(el) ? zonaDe(el) : undefined;
  }

  // Los enlaces a la portada y a la ficha de ejemplo van relativos a la raiz del
  // sitio; Quarto deja en cada pagina cuanto hay que subir para llegar a ella.
  function rutaDesdeRaiz(ruta) {
    const offset = document.querySelector('meta[name="quarto:offset"]');
    return (offset ? offset.content : "./") + ruta;
  }

  function construir() {
    velo = document.createElement("div");
    velo.className = "guia-velo";
    velo.addEventListener("click", cerrar);

    foco = document.createElement("div");
    foco.className = "guia-foco";
    foco.setAttribute("aria-hidden", "true");

    tarjeta = document.createElement("div");
    tarjeta.className = "guia-tarjeta";
    tarjeta.setAttribute("role", "dialog");
    tarjeta.setAttribute("aria-modal", "true");
    tarjeta.setAttribute("aria-labelledby", "guia-titulo");
    tarjeta.setAttribute("aria-describedby", "guia-texto");
    tarjeta.innerHTML =
      '<div class="guia-cabecera">' +
      '<span class="guia-rotulo"></span>' +
      '<span class="guia-contador"></span>' +
      '<button type="button" class="guia-cerrar" aria-label="Cerrar la guía">×</button>' +
      "</div>" +
      '<h2 class="guia-titulo" id="guia-titulo"></h2>' +
      '<div class="guia-texto" id="guia-texto"></div>' +
      '<div class="guia-pie">' +
      '<a class="guia-vuelve"></a>' +
      '<span class="guia-botones">' +
      '<button type="button" class="btn btn-outline-secondary btn-sm guia-anterior">Anterior</button>' +
      '<button type="button" class="btn btn-outline-secondary btn-sm guia-terminar">Terminar</button>' +
      '<button type="button" class="btn btn-primary btn-sm guia-siguiente">Siguiente</button>' +
      "</span>" +
      "</div>";

    tarjeta.querySelector(".guia-rotulo").textContent = guia.rotulo;
    tarjeta.querySelector(".guia-cerrar").addEventListener("click", cerrar);
    tarjeta.querySelector(".guia-terminar").addEventListener("click", cerrar);
    tarjeta.querySelector(".guia-anterior").addEventListener("click", function () {
      mostrar(indice - 1);
    });
    tarjeta.querySelector(".guia-siguiente").addEventListener("click", function () {
      if (indice < pasos.length - 1) {
        mostrar(indice + 1);
      } else if (guia.continua) {
        continuar();
      } else {
        cerrar();
      }
    });

    document.body.append(velo, foco, tarjeta);
  }

  function colocar() {
    marco = 0;

    if (!tarjeta) {
      return;
    }

    const ancho = window.innerWidth;
    const alto = window.innerHeight;
    const margen = 12;

    if (!destinoActual) {
      foco.hidden = true;
      velo.classList.add("guia-velo-oscuro");
      tarjeta.classList.add("guia-centrada");
      tarjeta.style.left = "";
      tarjeta.style.top = "";
      return;
    }

    velo.classList.remove("guia-velo-oscuro");
    tarjeta.classList.remove("guia-centrada");
    foco.hidden = false;

    const r = destinoActual.getBoundingClientRect();
    const holgura = 6;
    foco.style.left = r.left - holgura + "px";
    foco.style.top = r.top - holgura + "px";
    foco.style.width = r.width + holgura * 2 + "px";
    foco.style.height = r.height + holgura * 2 + "px";

    // En pantalla estrecha la tarjeta ocupa el ancho y va abajo o arriba,
    // donde no tape el destino; en escritorio, junto a el.
    const t = tarjeta.getBoundingClientRect();
    let top;

    if (r.bottom + holgura + margen + t.height <= alto) {
      top = r.bottom + holgura + margen;
    } else if (r.top - holgura - margen - t.height >= 0) {
      top = r.top - holgura - margen - t.height;
    } else {
      top = alto - t.height - margen;
    }

    let left = Math.min(Math.max(margen, r.left), ancho - t.width - margen);
    tarjeta.style.left = Math.max(margen, left) + "px";
    tarjeta.style.top = Math.max(margen, top) + "px";
  }

  function recolocar() {
    if (!marco) {
      marco = requestAnimationFrame(colocar);
    }
  }

  function mostrar(nuevo) {
    indice = Math.max(0, Math.min(nuevo, pasos.length - 1));
    const paso = pasos[indice];
    const ultimo = indice === pasos.length - 1;

    destinoActual = destinoDe(paso);
    tarjeta.querySelector(".guia-contador").textContent = indice + 1 + "/" + pasos.length;
    tarjeta.querySelector(".guia-titulo").textContent = paso.titulo;
    tarjeta.querySelector(".guia-texto").innerHTML = paso.texto;
    tarjeta.querySelector(".guia-anterior").hidden = indice === 0;

    // En el ultimo paso, si la guia continua en otra pagina, ese es el boton
    // principal y «Terminar» queda al lado; si no, el principal termina.
    const siguiente = tarjeta.querySelector(".guia-siguiente");
    siguiente.textContent = !ultimo ? "Siguiente" : guia.continua ? guia.continua.texto + " →" : "Terminar";
    tarjeta.querySelector(".guia-terminar").hidden = !(ultimo && guia.continua);

    const vuelve = tarjeta.querySelector(".guia-vuelve");
    vuelve.hidden = !(ultimo && guia.vuelve && parametros.get("desde") !== guia.vuelve.pagina);

    if (!vuelve.hidden) {
      vuelve.href = rutaDesdeRaiz(guia.vuelve.href);
      vuelve.textContent = guia.vuelve.texto;
    }

    if (destinoActual) {
      destinoActual.scrollIntoView({ block: "center", behavior: sinMovimiento ? "auto" : "smooth" });
    }

    colocar();
    tarjeta.querySelector(".guia-siguiente").focus({ preventScroll: true });
  }

  function continuar() {
    const fichas = guia.continua.fichas;
    const slug = fichas[Math.floor(Math.random() * fichas.length)];
    window.location.href = rutaDesdeRaiz("terminos/" + slug + ".html?tour=1&desde=" + guia.pagina);
  }

  function teclas(evento) {
    if (evento.key === "Escape") {
      cerrar();
    } else if (evento.key === "ArrowRight" && indice < pasos.length - 1) {
      mostrar(indice + 1);
    } else if (evento.key === "ArrowLeft" && indice > 0) {
      mostrar(indice - 1);
    } else if (evento.key === "Tab") {
      // El foco no sale de la tarjeta mientras la guia esta abierta.
      const enfocables = Array.from(tarjeta.querySelectorAll("button, a[href]")).filter(function (el) {
        return !el.hidden;
      });
      const primero = enfocables[0];
      const final = enfocables[enfocables.length - 1];

      if (evento.shiftKey && document.activeElement === primero) {
        evento.preventDefault();
        final.focus();
      } else if (!evento.shiftKey && document.activeElement === final) {
        evento.preventDefault();
        primero.focus();
      }
    }
  }

  function abrir() {
    if (tarjeta) {
      return;
    }

    // Los pasos sin destino siempre; los demas, solo si su destino se ve.
    pasos = guia.pasos.filter(function (paso) {
      return destinoDe(paso) !== undefined;
    });

    if (pasos.length === 0) {
      return;
    }

    focoPrevio = document.activeElement;
    construir();
    document.addEventListener("keydown", teclas);
    window.addEventListener("scroll", recolocar, { passive: true });
    window.addEventListener("resize", recolocar);
    mostrar(0);
  }

  function cerrar() {
    if (!tarjeta) {
      return;
    }

    document.removeEventListener("keydown", teclas);
    window.removeEventListener("scroll", recolocar);
    window.removeEventListener("resize", recolocar);
    velo.remove();
    foco.remove();
    tarjeta.remove();
    velo = foco = tarjeta = destinoActual = null;

    if (focoPrevio && focoPrevio.focus) {
      focoPrevio.focus({ preventScroll: true });
    }
  }

  function iniciar() {
    // En esta pagina hay guia propia: el enlace de la barra la abre aqui en
    // lugar de llevar a la de la portada.
    document.querySelectorAll('#quarto-header a[href*="tour=1"]').forEach(function (enlace) {
      enlace.addEventListener("click", function (evento) {
        evento.preventDefault();
        abrir();
      });
    });

    if (parametros.get("tour") === "1") {
      abrir();
    }
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", iniciar);
  } else {
    iniciar();
  }
})();

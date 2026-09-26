(function () {
  var raiz = document.querySelector("[data-meta]");
  if (!raiz) return;

  var url = raiz.getAttribute("data-meta-url") || "data/meta.json";

  function dinero(n) {
    var negativo = n < 0;
    var abs = Math.abs(n);
    var entero = Math.abs(abs - Math.round(abs)) < 1e-6;
    var partes = (entero ? String(Math.round(abs)) : abs.toFixed(2)).split(".");
    var miles = partes[0].replace(/\B(?=(\d{3})+(?!\d))/g, ",");
    return (negativo ? "-$" : "$") + miles + (partes[1] ? "." + partes[1] : "");
  }

  function fechaValida(s) {
    if (!/^\d{4}-\d{2}-\d{2}$/.test(s)) return false;
    var p = s.split("-");
    var y = Number(p[0]);
    var m = Number(p[1]);
    var d = Number(p[2]);
    var fecha = new Date(Date.UTC(y, m - 1, d));
    return fecha.getUTCFullYear() === y && fecha.getUTCMonth() === m - 1 && fecha.getUTCDate() === d;
  }

  function escribir(selector, texto) {
    var nodos = document.querySelectorAll(selector);
    for (var i = 0; i < nodos.length; i++) nodos[i].textContent = texto;
  }

  function fallo(mensaje) {
    escribir("[data-meta-cifra]", mensaje);
    raiz.setAttribute("aria-busy", "false");
  }

  fetch(url, { credentials: "same-origin", cache: "no-cache" })
    .then(function (res) {
      if (!res.ok) throw new Error("http");
      return res.json();
    })
    .then(function (data) {
      var meta = Number(data.goal_usd);
      var recaudado = Number(data.raised_usd);
      var actualizado = String(data.updated == null ? "" : data.updated);
      if (!isFinite(meta) || meta <= 0 || !isFinite(recaudado) || recaudado < 0 || !fechaValida(actualizado)) {
        fallo("No se pudo leer la cifra de la meta.");
        return;
      }

      var texto = dinero(recaudado) + " de " + dinero(meta);
      var pct = Math.min(100, (recaudado / meta) * 100);
      var ahora = Math.min(recaudado, meta);

      escribir("[data-meta-goal]", dinero(meta));
      escribir("[data-meta-cifra]", texto);
      escribir("[data-meta-fecha]", "Actualizado: " + actualizado);

      var barras = document.querySelectorAll("[data-meta-barra]");
      for (var i = 0; i < barras.length; i++) {
        var barra = barras[i];
        barra.setAttribute("aria-valuemin", "0");
        barra.setAttribute("aria-valuemax", String(meta));
        barra.setAttribute("aria-valuenow", String(ahora));
        barra.setAttribute("aria-valuetext", texto);
        var relleno = barra.querySelector("[data-meta-relleno]");
        if (!relleno) continue;
        if (recaudado <= 0) {
          relleno.classList.add("cero");
          relleno.style.width = "0%";
        } else {
          relleno.classList.remove("cero");
          relleno.style.width = pct + "%";
        }
      }

      raiz.setAttribute("aria-busy", "false");
    })
    .catch(function () {
      fallo("No se pudo leer la cifra de la meta.");
    });
})();

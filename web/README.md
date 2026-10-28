# Página web de CISPPH

`index.html` es la página completa: un solo archivo con el diseño, el contenido y la demostración del simulador. No necesita instalar nada: se abre con doble clic en cualquier navegador.

## Cómo está armada
- **Páginas:** Inicio, Producto, Cómo funciona, Demostración y Nosotros. Cada una es una sección del mismo archivo y se muestra según la dirección (`#inicio`, `#producto`, `#como`, `#demo`, `#nosotros`).
- **Estilos:** al comienzo del archivo, dentro de `<style>`. Los colores se definen una sola vez (variables `--acc`, `--bg`, etc.) y tienen versión clara y oscura.
- **Demostración:** el código del simulador está al final, dentro de `<script>`. Las reglas (`evaluar`), el generador de casos, el mapa dibujado en un `canvas` y las pestañas de usuarios, parqueadero, historial, cámaras y ajustes están separados por comentarios.
- **Documentos:** la lista de la página Nosotros sale de la variable `DOCS`; para agregar uno se añade una línea.

## Cómo editarla
Abra `index.html` en un editor de texto (por ejemplo Visual Studio Code), cambie el texto y recargue el navegador. Para publicarla en internet puede usar GitHub Pages.

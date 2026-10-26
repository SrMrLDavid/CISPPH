# Informe del simulador CISPPH — v4.2

Simulador didáctico del proyecto CISPPH; no es el sistema final.

## Qué cambia
1. **Barra superior corregida.** Los botones se salían de la pantalla (Config., Ayuda, Salir). Ahora la barra tiene tres filas: título y botones; controles de simulación; y los datos (dentro/libres/dinero/estrés) en una fila propia que no empuja los botones. Verificado en captura a 1280×720.
2. **Mejoras visuales pensadas para equipos modestos** (Ajustes > Gráficos):
   - Preajustes: **Equipo antiguo** (calidad baja, resolución 3D al 50 %), **Equilibrado**, **Atmosférico** (filtro VHS + ambiente tenso).
   - **Ambiente tenso:** más oscuro y con más niebla (la niebla también oculta la distancia).
   - **Filtro VHS / cámara de seguridad:** ver v4.1. Aplicado como un solo shader.
3. Durante el apagón la escena se ve desde la cámara de seguridad (antes quedaba mirando una pared de la garita).
4. El subtítulo ya no se encima con los mensajes de dinero/aciertos.

## Pruebas
Prueba punta a punta automatizada (render por software): 0 fallos.

## Sin probar
- **Rendimiento en un equipo antiguo real:** no lo he medido. Los preajustes son una estimación razonable, no una garantía.
- Audio, GPU real, Windows, ratón real.

## Pendiente
- Mapas de centro comercial y parqueadero en altura (esperando tu visto bueno a las reglas provisionales).
- Integrar los documentos de contexto que me vas a pasar.

# Informe del simulador CISPPH — v4.1 (correcciones)

Simulador didáctico del proyecto CISPPH; no es el sistema final.

## Correcciones
1. **Mensajes universales.** Ya no dicen «retengan el carro»: ahora «Detengan a esa persona y que no salga con el vehículo». Los botones dicen «Negar / detener a la persona». También se cambió «carro/coche» por «vehículo» en los mensajes de los residentes y la ayuda.
2. **Cinemática de la policía.** La cámara pasa a la escena de la garita: llega la policía («Alto ahí…»), el ladrón se detiene y luego se lo llevan a pie hacia la calle (segunda toma).
3. **Dueño del vehículo.** Sale del edificio, llega a la escena («¡Ese es mi vehículo! Gracias por detenerlo»), ve cómo se llevan al ladrón y regresa al edificio mientras el vehículo vuelve vacío a su puesto.
4. **Luces azul/rojo.** Se apagan cuando la policía se lleva a la persona (y hay un seguro: nunca duran más de 60 s). Antes el recorrido de salida era muy largo (~40 s) y la cámara no lo seguía.
5. **Filtro opcional «cámara de seguridad / VHS»** (Ajustes > Gráficos): grano, líneas, aberración cromática, viñeta, colores apagados y rótulo «REC CAM-01 + hora». Viene **desactivado**. Es solo un filtro de imagen: no cambia modelos ni texturas.

## Pruebas
Prueba punta a punta (render por software): 0 fallos. La cinemática de la policía y el dueño se vio en capturas; el filtro VHS se vio en una captura del menú.

## Sin probar
Audio, GPU real, Windows, ratón real. El filtro VHS no se midió en rendimiento en un equipo lento.

## Sobre llevar el juego a un estilo tipo Fears to Fathom
- **Puedo hacer** dentro de Godot, sin herramientas externas: filtro VHS (hecho, básico), baja resolución interna (la opción «Resolución 3D» ya existe), niebla, iluminación más oscura/dirigida y cámaras con balanceo.
- **No puedo hacer** desde aquí: generar modelos/texturas con servicios de IA (Meshy, Tripo, Mixamo, etc.); no tengo acceso a esos sitios. Si tú los generas y los importas (.glb/.gltf), puedo integrarlos al juego. Las IA de modelos 3D dan resultados irregulares y a veces con demasiados polígonos: hay que revisarlos.
- Los consejos de la conversación que pegaste son generales; no los verifiqué todos (p. ej. las condiciones de uso y planes gratuitos de cada servicio).

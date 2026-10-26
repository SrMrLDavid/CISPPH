# Informe del simulador CISPPH — v4

Simulador didáctico del proyecto CISPPH (ETITC, Diseño de Software I); no es el sistema final.

## Qué se hizo
1. **Apagón.** Ocurre al azar (cada ~4–7 min de tiempo simulado, se puede desactivar en Config.) o con el botón «Provocar un apagón ahora». Las luces bajan, hay una escena corta en la garita con subtítulos y dura ~75 s simulados.
2. **Sistema caído durante el apagón.** No hay decisión automática, ni citófono, ni veredicto del sistema, ni datos de la base. La tarjeta muestra «SISTEMA CAÍDO — decide tú» y la inspección solo muestra lo que se ve: placas, vehículo, documento que presenta el conductor. Todas las decisiones puntúan (premio o multa) como los casos dudosos.
3. **Enviar a preguntar.** Reemplaza al citófono: espera 10 s reales con «[esperando confirmación…]» y luego muestra la respuesta del residente o «no había a quién consultar».
4. **Estrés.** Barra en la parte superior y viñeta roja que crece. Sube mientras dura el apagón con vehículos esperando y baja con calma. Es solo visual: **no tiene otras consecuencias**.
5. **Monitor de cámaras** (botón 📹): 6 cámaras fijas que solo giran e inclinan (botones o arrastrando, con límites). Se actualiza ~4 veces por segundo y muestra «SIN SEÑAL» durante el apagón.
6. Al volver la luz el sistema se reinicia y reevalúa los vehículos en espera.

## Reglas y límites que conviene saber
- Durante el apagón no se puede permitir la entrada de un desconocido (no hay cómo registrarlo sin sistema); hay que negarlo o preguntar.
- Los tiempos, el estrés y el dinero son valores de juego, no reglas del proyecto.

## Pruebas
Prueba punta a punta (render por software): **0 fallos**, secciones a–o. La sección o cubre apagón, sin automático, sin citófono, preguntar (10 s), estrés, monitor (giro con límite, SIN SEÑAL y recuperación).

## Sin probar / no hecho
- Arrastre con ratón en el monitor y en ventanas; audio; GPU real; Windows.
- La estética del apagón solo se vio en capturas por software.
- **Mapas de centro comercial y parqueadero en altura: NO implementados.** Dependen de reglas (tarifas, tiquetes, pago, flujo) que el equipo debe definir. Si quieres, preparo una lista de preguntas para validarlas con el equipo/docente.

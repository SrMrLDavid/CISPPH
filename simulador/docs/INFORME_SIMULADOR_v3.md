# Informe del simulador CISPPH — v3

Proyecto: CISPPH (ETITC, Diseño de Software I). Esto es un simulador didáctico, no el sistema final.

## Qué se hizo
1. **Incoherencia carro/moto corregida.** Al salir, el caso describía el vehículo principal del usuario aunque en el parqueadero estaba otro. Ahora la placa y el tipo salen del vehículo que realmente está estacionado. Probado.
2. **Personas con brazos, piernas y movimiento** (`persona3d.gd`): guardas, civiles, policía y ladrón.
3. **Conductores a pie.** Al estacionar, el conductor baja y camina a una puerta de edificio (desaparece); al salir, camina desde el edificio a su vehículo y se sube.
4. **Robo / suplantación en la salida.** El ladrón forcejea con el vehículo (cámara orbital), luego la cámara vuelve a la normal y el guarda decide: permitir bajo riesgo propio, negar, o negar y retener. Si retiene: alarma y luces policiales, un policía se lleva al ladrón y el vehículo vuelve vacío a su puesto. (Se eligió la variante «alarma + policía + vehículo devuelto»; no se hizo la del dueño real.)
5. **Dinero del turno.** Retener a un ladrón +$20.000, caso normal +$1.000, dejar salir a un ladrón −$50.000, negar a alguien legítimo −$10.000. **Son valores de juego inventados, no reglas del proyecto.**
6. **Menú inicial** con botones-icono (Iniciar, Mapas, Ajustes con engranaje, Salir).
7. **Ajustes:** volumen general y de efectos, calidad, resolución 3D, pantalla completa, sensibilidad de cámara y reasignación de teclas (se guardan en archivo).
8. **Tarjeta «¿Qué es CISPPH?»** (ventana pequeña abajo a la derecha; al pulsarla se abre). El texto sale de la bitácora; el problema se presenta como hipótesis preliminar del equipo.
9. **Mapas:** solo el conjunto residencial está disponible; centro comercial y parqueadero en altura aparecen bloqueados («no disponible todavía»).
10. **Cinemática de inicio** (Esc la salta): el guarda llega en moto o carro, cambio de turno con el guarda saliente (subtítulos), se sienta en el puesto en primera persona; luego login y ventana «Tareas del turno» en el PC.
11. **Tecla 7:** puesto del guarda en primera persona (clic derecho mira alrededor).

## Pruebas
Prueba punta a punta automatizada (render por software): **0 fallos** en las secciones a–n. Incluye robo, policía, dinero, coherencia de autos/puestos, menú, intro saltada, tareas y reasignación de tecla.

## Sin probar / no hecho
- **Audio:** no puedo oírlo; los sonidos (sirena, dinero, multa) solo se verificaron por código.
- **Arrastre con el ratón** de ventanas y el control de cámara en primera persona: no probados con ratón real.
- **Pantalla completa, GPU real y Windows:** no probados.
- La cinemática se vio en capturas (llegada y cambio de turno), no a velocidad real de GPU.
- El login no tiene aspecto de monitor de PC; es el panel de siempre.
- **No hecho (v4):** apagón/estrés, «enviar a preguntar» (10 s), monitor con cámaras orientables, mapas de centro comercial y parqueadero en altura. Sus reglas (tarifas, tiquetes, pago) las debe validar el equipo.

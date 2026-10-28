# Informe v5 — Integración de los documentos del proyecto

## Qué funciona (probado con la prueba automática: 0 fallos; render con GL por software)
- Caso «Robles del Norte P.H.» (letrero y textos). Escala reducida: 25 puestos de residentes (R-01..R-25) y 15 de visitantes (V-01..V-15); el caso describe 210 y 15.
- Categorías No VIP / VIS / VIP como **definición de trabajo, pendiente de ratificar** (sin tarifas, prioridades ni cupos). Visibles en inspección, historial, usuarios; formulario con «Categoría VIP» y motivo.
- Trazabilidad: cada movimiento guarda categoría y «Registrado por» (guardia/administrador o Automático).
- Contador «Visitantes libres X/15» en el HUD.
- Excepciones del UML: bloqueo de 15 s tras 3 contraseñas incorrectas (demostración); error de conexión simulado (~7 %, la operación no se registra y se reintenta; se desactiva en Config.); expiración de sesión por inactividad (apagada por defecto; se activa en Config.).
- Ventana «Métricas»: tiempo de decisión (promedio/mín/máx), decisiones del guardia vs. automáticas, uso de la inspección, aciertos en casos dudosos, borrador de la tabla §11.1 «Registro de validación del prototipo» (copiar o guardar en CSV/Markdown en la carpeta de datos del juego).

## Limitaciones (sin inventar)
- El tiempo medido incluye el tiempo de pensar de la persona; **no** mide RNF-003 (umbral propuesto, no validado).
- Los participantes, cambios y estado de la tabla de validación los completa el equipo.
- Sin probar: sonido (no puedo oírlo), celular físico, exe de Windows.
- No hecho: modo comparación AS-IS (talonario) vs TO-BE, mapa de sótanos, controles táctiles, reporte por rango de fechas (RF-010 parcial: historial sí, exportar por fechas no).

## Contradicciones entre documentos (para que el equipo las resuelva)
1. «Definición y Validación VIS/VIP/NoVIP» dice validado con la administradora; la Bitácora (28/08) y la Guía de entregables (22/10) dicen que no está aprobado.
2. La Bitácora dice que no hay cliente real y que los cuestionarios fueron simulados; el Caso del Cliente narra una reunión del 20/08 con una administradora con nombre.
3. El Acta de Inicio aún lista PO/SM como pendientes.
4. La Guía dice 17/17 requisitos con evidencia bibliográfica; la Bitácora decía 13/17. Hay fechas distintas entre documentos.
5. La Guía indica que el entregable no exige producto programado (prototipo = mockups navegables): el simulador es un prototipo complementario.

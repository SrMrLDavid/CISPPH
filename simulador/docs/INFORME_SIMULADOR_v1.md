# Informe — Simulador CISPPH v1 (para el creador y para ChatGPT)

Fecha: 22/10/2026 · Proyecto: CISPPH (ETITC, Diseño de Software I, entrega 21/11/2026)
Motor: Godot 4.7.2 (Compatibility) · Carpeta: `cispph-simulador/`

## 1. Qué se hizo
Un simulador 3D **funcional de punta a punta en un solo escenario** (sin cambios de escena): calle de acceso → garita con
barrera de entrada y barrera de salida → parqueadero en circuito de 40 puestos (V-01…V-08 visitantes, R-01…R-32 residentes).
Todo se genera por código (cero archivos de modelos/texturas): ~3 400 líneas de GDScript, proyecto de ~0,3 MB.

Flujo: llega un vehículo → se detiene en la garita → 3 capturas de una cámara 3D (placa delantera, placa trasera, rostro del
conductor) → el sistema busca la placa, compara el rostro (distancia simulada, tolerancia 0,55), revisa turno / autorización /
duplicados / cupo → propone **AUTORIZADO / REVISAR / DENEGADO** → en modo automático ejecuta los claros tras N segundos y deja
los dudosos al guardia; en modo manual decide el guardia → barrera animada → el vehículo se estaciona en su puesto (o se retira
en reversa si se deniega). La salida hace el recorrido inverso (sale del puesto, da la vuelta, llega a la garita de salida).

## 2. Qué se reutilizó de Ecos del Cosmos
- **Protocolo Umbral (puesto de control):** la idea de «casos» con un defecto a detectar (`reglas_puesto.gd`): suplantación,
  documento/placa que no coincide, visitante sin autorización, sin cupo, etc. Se adaptó a `generador_casos.gd` y a las reglas de
  `sistema.gd`. No se copió el código tal cual: el de Ecos trabaja con zonas A01–A12 y relatos de ficción; aquí se reescribió con
  los 40 puestos y los roles del CISPPH.
- **Protocolo CISPPH de Ecos:** roles (residente/trabajador/visitante), citofono, historial, hash SHA-256 y tolerancia 0,55.
- **`rostro_vista.gd`:** rostro caricaturizado procedural (se copió tal cual).

## 3. Qué se probó y cómo (honesto)
- `prueba_sistema.gd` (reglas, sin render): **23 verificaciones, 0 fallos.**
- `prueba_simulador.tscn` (punta a punta, con render por software en Linux/Xvfb): **39 verificaciones, 0 fallos**:
  residente en modo automático, desconocido→citófono→denegado, registro de visitante en la garita y entrada, suplantación en entrada,
  salida normal en modo manual, salida con otro conductor (el auto regresa a su puesto), placa trasera distinta, 8 casos aleatorios
  seguidos sin atascos, coherencia usuarios dentro ↔ puestos ↔ autos, y apertura de todas las ventanas.
- Se miraron capturas de pantalla de: escenario (4 cámaras), garita con vehículo, tarjeta de carril, login, usuarios,
  historial, parqueadero y configuración.

**Lo que NO está probado / no puedo afirmar:**
- No se probó en Windows ni en la tarjeta AMD HD 4300/4500 real; el render se verificó con OpenGL por software (llvmpipe). El
  rendimiento real (FPS) en tu equipo es **desconocido**. Si va lento: Configuración → Calidad gráfica → Baja.
- **No puedo escuchar audio.** Los sonidos (pitidos, obturador, motor de barrera) se generan por código y se reproducen sin
  error, pero no sé cómo suenan.
- No se exportó el .exe (requiere las plantillas de exportación de Godot en tu PC; pasos en el README).
- No se probó con ratón/teclado reales (las pruebas llaman a las mismas funciones que los botones, y se vieron capturas de la UI).
- Los datos se guardan en un JSON local (`user://cispph_datos.json`), **no en SQLite** como describe el documento técnico de Python.

## 4. Qué es simulado (no se debe presentar como real)
- La **lectura de placa** es el texto de la placa del vehículo (no hay OCR).
- El **reconocimiento facial** compara números: misma persona = distancia entre 0,15 y 0,38; persona distinta = 0,62–0,90 (determinista);
  tolerancia 0,55. No hay red neuronal. Los rostros son caricaturas generadas, no fotos de personas.
- El **citófono** responde según el caso generado.

## 5. Lo que NO se implementó a propósito
Según la bitácora (no inventar, hipótesis ≠ hechos): **tarifas, minutos de gracia y clasificación VIS/VIP/No VIP** no están
implementados porque el equipo no los ha validado. El documento técnico menciona 128 puntos faciales con `face_recognition`:
aquí se simula el resultado de la comparación, no el cálculo.

## 6. Cambios respecto al esqueleto del ZIP
- 40 puestos (8 visitantes + 32 residentes) en lugar de 50.
- Se reemplazó la escena simple por un escenario único con garita, dos barreras y circuito.
- 12 usuarios de demostración (8 residentes —incluyen los 3 del README—, 2 trabajadores, 2 visitantes); María, Sofía y Andrés ya
  están dentro al empezar.
- Contraseña inicial admin / admin123 guardada solo como hash SHA-256.

## 7. Cómo se cumple lo del documento técnico
Login con hash ✔ · tipo de ID (CC, CE, Pasaporte + «agregar nuevo tipo») ✔ · registro con cédula, nombre, placa y rostro ✔ (rostro de
registro simulado) · historial con fecha y hora ✔ (con fotos asociadas) · identificación automática en tiempo real ✔ (simulada) ·
persistencia ✔ (JSON, no SQLite).

## 8. Pendientes honestos (si hay tiempo antes del 21/11)
1. Probar en tu PC y en el equipo de la presentación; medir FPS; ajustar calidad por defecto.
2. Exportar el .exe y probarlo en otro computador.
3. Revisar con el equipo si quieren agregar tarifas / VIS-VIP-NoVIP **cuando estén validadas**.
4. Decidir si se presenta la persistencia en JSON o se agrega SQLite (el documento de Python usa SQLite).
5. Pulir audio una vez lo escuches.

## 9. Archivos y reglas
Un único informe para este cambio (este). No se borró nada del proyecto original: el esqueleto del ZIP quedó reemplazado
solo en `scenes/principal.tscn` y `scripts/`. Ecos del Cosmos **no se modificó** en este paso (su Crónica y la entrada 022 siguen
como estaban; se retoma cuando lo indiques).

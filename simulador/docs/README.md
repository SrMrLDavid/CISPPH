# CISPPH — Simulador 3D de control de acceso vehicular

> v5: ver docs/INFORME_SIMULADOR_v5.md y docs/MATRIZ_TRAZABILIDAD_SIMULADOR.md

**Proyecto académico:** Control de Ingreso y Salida para Parqueaderos de Propiedad Horizontal
**Institución:** ETITC · **Asignatura:** Diseño de Software I · **Entrega:** 21/11/2026
**Equipo:** Luis David Caicedo Rodríguez (PO), Edisson David Vargas Castiblanco (SM), Javier Santiago Pérez Tobon (Dev)

Un solo escenario 3D (calle → garita con barreras de entrada y salida → parqueadero en circuito de 40 puestos),
hecho con Godot 4.7 (renderer Compatibility), sin modelos ni texturas externas (todo se genera por código) para que
corra en equipos modestos.

> **Alcance honesto:** la lectura de placa y el reconocimiento facial son **simulados** (didácticos). No hay OCR ni
> reconocimiento facial real. Tarifas, minutos de gracia y clasificación VIS/VIP/No VIP **no están implementados**
> porque el equipo aún no los ha validado.

## Cómo abrirlo
1. Instala Godot 4.7.x (versión estándar, sin .NET): https://godotengine.org
2. Abre `project.godot` con Godot y pulsa **F5** (la escena principal es `scenes/principal.tscn`).
3. Ingresa con **admin / admin123** (se puede cambiar en Configuración; se guarda como hash SHA-256).

Exportar a .exe: *Proyecto → Exportar…* → añade «Windows Desktop» (hay que descargar las plantillas de exportación
una vez) → *Exportar proyecto*. Los datos quedan en `user://` (en Windows: `%APPDATA%\Godot\app_userdata\CISPPH Simulador\`).

## Qué contiene
| Requisito del proyecto | Dónde está |
|---|---|
| Login con hash SHA-256 | Pantalla inicial; `Sistema.hash_clave()` |
| Registro de usuarios (tipo de ID con opción «agregar nuevo tipo», cédula, nombre, placa, rostro) | Usuarios → Registrar |
| Consultar / actualizar / eliminar usuarios | Usuarios → Consultar |
| Clasificación residente / trabajador / visitante / otro | `Sistema.evaluar_acceso()` |
| Cámaras virtuales: placa delantera, placa trasera, rostro | Capturas reales de una cámara 3D (SubViewport) en la garita |
| Reconocimiento facial con tolerancia 0.55 | `Sistema.distancia_rostro()` (simulado) |
| Historial de entradas/salidas con fecha, hora y fotos | Historial |
| Estado del parqueadero (40 puestos: 8 visitantes + 32 residentes) | Parqueadero |
| Modo automático / manual, aviso en segundos configurable | Configuración |
| Inspección del guardia en los casos dudosos (el modo automático NUNCA los decide) | Ventana «Inspección» (se abre sola en REVISAR) |
| Residentes con varios vehículos (placa + aspecto registrados por cada uno) | Usuarios → Consultar → Vehículos registrados |
| Citófono y registro de visitantes con datos precargados del conductor (nombre, documento, apto) | Inspección / botón «Cargar datos del conductor» en Usuarios |
| Ventanas flotantes, arrastrables y redimensionables | Todas las ventanas |
| Barreras de entrada y de salida animadas | Escenario 3D |
| Turnos de trabajadores (mañana 06–14, tarde 14–22) con hora simulada | Barra superior / Configuración |

## Controles
`E` entrada · `S` salida · `Enter` permitir · `Retroceso` denegar · `1` garita · `2` seguridad · `3` aérea ·
`4` libre (clic derecho gira, rueda acerca) · `6` cine · `7` puesto del guarda (primera persona, clic derecho mira alrededor) · `Esc` salta la cinemática. Todas se pueden cambiar en Ajustes.

## Estructura
```
project.godot            Compatibility, autoload Sistema, escena principal
scenes/principal.tscn    Un nodo con scripts/principal.gd (todo lo demás se construye por código)
scripts/sistema.gd       Datos + reglas + persistencia (JSON en user://) — autoload
scripts/escenario3d.gd   Mundo 3D, cámaras, barreras, rutas, capturas
scripts/vehiculo3d.gd    Vehículos procedurales y movimiento
scripts/generador_casos.gd  Casos de acceso (adaptados del «protocolo Umbral» de Ecos del Cosmos)
scripts/principal.gd     Controlador (carriles, decisiones, tráfico)
scripts/interfaz.gd      Toda la interfaz
scripts/audio_sim.gd     Sonidos sintéticos
scripts/persona3d.gd     Personas procedurales con brazos, piernas y animación (guardas, civiles, policía, ladrón)
scripts/icono_menu.gd    Botones-icono del menú (engranaje, play, mapa, salir)
scripts/ajustes.gd       Volumen, gráficos y controles (se guardan en user://cispph_ajustes.cfg)
scripts/rostro_vista.gd  Rostro caricaturizado procedural (de Ecos del Cosmos)
tools/pruebas/           Pruebas: prueba_sistema.gd (reglas), prueba_simulador.tscn (punta a punta), capturas
docs/                    Este README, informes (v1–v4.2) y guía de exposición
```

## Pruebas
- Reglas: `godot --headless --path . --script res://tools/pruebas/prueba_sistema.gd`
- Punta a punta (necesita render; en Linux con `xvfb-run`): `godot --path . res://tools/pruebas/prueba_simulador.tscn`

## Novedades v4
Apagón con sistema caído, enviar a preguntar, estrés y monitor de cámaras orientables (ver INFORME_SIMULADOR_v4.md).

## Novedades v3
Menú inicial, ajustes, tarjeta «¿Qué es CISPPH?», cinemática de inicio y tareas del turno, conductores que caminan al edificio, robo con policía, dinero del turno. Detalle y límites en `INFORME_SIMULADOR_v3.md`.

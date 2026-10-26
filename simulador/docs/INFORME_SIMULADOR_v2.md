# Informe — Simulador CISPPH v2 (para el creador y para ChatGPT)

Fecha: 23/10/2026 · Cambia sobre: v1 (`INFORME_SIMULADOR_v1.md`, que sigue vigente para todo lo no mencionado aquí)

## 1. Qué pediste y qué se hizo
| Pedido | Qué se hizo |
|---|---|
| El momento de decisión del guardia es confuso: falta una forma de inspeccionar cuando la placa/vehículo/conductor no cuadran (un residente con varios coches, alguien que roba un auto). Eso no debe ir en automático. | Ventana **Inspección** que se abre sola en todo caso en REVISAR. El modo automático **nunca** decide esos casos (solo ejecuta los claros y los denegados por regla). |
| Residente con varios coches | Cada usuario puede tener vehículos adicionales (placa + tipo + color). La placa de cualquiera de ellos pertenece al mismo titular. Se agregan en Usuarios → Consultar. Datos de demostración: Carlos tiene CAR-777 y Sofía SOF-204. |
| Poder saber si algo está bien o mal | La Inspección muestra comprobaciones ✔/✘: placa delantera = trasera, placa en la base, **vehículo visto vs registrado para esa placa**, rostro vs titular, **a quién corresponde el rostro en toda la base** (p. ej. «es un trabajador, no el titular»), estado dentro/fuera, turno, autorización, cupo, y la respuesta del citófono. |
| Robo / suplantación | Casos nuevos: placa del residente en vehículo distinto (cambio de carro **o** placa clonada), residente con otra persona al volante (familiar **o** impostor), salida con otra persona al volante (familiar autorizado **o** posible robo, conductor puede ser otro usuario registrado). El citófono al titular confirma o niega. |
| Ventanas arrastrables y de tamaño ajustable | Todas las ventanas son ahora ventanas flotantes (se arrastran por el título, se redimensionan por los bordes, pueden estar varias abiertas y no bloquean el resto). |
| Mostrar nombre, documento y demás datos de quien quiere ingresar para no inventar | Cada conductor presenta documento: la Inspección muestra nombre, tipo y número de documento, apartamento. «Registrar visitante» abre con todo precargado (incluido el residente que confirmó por citófono). En Usuarios → Registrar hay «Cargar datos del conductor que está en la garita» (también copia su rostro de registro). |

Extras: nota opcional del guardia que queda en el historial; los casos con otro conductor anotan «Conductor que presentó documento: …»; retroalimentación didáctica tras decidir un caso dudoso (la simulación sí sabe si era legítimo; un sistema real no) y contador de aciertos en la barra superior.

## 2. Cómo funciona la decisión ahora
1. Llega el vehículo → fotos → el sistema evalúa. Si todo coincide: AUTORIZADO; si una regla lo prohíbe (ya está dentro): DENEGADO; en ambos casos el modo automático ejecuta tras N segundos.
2. Si algo no cuadra: **REVISAR** → se abre la Inspección → el guardia decide (Permitir bajo su responsabilidad / Denegar-retener), con citófono y nota opcionales.
3. Un caso en REVISAR solo se puede permitir si hay un titular registrado, no está duplicado y hay cupo (o, en salida, si está dentro). Un vehículo no registrado se permite únicamente después de registrar al visitante.
4. Denegar una salida sospechosa: el vehículo regresa en reversa a su puesto (queda «retenido» dentro); denegar una entrada: se retira en reversa.

## 3. Qué se probó (honesto)
- Reglas (`prueba_sistema.gd`): 30 verificaciones (se añadieron 7: vehículos adicionales, vehículo distinto, identificar rostro, placa repetida).
- Punta a punta con render por software (`prueba_simulador.tscn`): incluye lo nuevo: segundo coche entra solo en automático, placa con vehículo distinto queda en REVISAR y **espera al guardia aunque el modo sea automático**, se abre y se cierra la ventana de inspección, la inspección marca los puntos en rojo, la nota llega al historial, la retroalimentación cuenta, `datos_garita` trae nombre/documento/placa y la ventana de registro abre precargada.
- Se miró una captura de la ventana de Inspección.
- **No probado:** arrastrar/redimensionar con el ratón real (las ventanas usan el componente estándar de Godot `Window` incrustada; en las pruebas se abren y cierran por código, no las arrastré). Tampoco Windows, la GPU real, ni audio.

## 4. Límites y decisiones a validar con el equipo
- Un usuario solo puede estar con **un** vehículo dentro a la vez (un puesto por usuario). Si una familia debe tener dos coches dentro al mismo tiempo, hay que definir la regla (¿dos puestos?).
- La retroalimentación («acertaste/fallaste») es solo didáctica; puedes ocultarla si no la quieren en la demo (avísame).
- Sigue sin haber tarifas, minutos de gracia ni VIS/VIP/No VIP (sin validar). El reconocimiento facial y la lectura de placa siguen simulados.
- Los nombres y documentos de los conductores aleatorios son inventados por el generador de la simulación (no son datos reales).

## 5. Archivos cambiados
`scripts/sistema.gd` (vehículos adicionales, identificar rostro, vehículo en la evaluación), `scripts/generador_casos.gd` (reescrito: personas, citófono, casos de robo), `scripts/principal.gd` (inspección, notas, retroalimentación), `scripts/interfaz.gd` (ventanas flotantes, ventana de inspección, precargas), `tools/pruebas/*`, `docs/*`. Ecos del Cosmos no se tocó.

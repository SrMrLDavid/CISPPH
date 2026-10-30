# Tablero del proyecto en GitHub (GitHub Projects)

GitHub Projects es el equivalente a Trello dentro de GitHub: un tablero con las tareas del proyecto, su estado y su fase. Este paquete deja listas las **32 tareas** del proyecto (las mismas del Trello, solo información pública: nombre, estado, fase y enlace al documento o carpeta del repositorio).

Archivos:
- `tablero_cispph.csv`: las 32 tareas (título, etapa, fase, enlace, descripción). Se abre con Excel.
- `crear_tablero_github.py`: las carga automáticamente.

## Paso 1. Preparar (una sola vez)

1. Instalar GitHub CLI desde https://cli.github.com
2. En una terminal: `gh auth login` (iniciar sesión con la cuenta SrMrLDavid).
3. `gh auth refresh -s project` (da permiso para manejar Projects).

## Paso 2. Crear el tablero con el script

Desde esta carpeta (`docs/tablero`):

```
python crear_tablero_github.py --dry-run     # prueba: solo muestra lo que hará
python crear_tablero_github.py               # lo crea de verdad
```

Crea el proyecto «C.I.S.P.P.H.», los campos **Etapa** (Por hacer, En curso, Validando, Hecho), **Fase** y **Enlace**, carga las 32 tareas y lo vincula al repositorio. Si falla algún comando, el script se detiene y muestra el mensaje: mándalo tal cual para corregirlo.

> Alternativa sin script: en https://github.com/SrMrLDavid → pestaña **Projects** → **New project** → plantilla **Board**; agrega los campos con **+** y pega las tareas con «Add item» (se puede copiar la columna de títulos del CSV).

## Paso 3. Crear las vistas (en el navegador, 2 minutos)

El script no crea vistas; se hacen así dentro del proyecto, como las del tablero del docente:

| Vista | Cómo se hace |
|---|---|
| **Reserva** | Tabla. Muestra todas las tareas con sus campos |
| **Junta** | **+ New view** → Board → menú de la vista → *Column field*: **Etapa** |
| **Iteración actual** | Tabla filtrada: `etapa:"En curso"` |
| **Hoja de ruta** | **+ New view** → Roadmap (necesita una fecha: agregar el campo *Fecha* y poner la de entrega, 21/11/2026) |
| **Mis artículos** | Tabla con filtro `assignee:@me` |

Para la vista Junta, quita las columnas vacías que no uses y deja: Por hacer, En curso, Validando, Hecho. Recuerda que **solo el docente marca «Hecho»**.

## Paso 4. Que el docente lo vea

Dos opciones:
- **Privado con invitación:** Proyecto → **⋯ → Settings → Manage access** → invitar al usuario de GitHub del docente (hay que preguntarle su usuario).
- **Público:** Settings → **Visibility → Public**. Solo hay información que ya es pública en el repositorio.

## Mantenerlo al día

Cada vez que una tarea cambie de estado, se mueve la tarjeta en la vista Junta (o se cambia el campo Etapa). Conviene que coincida con Trello.

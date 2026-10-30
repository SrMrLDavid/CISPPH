# Tablero de C.I.S.P.P.H. en GitHub Projects

Este tablero organiza el trabajo del proyecto igual que el Trello del equipo: cada **tarea** es una tarjeta que avanza por etapas hasta que el docente la valida.

## ¿Qué es la vista «Junta»?

«Junta» es la traducción al español de GitHub de **Board**, es decir, el **tablero Kanban**: columnas con tarjetas que se mueven de izquierda a derecha. No tiene relación con una reunión. Las otras vistas muestran las mismas tareas de otra forma:

| Vista | Para qué sirve en CISPPH |
|---|---|
| **Reserva** (Backlog) | Tabla con las 32 tareas, para buscar, ordenar y filtrar |
| **Junta** (Board) | Las tarjetas en columnas por etapa; se arrastran al avanzar |
| **Iteración actual** | Solo lo que se está trabajando en el sprint |
| **Hoja de ruta** (Roadmap) | Línea de tiempo hasta la entrega del 21/11/2026 |
| **Mis artículos** | Las tareas asignadas a cada integrante |

## Columnas de la Junta

| Etapa | Significado | Ejemplo |
|---|---|---|
| **Por hacer** | Aún no se ha empezado | Observación Directa |
| **En curso** | Alguien del equipo la está trabajando | Estado del Arte |
| **Validando** | El equipo la terminó y espera la revisión del docente | Acta de Inicio |
| **Hecho** | El docente la validó (solo el docente la marca) | — |

## Campos de cada tarjeta

- **Etapa:** la columna en la que está.
- **Fase:** el bloque del proyecto, de «01 Inicio y planeación» a «12 Página web».
- **Enlace:** el documento o carpeta del repositorio donde está el entregable.

## Cómo se usa

1. Al empezar una tarea, se arrastra la tarjeta de *Por hacer* a *En curso*.
2. Al terminarla y subir el entregable al repositorio, pasa a *Validando*.
3. El docente la revisa y, si está bien, la pasa a *Hecho*.
4. El estado debe coincidir con el del Trello del equipo.

## Relación con el resto del repositorio

- Los entregables están en [`docs/documentos/`](../documentos/).
- El código está en [`simulador/`](../../simulador/), [`sistema-python/`](../../sistema-python/) y [`prototipo-arduino/`](../../prototipo-arduino/).
- Para crear el tablero, ver [`GUIA_TABLERO_GITHUB.md`](GUIA_TABLERO_GITHUB.md).

**Equipo:** Luis David Caicedo Rodríguez (Product Owner) · Edisson David Vargas Castiblanco (Scrum Master) · Javier Santiago Pérez Tobon (Developer) · **Docente:** José Del Carmen Ortega Castro

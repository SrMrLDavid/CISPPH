# Trazabilidad simulador ↔ requisitos (orientativa; revisar contra el Anexo A.3)
Estado: ✔ cubierto en el simulador · ◐ parcial · ✘ no cubierto. Los números RF/RNF/CU son los de los documentos; esta matriz es una lectura mía y debe validarla el equipo.

| Función del simulador | Referencia | Estado |
|---|---|---|
| Registro de entrada/salida con decisión del guardia | RF-001..RF-004 (lectura) | ✔ |
| Gestión de usuarios y vehículos, edición | RF (usuarios) | ✔ |
| Categorías No VIP/VIS/VIP | definición de trabajo | ◐ (sin tarifas) |
| Disponibilidad de puestos de visitantes | RF-005 | ✔ (HUD) |
| Historial y consulta | RF-009/010 | ◐ (sin exportar por fechas) |
| Trazabilidad: quién registró | RNF-006 | ✔ |
| Excepciones: sesión expirada, error de conexión, 3 intentos | UML | ✔ (demostración) |
| Tiempo de decisión | RNF-003/004 | ◐ (no equivale a la medición del sistema) |
| Reportes, notificaciones, pagos | — | ✘ |

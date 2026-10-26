# Guía rápida para exponer el simulador (5–7 min)

1. **Qué es (30 s):** «Simulador 3D de un parqueadero de propiedad horizontal con control de ingreso y salida: placa, rostro, base de
   datos e historial.» Aclara desde el inicio que placa y rostro están **simulados**.
2. **Login (30 s):** admin / admin123. «La clave se guarda como hash SHA-256, nunca en texto.»
3. **Operación (2 min):** pulsa *Generar entrada*. Muestra las 3 fotos, la comparación de rostro (capturado vs registrado) y el
   banner AUTORIZADO. En modo Automático se ejecuta solo; la barrera sube y el auto se estaciona.
4. **Un caso dudoso (1.5 min):** genera hasta que salga REVISAR (conductor distinto, vehículo distinto al registrado, placa no registrada…).
   Se abre sola la ventana **Inspección**: muestra quién conduce y su documento, el titular y sus vehículos registrados, y ✔/✘ por cada comprobación.
   Explica que el modo automático **nunca** decide estos casos: decide el guardia (llama por **citófono**, deja una nota, Permitir o Denegar).
   Con un vehículo no registrado confirmado por citófono, usa *Registrar visitante* (viene precargado). Las ventanas se arrastran y se redimensionan.
5. **Salida (30 s):** *Generar salida*: el auto sale del puesto, llega a la garita de salida, se registra y el puesto queda libre.
6. **Administración (1 min):** Usuarios (registrar con «agregar nuevo tipo» de documento; consultar/actualizar/eliminar),
   Historial (filtros y fotos), Parqueadero (40 puestos), Configuración (modo, segundos, cambiar clave).
7. **Cierre (30 s):** límites — reconocimiento simulado; tarifas y VIS/VIP/No VIP **no implementados porque aún no se validan**;
   siguiente paso: reconocimiento real (como en el documento técnico con `face_recognition`) y SQLite.

Consejos: usa velocidad ×2 para que no se haga larga la espera; teclas 1–4 y 6 cambian de cámara; Calidad gráfica → Baja si el PC va justo.

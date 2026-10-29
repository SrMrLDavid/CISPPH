"""
=============================================================================
SISTEMA INTELIGENTE DE CONTROL DE ACCESO VEHICULAR - PRO FINAL
=============================================================================
Descripción General:
    Aplicación de escritorio desarrollada en Python utilizando CustomTkinter (GUI) 
    y OpenCV (procesamiento de video y captura biométrica). Está diseñada para 
    gestionar el control de acceso vehicular en conjuntos residenciales o corporativos.

Librerías y Módulos Utilizados:
    - os / pathlib: Interacción con el sistema de archivos y rutas multiplataforma.
    - sys / platform: Detección del sistema operativo (Windows, Linux, macOS).
    - hashlib: Generación de hash SHA-256 para contraseñas de acceso.
    - pickle: Serialización de encodings faciales para guardarlos en la base de datos.
    - sqlite3: Motor de base de datos relacional ligero para usuarios, movimientos y configuración.
    - datetime: Gestión y formato de fechas y marcas de tiempo.
    - threading: Ejecución de hilos en paralelo (worker de video) para no bloquear la GUI.
    - time: Pausas y control de tiempos.
    - cv2 (OpenCV): Captura y procesamiento de fotogramas de video.
    - customtkinter (ctk): Interfaz gráfica moderna con soporte nativo de Modo Oscuro.
    - PIL (Pillow): Manipulación y redimensionado de imágenes para la interfaz.
    - face_recognition: Reconocimiento facial (basado en dlib) para extracción y comparación de rostros.
    - numpy: Soporte numérico requerido por face_recognition.

Pestañas de la Interfaz:
    1. Operación & Monitoreo: Transmisión en vivo de la cámara y validación biométrica facial.
    2. Gestión de Usuarios: Registro biométrico, consulta detallada y actualización/eliminación.
    3. Estado Parqueadero: Historial completo de todos los movimientos de entrada y salida.

Mejoras de la versión 1.1 (integración con el simulador C.I.S.P.P.H.):
    - Las reglas de acceso y la base de datos viven en nucleo.py (con pruebas automáticas).
    - Categorías No VIP / VIS / VIP, cupo de visitantes, bloqueo tras 3 intentos fallidos,
      revisión del guarda y registro de las decisiones denegadas.
    - Opcional: puente con Arduino (puente_arduino.py) para abrir la pluma.

Mejoras de la versión 1.0:
    - Encodings faciales pre-calculados y almacenados en la BD (alto rendimiento).
    - Login de seguridad al inicio.
    - Sonido multiplataforma.
    - Manejo robusto de fallos de cámara.
    - Historial completo de entradas/salidas (cada movimiento es un registro independiente).
    - Formulario de registro se limpia automáticamente.
    - Inicio maximizado automático.

Autor: Desarrollado para Arquitectura de Software Pro
Versión: 1.1.0 - Comentarios Detallados + Historial Completo + Reglas del simulador
=============================================================================
"""

import os
import sys
import platform
import hashlib
import pickle
import sqlite3
import datetime
import threading
import time
from pathlib import Path

# Oculta advertencias innecesarias de OpenCV en consola
os.environ["OPENCV_LOG_LEVEL"] = "ERROR"

import cv2
import customtkinter as ctk
import tkinter as tk
from tkinter import messagebox
from PIL import Image
try:
    import face_recognition
    import numpy as np
    HAY_ROSTROS = True
except Exception:                       # si dlib no se pudo instalar, el programa abre igual y se opera en modo manual
    face_recognition = None
    np = None
    HAY_ROSTROS = False

from placa_ocr import LectorPlacas      # lectura automática de placas (EasyOCR o Tesseract, opcional)
from porteria import Porteria       # pluma y pantalla de la portería (virtuales, con Arduino opcional)
import nucleo                       # reglas de acceso y base de datos (sin cámara ni GUI)
from nucleo import hash_password   # SHA-256 de la clave

# =========================================================================
# CONFIGURACIÓN VISUAL Y CONSTANTES GLOBALES
# =========================================================================
ctk.set_appearance_mode("Dark")                  # Modo oscuro por defecto
ctk.set_default_color_theme("blue")              # Tema de color azul corporativo

# Rutas base del sistema (multiplataforma gracias a pathlib)
BASE_DIR = Path(os.environ.get("CISPPH_HOME", Path(__file__).resolve().parent))   # CISPPH_HOME permite cambiar la carpeta de datos (p. ej. en pruebas)
DATA_DIR = BASE_DIR / "data"                             # Carpeta data para la base de datos
CONFIG_DIR = BASE_DIR / "config"                         # Carpeta config para los archivos de texto
DB_FILE = DATA_DIR / "acceso_vehicular_pro.db"           # Archivo de la base de datos dentro de /data
FOTOS_DIR = BASE_DIR / "fotos_usuarios"                  # Carpeta de fotos de rostros
TXT_TIPOS_ID = CONFIG_DIR / "Tipo_ID.TXT"                # Archivo auxiliar de tipos de ID dentro de /config
TIEMPO_POPUP_FILE = CONFIG_DIR / "tiempo_popup.txt"      # Duración del popup dentro de /config

# Crear las carpetas data, config y fotos si no existen
DATA_DIR.mkdir(exist_ok=True)
CONFIG_DIR.mkdir(exist_ok=True)
FOTOS_DIR.mkdir(exist_ok=True)

# Credenciales por defecto del sistema (cambiar en producción)
DEFAULT_USER = "admin"
DEFAULT_PASS = "admin123"

# Parámetros de reconocimiento y video
FACE_TOLERANCE = 0.55          # Tolerancia de comparación facial (0.0 = estricto, 1.0 = permisivo)
VIDEO_WIDTH = 640              # Ancho del stream de video
VIDEO_HEIGHT = 480             # Alto del stream de video

# Crear carpeta de fotos si no existe
FOTOS_DIR.mkdir(exist_ok=True)


# =========================================================================
# UTILIDADES CROSS-PLATFORM Y DE SEGURIDAD
# =========================================================================
def play_sound(success: bool = True):
    """
    Reproduce un tono de éxito o error de forma multiplataforma.
    - Windows: usa winsound.Beep con frecuencias acústicas diferenciadas.
    - Linux / macOS: usa el carácter de campana (\a) del sistema como respaldo.
    """
    try:
        if platform.system() == "Windows":
            import winsound
            if success:
                # Tono acústico dual ascendente para indicar validación positiva
                winsound.Beep(880, 300)
                time.sleep(0.05)
                winsound.Beep(1174, 350)
            else:
                # Tono acústico grave para indicar error o rechazo
                winsound.Beep(300, 500)
        else:
            # Fallback para sistemas Unix / macOS mediante señal audible de consola
            print("\a" if success else "\a\a")
    except Exception:
        pass


def get_connection():
    """Devuelve una conexión SQLite simple (filas como tuplas) para las consultas de la interfaz."""
    import sqlite3
    return sqlite3.connect(DB_FILE)


def init_db():
    """Crea o migra la base de datos usando el núcleo (agrega las columnas nuevas si faltan)."""
    cn = nucleo.conectar(DB_FILE)
    nucleo.iniciar_db(cn)
    sincronizar_txt_tipos(cn)
    cn.close()


def sincronizar_txt_tipos(conn):
    """
    Exporta y sincroniza la lista de tipos de identificación almacenados en la base de datos 
    hacia un archivo de texto plano externo (Tipo_ID.TXT) para consumo auxiliar.
    """
    cursor = conn.cursor()
    cursor.execute("SELECT nombre_tipo FROM tipos_identificacion")
    tipos = cursor.fetchall()
    with open(TXT_TIPOS_ID, "w", encoding="utf-8") as f:
        for t in tipos:
            f.write(t[0] + "\n")


# Ejecutar la inicialización de la base de datos al arrancar el módulo
init_db()


# =========================================================================
# CLASE WORKER DE VIDEO (CAPTURA EN HILO SEPARADO)
# =========================================================================
class VideoCaptureWorker:
    """
    Clase encargada del procesamiento asíncrono de video.
    Lee los fotogramas de la cámara en un hilo secundario e independiente (Thread) 
    para evitar congelamientos o retrasos (*lag*) en la interfaz gráfica principal.
    Incluye lógica de detección de pérdidas de señal y reconexión.
    """

    def __init__(self):
        self.cap = None                  # Instancia del objeto VideoCapture de OpenCV
        self.current_frame = None        # Buffer que almacena la copia del último fotograma
        self.is_running = False          # Bandera de control para el bucle de captura
        self.lock = threading.Lock()     # Bloqueo mutex para evitar condiciones de carrera entre hilos
        self.cam_index = None            # Índice del dispositivo de video en uso
        self.error_count = 0             # Contador de fallos consecutivos en lectura de fotogramas

    def list_cameras(self, max_index=6):
        """
        Prueba secuencialmente los índices de video disponibles (0 a max_index-1) 
        y retorna una lista con los índices que responden correctamente.
        """
        disponibles = []
        for i in range(max_index):
            cap = cv2.VideoCapture(i, cv2.CAP_ANY)
            if cap.isOpened():
                ret, frame = cap.read()
                if ret and frame is not None:
                    disponibles.append(i)
                cap.release()
        return disponibles

    def start(self, cam_index):
        """
        Inicializa la cámara seleccionada e inicia el hilo secundario de captura.
        Si ya existía un stream corriendo, lo detiene primero.
        """
        self.stop()
        self.cam_index = cam_index
        self.error_count = 0
        try:
            self.cap = cv2.VideoCapture(cam_index, cv2.CAP_ANY)
            self.cap.set(cv2.CAP_PROP_FRAME_WIDTH, VIDEO_WIDTH)
            self.cap.set(cv2.CAP_PROP_FRAME_HEIGHT, VIDEO_HEIGHT)
            if self.cap.isOpened():
                self.is_running = True
                # Iniciar el hilo demonio para la captura en segundo plano
                threading.Thread(target=self._capture_loop, daemon=True).start()
                return True
        except Exception as e:
            print(f"[Video] Error al abrir cámara {cam_index}: {e}")
        return False

    def _capture_loop(self):
        """Bucle continuo que ejecuta el hilo secundario para refrescar el fotograma en memoria."""
        while self.is_running and self.cap and self.cap.isOpened():
            try:
                ret, frame = self.cap.read()
                if ret and frame is not None:
                    with self.lock:
                        self.current_frame = frame.copy()
                    self.error_count = 0
                else:
                    self.error_count += 1
                    time.sleep(0.05)
                    # Si la cámara falla repetidamente, se interrumpe la captura por seguridad
                    if self.error_count > 30:
                        break
            except Exception:
                self.error_count += 1
                time.sleep(0.1)
        self.is_running = False

    def get_frame(self):
        """Retorna una copia del fotograma actual de manera segura mediante el bloqueo mutex."""
        with self.lock:
            return self.current_frame.copy() if self.current_frame is not None else None

    def stop(self):
        """Detiene el bucle de captura y libera los recursos de la cámara activa."""
        self.is_running = False
        time.sleep(0.15)
        if self.cap is not None:
            try:
                self.cap.release()
            except Exception:
                pass
            self.cap = None


# =========================================================================
# APLICACIÓN PRINCIPAL
# =========================================================================
class AppAccesoVehicularFinal(ctk.CTk):
    """
    Clase de la aplicación principal que hereda de CustomTkinter (CTk).
    Controla el ciclo de vida de la GUI, autenticación de usuarios, captura biométrica,
    reconocimiento facial y la gestión de la base de datos.
    """

    def __init__(self):
        super().__init__()

        # Configuración dimensional básica de la ventana principal
        self.title("Sistema Inteligente de Control de Acceso Vehicular - Pro Final")
        self.geometry("1300x800")
        self.minsize(1100, 700)

        # Programar la maximización automática de la ventana tras cargarse la GUI
        self.after(100, self._maximizar)

        # Instanciar el trabajador de video y detectar cámaras en el sistema
        self.video_worker = VideoCaptureWorker()
        self.camaras_disponibles = self.video_worker.list_cameras()
        self.camara_actual_index = None
        self.autenticado = False
        self.intentos = nucleo.ControlIntentos()   # bloqueo tras 3 fallos seguidos
        self.puente = None                          # puente opcional con Arduino (ver puente_arduino.py)
        puerto = os.environ.get("CISPPH_ARDUINO_PORT")   # ej. COM3 o /dev/ttyUSB0
        if puerto:
            try:
                from puente_arduino import PuenteArduino
                self.puente = PuenteArduino(puerto)
            except Exception as e:                  # sin pyserial o sin placa: el sistema sigue funcionando
                print(f"Arduino no disponible ({e}); se continúa sin pluma física.")

        self.lector_placas = None                   # se carga en segundo plano para no demorar la ventana
        threading.Thread(target=self._cargar_lector_placas, daemon=True).start()
        self.porteria = Porteria(self.puente)       # pluma y LCD virtuales; también mueven el Arduino si existe

        # Mostrar primero la pantalla de inicio de sesión de seguridad
        self._mostrar_login()

    def _maximizar(self):
        """Aplica comandos del sistema operativo para desplegar la ventana maximizada."""
        try:
            if platform.system() == "Windows":
                self.state("zoomed")
            else:
                self.attributes("-zoomed", True)
        except Exception:
            try:
                self.attributes("-fullscreen", False)
                self.state("normal")
                self.update_idletasks()
                w = self.winfo_screenwidth()
                h = self.winfo_screenheight()
                self.geometry(f"{w}x{h}+0+0")
            except Exception:
                pass

    # -----------------------------------------------------------------
    # LOGIN DE SEGURIDAD
    # -----------------------------------------------------------------
    def _mostrar_login(self):
        """Dibuja el panel centralizado para el acceso protegido por contraseña."""
        self.login_frame = ctk.CTkFrame(self, corner_radius=15)
        self.login_frame.place(relx=0.5, rely=0.5, anchor="center")

        ctk.CTkLabel(
            self.login_frame,
            text="Acceso al Sistema",
            font=("Arial", 22, "bold")
        ).pack(pady=(30, 20))

        ctk.CTkLabel(self.login_frame, text="Usuario:").pack()
        self.txt_user = ctk.CTkEntry(self.login_frame, width=280, height=35)
        self.txt_user.pack(pady=5)
        self.txt_user.insert(0, DEFAULT_USER)

        ctk.CTkLabel(self.login_frame, text="Contraseña:").pack(pady=(10, 0))
        self.txt_pass = ctk.CTkEntry(self.login_frame, width=280, height=35, show="*")
        self.txt_pass.pack(pady=5)

        self.lbl_login_error = ctk.CTkLabel(
            self.login_frame, text="", text_color="#E74C3C"
        )
        self.lbl_login_error.pack(pady=5)

        ctk.CTkButton(
            self.login_frame,
            text="Ingresar",
            width=200,
            height=40,
            command=self._validar_login
        ).pack(pady=20)

        # Enlazar la tecla Enter/Return a la acción de validación
        self.txt_pass.bind("<Return>", lambda e: self._validar_login())

    def _validar_login(self):
        """Verifica las credenciales ingresadas contra los hashes guardados en la tabla config."""
        user = self.txt_user.get().strip()
        pwd = self.txt_pass.get().strip()

        conn = get_connection()
        cur = conn.cursor()
        cur.execute("SELECT valor FROM config WHERE clave = 'admin_user'")
        db_user = cur.fetchone()[0]
        cur.execute("SELECT valor FROM config WHERE clave = 'admin_hash'")
        db_hash = cur.fetchone()[0]
        conn.close()

        # Compara el usuario y la contraseña cifrada mediante SHA-256
        if user == db_user and hash_password(pwd) == db_hash:
            self.autenticado = True
            self.login_frame.destroy()
            self._construir_interfaz()
        else:
            self.lbl_login_error.configure(text="Usuario o contraseña incorrectos")
            play_sound(False)

    def _construir_interfaz(self):
        """Instancia los componentes visuales principales y las pestañas una vez autenticado."""
        self.tabview = ctk.CTkTabview(self)
        self.tabview.pack(padx=20, pady=20, fill="both", expand=True)

        self.tab_operacion = self.tabview.add(" Operación & Monitoreo ")
        self.tab_gestion = self.tabview.add(" Gestión de Usuarios ")
        self.tab_estado = self.tabview.add(" Estado Parqueadero ")

        self.setup_tab_operacion()
        self.setup_tab_gestion_usuarios()
        self.setup_tab_estado_parqueadero()

        # Iniciar la cámara predeterminada si se detectó alguna
        if self.camaras_disponibles:
            self.video_worker.start(self.camaras_disponibles[0])
            self.camara_actual_index = self.camaras_disponibles[0]

        self.update_video_ui()

    # -----------------------------------------------------------------
    # PESTAÑA 1: OPERACIÓN & MONITOREO
    # -----------------------------------------------------------------
    def setup_tab_operacion(self):
        """Construye los controles y el panel de visualización en la pestaña de Operación."""
        # Panel izquierdo: desplegado del feed de video
        self.frame_cam = ctk.CTkFrame(
            self.tab_operacion, width=560, fg_color="#181818", corner_radius=12
        )
        self.frame_cam.pack(side="left", padx=15, pady=15, fill="y")
        self.frame_cam.pack_propagate(False)

        ctk.CTkLabel(
            self.frame_cam,
            text="Monitoreo de Cámara Activa",
            font=("Arial", 14, "bold")
        ).pack(pady=(15, 5))

        self.lbl_video = ctk.CTkLabel(
            self.frame_cam,
            text="Iniciando video...",
            fg_color="#121212",
            corner_radius=8,
            width=520,
            height=390
        )
        self.lbl_video.pack(padx=20, pady=10)

        # Panel derecho: botones de acción, consola de eventos y selección de modo
        frame_right = ctk.CTkFrame(
            self.tab_operacion, fg_color="#212121", corner_radius=12
        )
        frame_right.pack(side="right", padx=15, pady=15, fill="both", expand=True)

        ctk.CTkLabel(
            frame_right,
            text="Panel de Operación Pro",
            font=("Arial", 18, "bold")
        ).pack(pady=(20, 10))

        # Dropdown para selección de cámara
        ctk.CTkLabel(
            frame_right,
            text="Seleccionar Dispositivo de Video:",
            font=("Arial", 12, "bold"),
            text_color="#2ECC71"
        ).pack(anchor="w", padx=25, pady=(5, 2))

        opciones = (
            [f"Cámara (Índice {i})" for i in self.camaras_disponibles]
            if self.camaras_disponibles
            else ["No se detectaron cámaras"]
        )
        self.combo_camaras = ctk.CTkOptionMenu(
            frame_right,
            values=opciones,
            width=350,
            height=35,
            command=self.cambiar_camara
        )
        self.combo_camaras.pack(padx=20, pady=5)
        if self.camaras_disponibles:
            self.combo_camaras.set(opciones[0])

        self.entry_url = ctk.CTkEntry(
            frame_right, width=350, height=30,
            placeholder_text="O pegue la dirección de una cámara IP (rtsp:// o http://)"
        )
        self.entry_url.pack(padx=20, pady=(5, 0))
        ctk.CTkButton(
            frame_right, text="Conectar cámara por dirección", fg_color="#444444",
            hover_color="#333333", height=30, command=self.conectar_camara_url
        ).pack(padx=20, pady=5)

        ctk.CTkButton(
            frame_right,
            text="🔍 Buscar Nuevas Cámaras",
            fg_color="#444444",
            hover_color="#333333",
            height=30,
            command=self.refrescar_camaras
        ).pack(padx=20, pady=5)

        # Selector de dirección de control (Entrada / Salida)
        ctk.CTkLabel(
            frame_right,
            text="Punto de Control:",
            font=("Arial", 12, "bold")
        ).pack(anchor="w", padx=25, pady=(15, 2))

        self.combo_modo = ctk.CTkOptionMenu(
            frame_right,
            values=["Entrada", "Salida"],
            width=350,
            height=35
        )
        self.combo_modo.pack(padx=20, pady=5)

        # Placa del vehículo (opcional): si se escribe, debe coincidir con la registrada a la persona
        self.entry_placa = ctk.CTkEntry(
            frame_right, width=350, height=35,
            placeholder_text="Placa del vehículo (opcional), ej. ABC-123"
        )
        self.entry_placa.pack(padx=20, pady=5)
        ctk.CTkButton(
            frame_right, text="Leer placa con la cámara", fg_color="#444444",
            hover_color="#333333", height=30, command=self.leer_placa_ahora
        ).pack(padx=20, pady=(0, 5))

        # Botón para activar el escaneo facial y procesar el movimiento
        self.btn_validar = ctk.CTkButton(
            frame_right,
            text="Validar Rostro / Registrar Movimiento",
            fg_color="#1F6AA5",
            hover_color="#144870",
            height=45,
            font=("Arial", 13, "bold"),
            command=self.ejecutar_reconocimiento
        )
        self.btn_validar.pack(padx=20, pady=(20, 6))

        # Ingreso manual (sin cámara) y modo de contingencia
        frame_manual = ctk.CTkFrame(frame_right, fg_color="#2D2D2D", corner_radius=8)
        frame_manual.pack(padx=20, pady=(0, 10), fill="x")
        self.entry_manual = ctk.CTkEntry(
            frame_manual, width=230, height=32, placeholder_text="Cédula o placa (ingreso manual)")
        self.entry_manual.pack(side="left", padx=(10, 6), pady=8)
        ctk.CTkButton(frame_manual, text="Validar manual", width=110, height=32, fg_color="#7D6608",
                      hover_color="#5C4A06", command=self.validar_manual).pack(side="left", padx=4, pady=8)
        self.sw_contingencia = ctk.CTkSwitch(frame_manual, text="Contingencia", command=self.toggle_contingencia)
        self.sw_contingencia.pack(side="left", padx=10, pady=8)
        ctk.CTkButton(frame_right, text="🚨 Reportar novedad (robo, sospecha, falla)", height=30, fg_color="#7B241C",
                      hover_color="#5B1B15", command=self.reportar_novedad).pack(padx=20, pady=(0, 6))
        self.lbl_contingencia = ctk.CTkLabel(frame_right, text="", text_color="#F39C12", font=("Arial", 12, "bold"))
        self.lbl_contingencia.pack()
        cn = nucleo.conectar(DB_FILE)
        if nucleo.contingencia_activa(cn):
            self.sw_contingencia.select()
            self.lbl_contingencia.configure(text="CONTINGENCIA ACTIVA")
        cn.close()

        # Contenedor visual del estado del sistema
        self.frame_estado = ctk.CTkFrame(
            frame_right, fg_color="#2D2D2D", corner_radius=8, height=80
        )
        self.frame_estado.pack(padx=20, pady=10, fill="x")

        ctk.CTkLabel(
            self.frame_estado,
            text="ESTADO ACTUAL",
            font=("Arial", 10, "bold"),
            text_color="#AAAAAA"
        ).pack(pady=(8, 2))

        self.lbl_estado = ctk.CTkLabel(
            self.frame_estado,
            text="Sistema Operativo OK",
            font=("Arial", 14, "bold"),
            text_color="#E0E0E0"
        )
        self.lbl_estado.pack(pady=(0, 8))

        # Pluma y pantalla de la portería (virtuales; el Arduino, si existe, los repite físicamente)
        frame_porteria = ctk.CTkFrame(frame_right, fg_color="#2D2D2D", corner_radius=8)
        frame_porteria.pack(padx=20, pady=(0, 10), fill="x")
        self.canvas_pluma = tk.Canvas(frame_porteria, width=210, height=84, bg="#2D2D2D", highlightthickness=0)
        self.canvas_pluma.pack(side="left", padx=10, pady=8)
        frame_lcd = ctk.CTkFrame(frame_porteria, fg_color="#0B3D2E", corner_radius=6)
        frame_lcd.pack(side="left", padx=(5, 12), pady=8, fill="x", expand=True)
        self.lbl_lcd1 = ctk.CTkLabel(frame_lcd, text="", font=("Consolas", 14, "bold"), text_color="#B9F6CA", anchor="w")
        self.lbl_lcd1.pack(fill="x", padx=10, pady=(8, 0))
        self.lbl_lcd2 = ctk.CTkLabel(frame_lcd, text="", font=("Consolas", 14, "bold"), text_color="#B9F6CA", anchor="w")
        self.lbl_lcd2.pack(fill="x", padx=10, pady=(0, 8))
        self._refrescar_porteria()

        # Consola interactiva para logs y auditoría inmediata
        ctk.CTkLabel(
            frame_right,
            text="Consola de Eventos:",
            font=("Arial", 12, "bold")
        ).pack(anchor="w", padx=25, pady=(10, 2))

        self.txt_log = ctk.CTkTextbox(
            frame_right,
            height=140,
            font=("Consolas", 11),
            fg_color="#121212"
        )
        self.txt_log.pack(padx=20, pady=(5, 20), fill="x")

    def _refrescar_porteria(self):
        """Dibuja la pluma (cerrada = barra horizontal; abierta = barra levantada) y el texto de la pantalla."""
        p = self.porteria
        p.revisar_tiempo()
        c = self.canvas_pluma
        c.delete("all")
        abierta = p.pluma_abierta
        c.create_rectangle(12, 30, 30, 76, fill="#555555", outline="")             # poste
        if abierta:
            c.create_line(21, 34, 21, 4, width=7, fill="#2ECC71", capstyle="round")   # brazo levantado
        else:
            c.create_line(21, 34, 190, 34, width=7, fill="#E74C3C", capstyle="round")  # brazo cruzando el carril
        c.create_text(120, 66, text="PLUMA ABIERTA" if abierta else "PLUMA CERRADA",
                      fill="#2ECC71" if abierta else "#E74C3C", font=("Arial", 10, "bold"))
        self.lbl_lcd1.configure(text=p.linea1.ljust(16))
        self.lbl_lcd2.configure(text=p.linea2.ljust(16))
        self.after(200, self._refrescar_porteria)

    def update_video_ui(self):
        """Bucle periódico (20ms) para renderizar el último fotograma en la interfaz."""
        frame = self.video_worker.get_frame()
        if frame is not None:
            try:
                rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
                img = Image.fromarray(rgb).resize((520, 390), Image.Resampling.LANCZOS)
                ctk_img = ctk.CTkImage(light_image=img, dark_image=img, size=(520, 390))
                self.lbl_video.configure(image=ctk_img, text="")
            except Exception:
                pass

        if self.video_worker.is_running:
            self.after(20, self.update_video_ui)
        else:
            self.lbl_video.configure(
                image=None,
                text="Cámara no disponible\n(use 'Buscar Nuevas Cámaras')"
            )

    def cambiar_camara(self, opcion):
        """Conmuta la fuente de captura activa según la selección hecha en el OptionMenu."""
        try:
            idx = int(opcion.split("Índice ")[1].replace(")", ""))
        except Exception:
            return
        if self.camara_actual_index == idx:
            return
        if self.video_worker.start(idx):
            self.camara_actual_index = idx
            self.lbl_estado.configure(
                text=f"Cámara Índice {idx} Activa",
                text_color="#E0E0E0"
            )
            self.update_video_ui()

    def conectar_camara_url(self):
        """Usa una cámara IP o de celular (RTSP/HTTP) en lugar de una cámara USB."""
        url = self.entry_url.get().strip()
        if not url:
            return
        if self.video_worker.start(url):
            self.camara_actual_index = url
            self.log(f"Cámara conectada por dirección: {url}")
            self.update_video_ui()
        else:
            self.log("⚠️ No se pudo abrir esa dirección de cámara.")

    def _cargar_lector_placas(self):
        self.lector_placas = LectorPlacas()
        motor = self.lector_placas.motor
        msg = f"Lectura de placas lista ({motor})." if motor else \
              "Lectura de placas no disponible: instale easyocr o pytesseract. La placa se puede escribir a mano."
        try:
            self.after(0, lambda: self.log(msg))
        except Exception:
            pass

    def leer_placa_ahora(self):
        """Lee la placa del fotograma actual y la escribe en el campo de placa."""
        placa = self._leer_placa(self.video_worker.get_frame())
        if placa:
            self.entry_placa.delete(0, "end")
            self.entry_placa.insert(0, placa)
            self.log(f"Placa leída: {placa}")
        else:
            self.log("No se pudo leer una placa en la imagen. Acerque la placa o escríbala a mano.")

    def _leer_placa(self, frame):
        if self.lector_placas is None or not self.lector_placas.disponible or frame is None:
            return None
        try:
            return self.lector_placas.leer(frame)
        except Exception as e:
            self.log(f"Error leyendo la placa: {e}")
            return None

    def refrescar_camaras(self):
        """Escanea nuevamente los puertos de video e invoca la actualización del menú visual."""
        self.camaras_disponibles = self.video_worker.list_cameras()
        opciones = (
            [f"Cámara (Índice {i})" for i in self.camaras_disponibles]
            if self.camaras_disponibles
            else ["No se detectaron cámaras"]
        )
        self.combo_camaras.configure(values=opciones)
        if self.camaras_disponibles:
            self.combo_camaras.set(opciones[0])
            self.cambiar_camara(opciones[0])

    def log(self, msg):
        """Inserta líneas de texto formateadas con marca de tiempo en la consola de la interfaz."""
        ts = datetime.datetime.now().strftime("%H:%M:%S")
        self.txt_log.insert("end", f"[{ts}] {msg}\n")
        self.txt_log.see("end")

    def set_estado(self, texto, color_bg, color_txt):
        """Modifica dinámicamente el texto y colores del cuadro de estado."""
        self.frame_estado.configure(fg_color=color_bg)
        self.lbl_estado.configure(text=texto, text_color=color_txt)

    def restablecer_estado(self):
        """Reinicia la apariencia del cuadro de estado al valor por defecto."""
        idx = self.video_worker.cam_index
        texto = f"Cámara Índice {idx} Activa" if idx is not None else "Sistema OK"
        self.set_estado(texto, "#2D2D2D", "#E0E0E0")
        self.porteria.reposo()

    # -----------------------------------------------------------------
    # RECONOCIMIENTO FACIAL (OPTIMIZADO CON ENCODINGS PRE-CALCULADOS)
    # -----------------------------------------------------------------
    def ejecutar_reconocimiento(self):
        """
        Proceso biométrico principal:
        1. Captura el fotograma actual enviado por el trabajador de video.
        2. Detecta la ubicación del rostro y extrae la codificación de 128 descriptores (encoding).
        3. Compara en memoria contra los encodings deserializados de la base de datos (Pickle).
        4. Aplica las reglas de negocio para impedir registros redundantes (Doble Entrada o Doble Salida).
        5. Inserta la novedad correspondiente en la tabla 'entrada_salida' si el acceso es válido.
        """
        modo = self.combo_modo.get()
        ahora_s = time.time()
        if self.intentos.bloqueado(ahora_s):
            self._denegar(f"Lector bloqueado por intentos fallidos. Espere {self.intentos.segundos_restantes(ahora_s)} s",
                          "Lector bloqueado")
            return
        if not HAY_ROSTROS:
            self.log("⚠️ El reconocimiento facial no está instalado en este equipo. Use «Ingreso manual» (cédula o placa).")
            play_sound(False)
            return
        self.log(f"Sensor activado ({modo}). Analizando rostro...")

        frame = self.video_worker.get_frame()
        if frame is None:
            self.log("⚠️ No hay señal de cámara.")
            play_sound(False)
            return

        try:
            rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
            locations = face_recognition.face_locations(rgb)
            if not locations:
                self._fallo("Ningún rostro detectado")
                return
            encoding_actual = face_recognition.face_encodings(rgb, locations)[0]
        except Exception as e:
            self.log(f"❌ Error de reconocimiento: {e}")
            play_sound(False)
            return

        # Cargar los encodings binarios almacenados previamente en la BD para optimizar rendimiento
        conn = get_connection()
        cur = conn.cursor()
        cur.execute(
            "SELECT id, nombre, apellido, parqueadero, placa, encodings "
            "FROM usuarios WHERE encodings IS NOT NULL"
        )
        usuarios = cur.fetchall()
        conn.close()

        usuario = None
        for uid, nombre, apellido, parqueadero, placa, enc_blob in usuarios:
            if not enc_blob:
                continue
            try:
                # Deserializar la lista de vectores de características de la imagen de referencia
                encodings_db = pickle.loads(enc_blob)
                matches = face_recognition.compare_faces(
                    encodings_db, encoding_actual, tolerance=FACE_TOLERANCE
                )
                if any(matches):
                    usuario = (uid, nombre, apellido, parqueadero, placa)
                    break
            except Exception:
                continue

        if not usuario:
            self._fallo("Rostro no coincide con la base de datos")
            return

        self.intentos.exito()                      # una persona reconocida reinicia el contador
        self._resolver_acceso(usuario, modo, frame, "rostro")

    def validar_manual(self):
        """Ingreso manual: el guarda escribe la cédula o la placa y el sistema aplica las mismas reglas.

        Sirve cuando la cámara falla, hay contingencia (sin energía principal) o la persona no tiene rostro registrado."""
        modo = self.combo_modo.get()
        ahora_s = time.time()
        if self.intentos.bloqueado(ahora_s):
            self._denegar(f"Lector bloqueado por intentos fallidos. Espere {self.intentos.segundos_restantes(ahora_s)} s",
                          "Lector bloqueado")
            return
        texto = self.entry_manual.get().strip()
        cn = nucleo.conectar(DB_FILE)
        u = nucleo.buscar_usuario(cn, texto)
        cn.close()
        if u is None:
            self._fallo("No hay nadie registrado con esa cédula o placa")
            return
        self.intentos.exito()
        self.entry_manual.delete(0, "end")
        self._resolver_acceso((u["id"], u["nombre"], u["apellido"], u["parqueadero"], u["placa"]), modo, None, "manual")

    def reportar_novedad(self):
        """Ventana para dejar constancia de algo anormal (intento de robo, suplantación, falla de equipo...)."""
        win = ctk.CTkToplevel(self)
        win.title("Reportar novedad")
        win.geometry("420x330")
        win.grab_set()
        ctk.CTkLabel(win, text="Tipo de novedad", font=("Arial", 12, "bold")).pack(anchor="w", padx=20, pady=(15, 2))
        combo = ctk.CTkOptionMenu(win, values=list(nucleo.TIPOS_NOVEDAD), width=380)
        combo.pack(padx=20)
        ctk.CTkLabel(win, text="Placa involucrada (opcional)", font=("Arial", 12, "bold")).pack(anchor="w", padx=20, pady=(10, 2))
        e_placa = ctk.CTkEntry(win, width=380)
        e_placa.pack(padx=20)
        ctk.CTkLabel(win, text="¿Qué ocurrió?", font=("Arial", 12, "bold")).pack(anchor="w", padx=20, pady=(10, 2))
        e_desc = ctk.CTkEntry(win, width=380, height=60)
        e_desc.pack(padx=20)
        lbl = ctk.CTkLabel(win, text="")
        lbl.pack(pady=4)

        def guardar():
            cn = nucleo.conectar(DB_FILE)
            try:
                admin = nucleo.leer_config(cn, "admin_user", "admin")
                nucleo.registrar_novedad(cn, combo.get(), e_desc.get(), e_placa.get(), registrado_por=f"Guardia · {admin}")
            except ValueError as e:
                lbl.configure(text=f"⚠️ {e}", text_color="#E74C3C")
                return
            finally:
                cn.close()
            self.log(f"🚨 Novedad registrada: {combo.get()}. Si hay peligro, llame a la policía.")
            win.destroy()

        ctk.CTkButton(win, text="Guardar novedad", command=guardar).pack(pady=8)

    def toggle_contingencia(self):
        """Activa o desactiva el modo de contingencia y deja constancia en la consola."""
        activa = bool(self.sw_contingencia.get())
        cn = nucleo.conectar(DB_FILE)
        nucleo.fijar_contingencia(cn, activa)
        cn.close()
        self.log("🔶 Modo de contingencia ACTIVADO: operar con ingreso manual; los movimientos quedan marcados."
                 if activa else "✅ Modo de contingencia desactivado.")
        self.lbl_contingencia.configure(text="CONTINGENCIA ACTIVA" if activa else "")

    def _resolver_acceso(self, usuario, modo, frame, origen):
        """Aplica las reglas del conjunto a una persona ya identificada (por rostro o de forma manual) y actúa."""
        uid, nombre, apellido, parqueadero, placa = usuario
        nombre_completo = f"{nombre} {apellido}"

        # Las reglas de negocio (ya dentro/fuera, cupo de visitantes, autorización, turno)
        # viven en nucleo.py y están cubiertas por pruebas automáticas.
        cn = nucleo.conectar(DB_FILE)
        decision = nucleo.evaluar_acceso(cn, uid, modo)
        placa_leida = self.entry_placa.get().strip()
        if not placa_leida and frame is not None:
            auto = self._leer_placa(frame)           # intenta leerla sola con la cámara
            if auto:
                placa_leida = auto
                self.log(f"Placa leída automáticamente: {auto}")
        if placa_leida and decision.resultado == nucleo.AUTORIZADO and not nucleo.placas_coinciden(placa_leida, placa):
            # El rostro es de la persona, pero el vehículo no es el registrado: lo decide el guarda.
            decision = nucleo.Decision(
                nucleo.REVISAR,
                f"La placa leída ({placa_leida.upper()}) no coincide con la registrada ({placa or 'sin placa'}).",
                decision.categoria)
        if nucleo.contingencia_activa(cn) and decision.resultado == nucleo.AUTORIZADO:
            # Sin energía principal el sistema no decide solo: el guarda confirma cada caso (como en el simulador).
            decision = nucleo.Decision(
                nucleo.REVISAR, "Contingencia: confirme la identidad de la persona (documento y placa a la vista).",
                decision.categoria, decision.puesto)
        if decision.resultado == nucleo.REVISAR:
            # Caso dudoso: el sistema nunca lo decide solo; lo decide el guarda.
            fila_u = cn.execute("SELECT rol, autorizado_por FROM usuarios WHERE id = ?", (uid,)).fetchone()
            cito = ""
            if fila_u and fila_u["rol"] == "visitante" and (fila_u["autorizado_por"] or "").strip():
                cito = f"\n\nCitófono: llame a «{fila_u['autorizado_por']}» para confirmar la visita."
            permitir = messagebox.askyesno(
                "Revisión del guarda",
                f"{nombre_completo}\n{decision.motivo}{cito}\n\n¿Permitir el movimiento de todos modos?"
            )
            if permitir:
                decision = nucleo.evaluar_acceso(cn, uid, modo, forzar=True)
                decision.motivo += " (permitido por el guarda)"
            else:
                decision = nucleo.Decision(nucleo.DENEGADO, decision.motivo, decision.categoria)
        admin = nucleo.leer_config(cn, "admin_user", "admin")
        notas = []
        if origen == "manual":
            notas.append("ingreso manual")
        if nucleo.contingencia_activa(cn):
            notas.append("contingencia")
        detalle = decision.motivo + (f" [{', '.join(notas)}]" if notas else "")
        nucleo.registrar_movimiento(cn, uid, modo, decision, registrado_por=f"Guardia · {admin}", detalle=detalle)
        libres = nucleo.visitantes_libres(cn)
        cupo = nucleo.cupo_visitantes(cn)
        cn.close()

        if decision.resultado != nucleo.AUTORIZADO:
            self.actualizar_tabla_estado()
            self._denegar(decision.motivo, nombre)
            return

        # Emitir notificaciones visuales, acústicas e interfaz emergente
        puesto = decision.puesto or parqueadero
        self.set_estado(
            f"ACCESO PERMITIDO ({modo.upper()}): {nombre_completo} [{decision.categoria}]",
            "#145A32",
            "#2ECC71"
        )
        self.log(
            f"✅ {modo} registrada → {nombre_completo} | "
            f"Placa: {placa} | Puesto: {puesto} | Categoría: {decision.categoria} | "
            f"Visitantes libres: {libres}/{cupo}"
        )
        self.porteria.abrir(nombre)                # sube la pluma virtual y, si hay Arduino, la física
        self.log("Pluma abierta 3 s")
        play_sound(True)
        self.mostrar_popup_bienvenida(nombre_completo, puesto, modo)
        self.actualizar_tabla_estado()
        self.after(4000, self.restablecer_estado)

    def _fallo(self, motivo):
        """Rechazo por no reconocer a la persona: cuenta como intento fallido (3 seguidos bloquean el lector)."""
        self.intentos.fallo(time.time())
        if self.intentos.bloqueado(time.time()):
            motivo += f" · lector bloqueado {nucleo.SEGUNDOS_BLOQUEO} s"
        self._denegar(motivo)

    def _denegar(self, motivo, linea_lcd=""):
        """Maneja el rechazo de acceso actualizando la interfaz y emitiendo tonos de alerta."""
        self.porteria.denegar(linea_lcd or motivo)
        self.set_estado("ACCESO DENEGADO", "#78281F", "#E74C3C")
        self.log(f"🚫 {motivo}")
        play_sound(False)
        self.after(4000, self.restablecer_estado)

    def leer_tiempo_popup(self):
        """Lee la duración configurada para la ventana emergente flotante desde el archivo externo."""
        if TIEMPO_POPUP_FILE.exists():
            try:
                return int(TIEMPO_POPUP_FILE.read_text().strip())
            except Exception:
                pass
        TIEMPO_POPUP_FILE.write_text("3")
        return 3

    def mostrar_popup_bienvenida(self, nombre, parqueadero, modo):
        """Crea una ventana flotante modal (Toplevel) que muestra los datos del acceso con auto-cierre."""
        segs = self.leer_tiempo_popup()
        popup = ctk.CTkToplevel(self)
        popup.title("¡Acceso Autorizado!")
        popup.geometry("450x280")
        popup.attributes("-topmost", True)
        popup.resizable(False, False)

        # Cálculo de coordenadas para desplegar la ventana emergente centrada sobre la aplicación
        popup.update_idletasks()
        x = self.winfo_x() + (self.winfo_width() // 2) - 225
        y = self.winfo_y() + (self.winfo_height() // 2) - 140
        popup.geometry(f"+{x}+{y}")

        ctk.CTkLabel(
            popup,
            text="¡ACCESO CONCEDIDO!",
            font=ctk.CTkFont(size=20, weight="bold"),
            text_color="#2ecc71"
        ).pack(pady=(25, 10))

        ctk.CTkLabel(
            popup,
            text=f"Modo: {modo.upper()}",
            font=ctk.CTkFont(size=14, weight="bold"),
            text_color="gray"
        ).pack()

        ctk.CTkLabel(
            popup,
            text=f"Bienvenido(a):\n{nombre}",
            font=ctk.CTkFont(size=16),
            justify="center"
        ).pack(pady=10)

        ctk.CTkLabel(
            popup,
            text=f"Puesto de Parqueadero: #{parqueadero}",
            font=ctk.CTkFont(size=15, weight="bold"),
            text_color="#3498db"
        ).pack(pady=5)

        ctk.CTkLabel(
            popup,
            text=f"Cierre automático en {segs} s...",
            text_color="darkgray"
        ).pack(pady=10)

        popup.after(segs * 1000, popup.destroy)

    # -----------------------------------------------------------------
    # PESTAÑA 2: GESTIÓN DE USUARIOS
    # -----------------------------------------------------------------
    def setup_tab_gestion_usuarios(self):
        """Crea el Tabview interno para dividir la gestión de usuarios en 3 sub-módulos."""
        self.sub_tabview = ctk.CTkTabview(self.tab_gestion)
        self.sub_tabview.pack(padx=10, pady=10, fill="both", expand=True)

        self.sub_registrar = self.sub_tabview.add(" ➕ Registrar Usuario ")
        self.sub_consultar = self.sub_tabview.add(" 📋 Consultar Usuarios ")
        self.sub_actualizar = self.sub_tabview.add(" ⚙️ Actualizar / Eliminar ")

        self.setup_sub_registrar()
        self.setup_sub_consultar()
        self.setup_sub_actualizar()

    def setup_sub_registrar(self):
        """
        Construye el formulario visual de captura de datos personales y de vehículos.
        Estructura mediante distribución de tipo grid:
          1. Nombre(s)
          2. Apellido(s)
          3. Tipo de Identificación (OptionMenu)
          4. Número de Identificación / Cédula
          5. Número de Parqueadero Asignado
          6. Placa del Vehículo
        """
        frame = ctk.CTkScrollableFrame(
            self.sub_registrar, fg_color="#1E1E1E", corner_radius=12
        )
        frame.pack(padx=20, pady=10, fill="both", expand=True)

        ctk.CTkLabel(
            frame,
            text="Registro de Usuarios y Rostros",
            font=("Arial", 18, "bold")
        ).pack(pady=15)

        grid = ctk.CTkFrame(frame, fg_color="transparent")
        grid.pack(pady=5)
        grid.grid_columnconfigure(0, weight=1, minsize=260)
        grid.grid_columnconfigure(1, weight=1, minsize=400)

        self.campos = {}
        fila = 0

        # Campo: Nombre
        ctk.CTkLabel(
            grid, text="Nombre(s):", font=("Arial", 12, "bold"), anchor="e"
        ).grid(row=fila, column=0, padx=(10, 15), pady=8, sticky="e")
        self.campos["nombre"] = ctk.CTkEntry(
            grid, placeholder_text="Ingrese el nombre", width=360, height=35
        )
        self.campos["nombre"].grid(row=fila, column=1, padx=(0, 10), pady=8, sticky="w")
        fila += 1

        # Campo: Apellido
        ctk.CTkLabel(
            grid, text="Apellido(s):", font=("Arial", 12, "bold"), anchor="e"
        ).grid(row=fila, column=0, padx=(10, 15), pady=8, sticky="e")
        self.campos["apellido"] = ctk.CTkEntry(
            grid, placeholder_text="Ingrese el apellido", width=360, height=35
        )
        self.campos["apellido"].grid(row=fila, column=1, padx=(0, 10), pady=8, sticky="w")
        fila += 1

        # Campo: Tipo de Identificación
        ctk.CTkLabel(
            grid, text="Tipo de Identificación:", font=("Arial", 12, "bold"), anchor="e"
        ).grid(row=fila, column=0, padx=(10, 15), pady=8, sticky="e")
        self.combo_tipo = ctk.CTkOptionMenu(
            grid,
            values=self.obtener_tipos_id(),
            width=360,
            height=35,
            command=self._on_tipo_id
        )
        self.combo_tipo.grid(row=fila, column=1, padx=(0, 10), pady=8, sticky="w")
        fila += 1

        # Campo: Número de Identificación / Cédula
        ctk.CTkLabel(
            grid, text="Número de Identificación:", font=("Arial", 12, "bold"), anchor="e"
        ).grid(row=fila, column=0, padx=(10, 15), pady=8, sticky="e")
        self.campos["cedula"] = ctk.CTkEntry(
            grid, placeholder_text="Ej. 1020304050", width=360, height=35
        )
        self.campos["cedula"].grid(row=fila, column=1, padx=(0, 10), pady=8, sticky="w")
        fila += 1

        # Campo: Parqueadero
        ctk.CTkLabel(
            grid, text="Número de Parqueadero:", font=("Arial", 12, "bold"), anchor="e"
        ).grid(row=fila, column=0, padx=(10, 15), pady=8, sticky="e")
        self.campos["parqueadero"] = ctk.CTkEntry(
            grid, placeholder_text="Ej. P-12", width=360, height=35
        )
        self.campos["parqueadero"].grid(row=fila, column=1, padx=(0, 10), pady=8, sticky="w")
        fila += 1

        # Campo: Placa del Vehículo
        ctk.CTkLabel(
            grid, text="Placa del Vehículo:", font=("Arial", 12, "bold"), anchor="e"
        ).grid(row=fila, column=0, padx=(10, 15), pady=8, sticky="e")
        self.campos["placa"] = ctk.CTkEntry(
            grid, placeholder_text="Ej. XYZ789", width=360, height=35
        )
        self.campos["placa"].grid(row=fila, column=1, padx=(0, 10), pady=8, sticky="w")
        fila += 1

        # Campos nuevos (v1.1): rol y categoría. No se incluyen en self.campos porque no siempre son obligatorios.
        ctk.CTkLabel(
            grid, text="Rol:", font=("Arial", 12, "bold"), anchor="e"
        ).grid(row=fila, column=0, padx=(10, 15), pady=8, sticky="e")
        self.combo_rol = ctk.CTkOptionMenu(grid, values=list(nucleo.ROLES), width=360, height=35)
        self.combo_rol.grid(row=fila, column=1, padx=(0, 10), pady=8, sticky="w")
        fila += 1
        self.chk_vip = ctk.CTkCheckBox(grid, text="Categoría VIP (trato diferenciado definido por la administración)")
        self.chk_vip.grid(row=fila, column=1, padx=(0, 10), pady=8, sticky="w")
        fila += 1
        ctk.CTkLabel(
            grid, text="Autoriza (solo visitantes):", font=("Arial", 12, "bold"), anchor="e"
        ).grid(row=fila, column=0, padx=(10, 15), pady=8, sticky="e")
        self.entry_autoriza = ctk.CTkEntry(grid, placeholder_text="Residente o área que autoriza la visita", width=360, height=35)
        self.entry_autoriza.grid(row=fila, column=1, padx=(0, 10), pady=8, sticky="w")
        fila += 1
        ctk.CTkLabel(
            grid, text="Turno (solo trabajadores):", font=("Arial", 12, "bold"), anchor="e"
        ).grid(row=fila, column=0, padx=(10, 15), pady=8, sticky="e")
        self.combo_turno = ctk.CTkOptionMenu(grid, values=["", "mañana", "tarde", "noche"], width=360, height=35)
        self.combo_turno.grid(row=fila, column=1, padx=(0, 10), pady=8, sticky="w")

        # Botón para iniciar el enrolamiento biométrico
        ctk.CTkButton(
            frame,
            text="Registrar Usuario y Capturar Rostro",
            fg_color="#27AE60",
            hover_color="#1E8449",
            width=450,
            height=45,
            font=("Arial", 14, "bold"),
            command=self.iniciar_registro
        ).pack(pady=25)

        self.lbl_status_reg = ctk.CTkLabel(
            frame, text="", font=("Arial", 13, "bold")
        )
        self.lbl_status_reg.pack()

    def obtener_tipos_id(self):
        """Consulta los tipos de documento registrados en la base de datos y agrega la opción de creación."""
        conn = get_connection()
        cur = conn.cursor()
        cur.execute("SELECT nombre_tipo FROM tipos_identificacion")
        tipos = [r[0] for r in cur.fetchall()]
        conn.close()
        tipos.append("➕ Agregar Nuevo Tipo...")
        return tipos

    def _on_tipo_id(self, valor):
        """Evalúa si la opción seleccionada corresponde al gatillo para abrir la ventana de creación."""
        if valor == "➕ Agregar Nuevo Tipo...":
            self._ventana_nuevo_tipo()

    def _ventana_nuevo_tipo(self):
        """Despliega una ventana modal para registrar un nuevo tipo de documento en la base de datos."""
        top = ctk.CTkToplevel(self)
        top.title("Nuevo Tipo de ID")
        top.geometry("400x200")
        top.attributes("-topmost", True)

        ctk.CTkLabel(
            top,
            text="Nuevo tipo de identificación:",
            font=("Arial", 14, "bold")
        ).pack(pady=20)

        txt = ctk.CTkEntry(top, width=300)
        txt.pack()

        def guardar():
            val = txt.get().strip()
            if not val:
                return
            try:
                conn = get_connection()
                cur = conn.cursor()
                cur.execute(
                    "INSERT INTO tipos_identificacion (nombre_tipo) VALUES (?)",
                    (val,)
                )
                sincronizar_txt_tipos(conn)
                conn.commit()
                conn.close()
                self.combo_tipo.configure(values=self.obtener_tipos_id())
                self.combo_tipo.set(val)
                top.destroy()
            except sqlite3.IntegrityError:
                pass

        ctk.CTkButton(
            top, text="Guardar", fg_color="#27AE60", command=guardar
        ).pack(pady=15)

    def iniciar_registro(self):
        """Valida que los campos requeridos contengan información válida antes de iniciar la captura de fotos."""
        datos = {k: e.get().strip() for k, e in self.campos.items()}
        datos["placa"] = datos["placa"].upper()
        tipo = self.combo_tipo.get()
        rol = self.combo_rol.get()
        if rol != "residente" and not datos["parqueadero"]:
            datos["parqueadero"] = "VISITANTES" if rol == "visitante" else "N/A"   # sin puesto propio
        if rol == "visitante" and not self.entry_autoriza.get().strip():
            self.lbl_status_reg.configure(
                text="⚠️ Indique quién autoriza al visitante", text_color="#E74C3C"
            )
            return

        if not all(datos.values()) or tipo == "➕ Agregar Nuevo Tipo...":
            self.lbl_status_reg.configure(
                text="⚠️ Todos los campos son obligatorios",
                text_color="#E74C3C"
            )
            return

        if not HAY_ROSTROS:                       # sin reconocimiento facial: se registra sin fotos
            self._registrar_sin_rostro(datos, tipo, rol)
            return

        self.abrir_popup_captura(
            datos["nombre"],
            datos["apellido"],
            tipo,
            datos["cedula"],
            datos["parqueadero"],
            datos["placa"]
        )

    def _registrar_sin_rostro(self, datos, tipo, rol):
        """Registra a la persona sin fotos (cuando el reconocimiento facial no está instalado).
        Se identificará por cédula o placa con el ingreso manual."""
        cn = nucleo.conectar(DB_FILE)
        try:
            nucleo.registrar_usuario(
                cn, nombre=datos["nombre"], apellido=datos["apellido"], tipo_id=tipo, cedula=datos["cedula"],
                parqueadero=datos["parqueadero"], placa=datos["placa"], rol=rol, vip=bool(self.chk_vip.get()),
                turno=self.combo_turno.get(), autorizado_por=self.entry_autoriza.get().strip())
        except ValueError as e:
            self.lbl_status_reg.configure(text=f"⚠️ {e}", text_color="#E74C3C")
            return
        finally:
            cn.close()
        self.actualizar_tabla_consultar()
        self.actualizar_lista_actualizar()
        self.actualizar_tabla_estado()
        self._popup_exito()

    def abrir_popup_captura(self, nombre, apellido, tipo_id, cedula, parqueadero, placa):
        """
        Ventana interactiva para la captura de 3 imágenes del rostro del usuario.
        Inspecciona el fotograma para asegurar que exista un rostro visible antes de almacenar la muestra.
        Una vez completadas las 3 muestras, calcula los encodings, los serializa con Pickle y guarda el registro.
        """
        popup = ctk.CTkToplevel(self)
        popup.title("Captura Biométrica")
        popup.geometry("500x560")
        popup.grab_set()
        popup.attributes("-topmost", True)

        ctk.CTkLabel(
            popup,
            text=f"Captura de Rostro: {nombre} {apellido}",
            font=("Arial", 15, "bold")
        ).pack(pady=10)

        lbl_video = ctk.CTkLabel(
            popup,
            text="Cámara",
            fg_color="#121212",
            width=400,
            height=300,
            corner_radius=8
        )
        lbl_video.pack(pady=5)

        lbl_cont = ctk.CTkLabel(
            popup,
            text="Fotos: 0 / 3",
            font=("Arial", 14, "bold"),
            text_color="#E74C3C"
        )
        lbl_cont.pack(pady=10)

        fotos = []
        encodings_list = []

        def actualizar():
            """Actualiza la vista previa del streaming de la cámara dentro del modal de captura."""
            frame = self.video_worker.get_frame()
            if frame is not None and popup.winfo_exists():
                rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
                img = Image.fromarray(rgb).resize((400, 300), Image.Resampling.LANCZOS)
                ctk_img = ctk.CTkImage(light_image=img, dark_image=img, size=(400, 300))
                lbl_video.configure(image=ctk_img, text="")
            if popup.winfo_exists():
                popup.after(30, actualizar)

        actualizar()

        btn_cap = ctk.CTkButton(
            popup,
            text="📸 Tomar Foto (1/3)",
            fg_color="#2980B9",
            width=300,
            height=35
        )
        btn_guardar = ctk.CTkButton(
            popup,
            text="💾 Guardar Registro",
            fg_color="#27AE60",
            width=300,
            height=40,
            state="disabled"
        )

        def capturar():
            """Toma una muestra del buffer de video y procesa los encodings biométricos."""
            frame = self.video_worker.get_frame()
            if frame is None or len(fotos) >= 3:
                return

            rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
            locs = face_recognition.face_locations(rgb)
            if not locs:
                lbl_cont.configure(
                    text="⚠️ No se detectó rostro. Intente de nuevo.",
                    text_color="#E74C3C"
                )
                return

            encs = face_recognition.face_encodings(rgb, locs)
            if not encs:
                return

            idx = len(fotos) + 1
            path = FOTOS_DIR / f"{cedula}_ref_{idx}.jpg"
            cv2.imwrite(str(path), frame)
            fotos.append(str(path))
            encodings_list.append(encs[0])

            lbl_cont.configure(
                text=f"Fotos: {len(fotos)} / 3",
                text_color="#2ECC71" if len(fotos) == 3 else "#E74C3C"
            )

            if len(fotos) < 3:
                btn_cap.configure(text=f"📸 Tomar Foto ({len(fotos)+1}/3)")
            else:
                btn_cap.configure(
                    text="✔️ Fotografías Completadas",
                    state="disabled",
                    fg_color="#555555"
                )
                btn_guardar.configure(state="normal")

        def guardar():
            """Guarda definitivamente al usuario, sus imágenes y su bloque binario (BLOB) de encodings."""
            rutas = ";".join(fotos)
            enc_blob = pickle.dumps(encodings_list)
            ahora = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")

            try:
                conn = get_connection()
                cur = conn.cursor()
                cur.execute('''
                    INSERT INTO usuarios
                    (nombre, apellido, tipo_id, cedula, parqueadero, placa,
                     fotos_rutas, encodings, fecha_registro, novedad, fecha_novedad)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                ''', (
                    nombre, apellido, tipo_id, cedula, parqueadero, placa,
                    rutas, enc_blob, ahora, "REGISTRO", ahora
                ))
                # Datos de rol y categoría (v1.1): se completan sobre el registro recién creado
                cur.execute(
                    "UPDATE usuarios SET rol=?, vip=?, autorizado_por=?, autorizacion_activa=?, turno=? WHERE id=?",
                    (self.combo_rol.get(), 1 if self.chk_vip.get() else 0,
                     self.entry_autoriza.get().strip(),
                     1 if self.combo_rol.get() == "visitante" else 0,
                     self.combo_turno.get(), cur.lastrowid)
                )
                conn.commit()
                conn.close()

                popup.destroy()
                self.actualizar_tabla_consultar()
                self.actualizar_lista_actualizar()
                self.actualizar_tabla_estado()
                self._popup_exito()          # Notifica e invoca la limpieza del formulario
            except sqlite3.IntegrityError:
                lbl_cont.configure(
                    text="⚠️ Cédula ya existe",
                    text_color="#E74C3C"
                )

        btn_cap.configure(command=capturar)
        btn_cap.pack(pady=5)
        btn_guardar.configure(command=guardar)
        btn_guardar.pack(pady=5)

    def _popup_exito(self):
        """
        Informa sobre el registro exitoso del usuario y procede a vaciar el formulario 
        para dejar la interfaz lista para la siguiente captura.
        """
        pop = ctk.CTkToplevel(self)
        pop.title("Éxito")
        pop.geometry("380x180")
        pop.grab_set()
        pop.attributes("-topmost", True)

        ctk.CTkLabel(
            pop,
            text="✅ Usuario registrado\nsatisfactoriamente",
            font=("Arial", 16, "bold"),
            text_color="#2ECC71"
        ).pack(pady=25)

        def limpiar():
            # Vaciar todos los campos de texto del formulario
            for entry in self.campos.values():
                entry.delete(0, "end")
            self.lbl_status_reg.configure(text="")
            pop.destroy()

        ctk.CTkButton(pop, text="Continuar", command=limpiar).pack(pady=10)

    # -----------------------------------------------------------------
    # SUB-PESTAÑA: CONSULTAR USUARIOS
    # -----------------------------------------------------------------
    def setup_sub_consultar(self):
        """Construye el contenedor principal para la tabla de visualización general de usuarios."""
        frame = ctk.CTkFrame(self.sub_consultar, fg_color="#1E1E1E", corner_radius=12)
        frame.pack(padx=20, pady=20, fill="both", expand=True)

        ctk.CTkLabel(
            frame,
            text="Listado de Usuarios",
            font=("Arial", 18, "bold")
        ).pack(pady=10)

        ctk.CTkButton(
            frame,
            text="🔄 Actualizar",
            fg_color="#444444",
            command=self.actualizar_tabla_consultar
        ).pack(pady=5)

        self.scroll_consulta = ctk.CTkScrollableFrame(frame, fg_color="#121212")
        self.scroll_consulta.pack(padx=10, pady=10, fill="both", expand=True)
        self.actualizar_tabla_consultar()

    def actualizar_tabla_consultar(self):
        """Renderiza las filas de la tabla de usuarios registrados, incluyendo la imagen miniatura."""
        for w in self.scroll_consulta.winfo_children():
            w.destroy()

        conn = get_connection()
        cur = conn.cursor()
        cur.execute(
            "SELECT id, nombre, apellido, tipo_id, cedula, parqueadero, placa, "
            "fotos_rutas, fecha_registro, novedad, fecha_novedad FROM usuarios"
        )
        usuarios = cur.fetchall()
        conn.close()

        # Estructura de cabeceras delimitadas
        headers = [
            ("FOTO", 65), ("NOMBRE", 190), ("TIPO / CÉDULA", 160),
            ("PARQUEADERO / PLACA", 180), ("FECHA REG.", 160), ("NOVEDAD", 180)
        ]
        header = ctk.CTkFrame(self.scroll_consulta, fg_color="#2C3E50", height=40)
        header.pack(fill="x", pady=2)
        for txt, w in headers:
            box = ctk.CTkFrame(header, fg_color="#34495E", width=w, height=36, corner_radius=0)
            box.pack(side="left", padx=1, pady=2)
            box.pack_propagate(False)
            ctk.CTkLabel(box, text=txt, font=("Arial", 10, "bold"), text_color="white").pack(expand=True)

        if not usuarios:
            ctk.CTkLabel(
                self.scroll_consulta,
                text="No hay usuarios registrados.",
                text_color="#AAA"
            ).pack(pady=20)
            return

        for u in usuarios:
            row = ctk.CTkFrame(self.scroll_consulta, fg_color="#212121", height=55)
            row.pack(fill="x", pady=2)
            row.pack_propagate(False)

            rutas = u[7].split(";") if u[7] else []
            foto = rutas[0] if rutas and Path(rutas[0]).exists() else None

            # Renderizado de miniatura de fotografía
            c1 = ctk.CTkFrame(row, fg_color="#2A2A2A", width=65, height=51, corner_radius=0)
            c1.pack(side="left", padx=1, pady=2)
            c1.pack_propagate(False)
            if foto:
                try:
                    img = Image.open(foto).resize((38, 38), Image.Resampling.LANCZOS)
                    ctk_img = ctk.CTkImage(light_image=img, dark_image=img, size=(38, 38))
                    lbl = ctk.CTkLabel(c1, image=ctk_img, text="")
                    lbl.image = ctk_img
                    lbl.pack(expand=True)
                except Exception:
                    ctk.CTkLabel(c1, text="[Sin]", font=("Arial", 9)).pack(expand=True)
            else:
                ctk.CTkLabel(c1, text="[Sin]", font=("Arial", 9)).pack(expand=True)

            # Renderizado del resto de celdas
            datos = [
                (f"{u[1]} {u[2]}", 190),
                (f"{u[3]} - {u[4]}", 160),
                (f"P: {u[5]} | {u[6]}", 180),
                (u[8] or "N/A", 160),
                (f"{u[9] or 'N/A'} ({u[10] or ''})", 180),
            ]
            for txt, w in datos:
                c = ctk.CTkFrame(row, fg_color="#2A2A2A", width=w, height=51, corner_radius=0)
                c.pack(side="left", padx=1, pady=2)
                c.pack_propagate(False)
                ctk.CTkLabel(c, text=txt, font=("Arial", 11), anchor="w").pack(
                    padx=8, expand=True, fill="x"
                )

    # -----------------------------------------------------------------
    # SUB-PESTAÑA: ACTUALIZAR / ELIMINAR
    # -----------------------------------------------------------------
    def setup_sub_actualizar(self):
        """Inicializa la vista del panel de administración individual de usuarios."""
        frame = ctk.CTkFrame(self.sub_actualizar, fg_color="#1E1E1E", corner_radius=12)
        frame.pack(padx=20, pady=20, fill="both", expand=True)

        ctk.CTkLabel(
            frame,
            text="Actualizar / Eliminar Usuarios",
            font=("Arial", 18, "bold")
        ).pack(pady=10)

        ctk.CTkButton(
            frame,
            text="🔄 Actualizar Lista",
            fg_color="#444444",
            command=self.actualizar_lista_actualizar
        ).pack(pady=5)

        self.scroll_act = ctk.CTkScrollableFrame(frame, fg_color="#121212")
        self.scroll_act.pack(padx=10, pady=10, fill="both", expand=True)
        self.actualizar_lista_actualizar()

    def actualizar_lista_actualizar(self):
        """Genera el listado interactivo con botones de acción para cada registro de usuario."""
        for w in self.scroll_act.winfo_children():
            w.destroy()

        conn = get_connection()
        cur = conn.cursor()
        cur.execute(
            "SELECT id, nombre, apellido, cedula, placa, fotos_rutas FROM usuarios"
        )
        usuarios = cur.fetchall()
        conn.close()

        if not usuarios:
            ctk.CTkLabel(
                self.scroll_act,
                text="No hay usuarios.",
                text_color="#AAA"
            ).pack(pady=20)
            return

        for uid, nombre, apellido, cedula, placa, fotos_str in usuarios:
            row = ctk.CTkFrame(self.scroll_act, fg_color="#212121", height=60)
            row.pack(fill="x", pady=3)
            row.pack_propagate(False)

            rutas = fotos_str.split(";") if fotos_str else []
            foto = rutas[0] if rutas and Path(rutas[0]).exists() else None

            if foto:
                try:
                    img = Image.open(foto).resize((40, 40), Image.Resampling.LANCZOS)
                    ctk_img = ctk.CTkImage(light_image=img, dark_image=img, size=(40, 40))
                    lbl = ctk.CTkLabel(row, image=ctk_img, text="")
                    lbl.image = ctk_img
                    lbl.pack(side="left", padx=15)
                except Exception:
                    ctk.CTkLabel(row, text="[Sin]", width=70).pack(side="left", padx=10)
            else:
                ctk.CTkLabel(row, text="[Sin Foto]", width=70).pack(side="left", padx=10)

            ctk.CTkLabel(
                row,
                text=f"ID:{uid} | {nombre} {apellido} — {cedula} — {placa}",
                font=("Arial", 12),
                anchor="w",
                width=620
            ).pack(side="left", padx=10)

            ctk.CTkButton(
                row,
                text="Actualizar",
                fg_color="#2980B9",
                width=100,
                height=32,
                command=lambda i=uid: self.abrir_popup_actualizar(i)
            ).pack(side="left", padx=5)

            ctk.CTkButton(
                row,
                text="Eliminar",
                fg_color="#C0392B",
                width=100,
                height=32,
                command=lambda i=uid: self.eliminar_usuario(i)
            ).pack(side="left", padx=5)

    def abrir_popup_actualizar(self, user_id):
        """Abre un modal que permite modificar los atributos de un usuario y registra la novedad."""
        conn = get_connection()
        cur = conn.cursor()
        cur.execute(
            "SELECT nombre, apellido, parqueadero, placa FROM usuarios WHERE id = ?",
            (user_id,)
        )
        data = cur.fetchone()
        conn.close()
        if not data:
            return

        pop = ctk.CTkToplevel(self)
        pop.title(f"Actualizar ID {user_id}")
        pop.geometry("450x400")
        pop.grab_set()
        pop.attributes("-topmost", True)

        ctk.CTkLabel(
            pop,
            text="Actualizar Datos",
            font=("Arial", 16, "bold")
        ).pack(pady=15)

        campos = {}
        for label, valor in [
            ("Nombre", data[0]),
            ("Apellido", data[1]),
            ("Parqueadero", data[2]),
            ("Placa", data[3])
        ]:
            ctk.CTkLabel(
                pop, text=label + ":", font=("Arial", 11, "bold")
            ).pack(anchor="w", padx=40)
            e = ctk.CTkEntry(pop, width=360)
            e.pack(pady=2)
            e.insert(0, valor)
            campos[label.lower()] = e

        def guardar():
            n = campos["nombre"].get().strip()
            a = campos["apellido"].get().strip()
            p = campos["parqueadero"].get().strip()
            pl = campos["placa"].get().strip().upper()
            if not all([n, a, p, pl]):
                return

            ahora = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
            conn = get_connection()
            cur = conn.cursor()
            cur.execute('''
                UPDATE usuarios
                SET nombre=?, apellido=?, parqueadero=?, placa=?,
                    novedad='ACTUALIZACIÓN', fecha_novedad=?
                WHERE id=?
            ''', (n, a, p, pl, ahora, user_id))
            conn.commit()
            conn.close()

            pop.destroy()
            self.actualizar_tabla_consultar()
            self.actualizar_lista_actualizar()
            self.actualizar_tabla_estado()

        ctk.CTkButton(
            pop, text="Guardar Cambios", fg_color="#27AE60", command=guardar
        ).pack(pady=20)

    def eliminar_usuario(self, user_id):
        """
        Elimina de la base de datos a un usuario y sus registros en entrada_salida.
        Elimina también las imágenes físicas de su rostro en el almacenamiento local.
        """
        conn = get_connection()
        cur = conn.cursor()

        # Borrado de los archivos de imagen guardados en la carpeta del proyecto
        cur.execute("SELECT fotos_rutas FROM usuarios WHERE id = ?", (user_id,))
        row = cur.fetchone()
        if row and row[0]:
            for r in row[0].split(";"):
                try:
                    Path(r).unlink(missing_ok=True)
                except Exception:
                    pass

        # Limpieza de registros dependientes y borrado definitivo del usuario
        cur.execute("DELETE FROM entrada_salida WHERE id_usuario = ?", (user_id,))
        cur.execute("DELETE FROM usuarios WHERE id = ?", (user_id,))
        conn.commit()
        conn.close()

        self.actualizar_tabla_consultar()
        self.actualizar_lista_actualizar()
        self.actualizar_tabla_estado()

    # -----------------------------------------------------------------
    # PESTAÑA 3: ESTADO PARQUEADERO (HISTORIAL COMPLETO)
    # -----------------------------------------------------------------
    def setup_tab_estado_parqueadero(self):
        """Inicializa la interfaz para la consulta del historial de auditoría de movimientos."""
        frame = ctk.CTkFrame(self.tab_estado, fg_color="#1E1E1E", corner_radius=12)
        frame.pack(padx=20, pady=20, fill="both", expand=True)

        ctk.CTkLabel(
            frame,
            text="Historial Completo de Entradas y Salidas",
            font=("Arial", 18, "bold")
        ).pack(pady=10)

        ctk.CTkButton(
            frame,
            text="🔄 Actualizar Historial",
            fg_color="#444444",
            command=self.actualizar_tabla_estado
        ).pack(pady=5)

        # Reportes por rango de fechas (AAAA-MM-DD; vacío = sin límite)
        barra = ctk.CTkFrame(frame, fg_color="transparent")
        barra.pack(pady=(0, 5))
        self.entry_desde = ctk.CTkEntry(barra, width=130, placeholder_text="Desde AAAA-MM-DD")
        self.entry_desde.pack(side="left", padx=4)
        self.entry_hasta = ctk.CTkEntry(barra, width=130, placeholder_text="Hasta AAAA-MM-DD")
        self.entry_hasta.pack(side="left", padx=4)
        ctk.CTkButton(barra, text="📊 Resumen", width=100, command=self.mostrar_resumen).pack(side="left", padx=4)
        ctk.CTkButton(barra, text="💾 Exportar CSV", width=120, command=self.exportar_historial).pack(side="left", padx=4)
        self.lbl_reporte = ctk.CTkLabel(frame, text="", text_color="#AAAAAA", justify="left")
        self.lbl_reporte.pack(pady=(0, 5))

        self.scroll_estado = ctk.CTkScrollableFrame(frame, fg_color="#121212")
        self.scroll_estado.pack(padx=10, pady=10, fill="both", expand=True)
        self.actualizar_tabla_estado()

    def mostrar_resumen(self):
        """Muestra cuántas entradas, salidas y denegados hubo en el rango de fechas elegido."""
        cn = nucleo.conectar(DB_FILE)
        try:
            r = nucleo.resumen_periodo(cn, self.entry_desde.get(), self.entry_hasta.get())
        except ValueError as e:
            self.lbl_reporte.configure(text=f"⚠️ {e}", text_color="#E74C3C")
            return
        finally:
            cn.close()
        cats = ", ".join(f"{k}: {v}" for k, v in r["por_categoria"].items()) or "sin movimientos"
        self.lbl_reporte.configure(
            text=(f"Movimientos: {r['total']} · Entradas: {r['entradas']} · Salidas: {r['salidas']} · "
                  f"Denegados: {r['denegados']} · Permitidos por el guarda: {r['permitidos_por_guarda']} · Novedades: {r['novedades']}\n"
                  f"Por categoría → {cats} · Visitantes libres ahora: {r['visitantes_libres']}/{r['cupo_visitantes']}"),
            text_color="#E0E0E0")

    def exportar_historial(self):
        """Guarda el historial del rango elegido en un CSV dentro de la carpeta «reportes»."""
        carpeta = BASE_DIR / "reportes"
        carpeta.mkdir(exist_ok=True)
        ruta = carpeta / f"historial_{datetime.datetime.now():%Y%m%d_%H%M%S}.csv"
        cn = nucleo.conectar(DB_FILE)
        try:
            n = nucleo.exportar_historial_csv(cn, ruta, self.entry_desde.get(), self.entry_hasta.get())
        except ValueError as e:
            self.lbl_reporte.configure(text=f"⚠️ {e}", text_color="#E74C3C")
            return
        finally:
            cn.close()
        ruta_nov = carpeta / (ruta.stem.replace("historial", "novedades") + ".csv")
        cn = nucleo.conectar(DB_FILE)
        try:
            n_nov = nucleo.exportar_novedades_csv(cn, ruta_nov, self.entry_desde.get(), self.entry_hasta.get())
        finally:
            cn.close()
        extra = f" y {n_nov} novedades en: {ruta_nov}" if n_nov else ""
        self.lbl_reporte.configure(text=f"✅ {n} movimientos guardados en: {ruta}{extra}", text_color="#2ECC71")

    def actualizar_tabla_estado(self):
        """
        Consulta y muestra cronológicamente de forma descendente (del más reciente al más antiguo) 
        todos los eventos almacenados en la tabla 'entrada_salida'.
        """
        for w in self.scroll_estado.winfo_children():
            w.destroy()

        conn = get_connection()
        cur = conn.cursor()
        # Selección completa del historial de transacciones
        cur.execute('''
            SELECT
                es.id,
                es.id_usuario,
                es.nombre_usuario,
                es.placa,
                es.estado,
                es.fecha,
                COALESCE(es.categoria, ''),
                COALESCE(es.puesto, '')
            FROM entrada_salida es
            ORDER BY es.id DESC
        ''')
        registros = cur.fetchall()
        conn.close()

        # Definición visual de la cabecera
        headers = [
            ("ID MOV.", 90),
            ("ID USUARIO", 100),
            ("NOMBRE COMPLETO", 260),
            ("PLACA", 140),
            ("ESTADO", 160),
            ("FECHA / HORA", 200),
            ("CATEGORÍA", 100),
            ("PUESTO", 90)
        ]
        header = ctk.CTkFrame(self.scroll_estado, fg_color="#2C3E50", height=40)
        header.pack(fill="x", pady=2)
        for txt, w in headers:
            box = ctk.CTkFrame(
                header, fg_color="#34495E", width=w, height=36, corner_radius=0
            )
            box.pack(side="left", padx=1, pady=2)
            box.pack_propagate(False)
            ctk.CTkLabel(
                box, text=txt, font=("Arial", 10, "bold"), text_color="white"
            ).pack(expand=True)

        if not registros:
            ctk.CTkLabel(
                self.scroll_estado,
                text="No hay movimientos registrados todavía.",
                text_color="#AAA"
            ).pack(pady=20)
            return

        # Generar filas diferenciadas por color según el estado del movimiento (Entrada / Salida)
        for mov_id, uid, nombre, placa, estado, fecha, categoria, puesto in registros:
            row = ctk.CTkFrame(self.scroll_estado, fg_color="#212121", height=48)
            row.pack(fill="x", pady=2)
            row.pack_propagate(False)

            if estado == "Entrada":
                txt_est = "🟢 Ingresó (Dentro)"
                color = "#2ECC71"
            elif estado == "Denegado":
                txt_est = "⛔ Denegado"
                color = "#F39C12"
            else:
                txt_est = "🔴 Salió (Fuera)"
                color = "#E74C3C"

            celdas = [
                (f"#{mov_id}", 90),
                (f"#{uid}", 100),
                (nombre, 260),
                (placa, 140),
                (txt_est, 160),
                (fecha, 200),
                (categoria or "-", 100),
                (puesto or "-", 90),
            ]

            for i, (txt, w) in enumerate(celdas):
                c = ctk.CTkFrame(
                    row, fg_color="#2A2A2A", width=w, height=44, corner_radius=0
                )
                c.pack(side="left", padx=1, pady=2)
                c.pack_propagate(False)
                col = color if i == 4 else None
                ctk.CTkLabel(
                    c,
                    text=txt,
                    font=("Arial", 11, "bold" if i in (0, 1, 3, 4) else "normal"),
                    text_color=col,
                    anchor="w"
                ).pack(padx=8, expand=True, fill="x")

    def on_closing(self):
        """Manejador del evento de cierre de ventana que libera los recursos de la cámara y los hilos activos."""
        self.video_worker.stop()
        self.destroy()


# =========================================================================
# PUNTO DE ENTRADA DE LA APLICACIÓN
# =========================================================================
if __name__ == "__main__":
    app = AppAccesoVehicularFinal()
    app.protocol("WM_DELETE_WINDOW", app.on_closing)
    app.mainloop()
  
 
/**
 * @file cispph_core.h
 * @brief Núcleo de reglas del control de acceso C.I.S.P.P.H. (sin dependencias de hardware).
 *
 * Esta librería es de solo encabezado y NO usa Arduino.h, de modo que las mismas reglas
 * se prueban en un PC (g++) y se ejecutan en el microcontrolador. El hardware (lector RFID,
 * servo, pantalla) se maneja desde el sketch; aquí solo se decide si un acceso se autoriza.
 *
 * Reglas implementadas (todas son propuestas del equipo, ver docs/):
 *  - Categorías: NO_VIP (residente), VIS (visitante) y VIP (trato diferenciado).
 *  - Los visitantes consumen un cupo de un contador de puestos de visitantes (bien común).
 *  - Una tarjeta no puede entrar dos veces seguidas ni salir sin haber entrado.
 *  - Tres lecturas inválidas consecutivas bloquean el lector por un tiempo configurable
 *    (regla tomada de Galindo y Hernández, 2020).
 *  - Las reglas de tarifas, minutos de gracia y cobros NO se implementan: no están definidas.
 */
#ifndef CISPPH_CORE_H
#define CISPPH_CORE_H

#include <stdint.h>
#include <stddef.h>
#include <string.h>
#include <stdio.h>

namespace cispph {

constexpr size_t MAX_TARJETAS = 16;
constexpr size_t LONG_UID = 4;
constexpr uint8_t INTENTOS_MAXIMOS = 3;

enum class Categoria : uint8_t { SIN_CATEGORIA = 0, NO_VIP, VIS, VIP };
enum class Sentido : uint8_t { ENTRADA = 0, SALIDA };
enum class Decision : uint8_t {
    AUTORIZADO = 0,
    DENEGADO_DESCONOCIDA,   ///< UID no registrado o tarjeta inactiva
    DENEGADO_BLOQUEO,       ///< lector bloqueado por intentos fallidos
    DENEGADO_SIN_CUPO,      ///< no hay puestos de visitantes libres
    DENEGADO_YA_DENTRO,     ///< intenta entrar estando ya dentro
    DENEGADO_NO_DENTRO      ///< intenta salir sin haber entrado
};

struct Tarjeta {
    uint8_t uid[LONG_UID];
    Categoria categoria;
    bool activa;
    bool dentro;
};

struct Resultado {
    Decision decision;
    Categoria categoria;
    uint8_t visitantes_ocupados;
    uint8_t intentos_fallidos;
};

class ControlAcceso {
public:
    /**
     * @param puestos_visitantes cantidad de puestos de visitantes (bien común).
     * @param bloqueo_ms duración del bloqueo tras INTENTOS_MAXIMOS lecturas inválidas.
     * @param vip_consume_cupo si es verdadero, un VIP también ocupa un puesto de visitantes
     *        (parámetro pendiente de definir por la administración; por defecto falso).
     */
    explicit ControlAcceso(uint8_t puestos_visitantes = 5, uint32_t bloqueo_ms = 30000,
                           bool vip_consume_cupo = false)
        : n_(0), puestos_(puestos_visitantes), ocupados_(0), bloqueo_ms_(bloqueo_ms),
          vip_consume_(vip_consume_cupo), fallidos_(0), bloqueado_(false), fin_bloqueo_(0) {}

    /** Registra una tarjeta. Devuelve false si ya existe o no hay espacio. */
    bool registrar(const uint8_t uid[LONG_UID], Categoria cat) {
        if (n_ >= MAX_TARJETAS || cat == Categoria::SIN_CATEGORIA || buscar(uid) >= 0) return false;
        Tarjeta &t = tarjetas_[n_++];
        memcpy(t.uid, uid, LONG_UID);
        t.categoria = cat; t.activa = true; t.dentro = false;
        return true;
    }

    /** Desactiva una tarjeta (p. ej. pérdida). Devuelve false si no existe. */
    bool desactivar(const uint8_t uid[LONG_UID]) {
        int i = buscar(uid);
        if (i < 0) return false;
        tarjetas_[i].activa = false;
        return true;
    }

    /** Evalúa una lectura. @param ahora_ms reloj monótono (millis() en Arduino). */
    Resultado evaluar(const uint8_t uid[LONG_UID], Sentido sentido, uint32_t ahora_ms) {
        // El reloj puede dar la vuelta (~49 días en Arduino); la resta sin signo lo tolera.
        if (bloqueado_) {
            if ((int32_t)(ahora_ms - fin_bloqueo_) >= 0) { bloqueado_ = false; fallidos_ = 0; }
            else return armar(Decision::DENEGADO_BLOQUEO, Categoria::SIN_CATEGORIA);
        }
        int i = buscar(uid);
        if (i < 0 || !tarjetas_[i].activa) {
            if (++fallidos_ >= INTENTOS_MAXIMOS) { bloqueado_ = true; fin_bloqueo_ = ahora_ms + bloqueo_ms_; }
            return armar(Decision::DENEGADO_DESCONOCIDA, Categoria::SIN_CATEGORIA);
        }
        Tarjeta &t = tarjetas_[i];
        fallidos_ = 0;                       // una tarjeta válida reinicia el contador
        if (sentido == Sentido::ENTRADA) {
            if (t.dentro) return armar(Decision::DENEGADO_YA_DENTRO, t.categoria);
            if (usa_cupo(t.categoria)) {
                if (ocupados_ >= puestos_) return armar(Decision::DENEGADO_SIN_CUPO, t.categoria);
                ++ocupados_;
            }
            t.dentro = true;
            return armar(Decision::AUTORIZADO, t.categoria);
        }
        if (!t.dentro) return armar(Decision::DENEGADO_NO_DENTRO, t.categoria);
        if (usa_cupo(t.categoria) && ocupados_ > 0) --ocupados_;
        t.dentro = false;
        return armar(Decision::AUTORIZADO, t.categoria);
    }

    uint8_t visitantes_ocupados() const { return ocupados_; }
    uint8_t puestos_visitantes() const { return puestos_; }
    bool bloqueado() const { return bloqueado_; }

    /** Texto corto de una decisión, para pantalla o bitácora. */
    static const char *texto(Decision d) {
        switch (d) {
            case Decision::AUTORIZADO: return "AUTORIZADO";
            case Decision::DENEGADO_DESCONOCIDA: return "TARJETA INVALIDA";
            case Decision::DENEGADO_BLOQUEO: return "LECTOR BLOQUEADO";
            case Decision::DENEGADO_SIN_CUPO: return "SIN CUPO";
            case Decision::DENEGADO_YA_DENTRO: return "YA ESTA DENTRO";
            case Decision::DENEGADO_NO_DENTRO: return "NO ESTA DENTRO";
        }
        return "?";
    }
    static const char *texto(Categoria c) {
        switch (c) {
            case Categoria::NO_VIP: return "No VIP";
            case Categoria::VIS: return "VIS";
            case Categoria::VIP: return "VIP";
            default: return "-";
        }
    }

    /** Escribe una línea CSV (ms,uid,sentido,decision,categoria,ocupados). Devuelve los caracteres escritos. */
    static int linea_csv(char *buf, size_t cap, uint32_t ms, const uint8_t uid[LONG_UID],
                         Sentido s, const Resultado &r) {
        return snprintf(buf, cap, "%lu,%02X%02X%02X%02X,%s,%s,%s,%u",
                        (unsigned long)ms, uid[0], uid[1], uid[2], uid[3],
                        s == Sentido::ENTRADA ? "ENTRADA" : "SALIDA", texto(r.decision),
                        texto(r.categoria), (unsigned)r.visitantes_ocupados);
    }

private:
    Tarjeta tarjetas_[MAX_TARJETAS];
    size_t n_;
    uint8_t puestos_, ocupados_;
    uint32_t bloqueo_ms_;
    bool vip_consume_;
    uint8_t fallidos_;
    bool bloqueado_;
    uint32_t fin_bloqueo_;

    int buscar(const uint8_t uid[LONG_UID]) const {
        for (size_t i = 0; i < n_; ++i)
            if (memcmp(tarjetas_[i].uid, uid, LONG_UID) == 0) return (int)i;
        return -1;
    }
    bool usa_cupo(Categoria c) const {
        return c == Categoria::VIS || (c == Categoria::VIP && vip_consume_);
    }
    Resultado armar(Decision d, Categoria c) const { return Resultado{d, c, ocupados_, fallidos_}; }
};

}  // namespace cispph
#endif  // CISPPH_CORE_H

// Pruebas del núcleo de reglas. Compilar: g++ -std=c++11 -Wall -Wextra -o test_core test_core.cpp && ./test_core
#include "../cispph/cispph_core.h"
#include <cstdio>
#include <cstring>
using namespace cispph;

static int fallos = 0, total = 0;
#define VERIFICAR(cond, nombre) do { ++total; if (!(cond)) { ++fallos; std::printf("FALLA: %s\n", nombre); } else std::printf("ok:    %s\n", nombre); } while (0)

static const uint8_t RES[4] = {1,1,1,1}, VIS1[4] = {2,2,2,2}, VIS2[4] = {3,3,3,3}, VIPT[4] = {4,4,4,4}, DESC[4] = {9,9,9,9};

int main() {
    {   ControlAcceso c(1, 1000);
        c.registrar(RES, Categoria::NO_VIP);
        VERIFICAR(c.evaluar(RES, Sentido::ENTRADA, 0).decision == Decision::AUTORIZADO, "residente entra");
        VERIFICAR(c.visitantes_ocupados() == 0, "residente no consume cupo de visitantes");
        VERIFICAR(c.evaluar(RES, Sentido::ENTRADA, 1).decision == Decision::DENEGADO_YA_DENTRO, "no entra dos veces");
        VERIFICAR(c.evaluar(RES, Sentido::SALIDA, 2).decision == Decision::AUTORIZADO, "residente sale");
        VERIFICAR(c.evaluar(RES, Sentido::SALIDA, 3).decision == Decision::DENEGADO_NO_DENTRO, "no sale sin haber entrado");
    }
    {   ControlAcceso c(1, 1000);
        c.registrar(VIS1, Categoria::VIS); c.registrar(VIS2, Categoria::VIS);
        VERIFICAR(c.evaluar(VIS1, Sentido::ENTRADA, 0).decision == Decision::AUTORIZADO, "visitante 1 entra");
        VERIFICAR(c.visitantes_ocupados() == 1, "contador de visitantes = 1");
        VERIFICAR(c.evaluar(VIS2, Sentido::ENTRADA, 1).decision == Decision::DENEGADO_SIN_CUPO, "sin cupo para visitante 2");
        c.evaluar(VIS1, Sentido::SALIDA, 2);
        VERIFICAR(c.visitantes_ocupados() == 0, "la salida libera el cupo");
        VERIFICAR(c.evaluar(VIS2, Sentido::ENTRADA, 3).decision == Decision::AUTORIZADO, "visitante 2 entra tras liberar");
    }
    {   ControlAcceso c(1, 1000);          // VIP no consume cupo por defecto
        c.registrar(VIPT, Categoria::VIP); c.registrar(VIS1, Categoria::VIS);
        c.evaluar(VIS1, Sentido::ENTRADA, 0);
        VERIFICAR(c.evaluar(VIPT, Sentido::ENTRADA, 1).decision == Decision::AUTORIZADO, "VIP entra aunque no haya cupo (parametro por defecto)");
        ControlAcceso k(1, 1000, true);
        k.registrar(VIPT, Categoria::VIP); k.registrar(VIS1, Categoria::VIS);
        k.evaluar(VIS1, Sentido::ENTRADA, 0);
        VERIFICAR(k.evaluar(VIPT, Sentido::ENTRADA, 1).decision == Decision::DENEGADO_SIN_CUPO, "VIP consume cupo si el parametro lo indica");
    }
    {   ControlAcceso c(1, 1000);
        c.registrar(RES, Categoria::NO_VIP);
        c.evaluar(DESC, Sentido::ENTRADA, 0); c.evaluar(DESC, Sentido::ENTRADA, 1);
        VERIFICAR(!c.bloqueado(), "dos fallos no bloquean");
        c.evaluar(DESC, Sentido::ENTRADA, 2);
        VERIFICAR(c.bloqueado(), "tres fallos bloquean");
        VERIFICAR(c.evaluar(RES, Sentido::ENTRADA, 500).decision == Decision::DENEGADO_BLOQUEO, "bloqueado rechaza incluso tarjeta valida");
        VERIFICAR(c.evaluar(RES, Sentido::ENTRADA, 1002).decision == Decision::AUTORIZADO, "se desbloquea al vencer el tiempo");
    }
    {   ControlAcceso c(1, 1000);
        c.registrar(RES, Categoria::NO_VIP);
        c.evaluar(DESC, Sentido::ENTRADA, 0); c.evaluar(DESC, Sentido::ENTRADA, 1);
        c.evaluar(RES, Sentido::ENTRADA, 2);       // lectura valida reinicia
        c.evaluar(DESC, Sentido::ENTRADA, 3); c.evaluar(DESC, Sentido::ENTRADA, 4);
        VERIFICAR(!c.bloqueado(), "una lectura valida reinicia el contador");
    }
    {   ControlAcceso c(1, 1000);
        c.registrar(RES, Categoria::NO_VIP); c.desactivar(RES);
        VERIFICAR(c.evaluar(RES, Sentido::ENTRADA, 0).decision == Decision::DENEGADO_DESCONOCIDA, "tarjeta desactivada es rechazada");
        VERIFICAR(!c.registrar(RES, Categoria::VIS), "no se duplica un UID");
        VERIFICAR(!c.registrar(DESC, Categoria::SIN_CATEGORIA), "no se registra sin categoria");
    }
    {   ControlAcceso c(1, 1000);              // desborde del reloj de 32 bits
        c.registrar(RES, Categoria::NO_VIP);
        uint32_t t = 0xFFFFFF00u;
        c.evaluar(DESC, Sentido::ENTRADA, t); c.evaluar(DESC, Sentido::ENTRADA, t + 1); c.evaluar(DESC, Sentido::ENTRADA, t + 2);
        VERIFICAR(c.evaluar(RES, Sentido::ENTRADA, t + 10).decision == Decision::DENEGADO_BLOQUEO, "bloqueo cerca del desborde del reloj");
        VERIFICAR(c.evaluar(RES, Sentido::ENTRADA, t + 2 + 1000 + 1).decision == Decision::AUTORIZADO, "desbloqueo tras el desborde del reloj");
    }
    {   ControlAcceso c(2, 1000);
        c.registrar(VIS1, Categoria::VIS);
        Resultado r = c.evaluar(VIS1, Sentido::ENTRADA, 42);
        char b[96]; ControlAcceso::linea_csv(b, sizeof b, 42, VIS1, Sentido::ENTRADA, r);
        VERIFICAR(std::strcmp(b, "42,02020202,ENTRADA,AUTORIZADO,VIS,1") == 0, "linea CSV de bitacora");
    }
    std::printf("\n%d pruebas, %d fallos\n", total, fallos);
    return fallos == 0 ? 0 : 1;
}

#!/usr/bin/env python3
"""Crea el tablero «C.I.S.P.P.H.» en GitHub Projects a partir de tablero_cispph.csv.

Requisitos (una sola vez, en tu computador):
  1. Instalar GitHub CLI: https://cli.github.com
  2. gh auth login
  3. gh auth refresh -s project      (da permiso para usar Projects)

Uso:
  python crear_tablero_github.py --dry-run     # solo muestra lo que haría
  python crear_tablero_github.py               # lo crea de verdad
"""
import argparse, csv, json, subprocess, sys
from pathlib import Path

OWNER = "@me"
REPO = "SrMrLDavid/cispph"
TITULO = "C.I.S.P.P.H."
ETAPAS = ["Por hacer", "En curso", "Validando", "Hecho"]

ap = argparse.ArgumentParser()
ap.add_argument("--dry-run", action="store_true")
args = ap.parse_args()

def gh(*a, json_out=False):
    cmd = ["gh", *a]
    if args.dry_run:
        print("  $", " ".join(f'"{x}"' if " " in x else x for x in cmd))
        return {} if json_out else ""
    r = subprocess.run(cmd, capture_output=True, text=True)
    if r.returncode != 0:
        sys.exit(f"Error al ejecutar: {' '.join(cmd)}\n{r.stderr}")
    return json.loads(r.stdout) if json_out else r.stdout

filas = list(csv.DictReader(open(Path(__file__).with_name("tablero_cispph.csv"), encoding="utf-8-sig"), delimiter=";"))
fases = sorted({f["fase"] for f in filas})
print(f"{len(filas)} tareas, {len(fases)} fases")

print("1) Crear el proyecto")
p = gh("project", "create", "--owner", OWNER, "--title", TITULO, "--format", "json", json_out=True)
num, pid = str(p.get("number", "N")), p.get("id", "ID")

print("2) Crear los campos")
gh("project", "field-create", num, "--owner", OWNER, "--name", "Etapa", "--data-type", "SINGLE_SELECT", "--single-select-options", ",".join(ETAPAS))
gh("project", "field-create", num, "--owner", OWNER, "--name", "Fase", "--data-type", "SINGLE_SELECT", "--single-select-options", ",".join(fases))
gh("project", "field-create", num, "--owner", OWNER, "--name", "Enlace", "--data-type", "TEXT")

campos = gh("project", "field-list", num, "--owner", OWNER, "--format", "json", json_out=True).get("fields", [])
def campo(nombre): return next((c for c in campos if c["name"] == nombre), {"id": nombre, "options": []})
def opcion(c, texto): return next((o["id"] for o in c.get("options", []) if o["name"] == texto), texto)
cE, cF, cL = campo("Etapa"), campo("Fase"), campo("Enlace")

print("3) Cargar las tareas")
for f in filas:
    print("-", f["titulo"])
    it = gh("project", "item-create", num, "--owner", OWNER, "--title", f["titulo"], "--body", f["descripcion"], "--format", "json", json_out=True)
    iid = it.get("id", "ITEM")
    gh("project", "item-edit", "--id", iid, "--project-id", pid, "--field-id", cE["id"], "--single-select-option-id", opcion(cE, f["etapa"]))
    gh("project", "item-edit", "--id", iid, "--project-id", pid, "--field-id", cF["id"], "--single-select-option-id", opcion(cF, f["fase"]))
    if f["enlace"]:
        gh("project", "item-edit", "--id", iid, "--project-id", pid, "--field-id", cL["id"], "--text", f["enlace"])

print("4) Vincular al repositorio")
gh("project", "link", num, "--owner", OWNER, "--repo", REPO)
print("\nListo. Ábrelo en https://github.com/users/<tu-usuario>/projects/" + num)
print("Falta crear las vistas (Tablero, Hoja de ruta…): sigue GUIA_TABLERO_GITHUB.md, paso 3.")

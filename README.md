# WorshipHub

Monorepo del proyecto WorshipHub que contiene el backend (Spring Boot + Kotlin) y el frontend (Flutter).

## Estructura

```
WorshipHub/
├── .kiro/              # Configuración de Kiro (specs, steering, hooks, skills)
├── worship_hub_api/    # Backend - Spring Boot + Kotlin (submodule)
├── worship_hub_ui/     # Frontend - Flutter (submodule)
└── skills-lock.json    # Lock de skills de Kiro
```

## Submódulos

Este repositorio usa git submodules para los proyectos:

```bash
# Clonar con submódulos
git clone --recurse-submodules <repo-url>

# Si ya clonaste sin submódulos
git submodule update --init --recursive
```

## Proyectos

- **worship_hub_api**: API REST con Spring Boot, Kotlin, PostgreSQL. Ver [README](worship_hub_api/README.md).
- **worship_hub_ui**: App Flutter multiplataforma con Clean Architecture. Ver [README](worship_hub_ui/README.md).

# Generación automática de setlists

Documento canónico del motor de generación de setlists de WorshipHub: cómo funciona el algoritmo, qué filtros se aplican, dónde vive cada pieza, plantillas reutilizables y cómo extenderlo.

> **TL;DR** — El usuario define **N secciones libres** (1..20) con nombre + cantidad + filtros opcionales. Toda la lógica algorítmica vive en el backend Kotlin. El frontend Flutter recolecta parámetros y dispara `POST /api/v1/services/setlists/generate`. Las configuraciones favoritas se persisten como `SetlistTemplate` por iglesia.

---

## 1. Filosofía del modelo

A diferencia de versiones anteriores, **no existen "slots litúrgicos" fijos** (OPENING / WORSHIP / OFFERING / CLOSING). Una canción puede cantarse en cualquier momento del servicio — solo está marcada con `categories` y `tags` libres que el líder usa al filtrar por sección.

**¿Por qué?**

- La realidad pastoral es diversa: algunas iglesias tienen comunión, otras llamado al altar, otras solo bloque continuo.
- Las canciones no encajan rígidamente en un solo momento — un himno de adoración puede abrir, cerrar o aparecer en medio.
- Hardcodear 4 slots forzaba al admin a renombrar las categorías semilla, perdiendo el binding y rompiendo la generación.
- El modelo libre + plantillas guarda lo mejor de ambos: rapidez para casos comunes, flexibilidad total para casos no comunes.

---

## 2. Reparto de responsabilidades

| Capa | Responsabilidad |
|---|---|
| **Frontend** (`worship_hub_ui`, Flutter) | Form de secciones (cards expandibles + drag-reorder), selector de plantillas, validación cross-field (BPM min ≤ max), serialización a JSON omitiendo nulos, llamada HTTP. |
| **Backend** (`worship_hub_api`, Kotlin/Spring Boot) | Bean Validation, consulta JPQL al catálogo por `(categoryIds, tagIds)`, pipeline de filtrado, ordenación por rotación, shuffle acotado, persistencia de setlist y plantillas. |

---

## 3. Endpoint de generación

```
POST /api/v1/services/setlists/generate
Headers:
  Authorization: Bearer <jwt>
  Church-Id: <uuid>
Body:
  {
    "name": "Servicio Domingo 2026-06-14",
    "rules": {
      "sections": [
        {
          "name": "Apertura",
          "count": 1,
          "categoryIds": ["<uuid>"]
        },
        {
          "name": "Adoración",
          "count": 3,
          "minBpm": 70,
          "maxBpm": 100,
          "categoryIds": ["<uuid-1>", "<uuid-2>"],
          "tagIds": ["<uuid-tag>"]
        },
        { "name": "Ofrenda", "count": 1 },
        { "name": "Cierre",   "count": 1 }
      ],
      "excludeRecentDays": 14,
      "minBpm": 60,
      "maxBpm": 140,
      "preferredKeys": ["G", "D"],
      "excludeSongIds": []
    }
  }
Responses:
  201 Created          → { "setlistId": "<uuid>" }
  400 Bad Request      → reglas inválidas (ver Bean Validation)
  403 Forbidden        → falta rol WORSHIP_LEADER o CHURCH_ADMIN
  409 Conflict         → no hay canciones suficientes para alguna sección
                         (validationErrors carry per-section deficits, e.g.
                          "[2] Adoración": "Missing 1 song(s)")
```

Autorización: [`ServiceEventController.kt`](../../worship_hub_api/api/src/main/kotlin/com/worshiphub/api/scheduling/ServiceEventController.kt) — `@PreAuthorize("hasRole('WORSHIP_LEADER') or hasRole('CHURCH_ADMIN')")`.

---

## 4. Catálogo de filtros

Estructura completa en [`GenerateSetlistCommand.kt`](../../worship_hub_api/application/src/main/kotlin/com/worshiphub/application/scheduling/GenerateSetlistCommand.kt).

### 4.1 Globales (en `SetlistRules`)

Aplican a todas las secciones que no los sobrescriban.

| Campo | Tipo | Comportamiento |
|---|---|---|
| `excludeRecentDays` | `Int?` `@PositiveOrZero` | Excluye canciones con `lastUsedAt` dentro de los últimos N días. `null`/`0` = no aplica. |
| `minBpm` | `Int?` (0..300) | Cota inferior de BPM. Canciones sin BPM **se mantienen** (best-effort). |
| `maxBpm` | `Int?` (0..300) | Cota superior de BPM. |
| `preferredKeys` | `List<String>` | **No excluye** — promueve canciones cuyo `key` esté en la lista al frente del pool. |
| `excludeSongIds` | `List<UUID>` | Lista negra dura — IDs jamás aparecerán. |

`preferredKeys` y `excludeSongIds` viven **solo a nivel global**: no tiene sentido excluir una canción específica "solo en la ofrenda" pero permitirla en otra sección.

### 4.2 Por sección (en `SectionRules`)

| Campo | Tipo | Comportamiento |
|---|---|---|
| `name` | `String` `@NotBlank @Size(max=50)` | Nombre libre ("Apertura", "Comunión", "Llamado al altar"). |
| `count` | `Int` `@Min(1) @Max(20)` | Canciones a elegir para esta sección. |
| `excludeRecentDays` | `Int?` | Override del valor global. Si es `0`, **desactiva** el filtro para esta sección incluso si el global lo activa. |
| `minBpm` | `Int?` | Override del valor global. |
| `maxBpm` | `Int?` | Override del valor global. |
| `categoryIds` | `List<UUID>` | Filtro **OR** por categoría. Vacío = sin restricción. |
| `tagIds` | `List<UUID>` | Filtro **OR** por tag. Vacío = sin restricción. |

**Semántica AND-between, OR-within:**
- `categoryIds: ["A", "B"]` → canción debe estar en A **OR** B.
- `tagIds: ["X"]` → canción debe tener X.
- Si ambos están presentes, debe satisfacer las dos dimensiones.

### 4.3 Implícitos (siempre activos, no configurables)

| Filtro | Implementación |
|---|---|
| **Pertenencia a la iglesia** | `WHERE s.churchId = :churchId` en JPQL ([`SongRepositoryImpl.kt`](../../worship_hub_api/infrastructure/src/main/kotlin/com/worshiphub/infrastructure/repository/SongRepositoryImpl.kt)). |
| **Sin duplicados entre secciones** | Set acumulador `alreadyPicked` ([`SetlistGenerationService.kt`](../../worship_hub_api/application/src/main/kotlin/com/worshiphub/application/scheduling/SetlistGenerationService.kt)). Una canción que pase los filtros de varias secciones se elige solo una vez (gana la primera sección en el orden). |
| **Rotación por uso** | Sort estable: `lastUsedAt ASC NULLS FIRST`, luego `usageCount ASC`. Las menos usadas / hace más tiempo no usadas, primero. |
| **Shuffle acotado** | Dentro de `max(rotationWindow=12, count*3)` se baraja antes de truncar. Garantiza variedad entre generaciones consecutivas. |

---

## 5. Algoritmo paso a paso

```
Para cada sección en `rules.sections` (en orden):

  1. Resolver filtros efectivos
     effectiveRecency = section.excludeRecentDays ?? rules.excludeRecentDays
     effectiveMin     = section.minBpm           ?? rules.minBpm
     effectiveMax     = section.maxBpm           ?? rules.maxBpm

  2. Pool inicial
     SongRepository.findByChurchAndCategoriesAndTags(
         churchId,
         categoryIds = section.categoryIds,
         tagIds      = section.tagIds
     )
     → JPQL con AND-between dimensiones, OR-within cada lista.
     → Si ambas listas están vacías, retorna todas las canciones de la iglesia.

  3. Pipeline de filtrado (en orden barato → caro)
     pool
       .filter { id ∉ rules.excludeSongIds }     // exclusión dura
       .filter { id ∉ alreadyPicked }            // sin duplicados entre secciones
       .filter { matchesBpmRange(effectiveMin, effectiveMax) }
       .filter { passesRecencyFilter(effectiveRecency) }

  4. Ordenación para rotación
     orderForRotation(filtered, rules.preferredKeys)
       sort by:
         · preferredKey match            // promueve preferidas (estable)
         · lastUsedAt ASC NULLS FIRST    // hace más tiempo primero
         · usageCount ASC                // menos usadas primero

  5. Shuffle acotado
     pickPool = ordered.take(max(12, section.count * 3))
     pickPool.shuffle()
     picked   = pickPool.take(section.count)

  6. Detección de déficit
     Si picked.size < section.count → registra deficit en `deficits["[index] name"]`

  7. Acumular
     selected += picked
     alreadyPicked += picked

Si hay deficits → throw InsufficientSongsException(deficits)
                  → HTTP 409 con desglose por sección (incluye índice 1-based
                    para distinguir secciones con nombres duplicados)
Si no → construir Setlist (en memoria) y persistir
```

El servicio es determinista módulo el `shuffle()` — usa el `Random` por defecto. El `Clock` se inyecta para tests reproducibles.

---

## 6. Plantillas

Las **plantillas** son configuraciones guardadas (`SetlistRules` serializado) por iglesia que el líder puede recargar para acelerar generaciones repetidas (servicio dominical AM, vigilia, comunión, etc).

### 6.1 Modelo

[`SetlistTemplate`](../../worship_hub_api/domain/src/main/kotlin/com/worshiphub/domain/scheduling/SetlistTemplate.kt) (entidad):

| Campo | Tipo | Notas |
|---|---|---|
| `id` | `UUID` | Identificador único. |
| `churchId` | `UUID` | FK a `churches`, `ON DELETE CASCADE`. |
| `name` | `String` | 1..100 chars. **Único por iglesia**. |
| `rulesJson` | `TEXT` | JSON-serialised `SetlistRules`. |
| `createdBy` | `UUID?` | Nullable: sobrevive a soft-delete del usuario. |
| `createdAt` / `updatedAt` | `Instant` | Auto-actualizados. |

Persistencia opaca: la entidad no conoce el schema de `SetlistRules`. La (de)serialización ocurre en el [`SetlistTemplateController`](../../worship_hub_api/api/src/main/kotlin/com/worshiphub/api/scheduling/SetlistTemplateController.kt) usando el `ObjectMapper` de Spring (Jackson 3 / `tools.jackson`).

### 6.2 Endpoints

```
GET    /api/v1/setlist-templates           # listar (TEAM_MEMBER+)
GET    /api/v1/setlist-templates/{id}      # detalle (TEAM_MEMBER+)
POST   /api/v1/setlist-templates           # crear (WORSHIP_LEADER+)
PUT    /api/v1/setlist-templates/{id}      # actualizar (WORSHIP_LEADER+)
DELETE /api/v1/setlist-templates/{id}      # borrar (WORSHIP_LEADER+)
```

Autorización: lectura abierta a cualquier miembro de la iglesia; mutación restringida a `WORSHIP_LEADER` o `CHURCH_ADMIN` (mismo nivel que `/generate`). Acceso cross-tenant (id válido pero de otra iglesia) se reporta como **404** para no filtrar existencia.

Errores específicos:
- `409 Duplicate Template Name` — el nombre ya existe en la iglesia.
- `404 Template Not Found` — id inexistente o de otra iglesia.

### 6.3 UX en el frontend

[`generate_setlist_page.dart`](../../worship_hub_ui/lib/presentation/features/setlists/pages/generate_setlist_page.dart) muestra una `TemplateSelectorBar` arriba del form:

- **Chip "En blanco"** + chips por plantilla guardada. Tap selecciona y carga sus reglas en el form.
- **Botón "Guardar como"** abre `SaveTemplateDialog` para persistir la configuración actual.
- **× en la plantilla seleccionada** la borra (con confirmación implícita por la separación visual de la acción).

Las plantillas no se cachean localmente — son infrecuentemente mutadas y siempre se leen online junto con el flujo de generación. Ver el comentario en [`SetlistTemplateRepositoryImpl`](../../worship_hub_ui/lib/data/repositories/setlist_template_repository_impl.dart) para la justificación.

---

## 7. Flujo end-to-end

```
┌─────────────────────────────────────────────────────────────────────┐
│ FRONTEND (Flutter)                                                  │
└─────────────────────────────────────────────────────────────────────┘

GenerateSetlistPage  (generate_setlist_page.dart)
  · TemplateSelectorBar — opcional: cargar plantilla
  · GlobalFiltersCard — recencia, BPM, tonalidades preferidas
  · ReorderableListView de SectionFilterCard
       · Editar nombre inline, _CountStepper para cantidad
       · Tap expande overrides: categorías (multi-select), tags,
         recencia per-sección, BPM per-sección
  · _onGenerate() valida y emite SetlistGenerateRequested
          ↓
SetlistBloc._onGenerateRequested  (setlist_bloc.dart)
  · emit(SetlistLoading)
  · await generateSetlist(name, rules)
          ↓
SetlistRules.toJson() — omite null/0/vacíos
          ↓
SetlistRepositoryImpl  (setlist_repository_impl.dart)
  POST {baseUrl}/services/setlists/generate

┌─────────────────────────────────────────────────────────────────────┐
│ BACKEND (Kotlin/Spring Boot)                                        │
└─────────────────────────────────────────────────────────────────────┘

ServiceEventController.generateSetlist  (ServiceEventController.kt)
  · @Valid valida SetlistRules + SectionRules anidados
  · Construye GenerateSetlistCommand
          ↓
SchedulingApplicationService.generateSetlist  (SchedulingApplicationService.kt)
  · setlistGenerationService.generate(name, churchId, rules)  ← núcleo (§5)
  · setlistRepository.save(generated)
          ↓
HTTP 201 Created  →  { setlistId }

┌─────────────────────────────────────────────────────────────────────┐
│ FRONTEND (continuación)                                             │
└─────────────────────────────────────────────────────────────────────┘

SetlistRepositoryImpl
  · _mapFromApi(response.data) + _saveOrUpdateLocal (Drift)
          ↓
SetlistBloc emite SetlistGenerated
          ↓
GenerateSetlistPage
  · Pop + SnackBar de éxito
```

---

## 8. Bucle de retroalimentación: rotación

La rotación solo funciona si los setlists se marcan como **reproducidos** después del servicio:

```
POST /api/v1/services/setlists/{setlistId}/mark-played
        ↓
SchedulingApplicationService.markSetlistAsPlayed
        ↓
Por cada Song del setlist:
  Song.markPlayed(playedAt)
    · lastUsedAt = playedAt
    · usageCount += 1
        ↓
Próxima generación:
  · Filtro `excludeRecentDays` deja fuera estas canciones durante N días
  · Sort por rotación las baja al final del pool
```

**Diseño consciente:** la rotación es *pull-based* (la generación pregunta por `lastUsedAt`) en lugar de *push-based* (un job que rota canciones). Esto permite varios servicios el mismo día sin colisiones, y mantiene el algoritmo puro/sin estado entre llamadas.

---

## 9. Cómo extender: añadir un nuevo filtro

Ejemplo — agregar filtro por idioma:

1. **Backend** — extender `SectionRules` y/o `SetlistRules` en [`GenerateSetlistCommand.kt`](../../worship_hub_api/application/src/main/kotlin/com/worshiphub/application/scheduling/GenerateSetlistCommand.kt) con la nueva propiedad y validación:
   ```kotlin
   data class SectionRules(
       // ...campos existentes...
       val languages: List<String> = emptyList(),
   )
   ```

2. **Backend** — añadir un `.filter { ... }` al pipeline de [`SetlistGenerationService.kt`](../../worship_hub_api/application/src/main/kotlin/com/worshiphub/application/scheduling/SetlistGenerationService.kt):
   ```kotlin
   .filter { song -> section.languages.isEmpty() || song.language in section.languages }
   ```

3. **Frontend (dominio)** — espejo en `SectionRules` Dart y su `toJson()` en [`generate_setlist.dart`](../../worship_hub_ui/lib/domain/usecases/generate_setlist.dart):
   ```dart
   final List<String> languages;
   if (languages.isNotEmpty) json['languages'] = languages;
   ```

4. **Frontend (UI)** — añadir input en [`SectionFilterCard`](../../worship_hub_ui/lib/presentation/features/setlists/widgets/section_filter_card.dart) dentro del bloque de overrides.

5. **Tests** — añadir caso en [`SetlistGenerationServiceTest`](../../worship_hub_api/application/src/test/kotlin/com/worshiphub/application/scheduling/SetlistGenerationServiceTest.kt) y [`setlist_rules_test.dart`](../../worship_hub_ui/test/unit/usecases/setlist_rules_test.dart).

> Mantén el orden del pipeline `barato → caro`. Filtros con coste constante (set membership, comparación numérica) van primero. Filtros que tocan la BD o cargan blobs van al final.

---

## 10. Errores comunes y troubleshooting

| Síntoma | Causa probable | Dónde mirar |
|---|---|---|
| `409 InsufficientSongsException` con `[2] Adoración: Missing 2 song(s)` | El catálogo no tiene suficientes canciones que pasen los filtros para esa sección. | Reducir `excludeRecentDays`, ampliar BPM, quitar categorías/tags muy estrechos, o crear más canciones. El número entre corchetes es el índice 1-based. |
| `400 Bad Request` en validación | Campos inválidos: `count` fuera de 1..20, BPM > 300, `name` vacío, `sections` lista vacía. | Anotaciones `@Min`/`@Max`/`@NotBlank` en `SetlistRules`/`SectionRules`. |
| `409 Duplicate Template Name` | Ya existe una plantilla con ese nombre en la iglesia. | Cambiar nombre o eliminar la anterior. |
| `404 Template Not Found` | ID inexistente, o el ID pertenece a otra iglesia (mensaje deliberadamente ambiguo). | Verificar que el ID corresponde a una plantilla de la iglesia activa. |
| Dos generaciones idénticas | El shuffle siempre opera con `Random` por defecto. Si el pool tiene **menos canciones que `count`**, no hay nada que barajar. | Ampliar el catálogo de la iglesia o relajar filtros. |
| Rotación no parece funcionar | Nadie está marcando setlists como `played`. | Endpoint `mark-played` (§8). Sin ese disparo, `lastUsedAt`/`usageCount` quedan estáticos. |
| `categoryIds` por sección no filtra | Las canciones del catálogo no tienen esas categorías asignadas. | Asignar canciones a categorías desde el form de canción. |

---

## 11. Referencias de código

### Backend

| Archivo | Rol |
|---|---|
| [`ServiceEventController.kt`](../../worship_hub_api/api/src/main/kotlin/com/worshiphub/api/scheduling/ServiceEventController.kt) | Endpoint `POST /generate` |
| [`SetlistTemplateController.kt`](../../worship_hub_api/api/src/main/kotlin/com/worshiphub/api/scheduling/SetlistTemplateController.kt) | CRUD de plantillas |
| [`GenerateSetlistRequest.kt`](../../worship_hub_api/api/src/main/kotlin/com/worshiphub/api/scheduling/GenerateSetlistRequest.kt) | DTO HTTP de `/generate` |
| [`SetlistTemplateDTOs.kt`](../../worship_hub_api/api/src/main/kotlin/com/worshiphub/api/scheduling/SetlistTemplateDTOs.kt) | DTOs de plantillas |
| [`GenerateSetlistCommand.kt`](../../worship_hub_api/application/src/main/kotlin/com/worshiphub/application/scheduling/GenerateSetlistCommand.kt) | `SetlistRules` + `SectionRules` con validación |
| [`SchedulingApplicationService.kt`](../../worship_hub_api/application/src/main/kotlin/com/worshiphub/application/scheduling/SchedulingApplicationService.kt) | Orquestador de `/generate` |
| [`SetlistGenerationService.kt`](../../worship_hub_api/application/src/main/kotlin/com/worshiphub/application/scheduling/SetlistGenerationService.kt) | **Núcleo del algoritmo** |
| [`SetlistTemplateApplicationService.kt`](../../worship_hub_api/application/src/main/kotlin/com/worshiphub/application/scheduling/SetlistTemplateApplicationService.kt) | CRUD de plantillas + ownership |
| [`SetlistTemplate.kt`](../../worship_hub_api/domain/src/main/kotlin/com/worshiphub/domain/scheduling/SetlistTemplate.kt) | Entidad de dominio |
| [`SetlistTemplateRepository.kt`](../../worship_hub_api/domain/src/main/kotlin/com/worshiphub/domain/scheduling/repository/SetlistTemplateRepository.kt) | Interfaz repo |
| [`SongRepositoryImpl.kt`](../../worship_hub_api/infrastructure/src/main/kotlin/com/worshiphub/infrastructure/repository/SongRepositoryImpl.kt) | `findByChurchAndCategoriesAndTags` |
| [`SetlistTemplateRepositoryImpl.kt`](../../worship_hub_api/infrastructure/src/main/kotlin/com/worshiphub/infrastructure/repository/SetlistTemplateRepositoryImpl.kt) | JPA repo de plantillas |
| `V21__remove_slots_and_add_setlist_templates.sql` | Migración (drop `slot_type` + crear tabla `setlist_templates`) |

### Frontend

| Archivo | Rol |
|---|---|
| [`generate_setlist_page.dart`](../../worship_hub_ui/lib/presentation/features/setlists/pages/generate_setlist_page.dart) | UI del form (cards expandibles + plantillas) |
| [`section_filter_card.dart`](../../worship_hub_ui/lib/presentation/features/setlists/widgets/section_filter_card.dart) | Card expandible por sección |
| [`multi_select_field.dart`](../../worship_hub_ui/lib/presentation/features/setlists/widgets/multi_select_field.dart) | Picker buscable de categorías/tags |
| [`template_selector_bar.dart`](../../worship_hub_ui/lib/presentation/features/setlists/widgets/template_selector_bar.dart) | Barra de chips de plantillas |
| [`save_template_dialog.dart`](../../worship_hub_ui/lib/presentation/features/setlists/widgets/save_template_dialog.dart) | Modal "guardar plantilla" |
| [`generate_setlist.dart`](../../worship_hub_ui/lib/domain/usecases/generate_setlist.dart) | `SetlistRules` + `SectionRules` Dart con `toJson` |
| [`setlist_template.dart`](../../worship_hub_ui/lib/domain/entities/setlist_template.dart) | Entidad de plantilla |
| [`setlist_template_repository.dart`](../../worship_hub_ui/lib/domain/repositories/setlist_template_repository.dart) | Contrato repo |
| [`setlist_template_repository_impl.dart`](../../worship_hub_ui/lib/data/repositories/setlist_template_repository_impl.dart) | Cliente HTTP |
| [`setlist_template_bloc.dart`](../../worship_hub_ui/lib/presentation/features/setlists/bloc/setlist_template_bloc.dart) | Bloc para plantillas |
| [`service_locator.dart`](../../worship_hub_ui/lib/core/dependency_injection/service_locator.dart) | DI |

---

## 12. Documentos relacionados

- [`backend/overview.md`](./overview.md) — bounded contexts y catálogo completo de endpoints.
- [`architecture/cascade-deletion.md`](../architecture/cascade-deletion.md) — semántica de borrado de `setlist_templates` (cascade desde `churches`), `setlist_songs`, `setlists`.
- [`frontend/offline-first.md`](../frontend/offline-first.md) — sincronización del agregado `Setlist` en el cliente.
- [`worship_hub_api/README.md`](../../worship_hub_api/README.md) — entrada operativa del backend.

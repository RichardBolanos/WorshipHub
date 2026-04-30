# Plan de Implementación: Asociación de Etiquetas y Categorías en el Módulo de Canciones

## Visión General

Implementación incremental que conecta el flujo completo de etiquetas y categorías en canciones: primero los DTOs y comandos del backend, luego la lógica de servicio, después la persistencia local en Flutter, los widgets de selección, y finalmente el filtrado y la integración en las páginas de creación/edición.

## Tareas

- [x] 1. Extender DTOs y comandos del backend con tagIds/categoryIds
  - [x] 1.1 Agregar campos `tagIds: List<UUID>?` y `categoryIds: List<UUID>?` a `CreateSongRequest`
    - Agregar campos opcionales con anotaciones `@Schema` de OpenAPI
    - Archivo: `worship_hub_api/api/src/main/kotlin/com/worshiphub/api/catalog/CreateSongRequest.kt`
    - _Requisitos: 8.1_

  - [x] 1.2 Agregar campos `tagIds: List<UUID>?` y `categoryIds: List<UUID>?` a `UpdateSongRequest`
    - Agregar campos opcionales con anotaciones `@Schema` de OpenAPI
    - Archivo: `worship_hub_api/api/src/main/kotlin/com/worshiphub/api/catalog/UpdateSongRequest.kt`
    - _Requisitos: 8.2_

  - [x] 1.3 Agregar campos `tagIds: List<UUID>?` y `categoryIds: List<UUID>?` a `CreateSongCommand`
    - Archivo: `worship_hub_api/application/src/main/kotlin/com/worshiphub/application/catalog/CreateSongCommand.kt`
    - _Requisitos: 8.1, 8.3_

  - [x] 1.4 Agregar campos `tagIds: List<UUID>?` y `categoryIds: List<UUID>?` a `UpdateSongCommand`
    - Archivo: `worship_hub_api/application/src/main/kotlin/com/worshiphub/application/catalog/UpdateSongCommand.kt`
    - _Requisitos: 8.2, 8.4_

  - [x] 1.5 Actualizar `SongController.createSong()` para propagar `tagIds`/`categoryIds` del request al command
    - Archivo: `worship_hub_api/api/src/main/kotlin/com/worshiphub/api/catalog/SongController.kt`
    - _Requisitos: 8.1, 8.3_

  - [x] 1.6 Actualizar `SongController.updateSong()` para propagar `tagIds`/`categoryIds` del request al command y retornar `SongResponse` completo
    - Archivo: `worship_hub_api/api/src/main/kotlin/com/worshiphub/api/catalog/SongController.kt`
    - _Requisitos: 8.2, 8.4_

- [x] 2. Implementar resolución de tags/categories en CatalogApplicationService
  - [x] 2.1 Modificar `CatalogApplicationService.createSong()` para resolver `tagIds`/`categoryIds` a entidades y asociarlas a la canción
    - Validar que todos los IDs existen; retornar `Result.failure` con error descriptivo si alguno no existe
    - Si `tagIds`/`categoryIds` son `null`, crear canción sin asociaciones
    - Archivo: `worship_hub_api/application/src/main/kotlin/com/worshiphub/application/catalog/CatalogApplicationService.kt`
    - _Requisitos: 1.3, 1.4, 1.5, 8.3, 8.5_

  - [x] 2.2 Modificar `CatalogApplicationService.updateSong()` para resolver `tagIds`/`categoryIds` y reemplazar asociaciones
    - Si `tagIds`/`categoryIds` son `null`, mantener asociaciones existentes
    - Si son lista vacía, eliminar todas las asociaciones
    - Validar que todos los IDs existen
    - Archivo: `worship_hub_api/application/src/main/kotlin/com/worshiphub/application/catalog/CatalogApplicationService.kt`
    - _Requisitos: 2.3, 2.4, 8.4, 8.5_

  - [x] 2.3 Escribir test de propiedad para round-trip de creación con asociaciones
    - **Propiedad 1: Round-trip de creación de canción con asociaciones**
    - Generar canciones aleatorias con subconjuntos aleatorios de tags/categories existentes, crear vía servicio, obtener y verificar asociaciones
    - Usar Kotest property testing con mínimo 100 iteraciones
    - Comentario: `Feature: song-tags-categories, Property 1: Round-trip de creación de canción con asociaciones`
    - **Valida: Requisitos 1.3, 3.3, 8.1, 8.3**

  - [x] 2.4 Escribir test de propiedad para reemplazo completo de asociaciones en actualización
    - **Propiedad 2: Actualización reemplaza asociaciones completamente**
    - Generar canción con asociaciones, actualizar con nuevo conjunto aleatorio, verificar reemplazo completo
    - Usar Kotest property testing con mínimo 100 iteraciones
    - Comentario: `Feature: song-tags-categories, Property 2: Actualización reemplaza asociaciones completamente`
    - **Valida: Requisitos 2.3, 8.2, 8.4**

  - [x] 2.5 Escribir test de propiedad para IDs inválidos producen error
    - **Propiedad 3: IDs inválidos producen error 400**
    - Generar UUIDs aleatorios no existentes, intentar crear/actualizar, verificar error
    - Usar Kotest property testing con mínimo 100 iteraciones
    - Comentario: `Feature: song-tags-categories, Property 3: IDs inválidos producen error 400`
    - **Valida: Requisitos 1.5**

  - [x] 2.6 Escribir test de propiedad para IDs nulos preservan asociaciones
    - **Propiedad 4: IDs nulos preservan asociaciones existentes en actualización**
    - Generar canción con asociaciones, actualizar sin tagIds/categoryIds, verificar que asociaciones se mantienen
    - Usar Kotest property testing con mínimo 100 iteraciones
    - Comentario: `Feature: song-tags-categories, Property 4: IDs nulos preservan asociaciones existentes en actualización`
    - **Valida: Requisitos 8.5**

- [x] 3. Checkpoint - Verificar backend
  - Asegurar que todos los tests pasan, preguntar al usuario si surgen dudas.

- [x] 4. Agregar columna categories a Drift y actualizar mapeo local
  - [x] 4.1 Agregar columna `categories` a la tabla `Songs` en Drift con `CategoryListConverter`
    - Crear `CategoryListConverter` similar a `TagListConverter` existente
    - Incrementar `schemaVersion` y agregar migración
    - Archivo: `worship_hub_ui/lib/core/database/database.dart`
    - _Requisitos: 7.1_

  - [x] 4.2 Actualizar `_mapFromDb()` y `_mapToDb()` en `SongRepositoryImpl` para incluir categories
    - Leer y escribir categories desde/hacia la nueva columna de Drift
    - Archivo: `worship_hub_ui/lib/data/repositories/song_repository_impl.dart`
    - _Requisitos: 7.1, 7.2, 7.3_

  - [x] 4.3 Actualizar `createSong()` y `updateSong()` en `SongRepositoryImpl` para enviar `tagIds`/`categoryIds` al API
    - Extraer IDs de las listas de tags/categories del Song entity y enviarlos como `tagIds`/`categoryIds` en el body HTTP
    - Archivo: `worship_hub_ui/lib/data/repositories/song_repository_impl.dart`
    - _Requisitos: 1.2, 2.2, 8.1, 8.2_

  - [x] 4.4 Escribir test de propiedad para round-trip de persistencia local
    - **Propiedad 6: Round-trip de persistencia local de etiquetas y categorías**
    - Generar canciones con tags/categories aleatorios, guardar en Drift, leer y comparar
    - Usar glados con mínimo 100 iteraciones
    - Comentario: `Feature: song-tags-categories, Property 6: Round-trip de persistencia local de etiquetas y categorías`
    - **Valida: Requisitos 7.1, 7.2**

- [x] 5. Crear widgets Selector_Etiquetas y Selector_Categorías
  - [x] 5.1 Crear widget `TagSelectorWidget` reutilizable
    - Recibe `availableTags`, `selectedTags`, `onChanged` callback
    - Muestra tags como chips seleccionables con su color
    - Incluye botón "+" para crear nueva etiqueta inline (llama a API `POST /api/v1/tags`)
    - Manejo de error al crear etiqueta: mostrar SnackBar y mantener selección previa
    - Archivo: `worship_hub_ui/lib/presentation/features/songs/widgets/tag_selector_widget.dart`
    - _Requisitos: 1.1, 5.1, 5.3, 5.4_

  - [x] 5.2 Crear widget `CategorySelectorWidget` reutilizable
    - Recibe `availableCategories`, `selectedCategories`, `onChanged` callback
    - Muestra categorías como chips seleccionables diferenciados visualmente de tags
    - Incluye botón "+" para crear nueva categoría inline (llama a API `POST /api/v1/categories`)
    - Manejo de error al crear categoría: mostrar SnackBar y mantener selección previa
    - Archivo: `worship_hub_ui/lib/presentation/features/songs/widgets/category_selector_widget.dart`
    - _Requisitos: 1.1, 5.2, 5.3, 5.4_

  - [x] 5.3 Escribir widget tests para TagSelectorWidget y CategorySelectorWidget
    - Verificar que muestra tags/categories disponibles
    - Verificar que permite selección/deselección
    - Verificar que el botón "+" abre diálogo de creación
    - _Requisitos: 1.1, 5.1, 5.2_

- [x] 6. Integrar selectores en páginas de creación y edición
  - [x] 6.1 Agregar eventos y estados al SongBloc para cargar tags/categories disponibles
    - Agregar evento `LoadTagsAndCategories` y estado con listas de tags/categories
    - Cargar tags vía `TagRepository` y categories vía `CategoryRepository` al iniciar formulario
    - Archivos: `worship_hub_ui/lib/presentation/features/songs/bloc/song_event.dart`, `song_state.dart`, `song_bloc.dart`
    - _Requisitos: 1.1, 2.1_

  - [x] 6.2 Modificar `CreateSongPage` para incluir `TagSelectorWidget` y `CategorySelectorWidget`
    - Cargar tags/categories disponibles al abrir la página
    - Incluir IDs seleccionados en el Song entity al guardar
    - Archivo: `worship_hub_ui/lib/presentation/features/songs/pages/create_song_page.dart`
    - _Requisitos: 1.1, 1.2, 1.4_

  - [x] 6.3 Crear `EditSongPage` o modificar flujo existente para edición con selectores
    - Mostrar tags/categories actuales como preseleccionados
    - Enviar lista completa de IDs al guardar
    - _Requisitos: 2.1, 2.2, 2.3, 2.4_

  - [x] 6.4 Escribir BLoC tests para carga de tags/categories y creación/edición con asociaciones
    - Verificar que `LoadTagsAndCategories` emite estado con listas correctas
    - Verificar que crear canción con tags/categories emite estado correcto
    - _Requisitos: 1.1, 1.2, 2.1, 2.2_

- [x] 7. Checkpoint - Verificar flujo de creación/edición
  - Asegurar que todos los tests pasan, preguntar al usuario si surgen dudas.

- [x] 8. Visualización de tags/categories en lista y detalle
  - [x] 8.1 Modificar `SongCard` para mostrar chips de categorías diferenciados de tags
    - Tags como chips con color de la etiqueta
    - Categorías como chips con estilo visual diferenciado (ej: outlined vs filled)
    - Archivo: `worship_hub_ui/lib/presentation/features/songs/widgets/song_card.dart`
    - _Requisitos: 3.1, 3.2_

  - [x] 8.2 Modificar `SongDetailPage` para mostrar tags con nombre/color y categories con nombre/descripción
    - Mostrar botón de editar tags/categories para usuarios con rol WORSHIP_LEADER o CHURCH_ADMIN
    - Archivo: `worship_hub_ui/lib/presentation/features/songs/pages/song_detail_page.dart`
    - _Requisitos: 4.1, 4.2, 4.3_

- [x] 9. Implementar filtrado por tags y categories
  - [x] 9.1 Modificar `FilterBottomSheet` para incluir selectores de categoría y tags
    - Permitir seleccionar una categoría y múltiples tags
    - Conectar con el endpoint `GET /api/v1/songs/filter` existente
    - Archivo: `worship_hub_ui/lib/presentation/features/songs/widgets/filter_bottom_sheet.dart`
    - _Requisitos: 6.1, 6.2, 6.3, 6.4_

  - [x] 9.2 Escribir test de propiedad para filtrado por categoría y etiquetas
    - **Propiedad 5: Filtrado por categoría y etiquetas**
    - Generar conjunto de canciones con asociaciones variadas, aplicar filtros aleatorios, verificar que resultados cumplen criterios
    - Usar Kotest property testing con mínimo 100 iteraciones
    - Comentario: `Feature: song-tags-categories, Property 5: Filtrado por categoría y etiquetas`
    - **Valida: Requisitos 6.1, 6.2, 6.3**

- [x] 10. Checkpoint final - Verificar integración completa
  - Asegurar que todos los tests pasan, preguntar al usuario si surgen dudas.

## Notas

- Las tareas marcadas con `*` son opcionales y pueden omitirse para un MVP más rápido
- Cada tarea referencia requisitos específicos para trazabilidad
- Los checkpoints aseguran validación incremental
- Los tests de propiedades validan propiedades universales de correctitud
- Los tests unitarios validan ejemplos específicos y edge cases
- Backend usa Kotlin/Kotest, Frontend usa Dart/glados para property-based testing

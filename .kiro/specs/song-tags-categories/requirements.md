# Documento de Requisitos: Asociación de Etiquetas y Categorías en el Módulo de Canciones

## Introducción

Este documento define los requisitos para integrar completamente las etiquetas (tags) y categorías en el módulo de canciones de WorshipHub. Actualmente, el backend tiene la estructura de datos y endpoints para asociar etiquetas y categorías a canciones (tablas `song_tags` y `song_categories`, relaciones JPA ManyToMany, y endpoints de asignación), pero el flujo completo no está conectado: al crear o editar una canción no se envían ni persisten las etiquetas/categorías seleccionadas, el frontend no ofrece UI para seleccionarlas durante la creación/edición, y la visualización de etiquetas/categorías asociadas a una canción es incompleta.

## Glosario

- **Sistema_Canciones**: Módulo completo de gestión de canciones (backend API + frontend Flutter)
- **API_Canciones**: Backend REST API de Spring Boot para operaciones de canciones (`SongController`, `CatalogApplicationService`)
- **UI_Canciones**: Frontend Flutter del módulo de canciones (páginas, BLoC, repositorio)
- **Canción**: Entidad principal del catálogo musical de una iglesia
- **Etiqueta**: Entidad `Tag` para etiquetado flexible de canciones (ej: "Navidad", "Comunión")
- **Categoría**: Entidad `Category` para clasificación de canciones por tipo (ej: "Adoración", "Alabanza")
- **Selector_Etiquetas**: Componente de UI que permite seleccionar etiquetas existentes o crear nuevas
- **Selector_Categorías**: Componente de UI que permite seleccionar categorías existentes o crear nuevas
- **ChurchId**: Identificador único de la iglesia propietaria de las canciones, etiquetas y categorías

## Requisitos

### Requisito 1: Asociar etiquetas y categorías al crear una canción

**User Story:** Como líder de adoración, quiero seleccionar etiquetas y categorías al crear una canción, para que la canción quede clasificada desde el momento de su creación.

#### Criterios de Aceptación

1. WHEN un usuario crea una canción, THE UI_Canciones SHALL mostrar el Selector_Etiquetas y el Selector_Categorías en el formulario de creación de canción.
2. WHEN un usuario selecciona etiquetas y categorías y envía el formulario de creación, THE UI_Canciones SHALL incluir los IDs de las etiquetas y categorías seleccionadas en la solicitud de creación al API_Canciones.
3. WHEN la API_Canciones recibe una solicitud de creación de canción con IDs de etiquetas y categorías, THE API_Canciones SHALL persistir la canción con las asociaciones a las etiquetas y categorías indicadas en una sola transacción.
4. WHEN un usuario crea una canción sin seleccionar etiquetas ni categorías, THE Sistema_Canciones SHALL crear la canción sin asociaciones de etiquetas ni categorías.
5. IF la API_Canciones recibe IDs de etiquetas o categorías que no existen, THEN THE API_Canciones SHALL retornar un error 400 indicando los IDs inválidos.

### Requisito 2: Editar etiquetas y categorías de una canción existente

**User Story:** Como líder de adoración, quiero modificar las etiquetas y categorías de una canción existente, para mantener la clasificación actualizada.

#### Criterios de Aceptación

1. WHEN un usuario abre el formulario de edición de una canción, THE UI_Canciones SHALL mostrar las etiquetas y categorías actualmente asociadas a la canción como preseleccionadas en el Selector_Etiquetas y Selector_Categorías.
2. WHEN un usuario modifica las etiquetas o categorías y guarda los cambios, THE UI_Canciones SHALL enviar la lista completa de IDs de etiquetas y categorías seleccionadas al API_Canciones.
3. WHEN la API_Canciones recibe una solicitud de actualización de canción con IDs de etiquetas y categorías, THE API_Canciones SHALL reemplazar las asociaciones existentes con las nuevas asociaciones indicadas.
4. WHEN un usuario elimina todas las etiquetas y categorías de una canción y guarda, THE API_Canciones SHALL eliminar todas las asociaciones de etiquetas y categorías de la canción.

### Requisito 3: Visualizar etiquetas y categorías en la lista de canciones

**User Story:** Como miembro del equipo, quiero ver las etiquetas y categorías de cada canción en la lista, para identificar rápidamente la clasificación de las canciones.

#### Criterios de Aceptación

1. THE UI_Canciones SHALL mostrar las etiquetas asociadas a cada canción como chips con el color correspondiente en la tarjeta de canción de la lista.
2. THE UI_Canciones SHALL mostrar las categorías asociadas a cada canción como chips diferenciados visualmente de las etiquetas en la tarjeta de canción.
3. WHEN la API_Canciones retorna la lista de canciones, THE API_Canciones SHALL incluir las etiquetas y categorías asociadas a cada canción en la respuesta.

### Requisito 4: Visualizar etiquetas y categorías en el detalle de canción

**User Story:** Como miembro del equipo, quiero ver las etiquetas y categorías en la página de detalle de una canción, para conocer su clasificación completa.

#### Criterios de Aceptación

1. WHEN un usuario abre el detalle de una canción, THE UI_Canciones SHALL mostrar todas las etiquetas asociadas con su nombre y color.
2. WHEN un usuario abre el detalle de una canción, THE UI_Canciones SHALL mostrar todas las categorías asociadas con su nombre y descripción.
3. WHEN un usuario con rol WORSHIP_LEADER o CHURCH_ADMIN visualiza el detalle, THE UI_Canciones SHALL mostrar un botón para editar las etiquetas y categorías de la canción.

### Requisito 5: Crear etiquetas y categorías desde el formulario de canción

**User Story:** Como líder de adoración, quiero poder crear nuevas etiquetas y categorías directamente desde el formulario de canción, para no tener que navegar a otra sección.

#### Criterios de Aceptación

1. WHEN un usuario necesita una etiqueta que no existe, THE Selector_Etiquetas SHALL permitir crear una nueva etiqueta con nombre y color desde el mismo selector.
2. WHEN un usuario necesita una categoría que no existe, THE Selector_Categorías SHALL permitir crear una nueva categoría con nombre y descripción desde el mismo selector.
3. WHEN un usuario crea una nueva etiqueta o categoría desde el selector, THE UI_Canciones SHALL llamar al endpoint correspondiente del API_Canciones y agregar la nueva etiqueta o categoría a la selección actual.
4. IF la creación de una nueva etiqueta o categoría falla, THEN THE UI_Canciones SHALL mostrar un mensaje de error y mantener la selección previa sin cambios.

### Requisito 6: Filtrar canciones por etiquetas y categorías

**User Story:** Como miembro del equipo, quiero filtrar canciones por etiquetas y categorías, para encontrar canciones específicas según su clasificación.

#### Criterios de Aceptación

1. WHEN un usuario selecciona una categoría en el filtro, THE Sistema_Canciones SHALL mostrar solo las canciones que pertenecen a la categoría seleccionada.
2. WHEN un usuario selecciona una o más etiquetas en el filtro, THE Sistema_Canciones SHALL mostrar solo las canciones que tienen al menos una de las etiquetas seleccionadas.
3. WHEN un usuario selecciona una categoría y etiquetas simultáneamente, THE Sistema_Canciones SHALL mostrar solo las canciones que cumplen ambos criterios.
4. WHEN un usuario limpia los filtros, THE Sistema_Canciones SHALL mostrar todas las canciones sin restricción.

### Requisito 7: Persistencia local de etiquetas y categorías en canciones

**User Story:** Como usuario, quiero que las etiquetas y categorías de las canciones se almacenen localmente, para poder ver la clasificación de canciones sin conexión.

#### Criterios de Aceptación

1. WHEN la UI_Canciones recibe canciones del API_Canciones con etiquetas y categorías, THE UI_Canciones SHALL almacenar las etiquetas y categorías asociadas en la base de datos local (Drift).
2. WHEN la UI_Canciones carga canciones desde la base de datos local, THE UI_Canciones SHALL incluir las etiquetas y categorías almacenadas en las entidades de canción.
3. WHILE la UI_Canciones opera sin conexión, THE UI_Canciones SHALL mostrar las etiquetas y categorías almacenadas localmente para cada canción.

### Requisito 8: Integración del comando de creación/actualización con etiquetas y categorías en el backend

**User Story:** Como desarrollador, quiero que los comandos de creación y actualización de canciones soporten etiquetas y categorías, para que el flujo completo funcione de extremo a extremo.

#### Criterios de Aceptación

1. THE API_Canciones SHALL aceptar campos opcionales `categoryIds` (lista de UUIDs) y `tagIds` (lista de UUIDs) en el request de creación de canción (`CreateSongRequest`).
2. THE API_Canciones SHALL aceptar campos opcionales `categoryIds` (lista de UUIDs) y `tagIds` (lista de UUIDs) en el request de actualización de canción (`UpdateSongRequest`).
3. WHEN la API_Canciones procesa un comando de creación con `categoryIds` y `tagIds`, THE API_Canciones SHALL resolver las entidades Category y Tag correspondientes y asociarlas a la canción creada.
4. WHEN la API_Canciones procesa un comando de actualización con `categoryIds` y `tagIds`, THE API_Canciones SHALL reemplazar las asociaciones existentes de categorías y etiquetas con las nuevas.
5. WHEN la API_Canciones procesa un comando de creación o actualización sin `categoryIds` ni `tagIds`, THE API_Canciones SHALL mantener las asociaciones existentes sin modificación (en actualización) o crear la canción sin asociaciones (en creación).

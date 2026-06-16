# Modo Presentación de Setlist (Live View)

Documento canónico del **modo de visualización en vivo** de un setlist en `worship_hub_ui`: la vista inmersiva que el equipo usa sobre el escenario para leer letras + acordes, avanzar entre canciones con un solo toque y transponer al vuelo.

> **TL;DR** — Desde la lista de setlists, un botón ▶ abre `SetlistPresentationPage` (ruta `present-setlist`). La página resuelve cada `songId` del setlist con `getSongById`, renderiza letras+acordes con el `ChordProRenderer` existente, y ofrece navegación de un toque, transposición rápida por semitonos (solo durante la sesión) y tamaño de letra ajustable. Mantiene la pantalla encendida con `wakelock_plus`. No modifica ninguna `Song` ni el `Setlist`.

---

## Tabla de contenidos

1. [Por qué existe](#1-por-qué-existe)
2. [Reparto de responsabilidades](#2-reparto-de-responsabilidades)
3. [Punto de entrada y ruta](#3-punto-de-entrada-y-ruta)
4. [La página `SetlistPresentationPage`](#4-la-página-setlistpresentationpage)
5. [Resolución de canciones](#5-resolución-de-canciones)
6. [Transposición en vivo](#6-transposición-en-vivo)
7. [Tamaño de letra y pantalla encendida](#7-tamaño-de-letra-y-pantalla-encendida)
8. [Reutilización vs. código nuevo](#8-reutilización-vs-código-nuevo)
9. [Localización](#9-localización)
10. [Reglas de oro](#10-reglas-de-oro)
11. [Cómo extenderlo](#11-cómo-extenderlo)

---

## 1. Por qué existe

Antes de este modo, "abrir" un setlist solo llevaba al **editor** (`SetlistBuilderPage`), pensado para armar la lista, no para usarla en vivo. No había una vista de lectura distraction-free para el escenario: el músico tenía que abrir cada canción por separado (`SongDetailPage`), perdiendo el contexto del orden del setlist y sin forma de avanzar de una canción a la siguiente con un gesto.

El modo presentación cubre exactamente ese hueco:

- **Un toque para avanzar** — el cuerpo de la página está dividido en dos zonas táctiles (mitad izquierda = anterior, mitad derecha = siguiente), más botones visibles "Anterior / Siguiente" como camino descubrible.
- **Transponer sin salir de la vista** — botones −/+ semitono con la tonalidad resultante visible y reset a "Original".
- **Legible a distancia** — fuente ajustable (A−/A+) persistida entre sesiones, alto contraste sobre fondo oscuro.
- **No se apaga la pantalla** — `wakelock` activo mientras la página esté montada.

---

## 2. Reparto de responsabilidades

| Pieza | Responsabilidad |
|---|---|
| `SetlistCard` ([`setlist_card.dart`](../../worship_hub_ui/lib/presentation/features/setlists/widgets/setlist_card.dart)) | Expone la acción "Presentar": botón ▶ dedicado + entrada en el menú overflow. Deshabilitada si el setlist no tiene canciones. |
| `SetlistListPage` ([`setlist_list_page.dart`](../../worship_hub_ui/lib/presentation/features/setlists/pages/setlist_list_page.dart)) | Cablea `onPresent` → `context.push('/home/setlists/present', extra: setlist)`. |
| `app_router.dart` ([`app_router.dart`](../../worship_hub_ui/lib/core/router/app_router.dart)) | Ruta `present-setlist` con transición fade; recibe el `Setlist` por `extra`, con fallback a la lista. |
| `SetlistPresentationPage` ([`setlist_presentation_page.dart`](../../worship_hub_ui/lib/presentation/features/setlist_presentation/pages/setlist_presentation_page.dart)) | Toda la vista en vivo: carga de canciones, navegación, transposición temporal, fuente, wakelock. |
| `SongRepository.getSongById` ([`song_repository.dart`](../../worship_hub_ui/lib/domain/repositories/song_repository.dart)) | Trae cada canción del setlist por id (resuelto vía `GetIt`). |

La feature vive en su propio folder, `lib/presentation/features/setlist_presentation/`, separada de `setlists/` (que es CRUD/edición) para no mezclar "armar" con "usar".

---

## 3. Punto de entrada y ruta

El modo se inicia **desde la tarjeta del setlist**, no desde el editor. Hay dos accesos al mismo callback `onPresent`:

1. **Botón ▶ dedicado** (`_PresentButton` en `setlist_card.dart`) — gradiente de la marca, 44×44, en el borde derecho de la tarjeta. Es el camino de un toque.
2. **Opción "Presentar"** en el menú overflow (`_OverflowMenu`), para descubrimiento.

Ambos quedan **deshabilitados (atenuados)** cuando `setlist.songIds.isEmpty`, mismo criterio que `onMarkPlayed`.

La ruta es hija de `/home/setlists`:

```
/home/setlists/present   →   name: 'present-setlist'
```

El `Setlist` viaja por `state.extra` (datos de dominio que no deben serializarse en la URL), igual que la ruta `edit-setlist`. Si `extra` no es un `Setlist` (p. ej. un deep link), la ruta hace `appRouter.go('/home/setlists')` y muestra la lista — nunca crashea.

La transición usa `_buildPageWithFadeTransition` (entrada inmersiva), a diferencia del slide del resto de rutas de setlist.

---

## 4. La página `SetlistPresentationPage`

`StatefulWidget` que recibe `final Setlist setlist`. Estructura vertical:

```
┌──────────────────────────────────────────────┐
│ _TopBar:  [X]  Título / artista   n/total  A- A+ │
├──────────────────────────────────────────────┤
│                                                │
│  _buildStage:                                  │
│    ChordProRenderer (o letra plana)            │
│    + zonas táctiles izq/der (Stack overlay)    │
│                                                │
├──────────────────────────────────────────────┤
│ _TransposeBar:  ♪ Tono [Sol] +2   [-] [+]      │
├──────────────────────────────────────────────┤
│ _NavBar:        [ ◁ Anterior ] [ Siguiente ▷ ] │
└──────────────────────────────────────────────┘
```

- **`_TopBar`** — salir (X → `Navigator.pop`), título + artista de la canción actual, indicador `n / total` y controles de fuente A−/A+ (se deshabilitan en los límites).
- **`_buildStage`** — el contenido scrollable con un `Stack`: debajo, el render de la canción; encima, un `Row` de dos `GestureDetector` translúcidos (`HitTestBehavior.translucent`) que capturan el toque izquierdo/derecho para `_prev` / `_next`. Los botones de `_NavBar` hacen lo mismo de forma explícita.
- **`_TransposeBar`** — controles de transposición (ver §6). Solo se muestra si la canción actual existe.
- **`_NavBar`** — botones Anterior/Siguiente; el "Siguiente" es el botón primario (gradiente).

El cambio de canción usa un `AnimatedSwitcher` (fade + slide) con `ValueKey` por `(_currentIndex, semitones)` para que el render se reconstruya limpio en cada cambio de canción o transposición, y dispara `HapticFeedback.selectionClick()`.

Estados borde manejados explícitamente:

| Situación | Qué se muestra |
|---|---|
| Cargando | `CircularProgressIndicator` |
| Falla la carga del catálogo | `_CenteredMessage` con `presentLoadError` |
| Setlist sin canciones | `_TopBar` + `presentEmptyTitle` / `presentEmptyMessage` |
| Canción no encontrada o eliminada | `_CenteredMessage` con `presentNoLyrics` (slide individual, no rompe la presentación) |
| Canción sin letra ni acordes | `_CenteredMessage` con `presentNoLyrics` |

---

## 5. Resolución de canciones

Un `Setlist` solo guarda `songIds` (UUID del servidor, con fallback al id local). Para mostrar las canciones hay que resolverlas contra el catálogo.

**Decisión:** se resuelve **cada id individualmente con `SongRepository.getSongById(id)`** (mismo enfoque que `SongDetailPage`), en orden, vía `Future.wait`.

**Por qué NO se usa `GetAllSongs()`:** ese use case pagina con `size = 20` por defecto ([`get_all_songs.dart`](../../worship_hub_ui/lib/domain/usecases/get_all_songs.dart)). Un setlist que referencie canciones fuera de la primera página quedaría incompleto. `getSongById` trae la canción exacta sin importar la paginación.

Robustez: si un `getSongById` individual falla (canción borrada, sin red y sin cache), ese slot queda `null` y se muestra como una canción "no disponible" — **una canción rota no tumba toda la presentación**. Solo un fallo del propio `GetIt`/repo marca `_error = true`.

> El helper [`SetlistSongResolver`](../../worship_hub_ui/lib/presentation/features/setlists/utils/setlist_song_resolver.dart) (extraído de `DraggableSongItem`) resuelve `songId → Song` contra una lista ya cargada. El modo presentación no lo usa hoy porque fetchea por id directamente, pero queda disponible si en el futuro la página decide trabajar sobre un catálogo ya en memoria.

---

## 6. Transposición en vivo

La transposición es **temporal y por canción durante la sesión**. Nunca muta la entidad `Song` ni el `Setlist`.

- El estado es un `Map<int, int> _semitonesBySong` (índice de canción → offset de semitonos acumulado).
- Al transponer, el texto se recalcula **siempre desde el texto base original** de la canción con `ChordProTransposer.transpose(rawChords, semitones)` — nunca sobre el texto ya transpuesto, para evitar drift acumulado.
- La tonalidad mostrada se calcula con `KeyTransposer.shiftKey(song.key, semitones)` (ver §8).
- `_TransposeBar` muestra: la tonalidad resultante en un badge con gradiente, el offset (`+2`, `Original`), y botones −/+. Tocar el offset cuando no es `0` resetea a original.

Solo aplica a canciones en formato **ChordPro** (las que contienen `[`); en letra plana no hay acordes que transponer y la barra de offset igual permite ver la tonalidad si la canción la declara.

---

## 7. Tamaño de letra y pantalla encendida

**Fuente.** `_fontSize` (default 17, rango 13–32, paso 2) se ajusta con A−/A+ del top bar y se **persiste en `SharedPreferences`** bajo la clave `presentation_font_size`, de modo que el tamaño elegido se mantiene entre canciones y entre sesiones. El `ChordProRenderer` recibe `fontSize` y un `lineSpacing` derivado (`fontSize * 0.9`).

**Wakelock.** `WakelockPlus.enable()` en `initState`, `WakelockPlus.disable()` en `dispose`. La pantalla se mantiene encendida solo mientras la página viva. Esto introdujo la dependencia [`wakelock_plus`](../../worship_hub_ui/pubspec.yaml) (única dependencia nueva de la feature).

> En Windows, compilar con plugins que usan symlinks (como `wakelock_plus`) requiere habilitar **Developer Mode** (`start ms-settings:developers`). Es un requisito del toolchain de Flutter en Windows, no del código.

---

## 8. Reutilización vs. código nuevo

La feature se construyó **reutilizando y extendiendo** los componentes existentes; lo nuevo se limitó a lo inevitable. Durante la implementación se extrajeron dos helpers compartidos para eliminar duplicación.

### Reutilizado sin cambios

| Componente | Uso |
|---|---|
| [`ChordProRenderer`](../../worship_hub_ui/lib/presentation/widgets/chord_pro/chord_pro_renderer.dart) | Render canónico de letras + acordes (badges sobre la sílaba). Acepta `text`, `originalKey`, `fontSize`, `lineSpacing`. |
| [`ChordProTransposer`](../../worship_hub_ui/lib/core/utils/chord_pro_transposer.dart) | Motor de transposición de acordes por semitonos. |
| `chromaticKeys` ([`transpose_bar.dart`](../../worship_hub_ui/lib/presentation/widgets/chord_pro/transpose_bar.dart)) | Escala cromática compartida. |
| `AppTheme` ([`app_theme.dart`](../../worship_hub_ui/lib/core/theme/app_theme.dart)) | Gradiente de fondo, colores y sombras premium. |
| `SongRepository.getSongById` | Carga de cada canción del setlist. |

### Helpers extraídos (refactor de des-duplicación)

| Helper nuevo | De dónde se extrajo | Quién lo consume ahora |
|---|---|---|
| [`KeyTransposer.shiftKey`](../../worship_hub_ui/lib/core/utils/key_transposer.dart) | El `_shiftKey` privado de `SongDetailPage` | `SongDetailPage` **y** `SetlistPresentationPage` |
| [`SetlistSongResolver.resolve`](../../worship_hub_ui/lib/presentation/features/setlists/utils/setlist_song_resolver.dart) | El `_findSong` privado de `DraggableSongItem` | `DraggableSongItem` (y disponible para presentación) |

### Nuevo (inevitable)

- `SetlistPresentationPage` y sus widgets privados (`_TopBar`, `_TransposeBar`, `_NavBar`, `_NavButton`, `_IconBox`, `_RoundButton`, `_CenteredMessage`).
- Ruta `present-setlist`.
- Dependencia `wakelock_plus`.
- Cadenas l10n (§9).

---

## 9. Localización

Siguiendo la convención del proyecto (ARB en `lib/l10n/`, español primario, ambas locales obligatorias, `flutter gen-l10n` tras editar). Claves añadidas en [`app_es.arb`](../../worship_hub_ui/lib/l10n/app_es.arb) y [`app_en.arb`](../../worship_hub_ui/lib/l10n/app_en.arb):

| Clave | ES | EN |
|---|---|---|
| `setlistCardPresent` | Presentar | Present |
| `presentExit` | Salir | Exit |
| `presentNext` | Siguiente | Next |
| `presentPrev` | Anterior | Previous |
| `presentSongProgress` | `{current} / {total}` | `{current} / {total}` |
| `presentNoLyrics` | Esta canción no tiene letra disponible | This song has no lyrics available |
| `presentFontSize` | Tamaño de letra | Font size |
| `presentFontDecrease` | Reducir tamaño de letra | Decrease font size |
| `presentFontIncrease` | Aumentar tamaño de letra | Increase font size |
| `presentOriginalKey` | Original | Original |
| `presentTransposeLabel` | Tono | Key |
| `presentEmptyTitle` | Setlist vacío | Empty setlist |
| `presentEmptyMessage` | Agrega canciones al setlist para poder presentarlo | Add songs to the setlist before presenting it |
| `presentLoadError` | No se pudieron cargar las canciones del setlist | Could not load the setlist songs |

---

## 10. Reglas de oro

1. **La transposición es de sesión.** Nunca persistir el offset en `Song` ni en `Setlist` desde este modo. Es lectura, no edición.
2. **Transponer siempre desde el texto base original**, recalculando con el offset acumulado. No encadenar `transpose` sobre el resultado anterior (drift).
3. **Resolver canciones por id, no por catálogo paginado.** `getSongById`, no `GetAllSongs()`.
4. **Una canción rota no rompe la presentación.** Slot `null` → slide "no disponible", el resto sigue navegable.
5. **`WakelockPlus.disable()` en `dispose` es obligatorio.** No dejar la pantalla encendida tras salir.
6. **Reutilizar `ChordProRenderer`** para cualquier render de letras+acordes. No duplicar el parser de `[Chord]`.
7. **Reutilizar `KeyTransposer.shiftKey`** para mover tonalidades. Si vuelves a escribir el regex `^([A-G][#b]?)(.*)$`, estás duplicando.

---

## 11. Cómo extenderlo

Ideas pre-evaluadas, ordenadas por valor:

- **Auto-scroll / teleprompter** — desplazamiento automático configurable por BPM de la canción. El `Song` ya expone `bpm`. Requiere un `ScrollController` y un `Ticker` en la página.
- **Modo "letra limpia"** — toque central para ocultar/mostrar las barras superior e inferior y maximizar el área de lectura. Hoy las zonas táctiles cubren izq/der; habría que reservar una franja central.
- **Mini-tira de canciones** — fila horizontal con los títulos para saltar a cualquier canción de un toque (hoy la navegación es secuencial).
- **Persistir transposición por setlist** — si el equipo quiere recordar "este domingo cantamos esta en La", habría que añadir almacenamiento por `(setlistId, songId)`. Esto **sí** cruza la línea de "solo lectura" — decisión de producto, no técnica.
- **Proyección a segunda pantalla** — separar el render para mandar solo la letra a un proyector. El `ChordProRenderer` ya es el componente a reutilizar.

Para cualquiera de estas, el `ChordProRenderer`, `ChordProTransposer` y `KeyTransposer` ya son la base; lo nuevo vive en `SetlistPresentationPage` o en widgets nuevos dentro de `features/setlist_presentation/`.

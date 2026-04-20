# 🎸 Acoustic Guitar System

App móvil personal desarrollada en Flutter para guitarristas. Integra visualizador de escalas, transpositor de tonos y un songbook con cifrado estilo Cifra Club, respaldado por una arquitectura en la nube con Supabase y n8n.

---

## Funcionalidades

- **Escalas y acordes** — visualizador interactivo para guitarra
- **Transpositor** — cambia el tono de cualquier acorde instantáneamente
- **Songbook** — canciones con acordes posicionados sobre sílabas (estilo Cifra Club)
  - Organización por secciones: verso, coro, puente
  - Selector de tono destino con transposición automática en tiempo real
  - Soporte de capo
  - Editor con tap sobre sílaba para asignar acordes
  - Búsqueda y filtros por categoría
  - Sincronización en la nube

---

## Stack tecnológico

| Capa | Tecnología |
|---|---|
| App móvil | Flutter + Dart |
| Estado | Riverpod |
| Backend / API | n8n Cloud (webhooks) |
| Base de datos | Supabase (PostgreSQL) |

---

## Arquitectura

```
┌─────────────────────────────────────────┐
│              Flutter App                │
│                                         │
│  EscalaPage ──► SongbookPage            │
│                    │                    │
│               SongViewPage              │
│               SongEditorPage            │
│                    │                    │
│            SongbookService              │
│          (HTTP → n8n webhook)           │
└──────────────────┬──────────────────────┘
                   │ REST / JSON
┌──────────────────▼──────────────────────┐
│              n8n Cloud                  │
│                                         │
│  GET    /webhook/songs                  │
│  POST   /webhook/songs                  │
│  PATCH  /webhook/songs/:id              │
│  DELETE /webhook/songs/:id              │
└──────────────────┬──────────────────────┘
                   │ PostgreSQL
┌──────────────────▼──────────────────────┐
│              Supabase                   │
│                                         │
│  tabla: songs                           │
│  id | title | artist | original_key     │
│  capo | tags | sections (JSONB)         │
└─────────────────────────────────────────┘
```

---

## Estructura del proyecto

```
acoustic_guitar_system/
│
├── lib/
│   ├── main.dart                        # Entry point + ProviderScope
│   ├── app.dart                         # MaterialApp + ThemeData
│   │
│   ├── models/
│   │   ├── song.dart                    # Modelo principal de canción
│   │   ├── song_section.dart            # Sección (verso, coro, etc.)
│   │   └── chorded_line.dart            # Línea con acordes posicionados
│   │
│   ├── core/helpers/
│   │   ├── transpose_helper.dart        # Lógica de transposición de tonos
│   │   ├── chord_helper.dart            # Validación y listas de acordes
│   │   ├── scale_helper.dart            # Lógica de escalas (existente)
│   │   └── constants.dart              # Constantes globales (existente)
│   │
│   ├── services/
│   │   ├── songbook_service.dart        # Cliente HTTP → n8n
│   │   └── providers.dart              # Providers de Riverpod
│   │
│   ├── widgets/
│   │   ├── chorded_line_widget.dart     # Renderiza acorde sobre sílaba
│   │   └── chord_picker_sheet.dart     # Bottom sheet selector de acordes
│   │
│   └── pages/
│       ├── escala_page.dart            # Pantalla de escalas (existente)
│       ├── songbook_page.dart          # Lista de canciones
│       ├── song_view_page.dart         # Vista de canción con transposición
│       └── song_editor_page.dart       # Editor con 3 tabs
│
├── n8n_workflow.json                    # Importar en n8n Cloud
├── database.sql                         # Ejecutar en Supabase SQL Editor
└── pubspec.yaml
```

---

## Modelo de datos

### Song
```dart
Song {
  id:           String?           // UUID generado por Supabase
  title:        String            // Título de la canción
  artist:       String            // Artista o autor
  originalKey:  String            // Tono original ej: "Am", "G"
  capo:         int               // Cejilla (0 = sin capo)
  tags:         List<String>      // ["Alabanza", "Adoración"]
  sections:     List<SongSection>
  createdAt:    DateTime?
}
```

### SongSection
```dart
SongSection {
  name:   String              // "Verso 1", "Coro", "Puente"
  lines:  List<ChordedLine>
}
```

### ChordedLine — el corazón del sistema de acordes
```dart
ChordedLine {
  lyrics: String              // "Renuévame, Señor"
  chords: Map<int, String>    // { 0: "Am", 11: "F" }
  //       ↑ índice de carácter donde va el acorde
}
```

Renderiza así:
```
Am          F
Renuévame, Señor
```

---

## Sistema de transposición

`TransposeHelper` calcula la diferencia en semitonos entre el tono original
y el tono destino, y desplaza cada acorde recorriendo la escala cromática:

```
C → C# → D → D# → E → F → F# → G → G# → A → A# → B → C
```

Ejemplo — canción en `Am`, usuario selecciona `Cm` (+3 semitonos):
```
Am → Cm     F → Ab     G → Bb
```

---

## API — Endpoints n8n

| Método | URL | Descripción |
|---|---|---|
| GET | `/webhook/songs` | Obtener todas las canciones |
| POST | `/webhook/songs` | Crear canción nueva |
| PATCH | `/webhook/songs/:id` | Actualizar canción |
| DELETE | `/webhook/songs/:id` | Eliminar canción |

### Ejemplo de payload (POST /songs)
```json
{
  "title": "Renuévame",
  "artist": "Marcos Witt",
  "original_key": "Am",
  "capo": 2,
  "tags": ["Adoración"],
  "sections": [
    {
      "name": "Verso 1",
      "lines": [
        {
          "lyrics": "Renuévame, Señor Jesús",
          "chords": { "0": "Am", "11": "F", "18": "C" }
        }
      ]
    }
  ]
}
```

---

## Instalación y configuración

### 1. Supabase
```
1. Crear proyecto en https://supabase.com
2. SQL Editor → ejecutar database.sql
3. Copiar: Settings → Database → Connection string → URI
```

### 2. n8n Cloud
```
1. Crear cuenta en https://n8n.io/cloud
2. Importar n8n_workflow.json
3. En cada nodo DB → Credential → Create new → Postgres:
   Host:     db.XXXXXXXX.supabase.co
   Port:     5432
   Database: postgres
   User:     postgres
   Password: [tu contraseña de Supabase]
   SSL:      require
4. Activar workflow → copiar Production URL
```

### 3. Flutter
```bash
flutter pub add flutter_riverpod http uuid shared_preferences
flutter pub add --dev build_runner riverpod_generator
flutter pub get
```

En `lib/services/songbook_service.dart`:
```dart
static const String _baseUrl = 'https://TU_INSTANCIA.app.n8n.cloud/webhook';
```

En `lib/main.dart`:
```dart
void main() => runApp(
  const ProviderScope(
    child: MyApp(),
  ),
);
```

### 4. Verificar conexión
```bash
curl https://TU_INSTANCIA.app.n8n.cloud/webhook/songs
# Debe devolver: []
```

---

## Dependencias principales

```yaml
dependencies:
  flutter_riverpod: ^2.5.1    # Gestión de estado
  http: ^1.2.1                 # Cliente HTTP
  uuid: ^4.4.0                 # Generación de IDs
  shared_preferences: ^2.2.3   # Persistencia local

dev_dependencies:
  build_runner: ^2.4.9
  riverpod_generator: ^2.4.3
```

---

## Próximas funcionalidades

- [ ] Exportar canciones a PDF
- [ ] Modo presentación (pantalla completa, fuente grande)
- [ ] Compartir canción como texto con `share_plus`
- [ ] Autenticación multi-usuario con Supabase Auth
- [ ] Modo sin conexión con caché local
- [ ] Metrónomo integrado
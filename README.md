# GeoPing

Comparte tu ubicación en tiempo real con un solo toque.

**Sin servidores propios — todo sobre Firebase. Sin polling — Firestore real-time streams.**

---

## Arquitectura general

| Plataforma | Rol | Tecnología |
|------------|-----|------------|
| **App móvil** | Pingo — comparte su ubicación | Flutter (Android + iOS) |
| **Web** | Familiar — monitorea la ubicación | Flutter Web → Cloudflare Pages |

El Familiar crea la configuración en la web, genera un QR y se lo muestra al Pingo. El Pingo escanea el QR con la app y desde ese momento puede compartir su ubicación con un toque.

---

## Roles

| Rol | Descripción |
|-----|-------------|
| **Pingo** | Ve un botón por cada familiar registrado. Lo toca y comparte su ubicación solo con esa persona. Interfaz simple: fuente mínimo 18sp, contraste alto. |
| **Familiar** | Accede desde el navegador. Crea configs, genera QR, ve tarjeta verde cuando hay sesión activa y abre el mapa en tiempo real. Recibe push notification al inicio de sesión. |

---

## Prerrequisitos

- Flutter 3.x (stable)
- Dart 3.x
- Node.js 20+
- pnpm: `npm install -g pnpm`
- Firebase CLI: `npm install -g firebase-tools`
- FlutterFire CLI: se instala automáticamente con `make firebase-configure`
- Cuenta Firebase con plan **Blaze** (necesario para Cloud Functions)
- Cuenta Cloudflare (para deploy del web)

---

## Setup inicial

### 0. Restaurar archivos sensibles

Los archivos de firma y configuración de Firebase no están en git. Se guardan en `_secret_config/` (fuera del repo). Copia esa carpeta al proyecto y ejecuta:

```bash
bash _secret_config/setup.sh
```

Esto coloca automáticamente:

| Archivo | Destino |
|---------|---------|
| `google-services.json` | `android/app/` |
| `GoogleService-Info.plist` | `ios/Runner/` |
| `key.properties` | `android/` |
| `upload-keystore.jks` | `android/` |

> Si no tienes la carpeta `_secret_config/`, pídela al equipo. Sin estos archivos no se puede compilar release ni conectar Firebase.

### 1. Inicializar proyecto Firebase

```bash
firebase login
make firebase-init PROJECT_ID=tu-proyecto-id
```

Esto crea el proyecto, registra las apps Android e iOS, descarga los archivos de config y despliega las Firestore rules.

### 2. Habilitar métodos de autenticación (manual)

Firebase Console → Authentication → Métodos de inicio de sesión:

- **Google** → Activar (usado por el Familiar en web)
- **Anónimo** → Activar (usado por el Pingo en móvil)

Luego en **Authentication → Configuración → Dominios autorizados**, añadir el dominio de producción de Cloudflare Pages (ej. `geoping.pages.dev`). `localhost` ya está por defecto.

### 3. Generar firebase_options.dart

```bash
make firebase-configure
```

Seleccionar plataformas: **android**, **ios**, **web** (desmarcar macos y windows).

Esto genera `lib/firebase_options.dart` con las credenciales del proyecto. El archivo se puede commitear — las credenciales web de Firebase son públicas por diseño.

### 4. Instalar dependencias y generar código

```bash
make setup
```

---

## Comandos disponibles

### App móvil (Pingo)

```bash
make run              # Ejecutar en dispositivo conectado / emulador
make emu              # Lanzar emulador Pixel_6_API_34 y correr app
make device           # Build release en dispositivo físico
make build-apk        # Build APK release
make build-ios        # Build IPA release
```

### Web (Familiar)

```bash
make web-dev          # Dev server en Chrome
make web-build        # Compilar para producción
make web-deploy       # Deploy a Cloudflare Pages
```

### Firebase / Backend

```bash
make deploy           # Deploy completo: Functions + Firestore rules + indexes
make functions-deploy # Deploy solo Cloud Functions
make rules-deploy     # Deploy solo Firestore rules e indexes
make functions-dev    # Correr Functions localmente con emuladores
make firebase-init    # Crear proyecto Firebase desde cero
make firebase-delete  # Limpiar datos y apps del proyecto Firebase
make firebase-configure # Regenerar firebase_options.dart
```

### Desarrollo

```bash
make codegen          # Regenerar código freezed/json_serializable
make codegen-watch    # Regenerar código en modo watch
make setup            # Instalar todo desde cero
make clean            # Limpiar y reinstalar Flutter deps
```

---

## Arquitectura técnica

### Firestore Data Model

```
configs/{configId}
  elderName: string           # Nombre del Pingo
  familiarName: string        # Nombre del familiar (aparece en los botones del Pingo)
  ownerUid: string            # UID Firebase Auth del familiar que creó esto
  writeToken: string          # UUID v4, incluido en el QR
  fcmTokens: Array<string>    # Tokens FCM del familiar para notificaciones
  createdAt: Timestamp

sessions/{configId}           # Un doc por config, se sobreescribe en cada sesión
  active: boolean
  lat: number
  lng: number
  accuracy: number
  writeToken: string          # El Pingo lo incluye para pasar security rules
  updatedAt: Timestamp
  expiresAt: Timestamp        # now + 60 minutos, verificado server-side en las rules
```

### Flujo QR de emparejamiento

1. **Familiar** (web) crea una configuración → Firestore genera `configId` + `writeToken`
2. **Familiar** muestra QR con payload: `{ v:1, configId, writeToken, familiarName }`
3. **Pingo** (app) escanea el QR → guarda `configId` + `writeToken` + `familiarName` en SharedPreferences
4. **Pingo** ve un botón: "Avisar ubicación a [familiarName]"

### Flujo de sesión

```
Pingo toca el botón de un familiar
  → Pide permiso de ubicación
  → Escribe sessions/{configId}: { active: true, lat, lng, writeToken, expiresAt }
  → Cloud Function detecta cambio → envía FCM solo al familiar de ese configId
  → Actualiza lat/lng en Firestore solo cuando el Pingo se mueve ≥10 m (distanceFilter stream)
  → Familiar ve tarjeta verde instantáneamente (stream en tiempo real)
  → Familiar toca "Ver mapa" → mapa OpenStreetMap con posición en vivo
  → A los 60 min la sesión caduca (server-side) — el Pingo puede iniciar una nueva
```

### Stack

| Capa | Tecnología |
|------|-----------|
| UI (móvil + web) | Flutter + Material 3 |
| State | flutter_riverpod |
| Navegación | go_router |
| Modelos | freezed + json_serializable |
| Auth | Firebase Auth — Google (web) · Anónimo (móvil) |
| DB | Cloud Firestore (streams) |
| Push | Firebase Cloud Messaging |
| Backend | Cloud Functions TypeScript (v2) |
| Ubicación background | geolocator + distanceFilter stream (≥10 m) |
| Mapa | flutter_map + OpenStreetMap |
| QR gen | qr_flutter (web) |
| QR scan | mobile_scanner (móvil) |
| Config Firebase | FlutterFire CLI → firebase_options.dart |
| Deploy web | Cloudflare Pages |

---

## Deploy

### Backend

```bash
make deploy           # Despliega todo (Functions + Firestore rules + indexes)
make rules-deploy     # Solo reglas — útil tras cambiar firestore.rules
make functions-deploy # Solo Functions
```

Requiere plan Blaze. La función `onSessionStarted` se dispara cuando `sessions/{configId}.active` cambia a `true` y envía FCM a los `fcmTokens` del familiar.

### Web (Familiar)

```bash
make web-deploy
```

Compila el target `lib/main_web.dart` y sube `build/web/` a Cloudflare Pages. El archivo `web/_redirects` asegura que las rutas SPA funcionen correctamente.

---

## Seguridad

- La ubicación del Pingo solo la puede leer el familiar dueño del config (`ownerUid`)
- El Pingo solo puede escribir sesiones si tiene el `writeToken` correcto (incluido en el QR)
- Las sesiones tienen expiración de 60 min verificada **server-side** en Firestore rules
- `google-services.json` y `GoogleService-Info.plist` están en `.gitignore`
- `firebase_options.dart` **sí se commitea** — las credenciales web de Firebase son públicas

---

## Restricciones (MVP)

- Sin servidor Express propio — Firebase es el backend
- Sin polling — solo Firestore streams y FCM
- Sin historial de ubicaciones — solo posición más reciente
- Sin autenticación email/password — Google en web, anónimo en móvil
- Sin tests — es MVP
- Sin i18n formal — todo hardcoded en español en `lib/core/strings.dart`
- Sin riverpod_generator — providers manuales
- Sin monorepo — proyecto Flutter en la raíz, web en el mismo build

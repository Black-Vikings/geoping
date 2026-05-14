# GeoPing

App Flutter para que una persona mayor ("el abuelo") comparta su ubicación en tiempo real con su familia con un solo toque.

**Sin servidores propios — todo sobre Firebase. Sin polling — Firestore real-time streams.**

---

## Roles

| Rol | Descripción |
|-----|-------------|
| **Abuelo** | Pantalla con botón rojo enorme. Un toque comparte la ubicación. Diseñado para personas mayores: fuente mínimo 18sp, contraste alto, interfaz mínima. |
| **Familiar** | Lista de abuelos configurados. Tarjeta verde cuando hay sesión activa. Mapa en tiempo real via OpenStreetMap (sin API key). Recibe push notification al inicio de sesión. |

---

## Prerrequisitos

- Flutter 3.x (stable)
- Dart 3.x
- Firebase CLI: `npm install -g firebase-tools`
- Node.js 20+
- Cuenta Firebase con plan **Blaze** (necesario para Cloud Functions)

---

## Setup inicial

### 1. Crear proyecto Firebase

```bash
firebase login
firebase projects:create geopping-prod
firebase use geopping-prod
```

### 2. Habilitar servicios en la consola Firebase

- Authentication → Métodos de inicio de sesión → **Anónimo** ✓
- Firestore Database → Crear base de datos (modo producción)
- Cloud Messaging → (se activa automáticamente)
- Functions → (requiere plan Blaze)

### 3. Agregar archivos de configuración

**Android:** Descarga `google-services.json` desde Consola Firebase → Configuración del proyecto → Android, y colócalo en:
```
android/app/google-services.json
```

**iOS:** Descarga `GoogleService-Info.plist` desde Consola Firebase → Configuración del proyecto → iOS, y colócalo en:
```
ios/Runner/GoogleService-Info.plist
```

### 4. Agregar plugin de Google Services a Android

En `android/build.gradle` (nivel proyecto), en `dependencies`:
```groovy
classpath 'com.google.gms:google-services:4.4.2'
```

En `android/app/build.gradle`, al final del archivo:
```groovy
apply plugin: 'com.google.gms.google-services'
```

### 5. Instalar dependencias y generar código

```bash
make setup
```

---

## Comandos disponibles

```bash
make run              # Ejecutar en dispositivo conectado / emulador
make emu              # Lanzar emulador Pixel_6_API_34 y correr app
make device           # Build release en dispositivo físico
make build-apk        # Build APK release
make build-ios        # Build IPA release
make codegen          # Regenerar código freezed/json_serializable
make codegen-watch    # Regenerar código en modo watch
make functions-deploy # Deploy Cloud Functions a producción
make functions-dev    # Correr Functions localmente con emuladores
make setup            # Instalar todo desde cero
make clean            # Limpiar y reinstalar Flutter deps
```

---

## Arquitectura

### Firestore Data Model

```
configs/{configId}
  elderName: string          # Nombre del abuelo
  contacts: Array<{name, phone}>  # Familiares (E.164)
  ownerUid: string           # UID del familiar dueño
  writeToken: string         # UUID v4, incluido en el QR
  fcmTokens: Array<string>   # Tokens FCM del familiar
  createdAt: Timestamp

sessions/{configId}          # Un doc por config, se sobreescribe
  active: boolean
  lat: number
  lng: number
  accuracy: number
  writeToken: string         # El abuelo lo incluye para pasar security rules
  updatedAt: Timestamp
  expiresAt: Timestamp       # now + 60 minutos
```

### Flujo QR de emparejamiento

1. **Familiar** crea una configuración → Firestore genera `configId` + `writeToken`
2. **Familiar** muestra QR con payload: `{ v:1, configId, writeToken, elderName }`
3. **Abuelo** escanea el QR → guarda `configId` + `writeToken` en SharedPreferences
4. **Abuelo** toca el botón → escribe en `sessions/{configId}` usando el `writeToken` como autorización

### Flujo de sesión

```
Abuelo toca botón
  → Pide permiso de ubicación
  → Escribe sessions/{configId}: { active: true, lat, lng, writeToken, expiresAt }
  → Cloud Function detecta cambio → envía FCM a fcmTokens del familiar
  → Timer cada 30s actualiza lat/lng en Firestore
  → Familiar ve tarjeta verde instantáneamente (stream en tiempo real)
  → Familiar toca "Ver mapa" → mapa OpenStreetMap con posición en vivo
```

### Stack

| Capa | Tecnología |
|------|-----------|
| UI | Flutter + Material 3 |
| State | flutter_riverpod 3.x |
| Navegación | go_router |
| Modelos | freezed + json_serializable |
| Auth | Firebase Auth (anónimo) |
| DB | Cloud Firestore (streams) |
| Push | Firebase Cloud Messaging |
| Backend | Cloud Functions TypeScript (v2) |
| Ubicación background | geolocator + Timer |
| Mapa | flutter_map + OpenStreetMap |
| QR gen | qr_flutter |
| QR scan | mobile_scanner |

---

## Deploy Cloud Functions

```bash
make functions-deploy
```

Requiere plan Blaze. La función `onSessionStarted` se dispara en Firestore cuando `sessions/{configId}.active` cambia de `false` a `true` y envía FCM a todos los `fcmTokens` del familiar dueño.

---

## Restricciones (MVP)

- Sin servidor Express propio — Firebase es el backend
- Sin polling — solo Firestore streams y FCM
- Sin historial de ubicaciones — solo posición más reciente
- Sin autenticación email/password — Firebase Auth anónimo
- Sin web app — solo móvil
- Sin tests — es MVP
- Sin i18n formal — todo hardcoded en español en `lib/core/strings.dart`
- Sin riverpod_generator — providers manuales para mantenerlo simple
- Sin monorepo — proyecto Flutter en la raíz

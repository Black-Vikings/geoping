# GeoPing

App Flutter para compartir ubicación en tiempo real con un solo toque.

**Sin servidores propios — todo sobre Firebase. Sin polling — Firestore real-time streams.**

---

## Roles

| Rol | Descripción |
|-----|-------------|
| **Pingo** | Ve un botón por cada familiar registrado. Lo toca y comparte su ubicación solo con esa persona. Diseñado para ser simple: fuente mínimo 18sp, contraste alto, interfaz mínima. |
| **Familiar** | Lista de Pingos configurados. Tarjeta verde cuando hay sesión activa. Mapa en tiempo real via OpenStreetMap (sin API key). Recibe push notification al inicio de sesión. |

---

## Prerrequisitos

- Flutter 3.x (stable)
- Dart 3.x
- Node.js 20+
- pnpm: `npm install -g pnpm`
- Firebase CLI: `npm install -g firebase-tools`
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

> Estos archivos están en `.gitignore` — descárgalos desde la consola Firebase y colócalos manualmente.

**Android:** Consola Firebase → Configuración del proyecto → Android → `google-services.json`:
```
android/app/google-services.json
```

**iOS:** Consola Firebase → Configuración del proyecto → iOS → `GoogleService-Info.plist`:
```
ios/Runner/GoogleService-Info.plist
```

### 4. Agregar plugin de Google Services a Android

En `android/build.gradle` (nivel proyecto), dentro de `dependencies`:
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
make deploy           # Deploy completo: Functions + Firestore rules + indexes
make functions-deploy # Deploy solo Cloud Functions
make rules-deploy     # Deploy solo Firestore rules e indexes
make functions-dev    # Correr Functions localmente con emuladores
make setup            # Instalar todo desde cero
make clean            # Limpiar y reinstalar Flutter deps
```

---

## Arquitectura

### Firestore Data Model

```
configs/{configId}
  elderName: string           # Nombre del Pingo
  familiarName: string        # Nombre del familiar (aparece en los botones del Pingo)
  contacts: Array<{name, phone}>  # Contactos adicionales (E.164)
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

1. **Familiar** crea una configuración → Firestore genera `configId` + `writeToken`
2. **Familiar** muestra QR con payload: `{ v:1, configId, writeToken, familiarName }`
3. **Pingo** escanea el QR → guarda `configId` + `writeToken` + `familiarName` en SharedPreferences
4. **Pingo** ve un botón por cada familiar escaneado: "Avisar ubicación a [familiarName]"

### Flujo de sesión

```
Pingo toca el botón de un familiar
  → Pide permiso de ubicación
  → Escribe sessions/{configId}: { active: true, lat, lng, writeToken, expiresAt }
  → Cloud Function detecta cambio → envía FCM solo al familiar de ese configId
  → Timer cada 30s actualiza lat/lng en Firestore (hasta que expiresAt caduque)
  → Familiar ve tarjeta verde instantáneamente (stream en tiempo real)
  → Familiar toca "Ver mapa" → mapa OpenStreetMap con posición en vivo
  → A los 60 min la sesión caduca (server-side) — el Pingo puede iniciar una nueva
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

## Deploy

```bash
make deploy           # Despliega todo (Functions + Firestore rules + indexes)
make rules-deploy     # Solo reglas — útil tras cambiar firestore.rules
make functions-deploy # Solo Functions
```

Requiere plan Blaze. La función `onSessionStarted` se dispara cuando `sessions/{configId}.active` cambia de `false` a `true` y envía FCM a los `fcmTokens` del familiar dueño de ese config.

---

## Seguridad

- La ubicación del Pingo solo la puede leer el familiar dueño del config (`ownerUid`)
- El Pingo solo puede escribir sesiones si tiene el `writeToken` correcto (incluido en el QR)
- Las sesiones tienen expiración de 60 min verificada **server-side** en Firestore rules
- `google-services.json` y `GoogleService-Info.plist` están en `.gitignore` — nunca se suben al repo

---

## Restricciones (MVP)

- Sin servidor Express propio — Firebase es el backend
- Sin polling — solo Firestore streams y FCM
- Sin historial de ubicaciones — solo posición más reciente
- Sin autenticación email/password — Firebase Auth anónimo (sin recuperación de cuenta)
- Sin web app — solo móvil
- Sin tests — es MVP
- Sin i18n formal — todo hardcoded en español en `lib/core/strings.dart`
- Sin riverpod_generator — providers manuales para mantenerlo simple
- Sin monorepo — proyecto Flutter en la raíz

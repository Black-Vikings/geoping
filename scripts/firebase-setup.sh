#!/usr/bin/env bash
set -euo pipefail

# ─── Colors ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'; YELLOW='\033[1;33m'; GREEN='\033[0;32m'; CYAN='\033[0;36m'; NC='\033[0m'
info()  { echo -e "${GREEN}▶${NC} $*"; }
warn()  { echo -e "${YELLOW}⚠${NC}  $*"; }
error() { echo -e "${RED}✖${NC}  $*"; exit 1; }
ask()   { echo -e "${CYAN}?${NC}  $*"; }

# ─── Usage ────────────────────────────────────────────────────────────────────
usage() {
  echo "Usage:"
  echo "  $0 setup  [project-id] [android-package] [ios-bundle-id]"
  echo "  $0 delete [project-id]"
  echo ""
  echo "Commands:"
  echo "  setup   Create project, register apps, deploy Firestore rules"
  echo "  delete  Delete Firestore data, app registrations, and optionally the project"
  echo ""
  echo "Examples:"
  echo "  $0 setup  geopping-prod com.example.geoping com.example.geoping"
  echo "  $0 delete geopping-prod"
  exit 1
}

# ─── Args ─────────────────────────────────────────────────────────────────────
COMMAND="${1:-}"
[[ "$COMMAND" == "setup" || "$COMMAND" == "delete" ]] || usage

PROJECT_ID="${2:-}"
ANDROID_PKG="${3:-com.example.geoping}"
IOS_BUNDLE="${4:-com.example.geoping}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# ─── Prerequisites ────────────────────────────────────────────────────────────
command -v firebase &>/dev/null || error "firebase CLI not found. Run: npm install -g firebase-tools"
command -v python3  &>/dev/null || error "python3 not found."

# ─── Helpers ──────────────────────────────────────────────────────────────────
confirm() {
  local prompt="$1"
  local answer
  ask "$prompt [s/N] "
  read -r answer
  [[ "$answer" =~ ^[sS]$ ]]
}

login() {
  info "Verificando sesión Firebase…"
  firebase login --no-localhost 2>/dev/null || firebase login
}

project_exists() {
  firebase projects:list --json 2>/dev/null \
    | python3 -c "
import sys, json
projects = json.load(sys.stdin).get('result', [])
ids = [p.get('projectId','') for p in projects]
print('yes' if '$1' in ids else 'no')
" 2>/dev/null
}

get_android_app_id() {
  firebase apps:list android --project "$PROJECT_ID" --json 2>/dev/null \
    | python3 -c "
import sys, json
apps = json.load(sys.stdin).get('result', [])
print(apps[0]['appId'] if apps else '')
" 2>/dev/null
}

get_ios_app_id() {
  firebase apps:list ios --project "$PROJECT_ID" --json 2>/dev/null \
    | python3 -c "
import sys, json
apps = json.load(sys.stdin).get('result', [])
print(apps[0]['appId'] if apps else '')
" 2>/dev/null
}

get_web_app_id() {
  firebase apps:list web --project "$PROJECT_ID" --json 2>/dev/null \
    | python3 -c "
import sys, json
apps = json.load(sys.stdin).get('result', [])
print(apps[0]['appId'] if apps else '')
" 2>/dev/null
}

# ══════════════════════════════════════════════════════════════════════════════
# BILLING ALERT
# ══════════════════════════════════════════════════════════════════════════════
setup_billing_alert() {
  if ! command -v gcloud &>/dev/null; then
    warn "gcloud no encontrado — omitiendo alerta de billing."
    warn "Instálalo en: https://cloud.google.com/sdk/docs/install"
    return
  fi

  info "Configurando alerta de billing a \$1…"

  # Obtener lista de cuentas de facturación
  local accounts_json
  accounts_json=$(gcloud billing accounts list --format=json 2>/dev/null || echo "[]")

  local count
  count=$(echo "$accounts_json" | python3 -c "import sys,json; print(len(json.load(sys.stdin)))" 2>/dev/null || echo "0")

  if [[ "$count" == "0" ]]; then
    warn "No se encontraron cuentas de billing vinculadas a tu cuenta de Google Cloud."
    warn "Activa el plan Blaze en: https://console.firebase.google.com/project/$PROJECT_ID/usage/details"
    return
  fi

  local billing_account
  if [[ "$count" == "1" ]]; then
    billing_account=$(echo "$accounts_json" | python3 -c "
import sys, json
accounts = json.load(sys.stdin)
print(accounts[0]['name'])
" 2>/dev/null)
    local display_name
    display_name=$(echo "$accounts_json" | python3 -c "
import sys, json
accounts = json.load(sys.stdin)
print(accounts[0].get('displayName', accounts[0]['name']))
" 2>/dev/null)
    info "Usando cuenta de billing: $display_name"
  else
    # Múltiples cuentas — mostrar menú
    echo ""
    ask "Se encontraron varias cuentas de billing. Elige una:"
    echo "$accounts_json" | python3 -c "
import sys, json
accounts = json.load(sys.stdin)
for i, a in enumerate(accounts, 1):
    print(f'  {i}) {a.get(\"displayName\", a[\"name\"])}  ({a[\"name\"]})')
" 2>/dev/null
    echo ""
    ask "Número (1-$count): "
    local choice
    read -r choice
    billing_account=$(echo "$accounts_json" | python3 -c "
import sys, json
accounts = json.load(sys.stdin)
idx = int('$choice') - 1
print(accounts[idx]['name'] if 0 <= idx < len(accounts) else '')
" 2>/dev/null)
    [[ -n "$billing_account" ]] || { warn "Selección inválida — omitiendo alerta de billing."; return; }
  fi

  # Vincular cuenta de billing al proyecto (por si no está vinculada)
  info "Vinculando cuenta de billing al proyecto…"
  gcloud billing projects link "$PROJECT_ID" \
    --billing-account="${billing_account#billingAccounts/}" \
    2>/dev/null || warn "El proyecto ya estaba vinculado a la cuenta de billing."

  # Crear el presupuesto con alerta al 50%, 90% y 100% de $1
  info "Creando presupuesto con alerta a \$1 (alertas al 50%, 90%, 100%)…"
  gcloud billing budgets create \
    --billing-account="${billing_account#billingAccounts/}" \
    --display-name="GeoPing — alerta \$1 (${PROJECT_ID})" \
    --budget-amount="1USD" \
    --threshold-rule="percent=0.5" \
    --threshold-rule="percent=0.9" \
    --threshold-rule="percent=1.0,basis=forecasted-spend" \
    --filter-projects="projects/$PROJECT_ID" \
    2>/dev/null && info "Alerta de billing creada." \
    || warn "No se pudo crear la alerta automáticamente. Hazlo en: https://console.cloud.google.com/billing/budgets"
}

# ══════════════════════════════════════════════════════════════════════════════
# SETUP
# ══════════════════════════════════════════════════════════════════════════════
cmd_setup() {
  if [[ -z "$PROJECT_ID" ]]; then
    ask "ID del proyecto Firebase (ej. geopping-prod): "
    read -r PROJECT_ID
    [[ -n "$PROJECT_ID" ]] || error "El ID del proyecto no puede estar vacío."
  fi

  login

  # ─── 1. Proyecto ──────────────────────────────────────────────────────────
  local exists
  exists=$(project_exists "$PROJECT_ID")

  if [[ "$exists" == "yes" ]]; then
    warn "El proyecto '$PROJECT_ID' ya existe en tu cuenta de Firebase."
    if confirm "¿Quieres usarlo tal como está (sin recrearlo)?"; then
      info "Usando proyecto existente '$PROJECT_ID'."
    else
      ask "Ingresa un nuevo ID de proyecto: "
      read -r PROJECT_ID
      [[ -n "$PROJECT_ID" ]] || error "ID vacío."
      info "Creando proyecto '$PROJECT_ID'…"
      firebase projects:create "$PROJECT_ID" --display-name "GeoPing"
    fi
  else
    info "Creando proyecto '$PROJECT_ID'…"
    firebase projects:create "$PROJECT_ID" --display-name "GeoPing"
  fi

  firebase use "$PROJECT_ID"

  # ─── 2. Firestore ─────────────────────────────────────────────────────────
  info "Creando base de datos Firestore (nam5 / producción)…"
  firebase firestore:databases:create \
    --location nam5 \
    --type FIRESTORE_NATIVE \
    2>/dev/null || warn "La base de datos Firestore ya existe — omitiendo."

  # ─── 3. App Android ───────────────────────────────────────────────────────
  info "Registrando app Android ($ANDROID_PKG)…"
  local android_id
  android_id=$(get_android_app_id)

  if [[ -z "$android_id" ]]; then
    android_id=$(
      firebase apps:create android "GeoPing Android" \
        --package-name="$ANDROID_PKG" \
        --project "$PROJECT_ID" \
        --json 2>/dev/null \
      | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['result']['appId'])" \
      2>/dev/null || true
    )
  else
    info "App Android ya registrada ($android_id)."
  fi

  if [[ -n "$android_id" ]]; then
    # ─── SHA-1 fingerprints ───────────────────────────────────────────────────
    local keystore="$ROOT_DIR/android/upload-keystore.jks"
    local debug_keystore="$HOME/.android/debug.keystore"

    register_sha1() {
      local ks="$1" alias="$2" pass="$3" label="$4"
      if [[ -f "$ks" ]]; then
        local sha1
        sha1=$(keytool -list -v -keystore "$ks" -alias "$alias" \
          -storepass "$pass" -keypass "$pass" 2>/dev/null \
          | grep "SHA1:" | awk '{print $2}')
        if [[ -n "$sha1" ]]; then
          info "Registrando SHA-1 $label ($sha1)…"
          firebase apps:android:sha:create "$android_id" "$sha1" \
            --project "$PROJECT_ID" 2>/dev/null \
            && info "  SHA-1 $label registrado." \
            || warn "  SHA-1 $label ya estaba registrado o falló."
        fi
      fi
    }

    register_sha1 "$keystore"       "upload"          "geoping2024" "release"
    register_sha1 "$debug_keystore" "androiddebugkey" "android"     "debug"

    info "Descargando google-services.json…"
    firebase apps:sdkconfig android "$android_id" \
      --out "$ROOT_DIR/android/app/google-services.json"
    info "  → android/app/google-services.json"
  else
    warn "No se pudo descargar google-services.json. Hazlo manualmente desde la consola."
  fi

  # ─── 4. App iOS ───────────────────────────────────────────────────────────
  info "Registrando app iOS ($IOS_BUNDLE)…"
  local ios_id
  ios_id=$(get_ios_app_id)

  if [[ -z "$ios_id" ]]; then
    ios_id=$(
      firebase apps:create ios "GeoPing iOS" \
        --bundle-id="$IOS_BUNDLE" \
        --project "$PROJECT_ID" \
        --json 2>/dev/null \
      | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['result']['appId'])" \
      2>/dev/null || true
    )
  else
    info "App iOS ya registrada ($ios_id)."
  fi

  if [[ -n "$ios_id" ]]; then
    info "Descargando GoogleService-Info.plist…"
    firebase apps:sdkconfig ios "$ios_id" \
      --out "$ROOT_DIR/ios/Runner/GoogleService-Info.plist"
    info "  → ios/Runner/GoogleService-Info.plist"
  else
    warn "No se pudo descargar GoogleService-Info.plist. Hazlo manualmente desde la consola."
  fi

  # ─── 5. App Web ───────────────────────────────────────────────────────────
  info "Registrando app Web…"
  local web_id
  web_id=$(get_web_app_id)

  if [[ -z "$web_id" ]]; then
    web_id=$(
      firebase apps:create web "GeoPing Web" \
        --project "$PROJECT_ID" \
        --json 2>/dev/null \
      | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['result']['appId'])" \
      2>/dev/null || true
    )
    [[ -n "$web_id" ]] && info "App Web creada ($web_id)." \
      || warn "No se pudo crear la app Web. Hazlo manualmente desde la consola."
  else
    info "App Web ya registrada ($web_id)."
  fi

  # ─── 6. Deploy rules + indexes ────────────────────────────────────────────
  info "Desplegando Firestore rules e indexes…"
  firebase deploy --only firestore --project "$PROJECT_ID"

  # ─── 7. Alerta de billing a $1 ────────────────────────────────────────────
  setup_billing_alert

  # ─── 8. Pasos manuales ────────────────────────────────────────────────────
  echo ""
  echo -e "${YELLOW}══════════════════════════════════════════════════════${NC}"
  echo -e "${YELLOW}  Pasos manuales requeridos en la consola Firebase:${NC}"
  echo -e "${YELLOW}══════════════════════════════════════════════════════${NC}"
  echo ""
  echo "  1. Habilitar métodos de autenticación:"
  echo "     https://console.firebase.google.com/project/$PROJECT_ID/authentication/providers"
  echo "     • Google  → Activar  (Familiar en web)"
  echo "     • Anónimo → Activar  (Pingo en móvil)"
  echo ""
  echo "  2. Añadir dominio de producción a Dominios autorizados:"
  echo "     https://console.firebase.google.com/project/$PROJECT_ID/authentication/settings"
  echo "     Authentication → Configuración → Dominios autorizados → Añadir dominio"
  echo "     (ej. geoping.pages.dev — localhost ya está por defecto)"
  echo ""
  echo "  3. Las huellas digitales SHA-1 (debug y release) se registran automáticamente."
  echo "     Si agregas un keystore nuevo, vuelve a correr: make firebase-init"
  echo ""
  echo "  4. Cloud Messaging se activa automáticamente. Sin acción extra."
  echo ""
  echo "  5. Para notificaciones iOS, sube tu clave APNs en:"
  echo "     Configuración del proyecto → Cloud Messaging → Configuración de app Apple"
  echo ""
  echo -e "${GREEN}¡Listo! Próximos pasos:${NC}"
  echo "  make firebase-configure   # genera lib/firebase_options.dart"
  echo "  make setup                # instala dependencias"
  echo "  make deploy               # sube Functions + Firestore rules"
}

# ══════════════════════════════════════════════════════════════════════════════
# DELETE
# ══════════════════════════════════════════════════════════════════════════════
cmd_delete() {
  if [[ -z "$PROJECT_ID" ]]; then
    ask "ID del proyecto a eliminar: "
    read -r PROJECT_ID
    [[ -n "$PROJECT_ID" ]] || error "El ID del proyecto no puede estar vacío."
  fi

  login

  local exists
  exists=$(project_exists "$PROJECT_ID")
  [[ "$exists" == "yes" ]] || error "El proyecto '$PROJECT_ID' no existe en tu cuenta."

  firebase use "$PROJECT_ID"

  echo ""
  echo -e "${RED}══════════════════════════════════════════════════════${NC}"
  echo -e "${RED}  ADVERTENCIA: Operación destructiva${NC}"
  echo -e "${RED}══════════════════════════════════════════════════════${NC}"
  echo ""
  echo "  Proyecto: $PROJECT_ID"
  echo ""
  echo "  Esto eliminará:"
  echo "    • Todos los documentos de Firestore (configs + sessions)"
  echo "    • El registro de las apps Android, iOS y Web"
  echo "    • Los archivos locales google-services.json, GoogleService-Info.plist y firebase_options.dart"
  echo ""
  confirm "¿Estás seguro de que quieres continuar?" || { info "Cancelado."; exit 0; }

  # ─── Firestore: borrar colecciones ────────────────────────────────────────
  info "Eliminando colección 'configs'…"
  firebase firestore:delete configs \
    --project "$PROJECT_ID" \
    --recursive --force 2>/dev/null \
    || warn "No se pudo borrar 'configs' (puede estar vacía)."

  info "Eliminando colección 'sessions'…"
  firebase firestore:delete sessions \
    --project "$PROJECT_ID" \
    --recursive --force 2>/dev/null \
    || warn "No se pudo borrar 'sessions' (puede estar vacía)."

  # ─── Apps registradas ─────────────────────────────────────────────────────
  local android_id ios_id web_id
  android_id=$(get_android_app_id)
  ios_id=$(get_ios_app_id)
  web_id=$(get_web_app_id)

  if [[ -n "$android_id" ]]; then
    info "Eliminando registro de app Android ($android_id)…"
    firebase apps:remove "$android_id" --project "$PROJECT_ID" --force 2>/dev/null \
      || warn "No se pudo eliminar la app Android (quizás ya fue eliminada)."
  fi

  if [[ -n "$ios_id" ]]; then
    info "Eliminando registro de app iOS ($ios_id)…"
    firebase apps:remove "$ios_id" --project "$PROJECT_ID" --force 2>/dev/null \
      || warn "No se pudo eliminar la app iOS (quizás ya fue eliminada)."
  fi

  if [[ -n "$web_id" ]]; then
    info "Eliminando registro de app Web ($web_id)…"
    firebase apps:remove "$web_id" --project "$PROJECT_ID" --force 2>/dev/null \
      || warn "No se pudo eliminar la app Web (quizás ya fue eliminada)."
  fi

  # ─── Archivos locales ─────────────────────────────────────────────────────
  local android_config="$ROOT_DIR/android/app/google-services.json"
  local ios_config="$ROOT_DIR/ios/Runner/GoogleService-Info.plist"

  if [[ -f "$android_config" ]]; then
    rm "$android_config"
    info "Eliminado: android/app/google-services.json"
  fi
  if [[ -f "$ios_config" ]]; then
    rm "$ios_config"
    info "Eliminado: ios/Runner/GoogleService-Info.plist"
  fi

  local firebase_options="$ROOT_DIR/lib/firebase_options.dart"
  if [[ -f "$firebase_options" ]]; then
    rm "$firebase_options"
    info "Eliminado: lib/firebase_options.dart"
  fi

  # ─── ¿Eliminar el proyecto completo? ──────────────────────────────────────
  echo ""
  warn "La CLI de Firebase no puede eliminar proyectos completos."
  echo "  Si quieres eliminar el proyecto '$PROJECT_ID' definitivamente:"
  echo "  https://console.firebase.google.com/project/$PROJECT_ID/settings/general"
  echo "  Configuración del proyecto → (al final) → Eliminar proyecto"
  echo ""
  echo -e "${GREEN}Limpieza local completada.${NC}"
}

# ─── Dispatch ─────────────────────────────────────────────────────────────────
case "$COMMAND" in
  setup)  cmd_setup  ;;
  delete) cmd_delete ;;
esac

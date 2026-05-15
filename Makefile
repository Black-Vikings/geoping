EMULATOR    ?= Pixel_6_API_34
PROJECT_ID  ?= geoping-b30a1
ANDROID_PKG ?= com.blackvikings.geoping
IOS_BUNDLE  ?= com.blackvikings.geoping

.PHONY: run emu device build-apk build-ios deploy functions-deploy rules-deploy functions-dev setup clean codegen firebase-init firebase-delete firebase-configure web-dev web-build web-deploy

run:
	flutter run

emu:
	flutter emulators --launch $(EMULATOR)
	flutter run

device:
	flutter run --release

build-apk:
	flutter build apk --release

build-ios:
	flutter build ipa --release

codegen:
	dart run build_runner build --delete-conflicting-outputs

codegen-watch:
	dart run build_runner watch --delete-conflicting-outputs

deploy:
	firebase deploy

functions-deploy:
	cd functions && npm run deploy

rules-deploy:
	firebase deploy --only firestore:rules,firestore:indexes

functions-dev:
	cd functions && npm run serve

firebase-init:
	bash scripts/firebase-setup.sh setup $(PROJECT_ID) $(ANDROID_PKG) $(IOS_BUNDLE)

firebase-delete:
	bash scripts/firebase-setup.sh delete $(PROJECT_ID)

firebase-configure:
	dart pub global activate flutterfire_cli
	flutterfire configure --project=$(PROJECT_ID)

web-dev:
	flutter run -d chrome --target lib/main_web.dart

web-build:
	flutter build web --target lib/main_web.dart --release

web-deploy: web-build
	npx wrangler pages deploy build/web --project-name geoping-familiar

setup:
	flutter pub get
	pnpm --prefix functions install
	dart run build_runner build --delete-conflicting-outputs

clean:
	flutter clean
	flutter pub get

EMULATOR ?= Pixel_6_API_34

.PHONY: run emu device build-apk build-ios functions-deploy functions-dev setup clean codegen

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

functions-deploy:
	cd functions && npm run deploy

functions-dev:
	cd functions && npm run serve

setup:
	flutter pub get
	dart run build_runner build --delete-conflicting-outputs
	cd functions && npm install

clean:
	flutter clean
	flutter pub get

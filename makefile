NAME := Ksign
PLATFORM := iphoneos
SCHEMES := Ksign

# استخدم مجلد ثابت حتى يستطيع GitHub Actions عمل Cache له
TMP := .build/$(NAME)
STAGE := $(TMP)/stage
APP := $(TMP)/Build/Products/Release-$(PLATFORM)

.PHONY: all clean deps $(SCHEMES)

all: $(SCHEMES)

clean:
	rm -rf "$(TMP)"
	rm -rf packages
	rm -rf Payload

# تحميل dependencies فقط إذا لم تكن موجودة
deps:
	mkdir -p deps

	@if [ ! -f deps/server.crt ]; then \
		echo "Downloading server.crt..."; \
		curl -L --fail --silent --show-error \
			-o deps/server.crt \
			https://backloop.dev/backloop.dev-cert.crt; \
	fi

	@if [ ! -f deps/server.key1 ]; then \
		echo "Downloading server.key1..."; \
		curl -L --fail --silent --show-error \
			-o deps/server.key1 \
			https://backloop.dev/backloop.dev-key.part1.pem; \
	fi

	@if [ ! -f deps/server.key2 ]; then \
		echo "Downloading server.key2..."; \
		curl -L --fail --silent --show-error \
			-o deps/server.key2 \
			https://backloop.dev/backloop.dev-key.part2.pem; \
	fi

	@if [ ! -f deps/server.pem ] && \
		[ -f deps/server.key1 ] && \
		[ -f deps/server.key2 ]; then \
		cat deps/server.key1 deps/server.key2 > deps/server.pem; \
	fi

	@rm -f deps/server.key1 deps/server.key2

	@echo "*.backloop.dev" > deps/commonName.txt

$(SCHEMES): deps
	@echo "======================================"
	@echo "Building $(NAME)"
	@echo "Platform: $(PLATFORM)"
	@echo "Scheme: $@"
	@echo "CPU cores: $$(sysctl -n hw.ncpu)"
	@echo "======================================"

	mkdir -p "$(TMP)"

	xcodebuild \
		-project Ksign.xcodeproj \
		-scheme "$@" \
		-configuration Release \
		-arch arm64 \
		-sdk $(PLATFORM) \
		-derivedDataPath "$(TMP)" \
		-skipPackagePluginValidation \
		-parallelizeTargets \
		-jobs $$(sysctl -n hw.ncpu) \
		CODE_SIGNING_ALLOWED=NO \
		ALWAYS_EMBED_SWIFT_STANDARD_LIBRARIES=NO

	@echo "Preparing IPA..."

	rm -rf Payload
	rm -rf "$(STAGE)"

	mkdir -p "$(STAGE)/Payload"

	mv "$(APP)/$@.app" "$(STAGE)/Payload/$@.app"

	chmod -R 0755 "$(STAGE)/Payload/$@.app"

	codesign \
		--force \
		--sign - \
		--timestamp=none \
		"$(STAGE)/Payload/$@.app"

	cp deps/* "$(STAGE)/Payload/$@.app/" || true

	rm -rf "$(STAGE)/Payload/$@.app/_CodeSignature"

	ln -sfn "$(STAGE)/Payload" Payload

	mkdir -p packages

	rm -f "packages/$@.ipa"

	cd "$(STAGE)" && \
		zip -r9 "../../packages/$@.ipa" Payload

	@echo "======================================"
	@echo "IPA created successfully:"
	@ls -lh "packages/$@.ipa"
	@echo "======================================"

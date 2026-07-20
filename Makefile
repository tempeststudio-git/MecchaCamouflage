NATIVE_APPLY_MODE ?= mesh_first_paint
RESEARCH_ARTIFACTS ?= $(MECCHA_RESEARCH_ARTIFACTS)
BUILD_PS := scripts/build.ps1
RUN_PS := scripts/dev.ps1
PACKAGE_PS := scripts/release.ps1
MESH_PS := scripts/mesh.ps1
REVIEW_DEAD_CODE_PS := scripts/review/runtime-dead-code-inventory.ps1
START_EXE ?= .build/bin/meccha-camouflage.exe
DEV_OUT_DIR ?= .build/bin-dev
RESEARCH_ARTIFACT_FLAGS := $(if $(filter 1 true TRUE yes YES on ON,$(RESEARCH_ARTIFACTS)),-EnableResearchArtifacts,)
MESH_ARGS := $(if $(PAKS),-PaksPath "$(PAKS)",) $(if $(MAPPINGS),-MappingsPath "$(MAPPINGS)",) $(if $(CUE4PARSE),-Cue4ParsePath "$(CUE4PARSE)",) $(if $(OUTPUT),-OutputPath "$(OUTPUT)",) $(if $(ASSET),-AssetPath "$(ASSET)",) $(if $(EXPORT),-ExportName "$(EXPORT)",) $(if $(GAME_VERSION),-GameVersion "$(GAME_VERSION)",) $(if $(OODLE),-OodlePath "$(OODLE)",) $(if $(ZLIB),-ZlibPath "$(ZLIB)",) $(if $(TEXTURE_SIZE),-TextureSize "$(TEXTURE_SIZE)",) $(if $(EXPECTED_VERTICES),-ExpectedVertices "$(EXPECTED_VERTICES)",) $(if $(EXPECTED_INDICES),-ExpectedIndices "$(EXPECTED_INDICES)",) $(if $(EXPECTED_BONES),-ExpectedBones "$(EXPECTED_BONES)",)

ifeq ($(OS),Windows_NT)
SHELL := cmd.exe
POWERSHELL_EXE := powershell.exe
# build.ps1 resolves the version when -Version is omitted.
BUILD_VERSION_ARGS :=

define RUN_POWERSHELL
	@$(POWERSHELL_EXE) -NoProfile -ExecutionPolicy Bypass -File $(1) $(2)
endef
else
VERSION ?= $(shell git describe --tags --exact-match 2>/dev/null || git describe --tags --dirty --always 2>/dev/null || printf dev)
BUILD_VERSION_ARGS := -Version $(VERSION)

define RUN_POWERSHELL
	@if command -v powershell.exe >/dev/null 2>&1; then \
		PS_SCRIPT_WIN="$$(if command -v wslpath >/dev/null 2>&1; then wslpath -w $(1); else printf '%s' $(1); fi)"; \
		powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$$PS_SCRIPT_WIN" $(2); \
	elif command -v pwsh >/dev/null 2>&1; then \
		pwsh -NoProfile -ExecutionPolicy Bypass -File $(1) $(2); \
	else \
		echo "PowerShell runtime not found." >&2; exit 127; \
	fi
endef
endif

.PHONY: build build-timed build-dev build-dev-timed run dev start package mesh review-dead-code clean clean-artifacts clean-all

build:
	$(call RUN_POWERSHELL,$(BUILD_PS),$(BUILD_VERSION_ARGS))

build-timed:
	$(call RUN_POWERSHELL,$(BUILD_PS),$(BUILD_VERSION_ARGS) -ShowTimings)

build-dev:
	$(call RUN_POWERSHELL,$(BUILD_PS),$(BUILD_VERSION_ARGS) -BuildMode DevLooseSelfContained -OutDir "$(DEV_OUT_DIR)")

build-dev-timed:
	$(call RUN_POWERSHELL,$(BUILD_PS),$(BUILD_VERSION_ARGS) -BuildMode DevLooseSelfContained -OutDir "$(DEV_OUT_DIR)" -ShowTimings)

run: build-dev
	$(call RUN_POWERSHELL,$(RUN_PS),-BuildOutputDir "$(DEV_OUT_DIR)" -NativeApplyMode $(NATIVE_APPLY_MODE) $(RESEARCH_ARTIFACT_FLAGS))

dev: run

ifeq ($(OS),Windows_NT)
start:
	@if not exist "$(START_EXE)" (echo Built exe not found: $(START_EXE). Run make build first, or pass START_EXE=path. 1>&2 & exit /b 1)
	@$(POWERSHELL_EXE) -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath '$(START_EXE)'"
else
start:
	@if [ ! -f "$(START_EXE)" ]; then \
		echo "Built exe not found: $(START_EXE). Run make build first, or pass START_EXE=path." >&2; \
		exit 1; \
	fi
	@if command -v powershell.exe >/dev/null 2>&1; then \
		EXE_WIN="$$(if command -v wslpath >/dev/null 2>&1; then wslpath -w "$(START_EXE)"; else printf '%s' "$(START_EXE)"; fi)"; \
		EXE_PS="$$(printf '%s' "$$EXE_WIN" | sed "s/'/''/g")"; \
		powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath '$$EXE_PS'"; \
	elif command -v pwsh >/dev/null 2>&1; then \
		EXE_PS="$$(printf '%s' "$(START_EXE)" | sed "s/'/''/g")"; \
		pwsh -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath '$$EXE_PS'"; \
	else \
		echo "PowerShell runtime not found." >&2; exit 127; \
	fi
endif

package: build
	$(call RUN_POWERSHELL,$(PACKAGE_PS),$(BUILD_VERSION_ARGS))

mesh:
	$(call RUN_POWERSHELL,$(MESH_PS),$(MESH_ARGS))

review-dead-code:
	$(call RUN_POWERSHELL,$(REVIEW_DEAD_CODE_PS),)

ifeq ($(OS),Windows_NT)
clean:
	@$(POWERSHELL_EXE) -NoProfile -Command "if (Test-Path '.build') { Remove-Item -Recurse -Force '.build' }"

clean-artifacts:
	@$(POWERSHELL_EXE) -NoProfile -Command "if (Test-Path 'artifacts') { Get-ChildItem 'artifacts' | Remove-Item -Recurse -Force }"
else
clean:
	rm -rf .build

clean-artifacts:
	rm -rf artifacts/*

endif

clean-all: clean clean-artifacts

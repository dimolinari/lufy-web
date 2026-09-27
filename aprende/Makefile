SWIFT ?= swift

.PHONY: test audio project sync

test:
	$(SWIFT) test

audio:
	python3 scripts/generate_audio.py

project: sync
	./scripts/setup.sh

sync:
	python3 scripts/sync_brand.py

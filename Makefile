-include .env.local

SRCDIR=./azerothcore-wotlk
MODDIR=$(SRCDIR)/modules

default: build

compose/up:
	podman unshare chown -R 1000:1000 .	/azerothcore-wotlk/env
	podman-compose -f $(SRCDIR)/docker-compose.yml \
		-f ./docker-compose.override.yml \
		up -d --no-build --pull=never

build/runtime: clone
	podman build --target runtime \
		-f $(SRCDIR)/apps/docker/Dockerfile \
		$(SRCDIR)
build/authserver: build/runtime
	podman build --target authserver \
		-t acore/ac-wotlk-authserver \
		-t ghcr.io/strootje/ac-wotlk-authserver \
		-f $(SRCDIR)/apps/docker/Dockerfile \
		$(SRCDIR)
build/worldserver: build/runtime
	podman build --target worldserver \
		-t acore/ac-wotlk-worldserver \
		-t ghcr.io/strootje/ac-wotlk-worldserver \
		-f $(SRCDIR)/apps/docker/Dockerfile \
		$(SRCDIR)
build/db-import: build/runtime
	podman build --target db-import \
		-t acore/ac-wotlk-db-import \
		-t ghcr.io/strootje/ac-wotlk-db-import \
		-f $(SRCDIR)/apps/docker/Dockerfile \
		$(SRCDIR)
build/client-data: build/runtime
	podman build --target client-data \
		-t acore/ac-wotlk-client-data \
		-t ghcr.io/strootje/ac-wotlk-client-data \
		-f $(SRCDIR)/apps/docker/Dockerfile \
		$(SRCDIR)
build: build/authserver build/worldserver build/db-import build/client-data

$(SRCDIR):
	git clone --branch=Playerbot \
		https://github.com/mod-playerbots/azerothcore-wotlk.git \
		$(SRCDIR)
$(MODDIR)/mod-playerbots: $(SRCDIR)
	git clone --branch=master \
		https://github.com/mod-playerbots/mod-playerbots.git \
		$(MODDIR)/mod-playerbots
$(MODDIR)/mod-individual-progression: $(SRCDIR)
	git clone --branch=master \
		https://github.com/ZhengPeiRu21/mod-individual-progression.git \
		$(MODDIR)/mod-individual-progression
$(MODDIR)/mod-ollama-chat: $(SRCDIR)
	git clone --branch=main \
		https://github.com/DustinHendrickson/mod-ollama-chat.git \
		$(MODDIR)/mod-ollama-chat
$(MODDIR)/mod-ah-bot-plus: $(SRCDIR)
	git clone --branch=master \
		https://github.com/NathanHandley/mod-ah-bot-plus.git \
		$(MODDIR)/mod-ah-bot-plus
$(MODDIR)/mod-aoe-loot: $(SRCDIR)
	git clone --branch=master \
		https://github.com/azerothcore/mod-aoe-loot.git \
		$(MODDIR)/mod-aoe-loot
$(MODDIR)/mod-dungeon-clean: $(SRCDIR)
	git clone --branch=master \
		https://github.com/jrad7/mod-dungeon-clear.git \
		$(MODDIR)/mod-dungeon-clear
clone: $(SRCDIR) $(MODDIR)/mod-playerbots $(MODDIR)/mod-individual-progression $(MODDIR)/mod-ollama-chat $(MODDIR)/mod-ah-bot-plus $(MODDIR)/mod-aoe-loot $(MODDIR)/mod-dungeon-clean

all: sidebar.html # apps

APPSMD = quickstart/apps.md
TMP = /tmp/.tmp.mos.yml
apps:
	curl -s https://api.github.com/orgs/mongoose-os-apps/repos?per_page=200 |\
		perl -nle 'print $$1 if /"full_name": "(.*)"/' > /tmp/repos.txt
	echo '# Example apps' > $(APPSMD)
	echo '|  GitHub repo  | Description | Author |' >> $(APPSMD)
	echo '|  ----  | ----------- | --- |' >> $(APPSMD)
	sort /tmp/repos.txt | while read REPO ; do \
		curl -s https://raw.githubusercontent.com/$$REPO/master/mos.yml > $(TMP); \
		echo $$REPO ; \
		echo "| [$${REPO#*/}](https://github.com/$$REPO) | $$(cat $(TMP) | perl -nle 'print $$1 if /^description: (.*)/') | $$(cat $(TMP) | perl -nle 'print $$1 if /^author: (.*)/') | " >> $(APPSMD) ;\
		done

API = mongoose-os/api
.PHONY: sidebar.html $(API)/core $(API)

CATEGORIES ?= core cloud net drivers arduino rpc misc
clean-generated:
	@for C in $(CATEGORIES) ; do rm -rf $(API)/$$C; mkdir $(API)/$$C; touch $(API)/$$C/index.md ; done


LIBS ?= /tmp/libs
LIBSINDEX ?= /tmp/libs.txt
DEV ?= ../cesanta.com
INC ?= ../mongoose-os/include

$(API)/core: clean-generated
	@echo '[]' > symbols.json
	@(cd $(INC) && ls *.h) | while read F; do node tools/genapi.js $@/$$F.md cesanta/mongoose-os $(INC)/$$F >> $@/index.md; done
	@node tools/genapi.js $@/frozen.h.md cesanta/frozen $(DEV)/frozen/frozen.h >> $@/index.md
	@node tools/genapi.js $@/cs_dbg.h.md cesanta/mongoose-os $(DEV)/common/cs_dbg.h >> $@/index.md
	@node tools/genapi.js $@/mbuf.h.md cesanta/mongoose-os $(DEV)/common/mbuf.h >> $@/index.md
	@node tools/genapi.js $@/mg_str.h.md cesanta/mongoose-os $(DEV)/common/mg_str.h >> $@/index.md

$(API):
	@test -f $(LIBSINDEX) || curl -s https://api.github.com/orgs/mongoose-os-libs/repos?per_page=200 | perl -nle 'print $$1 if /"full_name": "(.*)"/' | sort > $(LIBSINDEX)
	@mkdir -p $(LIBS)
	@cat $(LIBSINDEX) | while read REPO ; \
		do echo $$REPO; \
		BR=$$(basename $$REPO); \
		if test -d $(DEV)/mos_libs/$$BR; then \
			R=$(DEV)/mos_libs/$$BR; \
		else \
			R=$(LIBS)/$$BR; \
			test -d $$R && (cd $$R && git pull --quiet) || git clone --quiet https://github.com/$$REPO $$R; \
		fi; \
		CATEGORY=$$(perl -ne 'print $$1 if /docs:(.+?):(.+?)/' $$R/mos.yml); \
		test -z "$$CATEGORY" && CATEGORY=misc && echo "  github.com/$$REPO is missing docs:tag!"; \
		TITLE=$$(perl -ne 'print $$2 if /docs:(.+?):(.+?)\s*$$/' $$R/mos.yml); \
		test -z "$$TITLE" && TITLE=$$BR; \
		test -d $@/$$CATEGORY/index.md || mkdir -p $@/$$CATEGORY ; touch $@/$$CATEGORY/index.md; \
		node tools/genapi.js $@/$$CATEGORY/$$BR.md $$REPO \
			"$$(ls $$R/include/*.h 2>/dev/null | head -1)" \
			"$$(ls $$R/mjs_fs/*.js 2>/dev/null | head -1)" \
			"$$TITLE" "$$R/README.md" >> $@/$$CATEGORY/index.md; \
	done


sidebar.html: $(API)/core $(API)
	@for C in $(CATEGORIES) ; do sort -o $(API)/$$C/index.md $(API)/$$C/index.md ; done
	@node tools/gensidebar.js > $@


HTMLDIR ?= ../website-miot/front/docs
html:
	rm -rf $(HTMLDIR)/*
	@node tools/genhtml.js "$(HTMLDIR)" $$(find . -name \*.md)
	cp sidebar.html $(HTMLDIR)/

clean:
	rm -rf $(LIBS) $(LIBSINDEX)

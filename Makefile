DICTIONARY_DIR		=	dictionary
TEMPLATE_DIR		=	dictionary.tmpl
META_TEMPLATE_DIR	=	dictionary.tmpl.meta
SETTING_FILENAME	=	setting.data
BIN_DIR			=	bin
PARSE			=	parse_cs.pl
CREATE			=	create.pl

LIST_CS_FILES	=	bin/list.sh

dictionary_name := $$(perl -e 'my $$setting = do "./bin/$(SETTING_FILENAME)"; print $$setting->{dictionary_name}')

template:
	mkdir -p $(TEMPLATE_DIR)
	cp $(META_TEMPLATE_DIR)/xml.tmpl "$(TEMPLATE_DIR)/$(dictionary_name).tmpl"
	mkdir -p $(DICTIONARY_DIR)
	bin/instantiate.pl \
		$(META_TEMPLATE_DIR)/plist.tmpl \
		>"$(DICTIONARY_DIR)/$(dictionary_name)Info.plist"
	bin/instantiate.pl \
		$(META_TEMPLATE_DIR)/Makefile.tmpl \
		>$(DICTIONARY_DIR)/Makefile

instantiate:
	$(LIST_CS_FILES) \
		| xargs bin/parse_cs.pl \
		| bin/create.pl -template_filename=$(TEMPLATE_DIR)/$(dictionary_name).tmpl \
		>$(DICTIONARY_DIR)/$(dictionary_name).xml

build:
	$(MAKE) -C $(DICTIONARY_DIR)

test:
	mkdir -p $(TEMPLATE_DIR)
	ls testdata.d/*.cs \
		| xargs bin/parse_cs.pl \
		| bin/create.pl -template_filename=testdata.d/test.tmpl | tee testdata.d/test.xml

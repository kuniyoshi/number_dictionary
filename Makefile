DICTIONARY_DIR		=	dictionary
TEMPLATE_DIR		=	dictionary.tmpl
META_TEMPLATE_DIR	=	dictionary.tmpl.meta
SETTING_FILENAME	=	setting.data
BIN_DIR			=	bin
PARSE_ENUM		=	$(BIN_DIR)/parse_cs.pl
PARSE_CSV		=	$(BIN_DIR)/parse_csv.pl
CREATE			=	$(BIN_DIR)/create.pl
IMAGE			=	$(BIN_DIR)/image.pl

LIST_CS_FILES	=	bin/list.sh
LIST_CSV_FILES	=	bin/list_csv.sh

dictionary_name := $$(perl -e 'my $$setting = do "./bin/$(SETTING_FILENAME)"; print $$setting->{dictionary_name}')
PLIST_NAME	= $(dictionary_name)Info.plist
DICTIONARY_NAME	= $(dictionary_name)Dictionary.xml
CSS_NAME	= $(dictionary_name)Dictionary.css

.PHONY: all template instantiate image build install clean test

all: template instantiate image build install

template:
	mkdir -p $(TEMPLATE_DIR)
	cp $(META_TEMPLATE_DIR)/xml.tmpl "$(TEMPLATE_DIR)/$(dictionary_name).tmpl"
	mkdir -p $(DICTIONARY_DIR)
	bin/instantiate.pl \
		$(META_TEMPLATE_DIR)/plist.tmpl \
		>"$(DICTIONARY_DIR)/$(PLIST_NAME)"
	bin/instantiate.pl \
		$(META_TEMPLATE_DIR)/css.tmpl \
		>"$(DICTIONARY_DIR)/$(CSS_NAME)"
	bin/instantiate.pl \
		$(META_TEMPLATE_DIR)/Makefile.tmpl \
		>$(DICTIONARY_DIR)/Makefile

instantiate:
	{ \
		$(LIST_CS_FILES) \
			| xargs $(PARSE_ENUM); \
		$(LIST_CSV_FILES) \
			| xargs $(PARSE_CSV) -setting_filepath=./$(BIN_DIR)/$(SETTING_FILENAME); \
	} \
		| $(CREATE) -template_filename=$(TEMPLATE_DIR)/$(dictionary_name).tmpl \
		>"$(DICTIONARY_DIR)/$(DICTIONARY_NAME)"

image:
	$(LIST_CSV_FILES) \
		| xargs $(IMAGE) -setting_filepath=./$(BIN_DIR)/$(SETTING_FILENAME)

build:
	$(MAKE) -C $(DICTIONARY_DIR)

install:
	$(MAKE) -C $(DICTIONARY_DIR) install

clean:
	rm -Rf $(DICTIONARY_DIR)
	rm -Rf $(TEMPLATE_DIR)

test:
	{ \
		ls testdata.d/*.cs \
			| xargs $(PARSE_ENUM); \
		ls testdata.d/*.csv \
			| xargs $(PARSE_CSV) -setting_filepath=./testdata.d/setting.data; \
	} \
		| $(CREATE) -template_filename=testdata.d/test.tmpl | tee testdata.d/test.xml

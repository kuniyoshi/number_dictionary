DICTIONARY_DIR	=	dictionary
SETTING_FILENAME	=	setting.pl

template:
	mkdir -p $(DICTIONARY_DIR)
	dictionary_name=$$(perl -e 'my $$setting = do { "bin/$(SETTING_FILENAME)" }; print $$setting->{dictionary_name}')
	bin/create_template.pl \
		-setting=$(SETTING_FILENAME) \
		-in=dictionary.tmpl/Makefile.tmpl \
		>$(DICTIONARY_DIR)/Makefile
	bin/create_template.pl \
		-setting=$(SETTING_FILENAME) \
		-in=dictionary.tmpl/xml.tmpl \
		>"$(DICTIONARY_DIR)/$${dictionary_name}.xml"
	bin/create_template.pl \
		-setting=$(SETTING_FILENAME) \
		-in=dictionary.tmpl/plist.tmpl \
		>"$(DICTIONARY_DIR)/$${dictionary_name}.plist"

test:
	mkdir -p $(DICTIONARY_DIR)
	bin/parse_cs.pl testdata.d/MoveSpeedType.cs testdata.d/WeaponType.cs \
		| bin/create.pl -template_filename=testdata.d/test.tmpl | tee testdata.d/test.xml

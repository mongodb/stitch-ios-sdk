all:
	$(MAKE) -C StitchCore all
	$(MAKE) -C StitchCoreAdminClient all
	$(MAKE) -C StitchCoreTestUtils all
	$(MAKE) -C StitchCoreServicesTwilio all
update:
	$(MAKE) -C StitchCore update
	$(MAKE) -C StitchCoreAdminClient update
	$(MAKE) -C StitchCoreTestUtils update
	$(MAKE) -C StitchCoreServicesTwilio update
project:
	$(MAKE) -C StitchCore project
	$(MAKE) -C StitchCoreAdminClient project
	$(MAKE)	-C StitchCoreTestUtils project
	$(MAKE) -C StitchCoreServicesTwilio project

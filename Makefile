all:
	$(MAKE) -C BSON all
	$(MAKE) -C StitchCore all
	$(MAKE) -C StitchCoreAdminClient all
	$(MAKE) -C StitchCoreTestUtils all
project:
	$(MAKE) -C BSON	project
	$(MAKE) -C StitchCore project
	$(MAKE) -C StitchCoreAdminClient project
	$(MAKE)	-C StitchCoreTestUtils project

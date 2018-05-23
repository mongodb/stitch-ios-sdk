all:
	$(MAKE) -C StitchCore all
	$(MAKE) -C StitchCoreAdminClient all
	$(MAKE) -C StitchCoreTestUtils all
	$(MAKE) -C StitchCoreServicesTwilio all
git:
	$(MAKE) -C StitchCore git
	$(MAKE) -C StitchCoreAdminClient git
	$(MAKE) -C StitchCoreTestUtils git
	$(MAKE) -C StitchCoreServicesTwilio git
update:
	$(MAKE) -C StitchCore update
	$(MAKE) -C StitchCoreAdminClient update
	$(MAKE) -C StitchCoreTestUtils update
	$(MAKE) -C StitchCoreServicesTwilio update
test:
	$(MAKE) -C StitchCore test
	$(MAKE) -C StitchCoreAdminClient test
	$(MAKE) -C StitchCoreTestUtils test
	$(MAKE) -C StitchCoreServicesTwilio test
project:
	$(MAKE) -C StitchCore project
	$(MAKE) -C StitchCoreAdminClient project
	$(MAKE)	-C StitchCoreTestUtils project
	$(MAKE) -C StitchCoreServicesTwilio project

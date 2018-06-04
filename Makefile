all:
	$(MAKE) -C MockUtils all
	$(MAKE) -C StitchCore all
	$(MAKE) -C StitchCoreAdminClient all
	$(MAKE) -C StitchCoreTestUtils all
	$(MAKE) -C StitchCoreServicesAwsSes all
	$(MAKE) -C StitchCoreServicesTwilio all
lint:
	$(MAKE) -C MockUtils lint
	$(MAKE) -C StitchCore lint
	$(MAKE) -C StitchCoreAdminClient lint
	$(MAKE) -C StitchCoreTestUtils lint
	$(MAKE) -C StitchCoreServicesAwsSes lint
	$(MAKE) -C StitchCoreServicesTwilio lint
git:
	$(MAKE) -C MockUtils git
	$(MAKE) -C StitchCore git
	$(MAKE) -C StitchCoreAdminClient git
	$(MAKE) -C StitchCoreTestUtils git
	$(MAKE) -C StitchCoreServicesAwsSes git
	$(MAKE) -C StitchCoreServicesTwilio git
update:
	$(MAKE) -C MockUtils update
	$(MAKE) -C StitchCore update
	$(MAKE) -C StitchCoreAdminClient update
	$(MAKE) -C StitchCoreTestUtils update
	$(MAKE) -C StitchCoreServicesAwsSes update
	$(MAKE) -C StitchCoreServicesTwilio update
test:
	$(MAKE) -C MockUtils test
	$(MAKE) -C StitchCore test
	$(MAKE) -C StitchCoreAdminClient test
	$(MAKE) -C StitchCoreTestUtils test
	$(MAKE) -C StitchCoreServicesAwsSes test
	$(MAKE) -C StitchCoreServicesTwilio test
project:
	$(MAKE) -C MockUtils project
	$(MAKE) -C StitchCore project
	$(MAKE) -C StitchCoreAdminClient project
	$(MAKE)	-C StitchCoreTestUtils project
	$(MAKE) -C StitchCoreServicesAwsSes test
	$(MAKE) -C StitchCoreServicesTwilio project

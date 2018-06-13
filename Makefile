all:
	$(MAKE) -C MockUtils all
	$(MAKE) -C StitchCoreSDK all
	$(MAKE) -C StitchCoreAdminClient all
	$(MAKE) -C StitchCoreTestUtils all
	$(MAKE) -C StitchCoreAWSS3Service all
	$(MAKE) -C StitchCoreAWSSESService all
	$(MAKE) -C StitchCoreHTTPService all
	$(MAKE) -C StitchCoreRemoteMongoDBService all
	$(MAKE) -C StitchCoreTwilioService all
lint:
	$(MAKE) -C MockUtils lint
	$(MAKE) -C StitchCoreSDK lint
	$(MAKE) -C StitchCoreAdminClient lint
	$(MAKE) -C StitchCoreTestUtils lint
	$(MAKE) -C StitchCoreAWSS3Service lint
	$(MAKE) -C StitchCoreAWSSESService lint
	$(MAKE) -C StitchCoreHTTPService lint
	$(MAKE) -C StitchCoreRemoteMongoDBService lint
	$(MAKE) -C StitchCoreTwilioService lint
git:
	$(MAKE) -C MockUtils git
	$(MAKE) -C StitchCoreSDK git
	$(MAKE) -C StitchCoreAdminClient git
	$(MAKE) -C StitchCoreTestUtils git
	$(MAKE) -C StitchCoreAWSS3Service git
	$(MAKE) -C StitchCoreAWSSESService git
	$(MAKE) -C StitchCoreHTTPService git
	$(MAKE) -C StitchCoreRemoteMongoDBService git
	$(MAKE) -C StitchCoreTwilioService git
update:
	$(MAKE) -C MockUtils update
	$(MAKE) -C StitchCoreSDK update
	$(MAKE) -C StitchCoreAdminClient update
	$(MAKE) -C StitchCoreTestUtils update
	$(MAKE) -C StitchCoreAWSS3Service update
	$(MAKE) -C StitchCoreAWSSESService update
	$(MAKE) -C StitchCoreHTTPService update
	$(MAKE) -C StitchCoreRemoteMongoDBService update
	$(MAKE) -C StitchCoreTwilioService update
test:
	$(MAKE) -C MockUtils test
	$(MAKE) -C StitchCoreSDK test
	$(MAKE) -C StitchCoreAdminClient test
	$(MAKE) -C StitchCoreTestUtils test
	$(MAKE) -C StitchCoreAWSS3Service test
	$(MAKE) -C StitchCoreAWSSESService test
	$(MAKE) -C StitchCoreHTTPService test
	$(MAKE) -C StitchCoreRemoteMongoDBService test
	$(MAKE) -C StitchCoreTwilioService test
project:
	$(MAKE) -C MockUtils project
	$(MAKE) -C StitchCoreSDK project
	$(MAKE) -C StitchCoreAdminClient project
	$(MAKE)	-C StitchCoreTestUtils project
	$(MAKE) -C StitchCoreAWSS3Service project
	$(MAKE) -C StitchCoreAWSSESService project
	$(MAKE) -C StitchCoreHTTPService project
	$(MAKE) -C StitchCoreRemoteMongoDBService project
	$(MAKE) -C StitchCoreTwilioService project

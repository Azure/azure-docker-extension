BIN=docker-extension
BINDIR=bin
BUNDLE=docker-extension.zip
BUNDLEDIR=bundle

EXT_NS=Microsoft.Azure.Extensions
EXT_NAME=DockerExtension

# Storage account used for publishing the VM extension
STGACCT=dockerextension
SUBS_ID=c3dfd792-49a4-4b06-80fc-6fc6d06c4742

# Version for extension handler. (MAJOR.MINOR.BUILD)
# Bump MAJOR for breaking changes, MINOR for new features
# BUILD is yymmddHHMM of the bundle.
MAJOR=1
MINOR=0

# Regions for rolling out to PROD slices (not-so-popular regions).
REGION1=Southeast Asia
REGION2=Brazil South

bundle: clean binary
	@mkdir -p $(BUNDLEDIR)
	zip ./$(BUNDLEDIR)/$(BUNDLE) ./$(BINDIR)/$(BIN)
	zip -j ./$(BUNDLEDIR)/$(BUNDLE) ./metadata/HandlerManifest.json
	zip ./$(BUNDLEDIR)/$(BUNDLE) ./scripts/run-in-background.sh
	@echo "OK: Use $(BUNDLEDIR)/$(BUNDLE) to publish the extension."
binary:
	GOPATH=`pwd` go get -v ./...
	GOOS=linux GOARCH=amd64 GOPATH=`pwd` \
		go build -v -o $(BINDIR)/$(BIN) docker-extension
test:
	GOPATH=`pwd` go test docker-extension/... -test.v
clean:
	rm -rf "$(BUNDLEDIR)"
	rm -rf "pkg"
	rm -rf "$(BINDIR)"
publish:
	@read -p "Storage account key for uploading: " STORAGE_KEY && \
		buildnum="$$(date -r $(BUNDLEDIR)/$(BUNDLE) +%y%m%d%H%M)" && \
		VERSION="$(MAJOR).$(MINOR).$${buildnum}" && \
			echo "Version to be published: $${VERSION}" && \
		fn=docker-$$(date -r $(BUNDLEDIR)/$(BUNDLE) +%Y%m%d-%H%M%S).zip && \
		azure storage blob upload -q -a $(STGACCT) -k $${STORAGE_KEY} "./$(BUNDLEDIR)/$(BUNDLE)" "$(BUNDLEDIR)" "$${fn}" && \
			blob_url="https://$(STGACCT).blob.core.windows.net/$(BUNDLEDIR)/$${fn}" && \
			echo "OK: Extension package uploaded to $${blob_url}" && \
		read -p "Path to Subscription Management Cert (subs:$(SUBS_ID)): " CERT_PATH && \
		read -p "Mode (Update=1, NewExtension=0): " UPDATE  && \
			case "$${UPDATE}" in 1) VERB="PUT" URL="?action=update" ;; *) VERB="POST" URL="" ;; esac && \
		handlerxml=$$(cat ./metadata/DockerHandler.xml | \
			sed "s,%BLOB_URL%,$${blob_url},g" | \
			sed "s,%VERSION%,$${VERSION},g") && \
		echo "Handler XML to be published:\n-----\n$${handlerxml}\n-----" && \
		handlerxml_out="/tmp/DockerExtension-$${VERSION}.xml" && echo "$${handlerxml}" > $${handlerxml_out} && \
		echo "$${handlerxml}" |	\
			curl -i -E "$${CERT_PATH}" https://management.core.windows.net/$(SUBS_ID)/services/extensions$${URL} \
				-d @- \
				-X $${VERB} \
				-H "x-ms-version: 2015-04-01" \
				-H "Content-Type:application/xml" && \
		echo "\nOK: version $${VERSION} published internally if the response above was 202 Accepted." && \
			echo "\tPublish configuration saved to $${handlerxml_out} (use this at 'make slice2')" && \
			echo "Next steps:"; \
			echo "\t1. Use 'make replicationstatus' and 'make versions' to see if this version is replicated."; \
			echo "\t2. Deploy to a VM using 'azure vm extension set', verify if it works correctly."; \
			echo "\t3. Use 'make slice2' to roll out to 1 region."
slice2:
	@read -p "Publish config file from 'make publish': " PUBFILE && \
	if [ ! -f "$${PUBFILE}" ]; then echo "File does not exist.";  exit; fi && \
	xml=$$(cat "$${PUBFILE}") && \
	newxml=$$(echo "$${xml}" | \
		sed "s,<IsInternalExtension>true,<IsInternalExtension>false,g" | \
		sed "s,<!--%REGIONS%-->,<Regions>$(REGION1)</Regions>,g") && \
	echo "Handler XML to be used for rolling out to Slice #2 (one region):\n-----\n$${newxml}\n-----" && \
	read -p "Path to Subscription Management Cert (subs:$(SUBS_ID)): " CERT_PATH && \
	echo "$${newxml}" | \
		curl -i -E "$${CERT_PATH}" https://management.core.windows.net/$(SUBS_ID)/services/extensions?action=update \
			-d @- \
			-X PUT \
			-H "x-ms-version: 2015-04-01" \
			-H "Content-Type:application/xml" && \
	echo "\nOK: version rolling out to Slice #2 if the response above was 202 Accepted. Verify with 'make listversions'."; \
	echo "Next step: Roll out to two regions using 'make slice3'"
slice3:
	@read -p "Publish config file from 'make publish': " PUBFILE && \
	if [ ! -f "$${PUBFILE}" ]; then echo "File does not exist.";  exit; fi && \
	xml=$$(cat "$${PUBFILE}") && \
	newxml=$$(echo "$${xml}" | \
		sed "s,<IsInternalExtension>true,<IsInternalExtension>false,g" | \
		sed "s,<!--%REGIONS%-->,<Regions>$(REGION1);$(REGION2)</Regions>,g") && \
	echo "Handler XML to be used for rolling out to Slice #3 (two regions):\n-----\n$${newxml}\n-----" && \
	read -p "Path to Subscription Management Cert (subs:$(SUBS_ID)): " CERT_PATH && \
	echo "$${newxml}" | \
		curl -i -E "$${CERT_PATH}" https://management.core.windows.net/$(SUBS_ID)/services/extensions?action=update \
			-d @- \
			-X PUT \
			-H "x-ms-version: 2015-04-01" \
			-H "Content-Type:application/xml" && \
	echo "\nOK: version rolling out to Slice #3 if the response above was 202 Accepted. Verify with 'make listversions'."; \
	echo "Next step: Roll out to ALL PROD regions using 'make slice4'"
slice4:
	@read -p "Publish config file from 'make publish': " PUBFILE && \
	if [ ! -f "$${PUBFILE}" ]; then echo "File does not exist.";  exit; fi && \
	xml=$$(cat "$${PUBFILE}") && \
	newxml=$$(echo "$${xml}" | \
		sed "s,<IsInternalExtension>true,<IsInternalExtension>false,g" | \
		sed "s,<!--%REGIONS%-->,,g") && \
	echo "Handler XML to be used for rolling out to Slice #4 (ALL REGIONS):\n-----\n$${newxml}\n-----" && \
	read -p "Path to Subscription Management Cert (subs:$(SUBS_ID)): " CERT_PATH && \
	echo "$${newxml}" | \
		curl -i -E "$${CERT_PATH}" https://management.core.windows.net/$(SUBS_ID)/services/extensions?action=update \
			-d @- \
			-X PUT \
			-H "x-ms-version: 2015-04-01" \
			-H "Content-Type:application/xml" && \
	echo "\nOK: version rolling out to Slice #4 (ALL REGIONS in Prod) if the response above was 202 Accepted.";
listversions:
	@read -p "Path to Subscription Management Cert (subs:$(SUBS_ID)): " CERT_PATH && \
		curl -sSL -E "$${CERT_PATH}" -H "x-ms-version: 2015-04-01" \
		https://management.core.windows.net/$(SUBS_ID)/services/publisherextensions | \
		sed 's/<Version>/\n<Version>/g'
replicationstatus:
	@read -p "Path to Subscription Management Cert (subs:$(SUBS_ID)): " CERT_PATH && \
	read -p "Version (e.g. 1.0.1505311204): " VERSION && \
		curl -sSL -E "$${CERT_PATH}" -H "x-ms-version: 2015-04-01" \
		https://management.core.windows.net/$(SUBS_ID)/services/extensions/$(EXT_NS)/$(EXT_NAME)/$${VERSION}/replicationstatus | \
			sed 's/<ReplicationStatus>/\n<ReplicationStatus>/g' | \
			grep --color '<Status>[A-Za-z]\+</Status>'
unregisterversion:
	@read -p "Path to Subscription Management Cert (subs:$(SUBS_ID)): " CERT_PATH && \
	read -p "Version (e.g. 1.0.1505311204): " VERSION && \
	UPDATE_FILE="./metadata/UnregisterRequest.xml" && \
	if [ ! -f "$${UPDATE_FILE}" ]; then echo "Update template $${UPDATE_FILE} does not exist.";  exit; fi && \
	xml=$$(cat "$${UPDATE_FILE}") && \
	newxml=$$(echo "$${xml}" | \
		sed "s,{{VERSION}},$${VERSION},g") && \
		echo "Updating the extension to internal first:\n-----\n$${newxml}\n-----" && \
	echo "$${newxml}" | \
		curl -i -E "$${CERT_PATH}" https://management.core.windows.net/$(SUBS_ID)/services/extensions?action=update \
			-d @- \
			-X PUT \
			-H "x-ms-version: 2015-04-01" \
			-H "Content-Type:application/xml" && \
	echo "\n\nUpdate to internal=OK: If the request above was successful. Give it some time to replicate the manifest and use 'make deleteversion'."
deleteversion:
	@read -p "Path to Subscription Management Cert (subs:$(SUBS_ID)): " CERT_PATH && \
		read -p "Version (e.g. 1.0.1505311204): " VERSION && \
	echo "Unregistering (deleting) the extension version $${VERSION}." && \
		curl -iE "$${CERT_PATH}" \
			-X DELETE \
			-H "x-ms-version: 2015-04-01" \
		https://management.core.windows.net/$(SUBS_ID)/services/extensions/$(EXT_NS)/$(EXT_NAME)/$${VERSION} && \
		echo "\n\nUnregistering (deleting) version successful if request above was 202 Accepted. Watch for that operation ID to verify."

.PHONY: clean bundle binary publish test unregisterversion deleteversion listversions replicationstatus slice2 slice3 slice4

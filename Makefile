BIN=docker-extension
BINDIR=bin
BUNDLE=docker-extension.zip
BUNDLEDIR=bundle

bundle: clean binary
	@mkdir -p $(BUNDLEDIR)
	zip ./$(BUNDLEDIR)/$(BUNDLE) ./$(BINDIR)/$(BIN)
	zip -j ./$(BUNDLEDIR)/$(BUNDLE) ./metadata/HandlerManifest.json
	zip -j ./$(BUNDLEDIR)/$(BUNDLE) ./metadata/manifest.xml
	zip ./$(BUNDLEDIR)/$(BUNDLE) ./scripts/run-in-background.sh
	@echo "OK: Use $(BUNDLEDIR)/$(BUNDLE) to publish the extension."
binary:
	if [ -z "$$GOPATH" ]; then echo "GOPATH is not set"; exit 1; fi
	GOOS=linux GOARCH=amd64 go build -v -o $(BINDIR)/$(BIN) . 
test:
	if [ -z "$$GOPATH" ]; then echo "GOPATH is not set"; exit 1; fi
	go test ./... -test.v
clean:
	rm -rf "$(BUNDLEDIR)"
	rm -rf "$(BINDIR)"

.PHONY: clean bundle binary test

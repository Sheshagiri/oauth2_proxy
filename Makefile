include .env
BINARY := oauth2_proxy
VERSION := $(shell git describe --always --long --dirty --tags 2>/dev/null || echo "undefined")
.NOTPARALLEL:

.PHONY: all
all: dep lint $(BINARY)

.PHONY: clean
clean:
	rm -rf release
	rm -f $(BINARY)

.PHONY: distclean
distclean: clean
	rm -rf vendor

BIN_DIR := $(GOPATH)/bin
GOMETALINTER := $(BIN_DIR)/gometalinter

$(GOMETALINTER):
	$(GO) get -u github.com/alecthomas/gometalinter
	gometalinter --install %> /dev/null

.PHONY: lint
lint: $(GOMETALINTER)
	$(GOMETALINTER) --vendor --disable-all \
		--enable=vet \
		--enable=vetshadow \
		--enable=golint \
		--enable=ineffassign \
		--enable=goconst \
		--enable=deadcode \
		--enable=gofmt \
		--enable=goimports \
		--tests ./...

.PHONY: dep
dep:
	$(DEP) ensure --vendor-only

.PHONY: build
build: clean $(BINARY)

$(BINARY):
	$(GO) build -ldflags="-X main.VERSION=${VERSION}" -o $(BINARY) github.com/pusher/oauth2_proxy

.PHONY: test
test: dep lint
	$(GO) test -v -race $(go list ./... | grep -v /vendor/)

.PHONY: docker-build
docker-build:
	$(docker) build -t quay.io/sheshagiri0/$(BINARY):$(VERSION) .

.PHONY: docker-push
docker-push: docker-build
	$(docker) push quay.io/sheshagiri0/$(BINARY):$(VERSION)

.PHONY: release
release: lint test
	mkdir release
	GOOS=darwin GOARCH=amd64 go build -ldflags="-X main.VERSION=${VERSION}" -o release/$(BINARY)-darwin-amd64 github.com/pusher/oauth2_proxy
	GOOS=linux GOARCH=amd64 go build -ldflags="-X main.VERSION=${VERSION}" -o release/$(BINARY)-linux-amd64 github.com/pusher/oauth2_proxy
	GOOS=windows GOARCH=amd64 go build -ldflags="-X main.VERSION=${VERSION}" -o release/$(BINARY)-windows-amd64 github.com/pusher/oauth2_proxy
	shasum -a 256 release/$(BINARY)-darwin-amd64 > release/$(BINARY)-darwin-amd64-sha256sum.txt
	shasum -a 256 release/$(BINARY)-linux-amd64 > release/$(BINARY)-linux-amd64-sha256sum.txt
	shasum -a 256 release/$(BINARY)-windows-amd64 > release/$(BINARY)-windows-amd64-sha256sum.txt
	tar -cvf release/$(BINARY)-$(VERSION).darwin-amd64.$(GO_VERSION).tar.gz release/$(BINARY)-darwin-amd64
	tar -cvf release/$(BINARY)-$(VERSION).linux-amd64.$(GO_VERSION).tar.gz release/$(BINARY)-linux-amd64
	tar -cvf release/$(BINARY)-$(VERSION).windows-amd64.$(GO_VERSION).tar.gz release/$(BINARY)-windows-amd64

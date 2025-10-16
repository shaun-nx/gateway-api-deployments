# Kubernetes Gateway API Example Makefile
# Controller recommendation: NGINX Gateway Fabric (NGF)
# Ensure Gateway API CRDs and NGF are installed, and a GatewayClass named "nginx" exists.

.DEFAULT_GOAL := help

KUBECTL ?= kubectl
CURL ?= curl
OPENSSL ?= openssl

## help: Show available commands
.PHONY: help
help:
	@echo "Gateway API example deployments (NGINX Gateway Fabric)"
	@echo ""
	@echo "Basic (cafe-style routing):"
	@echo "  make deploy-basic        # Apply manifests"
	@echo "  make test-basic          # Curl http://basic.127.0.0.1.nip.io/ (routes to coffee)"
	@echo "  make test-basic-coffee   # Curl http://basic.127.0.0.1.nip.io/coffee"
	@echo "  make test-basic-tea      # Curl http://basic.127.0.0.1.nip.io/tea"
	@echo "  make undeploy-basic      # Delete manifests"
	@echo ""
	@echo "Cross-namespace routing:"
	@echo "  make deploy-crossns      # Apply manifests"
	@echo "  make test-crossns        # Curl http://crossns.127.0.0.1.nip.io/"
	@echo "  make undeploy-crossns    # Delete manifests"
	@echo ""
	@echo "Advanced routing (method and header matching):"
	@echo "  make deploy-advanced     # Apply manifests"
	@echo "  make test-advanced-get   # Curl GET http://advanced.127.0.0.1.nip.io/"
	@echo "  make test-advanced-post  # Curl POST http://advanced.127.0.0.1.nip.io/"
	@echo "  make test-advanced-header# Curl with X-Use: v2 header to '/'"
	@echo "  make undeploy-advanced   # Delete manifests"
	@echo ""
	@echo "Traffic splitting (weighted backends):"
	@echo "  make deploy-traffic      # Apply manifests"
	@echo "  make test-traffic        # Issue 20 requests and print server info"
	@echo "  make undeploy-traffic    # Delete manifests"
	@echo ""
	@echo "Request header filter (RequestHeaderModifier):"
	@echo "  make deploy-reqhdr       # Apply manifests"
	@echo "  make test-reqhdr         # Curl and grep for X-From-Gateway header"
	@echo "  make undeploy-reqhdr     # Delete manifests"
	@echo ""
	@echo "Response header filter (ResponseHeaderModifier):"
	@echo "  make deploy-resphdr      # Apply manifests"
	@echo "  make test-resphdr        # Curl -I and grep for X-Powered-By header"
	@echo "  make undeploy-resphdr    # Delete manifests"
	@echo ""
	@echo "gRPC routing (TLS, GRPCRoute):"
	@echo "  make deploy-grpc         # Generate cert, create secret, apply manifests"
	@echo "  make test-grpc-list      # Use grpcurl to list services via TLS"
	@echo "  make undeploy-grpc       # Delete manifests and TLS secret"
	@echo ""
	@echo "Utilities:"
	@echo "  make print-gatewayclasses# Show GatewayClasses"
	@echo "  make print-gateways      # Show all Gateways"
	@echo "  make print-httproutes    # Show all HTTPRoutes"
	@echo "  make clean               # Delete all example resources"
	@echo ""
	@echo "Note: Ensure Gateway API CRDs and the NGINX Gateway Fabric controller are installed."
	@echo "      The manifests use gatewayClassName=nginx. Change if your controller uses a different class name."

# Utility commands
.PHONY: print-gatewayclasses
print-gatewayclasses: ## List GatewayClasses
	$(KUBECTL) get gatewayclasses

.PHONY: print-gateways
print-gateways: ## List Gateways in all namespaces
	$(KUBECTL) get gateways -A

.PHONY: print-httproutes
print-httproutes: ## List HTTPRoutes in all namespaces
	$(KUBECTL) get httproutes -A

###############################################################################
# 0) Basic (cafe-style routing)
###############################################################################
.PHONY: deploy-basic
deploy-basic: ## Deploy basic cafe-style example
	$(KUBECTL) apply -f examples/basic-example/manifest.yaml

.PHONY: test-basic
test-basic: ## Test basic root route (routes to coffee)
	$(CURL) -sS http://basic.127.0.0.1.nip.io/ | head -n 20

.PHONY: test-basic-coffee
test-basic-coffee: ## Test /coffee route
	$(CURL) -sS http://basic.127.0.0.1.nip.io/coffee | head -n 20

.PHONY: test-basic-tea
test-basic-tea: ## Test /tea route
	$(CURL) -sS http://basic.127.0.0.1.nip.io/tea | head -n 20

.PHONY: undeploy-basic
undeploy-basic: ## Undeploy basic cafe-style example
	-$(KUBECTL) delete -f examples/basic-example/manifest.yaml --ignore-not-found

###############################################################################
# 1) Cross-namespace routing (unique to Gateway API)
###############################################################################
.PHONY: deploy-crossns
deploy-crossns: ## Deploy cross-namespace routing example
	$(KUBECTL) apply -f examples/cross-namespace/manifest.yaml

.PHONY: test-crossns
test-crossns: ## Test cross-namespace routing (prints top of HTML response)
	$(CURL) -sS http://crossns.127.0.0.1.nip.io/ | head -n 20

.PHONY: undeploy-crossns
undeploy-crossns: ## Undeploy cross-namespace routing example
	-$(KUBECTL) delete -f examples/cross-namespace/manifest.yaml --ignore-not-found

###############################################################################
# 2) Advanced routing: method and header matching (spec-native)
###############################################################################
.PHONY: deploy-advanced
deploy-advanced: ## Deploy advanced routing example
	$(KUBECTL) apply -f examples/advanced-routing/manifest.yaml

.PHONY: test-advanced-get
test-advanced-get: ## Test GET / routes to v1
	$(CURL) -sS http://advanced.127.0.0.1.nip.io/ | head -n 20

.PHONY: test-advanced-post
test-advanced-post: ## Test POST / routes to v2
	$(CURL) -sS -X POST http://advanced.127.0.0.1.nip.io/ | head -n 20

.PHONY: test-advanced-header
test-advanced-header: ## Test GET / with header X-Use: v2 routes to v2
	$(CURL) -sS -H "X-Use: v2" http://advanced.127.0.0.1.nip.io/ | head -n 20

.PHONY: undeploy-advanced
undeploy-advanced: ## Undeploy advanced routing example
	-$(KUBECTL) delete -f examples/advanced-routing/manifest.yaml --ignore-not-found

###############################################################################
# 3) Traffic splitting (weighted backends)
###############################################################################
.PHONY: deploy-traffic
deploy-traffic: ## Deploy traffic splitting example
	$(KUBECTL) apply -f examples/traffic-splitting/manifest.yaml

.PHONY: test-traffic
test-traffic: ## Test traffic splitting (runs multiple requests and prints server pod names)
	@echo "Running 20 requests against traffic.127.0.0.1.nip.io..."
	@for i in $$(seq 1 20); do \
		$(CURL) -sS http://traffic.127.0.0.1.nip.io/ | grep -E 'Server name|Server address' | head -n 1; \
	done

.PHONY: undeploy-traffic
undeploy-traffic: ## Undeploy traffic splitting example
	-$(KUBECTL) delete -f examples/traffic-splitting/manifest.yaml --ignore-not-found

###############################################################################
# 4) Request header filter (RequestHeaderModifier)
###############################################################################
.PHONY: deploy-reqhdr
deploy-reqhdr: ## Deploy request header filter example
	$(KUBECTL) apply -f examples/http-request-header-filter/manifest.yaml

.PHONY: test-reqhdr
test-reqhdr: ## Test request header filter (greps for injected header)
	$(CURL) -sS http://reqhdr.127.0.0.1.nip.io/ | grep -i "X-From-Gateway"

.PHONY: undeploy-reqhdr
undeploy-reqhdr: ## Undeploy request header filter example
	-$(KUBECTL) delete -f examples/http-request-header-filter/manifest.yaml --ignore-not-found

###############################################################################
# 5) Response header filter (ResponseHeaderModifier)
###############################################################################
.PHONY: deploy-resphdr
deploy-resphdr: ## Deploy response header filter example
	$(KUBECTL) apply -f examples/http-response-header-filter/manifest.yaml

.PHONY: test-resphdr
test-resphdr: ## Test response header filter (checks response headers)
	$(CURL) -sSI http://resphdr.127.0.0.1.nip.io/ | grep -i "X-Powered-By"

.PHONY: undeploy-resphdr
undeploy-resphdr: ## Undeploy response header filter example
	-$(KUBECTL) delete -f examples/http-response-header-filter/manifest.yaml --ignore-not-found

###############################################################################
# 6) gRPC routing (TLS, GRPCRoute)
###############################################################################
.PHONY: grpc-cert
grpc-cert: ## Generate self-signed cert and create TLS secret for gRPC
	@mkdir -p certs/grpc
	$(OPENSSL) req -x509 -nodes -newkey rsa:2048 \
		-keyout certs/grpc/tls.key \
		-out certs/grpc/tls.crt \
		-days 365 \
		-subj "/CN=grpc.127.0.0.1.nip.io/O=Example"
	# Ensure namespace exists
	$(KUBECTL) create namespace gateway-grpc-example --dry-run=client -o yaml | $(KUBECTL) apply -f -
	# Create or update the TLS secret
	$(KUBECTL) -n gateway-grpc-example create secret tls grpc-tls \
		--cert=certs/grpc/tls.crt --key=certs/grpc/tls.key \
		--dry-run=client -o yaml | $(KUBECTL) apply -f -

.PHONY: deploy-grpc
deploy-grpc: grpc-cert ## Deploy gRPC routing example
	$(KUBECTL) apply -f examples/grpc-routing/manifest.yaml

.PHONY: test-grpc-list
test-grpc-list: ## Test gRPC routing using grpcurl service listing (TLS, ignore self-signed)
	grpcurl -k grpc.127.0.0.1.nip.io:443 list | head -n 20

.PHONY: undeploy-grpc
undeploy-grpc: ## Undeploy gRPC routing example and delete TLS secret
	-$(KUBECTL) delete -f examples/grpc-routing/manifest.yaml --ignore-not-found
	-$(KUBECTL) -n gateway-grpc-example delete secret grpc-tls --ignore-not-found

###############################################################################
# Clean up everything
###############################################################################
.PHONY: clean
clean: ## Delete all example resources
	$(MAKE) undeploy-basic undeploy-crossns undeploy-advanced undeploy-traffic undeploy-reqhdr undeploy-resphdr undeploy-grpc
	- rm -rf certs/grpc
	@echo "Cleaned all examples."

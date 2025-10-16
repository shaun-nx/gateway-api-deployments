Gateway API Deployment Examples
================================

This repository provides example Kubernetes manifests that demonstrate using the Kubernetes Gateway API as the entrypoint to a cluster, focusing on capabilities that are unique to the Gateway API (or available as first-class, portable features in the spec) rather than controller-specific Ingress annotations.

Each example deploys a simple NGINX “Hello world” app (nginxdemos/hello) and exposes it via a Gateway and HTTPRoute. A Makefile is provided with deploy, test, and cleanup commands for each example.

Unique capabilities showcased
-----------------------------

- Cross-namespace routing with explicit authorization via ReferenceGrant.
- Rich request matching (method and header) defined in the Gateway API spec.
- Portable filters for request and response header manipulation.
- Native weighted traffic splitting across multiple backends.

Prerequisites
-------------

- A Kubernetes cluster (kind, k3d, minikube, GKE, EKS, AKS, etc.)
- `kubectl` configured to point at your cluster
- Gateway API CRDs and a Gateway controller installed
  - Recommendation: NGINX Gateway Fabric (NGF). Ensure a `GatewayClass` named `nginx` exists.
  - NGF repo: https://github.com/nginx/nginx-gateway-fabric
- Tools: `curl`, `openssl`, and `grpcurl` (used by the Makefile; gRPC example testing)
- Hostname resolution to your Gateway endpoint:
  - The manifests use `*.127.0.0.1.nip.io` hostnames, which resolve to 127.0.0.1. Ensure your controller’s data plane is reachable at localhost:80 and localhost:443 (or update hosts to match your setup).

Tip: If your Gateway is exposed via a LoadBalancer/NodePort with a different IP, change the hostname values in the manifests to match that IP using nip.io (e.g., `crossns.<your-ip>.nip.io`), or add local DNS entries.

Quickstart
----------

- Show all commands: `make help`

Utility commands:
- List GatewayClasses: `make print-gatewayclasses`
- List Gateways: `make print-gateways`
- List HTTPRoutes: `make print-httproutes`
- List GRPCRoutes: `make print-grpcroutes`

Examples and commands
---------------------

0) Basic example (cafe-style routing)
- Manifest: `examples/basic-example/manifest.yaml`
- Namespace: `gateway-basic-example`
- Host: `basic.127.0.0.1.nip.io`
- Description:
  - Routes `/coffee` to Service `coffee`, `/tea` to Service `tea`, and `/` to `coffee`.
- Commands:
  - Deploy: `make deploy-basic`
  - Test root: `make test-basic`
    - Equivalent: `curl -sS http://basic.127.0.0.1.nip.io/ | head -n 20`
  - Test coffee: `make test-basic-coffee`
    - Equivalent: `curl -sS http://basic.127.0.0.1.nip.io/coffee | head -n 20`
  - Test tea: `make test-basic-tea`
    - Equivalent: `curl -sS http://basic.127.0.0.1.nip.io/tea | head -n 20`
  - Undeploy: `make undeploy-basic`

1) Cross-namespace routing (unique to Gateway API)
- Manifest: `examples/cross-namespace/manifest.yaml`
- Namespaces:
  - Gateway + HTTPRoute: `gw-cross-ns`
  - App (Deployment + Service): `app-cross-ns`
- Host: `crossns.127.0.0.1.nip.io`
- Description:
  - A Gateway and HTTPRoute in `gw-cross-ns` route to a Service in `app-cross-ns`.
  - A `ReferenceGrant` in `app-cross-ns` explicitly allows the cross-namespace Service reference from the HTTPRoute in `gw-cross-ns`.
- Commands:
  - Deploy: `make deploy-crossns`
  - Test: `make test-crossns`
    - Equivalent: `curl -sS http://crossns.127.0.0.1.nip.io/ | head -n 20`
  - Undeploy: `make undeploy-crossns`

2) Advanced routing: method and header matching (spec-native)
- Manifest: `examples/advanced-routing/manifest.yaml`
- Namespace: `gateway-advanced-example`
- Host: `advanced.127.0.0.1.nip.io`
- Description:
  - Uses HTTPRoute matches for HTTP method and a request header — features defined in the Gateway API spec.
  - GET `/` -> `hello-v1`; POST `/` -> `hello-v2`; GET `/` with header `X-Use: v2` -> `hello-v2`.
- Commands:
  - Deploy: `make deploy-advanced`
  - Test GET: `make test-advanced-get`
    - Equivalent: `curl -sS http://advanced.127.0.0.1.nip.io/ | head -n 20`
  - Test POST: `make test-advanced-post`
    - Equivalent: `curl -sS -X POST http://advanced.127.0.0.1.nip.io/ | head -n 20`
  - Test header: `make test-advanced-header`
    - Equivalent: `curl -sS -H "X-Use: v2" http://advanced.127.0.0.1.nip.io/ | head -n 20`
  - Undeploy: `make undeploy-advanced`

3) Traffic splitting (weighted backends)
- Manifest: `examples/traffic-splitting/manifest.yaml`
- Namespace: `gateway-traffic-example`
- Host: `traffic.127.0.0.1.nip.io`
- Description:
  - Demonstrates weighted traffic splitting across multiple backends in a single rule: `hello-v1` (70%) and `hello-v2` (30%).
  - The test issues multiple requests and prints the responding server pod information shown by the hello app.
- Commands:
  - Deploy: `make deploy-traffic`
  - Test: `make test-traffic`
    - Issues 20 requests and prints server info lines from the HTML response.
  - Update weights: `make update-traffic-weights V1=80 V2=20`
    - Patches the HTTPRoute backendRefs weights for hello-v1 and hello-v2. Example: `make update-traffic-weights V1=90 V2=10`
  - Undeploy: `make undeploy-traffic`

4) Request header filter (RequestHeaderModifier)
- Manifest: `examples/http-request-header-filter/manifest.yaml`
- Namespace: `gateway-reqhdr-example`
- Host: `reqhdr.127.0.0.1.nip.io`
- Description:
  - Adds a request header `X-From-Gateway: true` via `RequestHeaderModifier` filter.
  - The `nginxdemos/hello` app echoes request headers in the HTML response; the test greps for the injected header.
- Commands:
  - Deploy: `make deploy-reqhdr`
  - Test: `make test-reqhdr`
    - Equivalent: `curl -sS http://reqhdr.127.0.0.1.nip.io/ | grep -i "X-From-Gateway"`
  - Undeploy: `make undeploy-reqhdr`

5) Response header filter (ResponseHeaderModifier)
- Manifest: `examples/http-response-header-filter/manifest.yaml`
- Namespace: `gateway-resphdr-example`
- Host: `resphdr.127.0.0.1.nip.io`
- Description:
  - Adds a response header `X-Powered-By: GatewayAPI` via `ResponseHeaderModifier` filter.
  - The test reads response headers with `curl -I` and greps for the header.
- Commands:
  - Deploy: `make deploy-resphdr`
  - Test: `make test-resphdr`
    - Equivalent: `curl -sSI http://resphdr.127.0.0.1.nip.io/ | grep -i "X-Powered-By"`
  - Undeploy: `make undeploy-resphdr`

6) gRPC routing (TLS, GRPCRoute)
- Manifest: `examples/grpc-routing/manifest.yaml`
- Namespace: `gateway-grpc-example`
- Host: `grpc.127.0.0.1.nip.io`
- Description:
  - Gateway HTTPS listener terminates TLS and forwards to `grpcbin` Service over plaintext gRPC.
  - Uses GRPCRoute to route gRPC traffic to the backend service.
- Commands:
  - Deploy: `make deploy-grpc` (generates self-signed cert and creates TLS secret `grpc-tls`)
  - Test list services: `make test-grpc-list`
    - Equivalent: `grpcurl -k grpc.127.0.0.1.nip.io:443 list | head -n 20`
  - Undeploy: `make undeploy-grpc` (deletes manifest and TLS secret)

Cleanup
-------

- Delete all example resources: `make clean`

Testing notes
-------------

- The `nginxdemos/hello` app returns:
  - HTML including request headers (useful for verifying `RequestHeaderModifier`).
  - The server name/address lines that include pod details (useful to distinguish v1 vs v2 backends for traffic splitting).
- Expect approximate distributions for weighted traffic (e.g., ~70/30 over multiple requests).

Omitted example categories
--------------------------

Per request, this repository omits examples related to:
- client-settings-policy
- externalname-service
- helm
- snippets-filter
- upstream-settings-policy

Troubleshooting
---------------

- Verify your Gateway controller and class:
  - `kubectl get gatewayclasses`
  - `kubectl get pods -A | grep -i nginx-gateway`
- Inspect Gateway/HTTPRoute status:
  - `kubectl get gateways,httproutes,grpcroutes -A`
  - `kubectl describe httproute -n <ns> <name>`
- Check that the Gateway data plane is reachable at the host/port you are using (nip.io hostnames assume 127.0.0.1).
- Cross-namespace routing:
  - Ensure the `ReferenceGrant` exists in the backend Service’s namespace and authorizes from the correct HTTPRoute namespace.
- Header filters:
  - Confirm your controller supports `RequestHeaderModifier`/`ResponseHeaderModifier` filters (NGF does).

References
----------

- Gateway API: https://gateway-api.sigs.k8s.io/
- NGINX Gateway Fabric examples (reference only; excluded categories per request):
  - https://github.com/nginx/nginx-gateway-fabric/tree/main/examples

License
-------

Apache-2.0

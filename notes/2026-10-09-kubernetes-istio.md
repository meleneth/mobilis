# Kubernetes and Istio vertical slice

Mobilis now carries Kubernetes deployment intent alongside the normal config graph.
The project name is the existing argument to `Mobilis::DSL.generate`, never a second declaration.
The new example is `scripts/21_kubernetes_initial.rb`; the existing OTEL examples are unchanged.

```ruby
deploy_kubernetes "*.deva.station" do
  istio do
    expose "app", root: true
    expose "jaeger"
    expose "grafana"
  end
end
```

The deployment uses the existing development/test/production realized environments,
with deployment names dev/test/prod. For `initial`, namespaces are `initial-dev`,
`initial-test`, and `initial-prod`. Hosts are project-first and flat beneath the
respective environment domain:

| Environment | Root | Jaeger | Grafana |
| --- | --- | --- | --- |
| dev | initial.dev.deva.station | initial-jaeger.dev.deva.station | initial-grafana.dev.deva.station |
| test | initial.test.deva.station | initial-jaeger.test.deva.station | initial-grafana.test.deva.station |
| prod | initial.prod.deva.station | initial-jaeger.prod.deva.station | initial-grafana.prod.deva.station |

All services use ClusterIP discovery. Compose published ports never imply external
Kubernetes routes. Only explicit Istio exposures generate routing objects.
The Istio gateway is the existing Devastation ingress gateway. Mobilis generates
HTTP routes; Devastation owns resolver configuration and edge TLS. Istio's internal
[Gateway semantics](https://istio.io/latest/docs/reference/config/networking/gateway/)
are not part of the public DSL.

## Generate and deploy

Generation retains the usual Compose output and existing Rails builder/plugins.
It adds `kubernetes/{dev,test,prod}/resources.yml`, `builds.json`, `universe.json`,
and an executable `deploy-kubernetes`. Kubernetes output is written after plugin
hooks so application files and instrumentation are included in subsequent builds.
No cluster mutation happens during generation.

From a working directory where replacing `generate/` is intentional:

```sh
bundle exec ruby -Ilib scripts/21_kubernetes_initial.rb
cd generate
./deploy-kubernetes dev
```

The helper defaults to `kind-devastation`, checks Istio, and checks namespace
ownership and route hostname collisions before building. It uses the existing
realized build contexts, Dockerfiles, args and target, tags application images as
`registry.deva.station/initial/app:dev`, and pushes them to the registry that
Devastation configures and trusts in Kind. It applies the complete generated resources and waits for readiness. It does not
prune resources or restart existing workloads. Mobilis generates a project once;
subsequent changes and lifecycle operations belong to the artifact owner. An explicit
`MOBILIS_KUBE_CONTEXT` can select another context using the same runtime setup.

## Observe and verify

A root request produces a `demo.request` span and a structured log message. Rails
exports spans directly to the private Collector's Service. The Collector exports
to Jaeger. Prometheus scrapes the Collector and the demo's `/metrics` endpoint.
Alloy reads pod logs through the Kubernetes API, using a namespace-scoped ServiceAccount
and Role, and ships them to private Loki. Grafana provisions Jaeger, Prometheus,
and Loki data sources from the same generated configuration as Compose. Its local
demo credentials remain `admin` / `mobilis-admin`.

Run from the Mobilis repository after deployment:

```sh
MOBILIS_ARTIFACT_ROOT=/path/to/generated/project ruby scripts/kubernetes/verify.rb
```

The verifier checks all three public routes, traces in Jaeger, counters and logs
through Grafana's data source proxy, eight ClusterIP services in dev/test (eleven in prod, including Rails database fanout), and HTTP 404 for the
private infrastructure hostnames, including the database. It retries asynchronous telemetry delivery.
Before DNS is available, forward the existing gateway and set an address override:

```sh
kubectl --context kind-devastation -n istio-system port-forward service/istio-ingressgateway 18080:80
MOBILIS_GATEWAY_URL=http://127.0.0.1:18080 MOBILIS_ARTIFACT_ROOT=/path/to/generated/project ruby scripts/kubernetes/verify.rb
```

The override still sends the generated Host headers and exercises Istio routing.
It does not verify Devastation DNS or TLS.

## Scope and limits

This is a local deployment slice. Declared state uses PVCs in dev/prod and
emptyDir in test. See [storage and ownership](2026-10-09-kubernetes-storage.md)
for the verified durability boundary. Jaeger remains an in-memory trace backend.
There is no lifecycle policy, cluster provisioning, or alternate ingress layer. Existing local/demo environment values are reused.
No Kubernetes Secret system is introduced. Configuration uses file mounts; future
Vault-delivered files can use that same workload boundary.

Names are validated rather than silently rewritten. Service underscores retain
Mobilis's existing normalization. Projects remain exact DNS labels; derived
names must fit DNS limits. Generation checks cross-universe namespace and hostname
collisions; deployment checks existing cluster ownership and public routes.

Validation is covered by `spec/mobilis/kubernetes_spec.rb`, executable deployment
helper tests, and the opt-in live verifier. The normal suite remains
`bundle exec rspec`.

## Original live validation, 2026-10-09 (before durable storage)

Generated the new demo in an isolated `/tmp` directory and deployed `initial-dev`
to the local Devastation Kind cluster. The Rails image was built with its generated
Dockerfile and pushed to `registry.deva.station/initial/app:dev`; all seven
Deployments became ready. Rails keeps the generated image entrypoint and Thruster
startup, with an unprivileged 8080 listener behind Service port 80.

The end-to-end verifier passed through the existing Istio gateway using generated
Host headers: root returned the demo JSON, Jaeger contained `demo.request`, Grafana
queried the application counter and logs through its private data sources, all
seven Services were ClusterIP, and private infrastructure hostnames returned 404.
Initial verification used a gateway port-forward while resolver configuration was
being prepared. After DNS was configured, the same end-to-end verifier passed
directly through the generated hostnames without a port-forward. HTTPS was not
verified.

The complete RSpec suite passed with 232 examples, zero failures, and two existing
pending examples. The opt-in live RSpec check passed, and Standard passed for all
new Ruby files. Existing OTEL scripts had no diff.

# deepdive-gitops

Argo CD watches `apps/`. Each file there is one Application. Charts come from
upstream repos; only values live here.

```
bootstrap/   argo install values + the one manifest applied by hand
apps/        one Application per component (this is the only dir Argo watches)
values/      values files, referenced from apps/ via $values/values/<name>.yaml
manifests/   raw CRs the operators consume
```

## Order

```bash
git init && git add -A && git commit -m "scaffold" \
  && git remote add origin https://github.com/soolame/deepdive-gitops && git push -u origin main

minikube start --memory=9216 --cpus=6 --disk-size=40g \
  --driver=docker --registry-mirror=https://mirror.gcr.io \
  --addons=ingress,metrics-server

make chart-versions   # resolve TODO-PIN, paste the versions in, commit
make argocd
make check            # server-side dry-run everything
make bootstrap
make password
```

Second terminal, leave running: `minikube tunnel`

## Adding a component later

Drop one file in `apps/` and one in `values/`. That is the whole workflow.

## Unpinned by design

Every `targetRevision` says `TODO-PIN`. `make chart-versions` queries the real
repos and tells you what to write. Do not guess -- a wrong chart version fails
as an opaque Argo sync error.

Same for `manifests/redpanda/redpanda.yaml`: the Redpanda CR apiVersion has
moved between releases. `kubectl api-resources | grep redpanda` after the
operator is up, then fix it. `make check` catches this.

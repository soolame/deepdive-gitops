SHELL     := /bin/bash
ARGOCD_NS := argocd
DATA_NS   := data

.PHONY: help
help:
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) \
	  | awk 'BEGIN{FS=":.*?## "};{printf "  \033[36m%-16s\033[0m %s\n",$$1,$$2}'

.PHONY: chart-versions
chart-versions: ## Resolve the real version of every upstream chart
	@./scripts/chart-versions.sh

.PHONY: argocd
argocd: ## Install/upgrade Argo CD
	helm repo add argo https://argoproj.github.io/argo-helm
	helm repo update argo
	helm upgrade --install argocd argo/argo-cd -n $(ARGOCD_NS) --create-namespace \
	  -f bootstrap/argocd-values.yaml --wait

.PHONY: secrets
secrets: ## Create postgres-credentials (basic-auth type, required by CNPG)
	@kubectl get ns $(DATA_NS) >/dev/null 2>&1 || kubectl create ns $(DATA_NS)
	@kubectl -n $(DATA_NS) get secret postgres-credentials >/dev/null 2>&1 \
	  && echo "already exists" \
	  || kubectl -n $(DATA_NS) create secret generic postgres-credentials \
	       --type=kubernetes.io/basic-auth \
	       --from-literal=username=app \
	       --from-literal=password="$$(openssl rand -hex 16)"

.PHONY: bootstrap
bootstrap: secrets ## Apply the root Application
	kubectl apply -f bootstrap/root-app.yaml

.PHONY: check
check: ## Server-side dry-run every manifest against the live cluster
	@for f in apps/*.yaml manifests/*/*.yaml; do \
	  printf '%-40s ' "$$f"; \
	  kubectl apply --dry-run=server -f "$$f" >/dev/null 2>&1 \
	    && echo OK || echo "FAILED - kubectl apply --dry-run=server -f $$f"; \
	done

.PHONY: password
password: ## Argo CD admin password
	@kubectl -n $(ARGOCD_NS) get secret argocd-initial-admin-secret \
	  -o jsonpath='{.data.password}' | base64 -d; echo

.PHONY: status
status: ## App health + real memory use
	@kubectl -n $(ARGOCD_NS) get applications -o custom-columns=\
'NAME:.metadata.name,SYNC:.status.sync.status,HEALTH:.status.health.status'
	@echo; kubectl get pod -A | grep -Ev 'kube-system|Completed' || true
	@echo; kubectl top pod -A --sort-by=memory 2>/dev/null | head -15 || true

.PHONY: urls
urls: ## Ingress URLs (needs `minikube tunnel` running)
	@echo "Argo CD    http://argocd.127.0.0.1.nip.io"
	@echo "Kafka UI   http://kafka-ui.127.0.0.1.nip.io"

.PHONY: psql
psql: ## psql shell into postgres
	kubectl -n $(DATA_NS) exec -it postgres-0 -- psql -U app -d orders

.PHONY: nuke
nuke: ## Delete the data namespace (destructive)
	kubectl delete ns $(DATA_NS) --wait=true || true

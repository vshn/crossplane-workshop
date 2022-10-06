.PHONY: setup-cloudsql
setup-cloudsql: export KUBECONFIG = $(KIND_KUBECONFIG)
setup-cloudsql: local-install provider-gcp provider-sql
setup-cloudsql: ## install provider-gcp, composite, composition and claim
	kubectl apply -n crossplane-system -f crossplane/cloudsql/composite.yaml
	kubectl apply -n crossplane-system -f crossplane/cloudsql/composition.yaml
	sleep 5
	kubectl wait --for condition=Established customresourcedefinition.apiextensions.k8s.io/xclouspostgresqls.appcat.vshn.net --timeout 60s
	kubectl apply -f crossplane/cloudsql/claim.yaml

.PHONY: setup-stackgres
setup-stackgres: export KUBECONFIG = $(KIND_KUBECONFIG)
setup-stackgres: local-install provider-helm provider-kubernetes provider-sql install-stackgres
setup-stackgres: ## install provider-stackgres, composite, composition and claim
	kubectl apply -n crossplane-system -f crossplane/stackgres/composite.yaml
	kubectl apply -n crossplane-system -f crossplane/stackgres/composition.yaml
	sleep 5
	kubectl wait --for condition=Established customresourcedefinition.apiextensions.k8s.io/xpostgresqlinstances.appcat.vshn.net --timeout 60s
	kubectl apply -n crossplane-system -f crossplane/stackgres/claim.yaml

.PHONY: setup-terraform
setup-terraform: export KUBECONFIG = $(KIND_KUBECONFIG)
setup-terraform: local-install provider-terraform
setup-terraform: ## install provider-terraform, composite, composition and claim
	kubectl apply -n crossplane-system -f crossplane/terraform/composite.yaml
	kubectl apply -n crossplane-system -f crossplane/terraform/composition.yaml
	sleep 5
	kubectl wait --for condition=Established customresourcedefinition.apiextensions.k8s.io/xterraformpostgresqls.appcat.vshn.net --timeout 60s
	kubectl apply -f crossplane/terraform/claim.yaml

.PHONY: provider-gcp
provider-gcp: export KUBECONFIG = $(KIND_KUBECONFIG)
provider-gcp: $(kind_dir)/.credentials.yaml
provider-gcp:
	kubectl apply -n crossplane-system -f crossplane/provider-gcp/provider.yaml
	kubectl wait --for condition=Healthy provider.pkg.crossplane.io/provider-gcp --timeout 60s
	kubectl apply -n crossplane-system -f crossplane/provider-gcp/providerconfig.yaml

$(kind_dir)/.credentials.yaml:
	@if [ "$$GCP_CREDENTIALS" = "" ]; then echo "Environment variable GCP_CREDENTIALS not set"; exit 1; fi
	kubectl create secret generic --from-literal credentials.json="$$GCP_CREDENTIALS" -o yaml --dry-run=client workshop-provider-gcp > $@
	kubectl apply -n crossplane-system -f $@

.PHONY: provider-kubernetes
provider-kubernetes: export KUBECONFIG = $(KIND_KUBECONFIG)
provider-kubernetes:
	kubectl apply -n crossplane-system -f crossplane/provider-kubernetes/provider.yaml
	kubectl wait --for condition=Healthy provider.pkg.crossplane.io/provider-kubernetes --timeout 60s
	kubectl apply -n crossplane-system -f crossplane/provider-kubernetes/providerconfig.yaml
	kubectl create clusterrolebinding crossplane:provider-kubernetes-admin --clusterrole cluster-admin --serviceaccount crossplane-system:$$(kubectl get sa -n crossplane-system -o custom-columns=NAME:.metadata.name --no-headers | grep provider-kubernetes) || true

.PHONY: provider-helm
provider-helm: export KUBECONFIG = $(KIND_KUBECONFIG)
provider-helm:
	kubectl apply -n crossplane-system -f crossplane/provider-helm/provider.yaml
	kubectl wait --for condition=Healthy provider.pkg.crossplane.io/provider-helm --timeout 60s
	kubectl apply -n crossplane-system -f crossplane/provider-helm/providerconfig.yaml

.PHONY: provider-sql
provider-sql: export KUBECONFIG = $(KIND_KUBECONFIG)
provider-sql:
	kubectl apply -n crossplane-system -f crossplane/provider-sql
	kubectl wait --for condition=Healthy provider.pkg.crossplane.io/provider-sql --timeout 60s

.PHONY: clean-crossplane
clean-crossplane: export KUBECONFIG = $(KIND_KUBECONFIG)
clean-crossplane:
	for xrd in $$(kubectl get compositeresourcedefinitions.apiextensions.crossplane.io | grep -v NAME|cut -d " " -f1); do kubectl delete compositeresourcedefinitions.apiextensions.crossplane.io $$xrd; done
	for comp in $$(kubectl get compositions.apiextensions.crossplane.io | grep -v NAME|cut -d " " -f1); do kubectl delete compositions.apiextensions.crossplane.io $$comp; done
	for crd in $$(kubectl get crd | grep gcp|cut -d " " -f1); do kubectl delete crd $$crd; done
	for crd in $$(kubectl get crd | grep kubernetes|cut -d " " -f1); do kubectl delete crd $$crd; done
	for crd in $$(kubectl get crd | grep helm|cut -d " " -f1); do kubectl delete crd $$crd; done
	for crd in $$(kubectl get crd | grep tf|cut -d " " -f1); do kubectl delete crd $$crd; done
	for controllerconfig in $$(kubectl get controllerconfigs.pkg.crossplane.io | grep -v NAME |cut -d " " -f1); do kubectl delete controllerconfigs.pkg.crossplane.io $$controllerconfig; done
	for provider in $$(kubectl get providers.pkg.crossplane.io | grep -v NAME |cut -d " " -f1); do kubectl delete providers.pkg.crossplane.io $$provider; done
	for crd in $$(kubectl get crd | grep stackgres|cut -d " " -f1); do kubectl delete crd $$crd; done
	helm -n stackgres uninstall stackgres-operator || true
	rm -f $(stackgres_sentinel)

stackgres_sentinel = $(kind_dir)/stackgres-sentinel

install-stackgres: $(stackgres_sentinel) ## Setup the stackgres operator
$(stackgres_sentinel): export KUBECONFIG = $(KIND_KUBECONFIG)
$(stackgres_sentinel):
	kubectl create ns stackgres || true
	helm repo add stackgres-charts https://stackgres.io/downloads/stackgres-k8s/stackgres/helm/
	helm install --namespace stackgres stackgres-operator \
	stackgres-charts/stackgres-operator
	@touch $@

.PHONY: provider-terraform
provider-terraform: export KUBECONFIG = $(KIND_KUBECONFIG)
provider-terraform: $(kind_dir)/.credentials.yaml
provider-terraform:
	kubectl apply -n crossplane-system -f crossplane/provider-terraform/provider.yaml
	kubectl wait --for condition=Healthy provider.pkg.crossplane.io/provider-terraform --timeout 60s
	kubectl apply -n crossplane-system -f crossplane/provider-terraform/providerconfig.yaml

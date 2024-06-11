#!/usr/bin/env bash
# It's recommended to source this script

## The first argument passed (if any) is the name of the cluster
cluster_name=${1:-sbcl}

if [[ $0 = ${BASH_SOURCE[0]} ]]
then
    echo -e "\a\nIt's recommended to source this script!\n"
fi

if [[ $(pwd) =~ ShuffleBench/kubernetes$ ]]
then
    echo "Running in ShuffleBench/kubernetes, good."
    if [[ ! -d "$(pwd)/theodolite" ]]
    then
        echo "Please also clone theodolite into ShuffleBench/kubernetes folder"
        echo "e.g.: git clone https://github.com/cau-se/theodolite.git"
        if [[ $0 = ${BASH_SOURCE[0]} ]]; then
            exit 1
        else
            return 1
        fi
    fi
else
    echo "Please invoke this script from ShuffleBench/kubernetes"
    echo "If necessary, clone ShuffleBench from https://github.com/dynatrace-research/ShuffleBench.git"
    if [[ $0 = ${BASH_SOURCE[0]} ]]; then
        exit 1
    else
        return 1
    fi
fi

base_path=$(dirname ${BASH_SOURCE[0]})

## Uncomment export statement if using HPA own CPU metric per container (instead  of per pod):
## metrics.type = ContainerResource
# export KUBE_FEATURE_GATES=HPAContainerMetrics=true

minikube start --nodes 1 -p ${cluster_name} --addons metrics-server dashboard storage-provisioner default-storageclass --cni calico --cpus no-limit --memory no-limit --wait=all

kubectl wait --all --timeout=10m --for=condition=Ready pods

minikube addons -p ${cluster_name} enable dashboard

kubectl label nodes ${cluster_name} type=infra
# kubectl label nodes ${cluster_name}-m02 type=sut
# kubectl label nodes ${cluster_name}-m03 type=kafka


kubectl apply -f ${base_path}/rbac-storage-provisioner.yaml
kubectl apply -f ${base_path}/kafka-storage-class.yaml


helm dependencies update theodolite/helm

helm install theodolite theodolite/helm -f https://raw.githubusercontent.com/cau-se/theodolite/main/helm/preconfigs/extended-metrics.yaml -f ${base_path}/values-theodolite-local.yaml

kubectl wait --all --timeout=15m --for=condition=Ready pods

# Add a few more plots to the dashboard in Grafana
kubectl replace -f ${base_path}/dashboard-config-map.yaml
kubectl scale deployment theodolite-grafana --replicas=0 && kubectl scale deployment theodolite-grafana --replicas=1

helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
helm install prom-adapt prometheus-community/prometheus-adapter -f ${base_path}/values-prom-adapt.yaml


kubectl delete configmaps --ignore-not-found=true shufflebench-resources-load-generator shufflebench-resources-latency-exporter shufflebench-resources-kstreams
kubectl create configmap shufflebench-resources-load-generator --from-file ${base_path}/shuffle-load-generator/
kubectl create configmap shufflebench-resources-latency-exporter --from-file ./shuffle-latency-exporter/
kubectl create configmap shufflebench-resources-kstreams --from-file ${base_path}/shuffle-kstreams/

kubectl apply -f ${base_path}/theodolite-benchmark-kstreams-simple.yaml

## The execution should be started separately (e.g. by using the execute-banchmark function) 
# kubectl apply -f ${base_path}/kstreams-baseline-atp.yaml

# kubectl autoscale deployment shuffle-kstreams --cpu-percent=70 --min=1 --max=10

# kubectl apply -f ${base_path}/hpa-sb-container-cpu.yaml

kubectl apply -f ${base_path}/hpa-authorization.yaml
kubectl apply -f ${base_path}/hpa-custom.yaml

execute-benchmark() {
  kubectl delete --ignore-not-found=true execution shufflebench-kstreams-baseline-atp
  kubectl apply -f ${base_path}/kstreams-baseline-atp.yaml
}

copy-results() {
  # The first argument is the name of the local output folder
  output_path=${1:-results}
  kubectl cp $(kubectl get pod -l app=theodolite -o jsonpath="{.items[0].metadata.name}"):results $output_path -c results-access
}


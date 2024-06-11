#!/usr/bin/env bash

## The optional first argument is the cluster name.
cluster_name=${1:-sbcl}

kubectl delete --ignore-not-found=true execution shufflebench-kstreams-baseline-atp
kubectl delete --ignore-not-found=true  benchmark shuffle-kstreams
kubectl delete configmaps --ignore-not-found=true shufflebench-resources-load-generator shufflebench-resources-latency-exporter shufflebench-resources-kstreams shufflebench-resources-hzcast shufflebench-resources-flink shufflebench-resources-spark
helm uninstall prom-adapt
helm uninstall theodolite
sleep 20s
minikube delete -p $cluster_name


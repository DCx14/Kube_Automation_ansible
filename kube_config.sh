#!/bin/bash
cd /root
# Installation CNI Antrea
helm repo add antrea https://charts.antrea.io
helm repo update
wget https://raw.githubusercontent.com/antrea-io/antrea/main/build/charts/antrea/values.yaml -O helm-values/antrea-values.yaml
helm upgrade --install --atomic antrea antrea/antrea -f helm-values/antrea-values.yaml --namespace kube-system
sleep 30
# installation rook release
helm repo add rook-release https://charts.rook.io/release
helm upgrade --install --atomic --create-namespace --namespace rook-ceph rook-ceph rook-release/rook-ceph -f helm-values/rook-operator-values.yaml --version 1.14.2
# Installation rook cluster
#wget https://pastebin.com/raw/gSVcuEuj -O helm-values/rook-cluster-values.yaml
helm upgrade --install --atomic --namespace rook-ceph rook-ceph-cluster rook-release/rook-ceph-cluster -f helm-values/rook-cluster-values.yaml --version 1.14.2
# Activation du dashboard en LB optional
#git clone https://github.com/rook/rook.git
#kubectl apply -f /root/rook/deploy/examples/dashboard-loadbalancer.yaml
sleep 30
#Configuration ceph
# Initialisation du compteur
count=0
# Boucle for pour vérifier si la variable POD_NAME commence par "rook-ceph-tools-" et $status est égal à "running"
for (( ; ; )); do
    POD_NAME=$(kubectl get pods -n rook-ceph | grep "rook-ceph-tools-" | awk '{print $1}')
    status=$(kubectl get pod $POD_NAME -n rook-ceph -o=jsonpath='{.status.phase}' 2>/dev/null)
    if [[ $POD_NAME == "rook-ceph-tools-"* && $status == "Running" ]]; then
       sleep 2
       kubectl exec -it --namespace=rook-ceph $POD_NAME -- bash -c  "ceph mgr module enable rook"
       kubectl exec -it --namespace=rook-ceph $POD_NAME -- bash -c  "ceph orch set backend rook"
       kubectl exec -it --namespace=rook-ceph $POD_NAME -- bash -c  "ceph device monitoring on"
#       kubectl exec -it --namespace=rook-ceph $POD_NAME -- bash -c  "ceph mgr module enable dashboard"
#      kubectl exec -it --namespace=rook-ceph $POD_NAME -- bash -c  "ceph dashboard feature disable dashboard"
        break
    else
        # Incrémentation du compteur
        ((count++))
        # Vérification si le compteur a atteint 120 (2 minutes)
        if [ $count -eq 120 ]; then
            echo "Le script s'est arrêté car les conditions n'ont pas été remplies après 2 minutes."
            exit 1
        fi
        # Attente de 1 seconde avant de vérifier à nouveau
	    echo "zob timer $POD_NAME & $status"
        sleep 1
    fi
done
# install metalb
kubectl label nodes --all node.kubernetes.io/exclude-from-external-load-balancers-
helm repo add metallb https://metallb.github.io/metallb
helm repo update
helm upgrade --install --atomic --create-namespace -n metallb-system metallb metallb/metallb -f helm-values/metallb-values.yaml --version 0.14.3
# configuration metallb
echo "configuration metallb"
cat << EOF > helm-values/metallb-config.yaml
apiVersion: metallb.io/v1beta2
kind: BGPPeer
metadata:
  name: bgp-peer
  namespace: metallb-system
spec:
  myASN: 64512
  peerASN: 64512
  peerAddress: 172.19.183.1
---
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: ip-pool
  namespace: metallb-system
spec:
  addresses:
  - $1
---
apiVersion: metallb.io/v1beta1
kind: BGPAdvertisement
metadata:
  name: bgp-advertisement
  namespace: metallb-system
spec:
  localPref: 50
EOF
kubectl apply -f helm-values/metallb-config.yaml
# COnfiguration prometheus
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
helm upgrade --install --atomic  -n monitoring --create-namespace kube-prometheus-stack prometheus-community/kube-prometheus-stack -f helm-values/kube-prometheus-stack-values.yaml
# modifier le monitoring
sed -i '/^monitoring:/,/enabled:/ { s/enabled: true/enabled: false/; }' helm-values/rook-operator-values.yaml
sed -i '/^monitoring:/,/createPrometheusRules:/ { s/enabled: false/enabled: true/; s/createPrometheusRules: false/createPrometheusRules: true/; }' helm-values/rook-cluster-values.yaml
helm upgrade --namespace rook-ceph rook-ceph rook-release/rook-ceph -f helm-values/rook-operator-values.yaml
helm upgrade --namespace rook-ceph rook-ceph-cluster --set operatorNamespace=rook-ceph rook-release/rook-ceph-cluster -f helm-values/rook-cluster-values.yaml
# install metric
wget https://raw.githubusercontent.com/kubernetes-sigs/metrics-server/master/charts/metrics-server/values.yaml -O helm-values/metrics-server-values.yaml
helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/
helm repo update
helm upgrade --install --atomic  -n monitoring metrics-server metrics-server/metrics-server -f helm-values/metrics-server-values.yaml
# zabbix
rpm -Uvh https://repo.zabbix.com/zabbix/6.4/rhel/8/x86_64/zabbix-release-6.4-1.el8.noarch.rpm
dnf -y install zabbix-agent2 zabbix-agent2-plugin-*
cat <<EOF | tee /etc/zabbix/zabbix_agent2.conf
PidFile=/var/run/zabbix/zabbix_agent2.pid
LogFile=/var/log/zabbix/zabbix_agent2.log
LogFileSize=0
Server=127.0.0.1
ServerActive=zabbix.septeo.fr
HostMetadata=linux lattes
Include=/etc/zabbix/zabbix_agent2.d/*.conf
ControlSocket=/tmp/agent.sock
Timeout=30
EOF
systemctl enable zabbix-agent2.service
systemctl start zabbix-agent2.service
helm upgrade --install --atomic --create-namespace --namespace rook-ceph rook-ceph rook-release/rook-ceph -f helm-values/rook-operator-values-true.yaml --version 1.14.2
#Configuration ceph 2 ou cas ou :)
# Initialisation du compteur
count=0
# Boucle for pour vérifier si la variable POD_NAME commence par "rook-ceph-tools-" et $status est égal à "running"
for (( ; ; )); do
    POD_NAME=$(kubectl get pods -n rook-ceph | grep "rook-ceph-tools-" | awk '{print $1}')
    status=$(kubectl get pod $POD_NAME -n rook-ceph -o=jsonpath='{.status.phase}' 2>/dev/null)
    if [[ $POD_NAME == "rook-ceph-tools-"* && $status == "Running" ]]; then
       sleep 2
       kubectl exec -it --namespace=rook-ceph $POD_NAME -- bash -c  "ceph mgr module enable rook"
       kubectl exec -it --namespace=rook-ceph $POD_NAME -- bash -c  "ceph orch set backend rook"
       kubectl exec -it --namespace=rook-ceph $POD_NAME -- bash -c  "ceph device monitoring on"
#       kubectl exec -it --namespace=rook-ceph $POD_NAME -- bash -c  "ceph mgr module enable dashboard"
#      kubectl exec -it --namespace=rook-ceph $POD_NAME -- bash -c  "ceph dashboard feature disable dashboard"
        break
    else
        # Incrémentation du compteur
        ((count++))
        # Vérification si le compteur a atteint 120 (2 minutes)
        if [ $count -eq 120 ]; then
            echo "Le script s'est arrêté car les conditions n'ont pas été remplies après 2 minutes."
            exit 1
        fi
        # Attente de 1 seconde avant de vérifier à nouveau
	    echo "zob timer $POD_NAME & $status"
        sleep 1
    fi
done

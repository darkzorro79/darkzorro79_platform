# Otus Kubernetes course

## HW-1 Kubernetes Intro

### Install

* kubectl 

https://kubernetes.io/docs/tasks/tools/install-kubectl/

* minicube

https://kubernetes.io/docs/tasks/tools/install-minikube/

* kind

https://kind.sigs.k8s.io/docs/user/quick-start/

* Web UI (Dashboard)

https://kubernetes.io/docs/tasks/access-application-cluster/web-ui-dashboard/

* Kubernetes CLI

https://k9scli.io/


### Minikube

#### Start

```
PS C:\Windows\system32> minikube start --cpus=4 --memory=8gb --disk-size=25gb --driver vmware
* minikube v1.26.1 на Microsoft Windows 10 Enterprise 10.0.19045 Build 19045
* Используется драйвер vmware на основе конфига пользователя
* Запускается control plane узел minikube в кластере minikube
* Creating vmware VM (CPUs=4, Memory=8192MB, Disk=25600MB) ...
* minikube 1.28.0 is available! Download it: https://github.com/kubernetes/minikube/releases/tag/v1.28.0
* To disable this notice, run: 'minikube config set WantUpdateNotification false'

* Подготавливается Kubernetes v1.24.3 на Docker 20.10.17 ...
  - Generating certificates and keys ...
  - Booting up control plane ...
  - Configuring RBAC rules ...
* Компоненты Kubernetes проверяются ...
  - Используется образ gcr.io/k8s-minikube/storage-provisioner:v5
* Включенные дополнения: storage-provisioner, default-storageclass
* Готово! kubectl настроен для использования кластера "minikube" и "default" пространства имён по умолчанию
```

#### Check config

```
PS C:\Windows\system32> kubectl cluster-info
Kubernetes control plane is running at https://192.168.136.17:8443
CoreDNS is running at https://192.168.136.17:8443/api/v1/namespaces/kube-system/services/kube-dns:dns/proxy

To further debug and diagnose cluster problems, use 'kubectl cluster-info dump'.


PS C:\Windows\system32> kubectl config view
apiVersion: v1
clusters:
- cluster:
    certificate-authority: C:\Users\DarkZorro\.minikube\ca.crt
    extensions:
    - extension:
        last-update: Mon, 26 Dec 2022 16:43:37 MSK
        provider: minikube.sigs.k8s.io
        version: v1.26.1
      name: cluster_info
    server: https://192.168.136.17:8443
  name: minikube
contexts:
- context:
    cluster: minikube
    extensions:
    - extension:
        last-update: Mon, 26 Dec 2022 16:43:37 MSK
        provider: minikube.sigs.k8s.io
        version: v1.26.1
      name: context_info
    namespace: default
    user: minikube
  name: minikube
current-context: minikube
kind: Config
preferences: {}
users:
- name: minikube
  user:
    client-certificate: C:\Users\DarkZorro\.minikube\profiles\minikube\client.crt
    client-key: C:\Users\DarkZorro\.minikube\profiles\minikube\client.key
	
```

#### Playing with k8s

* Connect to k8s and try delete containers. As we see they rise again.

```
PS C:\Windows\system32> minikube ssh
                         _             _
            _         _ ( )           ( )
  ___ ___  (_)  ___  (_)| |/')  _   _ | |_      __
/' _ ` _ `\| |/' _ `\| || , <  ( ) ( )| '_`\  /'__`\
| ( ) ( ) || || ( ) || || |\`\ | (_) || |_) )(  ___/
(_) (_) (_)(_)(_) (_)(_)(_) (_)`\___/'(_,__/'`\____)

$ docker ps
CONTAINER ID   IMAGE                  COMMAND                  CREATED         STATUS         PORTS     NAMES
96891025e363   6e38f40d628d           "/storage-provisioner"   4 minutes ago   Up 4 minutes             k8s_storage-provisioner_storage-provisioner_kube-system_1455f9b0-d74f-4acf-a1f9-5a60f90a14eb_1
1fe7385a38f5   a4ca41631cc7           "/coredns -conf /etc…"   5 minutes ago   Up 5 minutes             k8s_coredns_coredns-6d4b75cb6d-wbhzp_kube-system_38459578-57fa-49d3-a02e-b41bd7f0a27c_0
856a05b1f1e1   k8s.gcr.io/pause:3.6   "/pause"                 5 minutes ago   Up 5 minutes             k8s_POD_coredns-6d4b75cb6d-wbhzp_kube-system_38459578-57fa-49d3-a02e-b41bd7f0a27c_0
609ba8306b78   2ae1ba6417cb           "/usr/local/bin/kube…"   5 minutes ago   Up 5 minutes             k8s_kube-proxy_kube-proxy-v5ql5_kube-system_f7650fba-f138-4116-a4c4-124a13e1dcba_0
e68b5800cc89   k8s.gcr.io/pause:3.6   "/pause"                 5 minutes ago   Up 5 minutes             k8s_POD_kube-proxy-v5ql5_kube-system_f7650fba-f138-4116-a4c4-124a13e1dcba_0
06c59aa22882   k8s.gcr.io/pause:3.6   "/pause"                 5 minutes ago   Up 5 minutes             k8s_POD_storage-provisioner_kube-system_1455f9b0-d74f-4acf-a1f9-5a60f90a14eb_0
10158d97084b   aebe758cef4c           "etcd --advertise-cl…"   5 minutes ago   Up 5 minutes             k8s_etcd_etcd-minikube_kube-system_cb5e4580f7f0814d2e19d6b47346a376_0
2795be1d985e   k8s.gcr.io/pause:3.6   "/pause"                 5 minutes ago   Up 5 minutes             k8s_POD_etcd-minikube_kube-system_cb5e4580f7f0814d2e19d6b47346a376_0
2ea919d7bda0   d521dd763e2e           "kube-apiserver --ad…"   5 minutes ago   Up 5 minutes             k8s_kube-apiserver_kube-apiserver-minikube_kube-system_e3b1569d7430a678835c3ac15adbf72d_0
b9c9039a2dd1   3a5aa3a515f5           "kube-scheduler --au…"   5 minutes ago   Up 5 minutes             k8s_kube-scheduler_kube-scheduler-minikube_kube-system_2e95d5efbc70e877d20097c03ba4ff89_0
3d304cc341f5   586c112956df           "kube-controller-man…"   5 minutes ago   Up 5 minutes             k8s_kube-controller-manager_kube-controller-manager-minikube_kube-system_4f82078a5dfd579f16196dd9ef946750_0
0d6c4224fb41   k8s.gcr.io/pause:3.6   "/pause"                 5 minutes ago   Up 5 minutes             k8s_POD_kube-apiserver-minikube_kube-system_e3b1569d7430a678835c3ac15adbf72d_0
e94d2fa9b3e8   k8s.gcr.io/pause:3.6   "/pause"                 5 minutes ago   Up 5 minutes             k8s_POD_kube-scheduler-minikube_kube-system_2e95d5efbc70e877d20097c03ba4ff89_0
71982aa1a47c   k8s.gcr.io/pause:3.6   "/pause"                 5 minutes ago   Up 5 minutes             k8s_POD_kube-controller-manager-minikube_kube-system_4f82078a5dfd579f16196dd9ef946750_0

$ docker rm -f $(docker ps -a -q)
96891025e363
1fe7385a38f5
856a05b1f1e1
609ba8306b78
e68b5800cc89
ebaeac14f750
06c59aa22882
10158d97084b
2795be1d985e
2ea919d7bda0
b9c9039a2dd1
3d304cc341f5
0d6c4224fb41
e94d2fa9b3e8
71982aa1a47c
$ docker ps
CONTAINER ID   IMAGE                  COMMAND                  CREATED          STATUS          PORTS     NAMES
02abdbd9463e   6e38f40d628d           "/storage-provisioner"   15 seconds ago   Up 14 seconds             k8s_storage-provisioner_storage-provisioner_kube-system_1455f9b0-d74f-4acf-a1f9-5a60f90a14eb_2
a818c5c63def   a4ca41631cc7           "/coredns -conf /etc…"   15 seconds ago   Up 15 seconds             k8s_coredns_coredns-6d4b75cb6d-wbhzp_kube-system_38459578-57fa-49d3-a02e-b41bd7f0a27c_1
1938ccc6c9cc   586c112956df           "kube-controller-man…"   15 seconds ago   Up 14 seconds             k8s_kube-controller-manager_kube-controller-manager-minikube_kube-system_4f82078a5dfd579f16196dd9ef946750_1
33ddd1f33574   3a5aa3a515f5           "kube-scheduler --au…"   15 seconds ago   Up 14 seconds             k8s_kube-scheduler_kube-scheduler-minikube_kube-system_2e95d5efbc70e877d20097c03ba4ff89_1
53506efecd3a   aebe758cef4c           "etcd --advertise-cl…"   15 seconds ago   Up 14 seconds             k8s_etcd_etcd-minikube_kube-system_cb5e4580f7f0814d2e19d6b47346a376_1
4720244d9dd5   d521dd763e2e           "kube-apiserver --ad…"   15 seconds ago   Up 14 seconds             k8s_kube-apiserver_kube-apiserver-minikube_kube-system_e3b1569d7430a678835c3ac15adbf72d_1
b60019599857   2ae1ba6417cb           "/usr/local/bin/kube…"   15 seconds ago   Up 15 seconds             k8s_kube-proxy_kube-proxy-v5ql5_kube-system_f7650fba-f138-4116-a4c4-124a13e1dcba_1
33dd40dcb5b2   k8s.gcr.io/pause:3.6   "/pause"                 15 seconds ago   Up 15 seconds             k8s_POD_kube-controller-manager-minikube_kube-system_4f82078a5dfd579f16196dd9ef946750_0
5cd8f359cd77   k8s.gcr.io/pause:3.6   "/pause"                 15 seconds ago   Up 15 seconds             k8s_POD_etcd-minikube_kube-system_cb5e4580f7f0814d2e19d6b47346a376_0
42d9cbf71cba   k8s.gcr.io/pause:3.6   "/pause"                 15 seconds ago   Up 15 seconds             k8s_POD_kube-proxy-v5ql5_kube-system_f7650fba-f138-4116-a4c4-124a13e1dcba_0
8fe67a32f98a   k8s.gcr.io/pause:3.6   "/pause"                 15 seconds ago   Up 15 seconds             k8s_POD_storage-provisioner_kube-system_1455f9b0-d74f-4acf-a1f9-5a60f90a14eb_0
c9ccaa918734   k8s.gcr.io/pause:3.6   "/pause"                 15 seconds ago   Up 15 seconds             k8s_POD_coredns-6d4b75cb6d-wbhzp_kube-system_38459578-57fa-49d3-a02e-b41bd7f0a27c_0
16442d1bcfbd   k8s.gcr.io/pause:3.6   "/pause"                 15 seconds ago   Up 15 seconds             k8s_POD_kube-scheduler-minikube_kube-system_2e95d5efbc70e877d20097c03ba4ff89_0
83b9e88e986e   k8s.gcr.io/pause:3.6   "/pause"                 15 seconds ago   Up 15 seconds             k8s_POD_kube-apiserver-minikube_kube-system_e3b1569d7430a678835c3ac15adbf72d_0
```

* Status by kubernetes NS

```
PS C:\Windows\system32> kubectl get pods -n kube-system
NAME                               READY   STATUS    RESTARTS   AGE
coredns-6d4b75cb6d-wbhzp           1/1     Running   1          12m
etcd-minikube                      1/1     Running   1          12m
kube-apiserver-minikube            1/1     Running   1          12m
kube-controller-manager-minikube   1/1     Running   1          12m
kube-proxy-v5ql5                   1/1     Running   1          12m
kube-scheduler-minikube            1/1     Running   1          12m
storage-provisioner                1/1     Running   2          12m
```

* Delete again and get all ok.

```
PS C:\Windows\system32> kubectl delete pod --all -n kube-system
pod "coredns-6d4b75cb6d-wbhzp" deleted
pod "etcd-minikube" deleted
pod "kube-apiserver-minikube" deleted
pod "kube-controller-manager-minikube" deleted
pod "kube-proxy-v5ql5" deleted
pod "kube-scheduler-minikube" deleted
pod "storage-provisioner" deleted


PS C:\Windows\system32> kubectl get componentstatuses
Warning: v1 ComponentStatus is deprecated in v1.19+
NAME                 STATUS    MESSAGE                         ERROR
scheduler            Healthy   ok
etcd-0               Healthy   {"health":"true","reason":""}
controller-manager   Healthy   ok
```


### Pods in NS kube-system are recreating due:

1. Kubernetes static pods in manifest dir controled directly by kublet.

```
$ ls -la /etc/kubernetes/manifests/
total 16
drwxr-xr-x 2 root root  120 Dec 27 13:00 .
drwxr-xr-x 4 root root  160 Dec 27 13:00 ..
-rw------- 1 root root 2369 Dec 27 13:00 etcd.yaml
-rw------- 1 root root 3637 Dec 27 13:00 kube-apiserver.yaml
-rw------- 1 root root 2946 Dec 27 13:00 kube-controller-manager.yaml
-rw------- 1 root root 1436 Dec 27 13:00 kube-scheduler.yaml
```

2. Core-dns is recreated by Deployment.

```
PS W:\Otus\Kubernetes\2 Занятие> kubectl get deployment --namespace=kube-system -o wide
NAME      READY   UP-TO-DATE   AVAILABLE   AGE    CONTAINERS   IMAGES                              SELECTOR
coredns   1/1     1            1           160m   coredns      k8s.gcr.io/coredns/coredns:v1.8.6   k8s-app=kube-dns
```

3. Kube-proxy recreated by DaemonSet.

```
PS W:\Otus\Kubernetes\2 Занятие> kubectl get ds --namespace=kube-system -o wide
NAME         DESIRED   CURRENT   READY   UP-TO-DATE   AVAILABLE   NODE SELECTOR            AGE    CONTAINERS   IMAGES                          SELECTOR
kube-proxy   1         1         1       1            1           kubernetes.io/os=linux   161m   kube-proxy   k8s.gcr.io/kube-proxy:v1.24.3   k8s-app=kube-proxy
```



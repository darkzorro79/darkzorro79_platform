# darkzorro79_platform

## Шаблонизация манифестов Kubernetes

### Intro

Домашнее задание выполняем в YandexCloud кластере.  

```console
 yc managed-kubernetes cluster --id=$K8S_ID list-node-groups
+----------------------+-----------------+----------------------+---------------------+---------+------+
|          ID          |      NAME       |  INSTANCE GROUP ID   |     CREATED AT      | STATUS  | SIZE |
+----------------------+-----------------+----------------------+---------------------+---------+------+
| cat6hqo57nhgaf3ia6bi | kube-otus-group | cl1af8p23sbvoadcj3ip | 2023-02-25 18:12:40 | RUNNING |    2 |
+----------------------+-----------------+----------------------+---------------------+---------+------+
```

### Устанавливаем готовые Helm charts

Попробуем установить Helm charts созданные сообществом. С их помощью создадим и настроим инфраструктурные сервисы, необходимые для работы нашего кластера.

Для установки будем использовать **Helm 3**.

Сегодня будем работать со следующими сервисами:

- [nginx-ingress](https://github.com/helm/charts/tree/master/stable/nginx-ingress) - сервис, обеспечивающий доступ к публичным ресурсам кластера
- [cert-manager](https://github.com/jetstack/cert-manager/tree/master/deploy/charts/cert-manager) - сервис, позволяющий динамически генерировать Let's Encrypt сертификаты для ingress ресурсов
- [chartmuseum](https://github.com/helm/charts/tree/master/stable/chartmuseum) - специализированный репозиторий для хранения helm charts
- [harbor](https://github.com/goharbor/harbor-helm) - хранилище артефактов общего назначения (Docker Registry), поддерживающее helm charts

### Установка Helm 3

Для начала нам необходимо установить **Helm 3** на локальную машину.  
Инструкции по установке можно найти по [ссылке](https://github.com/helm/helm#install).

```console
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3;
chmod 700 get_helm.sh;
./get_helm.sh
```

Критерий успешности установки - после выполнения команды вывод:

```console
helm version
version.BuildInfo{Version:"v3.11.1", GitCommit:"293b50c65d4d56187cd4e2f390f0ada46b4c4737", GitTreeState:"clean", GoVersion:"go1.18.10"}
```

### Памятка по использованию Helm

Создание **release**:

```console
helm install <chart_name> --name=<release_name> --namespace=<namespace>
kubectl get secrets -n <namespace> | grep <release_name>
```

Обновление **release**:

```console
helm upgrade <release_name> <chart_name> --namespace=<namespace>
kubectl get secrets -n <namespace> | grep <release_name>
```

Создание или обновление **release**:

```console
helm upgrade --install <release_name> <chart_name> --namespace=<namespace>
kubectl get secrets -n <namespace> | grep <release_name>
```

Добавим репозиторий stable

По умолчанию в **Helm 3** не установлен репозиторий stable

```console
helm repo add stable https://charts.helm.sh/stable
"stable" has been added to your repositories

helm repo list
NAME    URL
stable  https://charts.helm.sh/stable
```

```console
kubectl create ns nginx-ingress
namespace/nginx-ingress created

helm upgrade --install nginx-ingress stable/nginx-ingress --wait \
 --namespace=nginx-ingress \
 --version=1.41.3
Release "nginx-ingress" does not exist. Installing it now.
WARNING: This chart is deprecated
Error: timed out waiting for the condition
```
Что-то пошло не так:

```console
kubectl -n nginx-ingress get po
NAME                                             READY   STATUS             RESTARTS        AGE
nginx-ingress-controller-65845897bc-ccr4m        0/1     CrashLoopBackOff   6 (2m35s ago)   10m
nginx-ingress-default-backend-5974cfcb46-m28wc   1/1     Running            0               10m

kubectl -n nginx-ingress logs nginx-ingress-controller-65845897bc-ccr4m
-------------------------------------------------------------------------------
NGINX Ingress controller
  Release:       v0.34.1
  Build:         v20200715-ingress-nginx-2.11.0-8-gda5fa45e2
  Repository:    https://github.com/kubernetes/ingress-nginx
  nginx version: nginx/1.19.1

-------------------------------------------------------------------------------

I0226 18:23:12.463647       8 flags.go:205] Watching for Ingress class: nginx
W0226 18:23:12.463967       8 flags.go:250] SSL certificate chain completion is disabled (--enable-ssl-chain-completion=false)
W0226 18:23:12.464015       8 client_config.go:552] Neither --kubeconfig nor --master was specified.  Using the inClusterConfig.  This might not work.
I0226 18:23:12.464199       8 main.go:231] Creating API client for https://10.233.32.1:443
I0226 18:23:12.475384       8 main.go:275] Running in Kubernetes cluster version v1.23 (v1.23.6) - git (clean) commit ad3338546da947756e8a88aa6822e9c11e7eac22 - platform linux/amd64
I0226 18:23:12.493835       8 main.go:87] Validated nginx-ingress/nginx-ingress-default-backend as the default backend.
I0226 18:23:12.593120       8 main.go:105] SSL fake certificate created /etc/ingress-controller/ssl/default-fake-certificate.pem
I0226 18:23:12.594921       8 main.go:113] Enabling new Ingress features available since Kubernetes v1.18
E0226 18:23:12.597003       8 main.go:122] Unexpected error searching IngressClass: ingressclasses.networking.k8s.io "nginx" is forbidden: User "system:serviceaccount:nginx-ingress:nginx-ingress" cannot get resource "ingressclasses" in API group "networking.k8s.io" at the cluster scope
W0226 18:23:12.597020       8 main.go:125] No IngressClass resource with name nginx found. Only annotation will be used.
W0226 18:23:12.610444       8 store.go:659] Unexpected error reading configuration configmap: configmaps "nginx-ingress-controller" not found
I0226 18:23:12.620088       8 nginx.go:263] Starting NGINX Ingress controller
E0226 18:23:13.726414       8 reflector.go:178] pkg/mod/k8s.io/client-go@v0.18.5/tools/cache/reflector.go:125: Failed to list *v1beta1.Ingress: the server could not find the requested resource
E0226 18:23:14.880088       8 reflector.go:178] pkg/mod/k8s.io/client-go@v0.18.5/tools/cache/reflector.go:125: Failed to list *v1beta1.Ingress: the server could not find the requested resource
E0226 18:23:16.726997       8 reflector.go:178] pkg/mod/k8s.io/client-go@v0.18.5/tools/cache/reflector.go:125: Failed to list *v1beta1.Ingress: the server could not find the requested resource
E0226 18:23:21.223606       8 reflector.go:178] pkg/mod/k8s.io/client-go@v0.18.5/tools/cache/reflector.go:125: Failed to list *v1beta1.Ingress: the server could not find the requested resource
E0226 18:23:29.606898       8 reflector.go:178] pkg/mod/k8s.io/client-go@v0.18.5/tools/cache/reflector.go:125: Failed to list *v1beta1.Ingress: the server could not find the requested resource
E0226 18:23:47.328077       8 reflector.go:178] pkg/mod/k8s.io/client-go@v0.18.5/tools/cache/reflector.go:125: Failed to list *v1beta1.Ingress: the server could not find the requested resource
I0226 18:23:48.216123       8 main.go:179] Received SIGTERM, shutting down
I0226 18:23:48.216142       8 nginx.go:380] Shutting down controller queues
I0226 18:23:48.216156       8 status.go:118] updating status of Ingress rules (remove)
E0226 18:23:48.216304       8 store.go:186] timed out waiting for caches to sync
I0226 18:23:48.216333       8 nginx.go:307] Starting NGINX process
I0226 18:23:48.216564       8 leaderelection.go:242] attempting to acquire leader lease  nginx-ingress/ingress-controller-leader-nginx...
E0226 18:23:48.216770       8 queue.go:78] queue has been shutdown, failed to enqueue: &ObjectMeta{Name:initial-sync,GenerateName:,Namespace:,SelfLink:,UID:,ResourceVersion:,Generation:0,CreationTimestamp:0001-01-01 00:00:00 +0000 UTC,DeletionTimestamp:<nil>,DeletionGracePeriodSeconds:nil,Labels:map[string]string{},Annotations:map[string]string{},OwnerReferences:[]OwnerReference{},Finalizers:[],ClusterName:,ManagedFields:[]ManagedFieldsEntry{},}
I0226 18:23:48.228539       8 leaderelection.go:252] successfully acquired lease nginx-ingress/ingress-controller-leader-nginx
E0226 18:23:48.228735       8 queue.go:78] queue has been shutdown, failed to enqueue: &ObjectMeta{Name:sync status,GenerateName:,Namespace:,SelfLink:,UID:,ResourceVersion:,Generation:0,CreationTimestamp:0001-01-01 00:00:00 +0000 UTC,DeletionTimestamp:<nil>,DeletionGracePeriodSeconds:nil,Labels:map[string]string{},Annotations:map[string]string{},OwnerReferences:[]OwnerReference{},Finalizers:[],ClusterName:,ManagedFields:[]ManagedFieldsEntry{},}
I0226 18:23:48.228807       8 status.go:86] new leader elected: nginx-ingress-controller-65845897bc-ccr4m
I0226 18:23:48.233998       8 status.go:137] removing address from ingress status ([158.160.7.42])
I0226 18:23:48.234057       8 nginx.go:396] Stopping NGINX process
2023/02/26 18:23:48 [notice] 26#26: signal process started
I0226 18:23:52.240562       8 nginx.go:409] NGINX process has stopped
I0226 18:23:52.240580       8 main.go:187] Handled quit, awaiting Pod deletion
I0226 18:24:02.240711       8 main.go:190] Exiting with 0
```
Коллеги, видим что данный helm chart - это гвоздь не от той стены.
 - версия available since Kubernetes v1.18 - не совподает с минимальной на YC, а наша инсталлированная 1.23.6
 - 
```console
helm search repo -l stable/nginx-ingress
NAME                    CHART VERSION   APP VERSION     DESCRIPTION
stable/nginx-ingress    1.41.3          v0.34.1         DEPRECATED! An nginx Ingress controller that us...
stable/nginx-ingress    1.41.2          v0.34.1         An nginx Ingress controller that uses ConfigMap...
stable/nginx-ingress    1.41.1          v0.34.1         An nginx Ingress controller that uses ConfigMap...
```
есть подозорение, что весь репозиторий протух.

```console
 yc managed-kubernetes cluster --id=$K8S_ID get
id: catf200i5kplhbbh8lda
folder_id: b1gj57gf35l6pbm9pai4
created_at: "2023-02-26T16:41:48Z"
name: kube-otus
status: RUNNING
health: HEALTHY
network_id: enpofgjpegsapvs3qmsa
master:
  zonal_master:
    zone_id: ru-central1-b
    internal_v4_address: 10.129.0.6
    external_v4_address: 130.193.41.7
  version: "1.23"
```

Удаляем кривую инсталляцию ingress.
Идём в инструкцию: https://kubernetes.github.io/ingress-nginx/deploy/
запускаем оттуда рекомендованный helm chart


```console
helm upgrade --install ingress-nginx ingress-nginx \
  --repo https://kubernetes.github.io/ingress-nginx \
  --namespace ingress-nginx --create-namespace

Release "ingress-nginx" does not exist. Installing it now.
NAME: ingress-nginx
LAST DEPLOYED: Sun Feb 26 19:19:06 2023
NAMESPACE: ingress-nginx
STATUS: deployed
REVISION: 1
TEST SUITE: None
NOTES:
The ingress-nginx controller has been installed.
It may take a few minutes for the LoadBalancer IP to be available.
You can watch the status by running 'kubectl --namespace ingress-nginx get services -o wide -w ingress-nginx-controller'

An example Ingress that makes use of the controller:
  apiVersion: networking.k8s.io/v1
  kind: Ingress
  metadata:
    name: example
    namespace: foo
  spec:
    ingressClassName: nginx
    rules:
      - host: www.example.com
        http:
          paths:
            - pathType: Prefix
              backend:
                service:
                  name: exampleService
                  port:
                    number: 80
              path: /
    # This section is only required if TLS is to be enabled for the Ingress
    tls:
      - hosts:
        - www.example.com
        secretName: example-tls

If TLS is enabled for the Ingress, a Secret containing the certificate and key must also be provided:

  apiVersion: v1
  kind: Secret
  metadata:
    name: example-tls
    namespace: foo
  data:
    tls.crt: <base64 encoded cert>
    tls.key: <base64 encoded key>
  type: kubernetes.io/tls
```


Разберем используемые ключи:

- **--wait** - ожидать успешного окончания установки ([подробности](https://helm.sh/docs/using_helm/#helpful-options-for-install-upgrade-rollback))
- **--timeout** - считать установку неуспешной по истечении указанного времени
- **--namespace** - установить chart в определенный namespace (если не существует, необходимо создать)
- **--version** - установить определенную версию chart

### cert-manager

Добавим репозиторий, в котором хранится актуальный helm chart cert-manager:

```console
helm repo add jetstack https://charts.jetstack.io
"jetstack" has been added to your repositories

helm repo update
Hang tight while we grab the latest from your chart repositories...
...Successfully got an update from the "jetstack" chart repository
...Successfully got an update from the "stable" chart repository
Update Complete. ⎈ Happy Helming!⎈
```

Создадим namespace

```console
kubectl create namespace cert-manager
namespace/cert-manager created
```

Также для установки cert-manager предварительно потребуется создать в кластере некоторые **CRD**:

```console
kubectl apply --validate=false -f https://github.com/jetstack/cert-manager/releases/download/v0.16.1/cert-manager.crds.yaml
resource mapping not found for name: "certificaterequests.cert-manager.io" namespace: "" from "https://github.com/jetstack/cert-manager/releases/download/v0.16.1/cert-manager.crds.yaml": no matches for kind "CustomResourceDefinition" in version "apiextensions.k8s.io/v1beta1"
ensure CRDs are installed first
resource mapping not found for name: "certificates.cert-manager.io" namespace: "" from "https://github.com/jetstack/cert-manager/releases/download/v0.16.1/cert-manager.crds.yaml": no matches for kind "CustomResourceDefinition" in version "apiextensions.k8s.io/v1beta1"
ensure CRDs are installed first
resource mapping not found for name: "challenges.acme.cert-manager.io" namespace: "" from "https://github.com/jetstack/cert-manager/releases/download/v0.16.1/cert-manager.crds.yaml": no matches for kind "CustomResourceDefinition" in version "apiextensions.k8s.io/v1beta1"
ensure CRDs are installed first
resource mapping not found for name: "clusterissuers.cert-manager.io" namespace: "" from "https://github.com/jetstack/cert-manager/releases/download/v0.16.1/cert-manager.crds.yaml": no matches for kind "CustomResourceDefinition" in version "apiextensions.k8s.io/v1beta1"
ensure CRDs are installed first
resource mapping not found for name: "issuers.cert-manager.io" namespace: "" from "https://github.com/jetstack/cert-manager/releases/download/v0.16.1/cert-manager.crds.yaml": no matches for kind "CustomResourceDefinition" in version "apiextensions.k8s.io/v1beta1"
ensure CRDs are installed first
resource mapping not found for name: "orders.acme.cert-manager.io" namespace: "" from "https://github.com/jetstack/cert-manager/releases/download/v0.16.1/cert-manager.crds.yaml": no matches for kind "CustomResourceDefinition" in version "apiextensions.k8s.io/v1beta1"
ensure CRDs are installed first
```
есть подозрение, что наша версия так же не подходит по причине обновившегося API

```console
$ kubectl apply --validate=false -f https://github.com/cert-manager/cert-manager/releases/download/v1.11.0/cert-manager.crds.yaml
customresourcedefinition.apiextensions.k8s.io/clusterissuers.cert-manager.io created
customresourcedefinition.apiextensions.k8s.io/challenges.acme.cert-manager.io created
customresourcedefinition.apiextensions.k8s.io/certificaterequests.cert-manager.io created
customresourcedefinition.apiextensions.k8s.io/issuers.cert-manager.io created
customresourcedefinition.apiextensions.k8s.io/certificates.cert-manager.io created
customresourcedefinition.apiextensions.k8s.io/orders.acme.cert-manager.io created
```

```console
helm upgrade --install cert-manager jetstack/cert-manager --wait \
 --namespace=cert-manager \
 --version=v1.11.0
Release "cert-manager" does not exist. Installing it now.
NAME: cert-manager
LAST DEPLOYED: Sun Feb 26 20:04:12 2023
NAMESPACE: cert-manager
STATUS: deployed
REVISION: 1
TEST SUITE: None
NOTES:
cert-manager v1.11.0 has been deployed successfully!

In order to begin issuing certificates, you will need to set up a ClusterIssuer
or Issuer resource (for example, by creating a 'letsencrypt-staging' issuer).

More information on the different types of issuers and how to configure them
can be found in our documentation:

https://cert-manager.io/docs/configuration/

For information on how to configure cert-manager to automatically provision
Certificates for Ingress resources, take a look at the `ingress-shim`
documentation:

https://cert-manager.io/docs/usage/ingress/
```

Проверим, что cert-manager успешно развернут и работает:

```console
kubectl get pods --namespace cert-manager
NAME                                       READY   STATUS    RESTARTS   AGE
cert-manager-6b4d84674-qvqpr               1/1     Running   0          3m23s
cert-manager-cainjector-59f8d9f696-9jmln   1/1     Running   0          3m23s
cert-manager-webhook-56889bfc96-xjhs8      1/1     Running   0          3m23s


cat <<EOF > test-resources.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: cert-manager-test
---
apiVersion: cert-manager.io/v1
kind: Issuer
metadata:
  name: test-selfsigned
  namespace: cert-manager-test
spec:
  selfSigned: {}
---
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: selfsigned-cert
  namespace: cert-manager-test
spec:
  dnsNames:
    - example.com
  secretName: selfsigned-cert-tls
  issuerRef:
    name: test-selfsigned

kubectl apply -f test-resources.yaml
namespace/cert-manager-test created
issuer.cert-manager.io/test-selfsigned created
certificate.cert-manager.io/selfsigned-cert created

kubectl describe certificate -n cert-manager-test
Name:         selfsigned-cert
Namespace:    cert-manager-test
Labels:       <none>
Annotations:  <none>
API Version:  cert-manager.io/v1
Kind:         Certificate
Metadata:
  Creation Timestamp:  2023-02-26T21:05:06Z
  Generation:          1
  Managed Fields:
    API Version:  cert-manager.io/v1
    Fields Type:  FieldsV1
    fieldsV1:
      f:metadata:
        f:annotations:
          .:
          f:kubectl.kubernetes.io/last-applied-configuration:
      f:spec:
        .:
        f:dnsNames:
        f:issuerRef:
          .:
          f:name:
        f:secretName:
    Manager:      kubectl-client-side-apply
    Operation:    Update
    Time:         2023-02-26T21:05:06Z
    API Version:  cert-manager.io/v1
    Fields Type:  FieldsV1
    fieldsV1:
      f:status:
        f:revision:
    Manager:      cert-manager-certificates-issuing
    Operation:    Update
    Subresource:  status
    Time:         2023-02-26T21:05:07Z
    API Version:  cert-manager.io/v1
    Fields Type:  FieldsV1
    fieldsV1:
      f:status:
        .:
        f:conditions:
          .:
          k:{"type":"Ready"}:
            .:
            f:lastTransitionTime:
            f:message:
            f:observedGeneration:
            f:reason:
            f:status:
            f:type:
        f:notAfter:
        f:notBefore:
        f:renewalTime:
    Manager:         cert-manager-certificates-readiness
    Operation:       Update
    Subresource:     status
    Time:            2023-02-26T21:05:07Z
  Resource Version:  69850
  UID:               dbdb3a2b-3b36-4c76-80b3-babfd0e2a9dc
Spec:
  Dns Names:
    example.com
  Issuer Ref:
    Name:       test-selfsigned
  Secret Name:  selfsigned-cert-tls
Status:
  Conditions:
    Last Transition Time:  2023-02-26T21:05:07Z
    Message:               Certificate is up to date and has not expired
    Observed Generation:   1
    Reason:                Ready
    Status:                True
    Type:                  Ready
  Not After:               2023-05-27T21:05:07Z
  Not Before:              2023-02-26T21:05:07Z
  Renewal Time:            2023-04-27T21:05:07Z
  Revision:                1
Events:
  Type    Reason     Age   From                                       Message
  ----    ------     ----  ----                                       -------
  Normal  Issuing    13s   cert-manager-certificates-trigger          Issuing certificate as Secret does not exist
  Normal  Generated  12s   cert-manager-certificates-key-manager      Stored new private key in temporary Secret resource "selfsigned-cert-rg24l"
  Normal  Requested  12s   cert-manager-certificates-request-manager  Created new CertificateRequest resource "selfsigned-cert-5xndv"
  Normal  Issuing    12s   cert-manager-certificates-issuing          The certificate has been successfully issued

kubectl delete -f test-resources.yaml
namespace "cert-manager-test" deleted
issuer.cert-manager.io "test-selfsigned" deleted
certificate.cert-manager.io "selfsigned-cert" deleted
```


### cert-manager | Самостоятельное задание

Для выпуска сертификатов нам потребуются ClusterIssuers. Создадим их для staging и production окружений.

cluster-issuer-prod.yaml:

```yml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-production
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: admin@kropalik.ru
    privateKeySecretRef:
      name: letsencrypt-production
    solvers:
    - http01:
        ingress:
          class:  nginx
```
cluster-issuer-stage.yaml

```yml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-staging
spec:
  acme:
    server: https://acme-staging-v02.api.letsencrypt.org/directory
    email: admin@kropalik.ru
    privateKeySecretRef:
      name: letsencrypt-staging
    solvers:
    - http01:
        ingress:
          class:  nginx
```


Проверим статус:

```console
kubectl describe clusterissuers -n cert-manager
Name:         letsencrypt-production
Namespace:
Labels:       <none>
Annotations:  <none>
API Version:  cert-manager.io/v1
Kind:         ClusterIssuer
Metadata:
  Creation Timestamp:  2023-02-26T21:31:08Z
  Generation:          1
  Managed Fields:
    API Version:  cert-manager.io/v1
    Fields Type:  FieldsV1
    fieldsV1:
      f:metadata:
        f:annotations:
          .:
          f:kubectl.kubernetes.io/last-applied-configuration:
      f:spec:
        .:
        f:acme:
          .:
          f:email:
          f:privateKeySecretRef:
            .:
            f:name:
          f:server:
          f:solvers:
    Manager:      kubectl-client-side-apply
    Operation:    Update
    Time:         2023-02-26T21:31:08Z
    API Version:  cert-manager.io/v1
    Fields Type:  FieldsV1
    fieldsV1:
      f:status:
        .:
        f:acme:
          .:
          f:lastRegisteredEmail:
          f:uri:
        f:conditions:
          .:
          k:{"type":"Ready"}:
            .:
            f:lastTransitionTime:
            f:message:
            f:observedGeneration:
            f:reason:
            f:status:
            f:type:
    Manager:         cert-manager-clusterissuers
    Operation:       Update
    Subresource:     status
    Time:            2023-02-26T21:31:10Z
  Resource Version:  77137
  UID:               ccee8f8a-978d-45af-9a0a-c184a6961af6
Spec:
  Acme:
    Email:            admin@kropalik.ru
    Preferred Chain:
    Private Key Secret Ref:
      Name:  letsencrypt-production
    Server:  https://acme-v02.api.letsencrypt.org/directory
    Solvers:
      http01:
        Ingress:
          Class:  nginx
Status:
  Acme:
    Last Registered Email:  admin@kropalik.ru
    Uri:                    https://acme-v02.api.letsencrypt.org/acme/acct/983932736
  Conditions:
    Last Transition Time:  2023-02-26T21:31:10Z
    Message:               The ACME account was registered with the ACME server
    Observed Generation:   1
    Reason:                ACMEAccountRegistered
    Status:                True
    Type:                  Ready
Events:                    <none>


Name:         letsencrypt-staging
Namespace:
Labels:       <none>
Annotations:  <none>
API Version:  cert-manager.io/v1
Kind:         ClusterIssuer
Metadata:
  Creation Timestamp:  2023-02-26T21:31:16Z
  Generation:          1
  Managed Fields:
    API Version:  cert-manager.io/v1
    Fields Type:  FieldsV1
    fieldsV1:
      f:metadata:
        f:annotations:
          .:
          f:kubectl.kubernetes.io/last-applied-configuration:
      f:spec:
        .:
        f:acme:
          .:
          f:email:
          f:privateKeySecretRef:
            .:
            f:name:
          f:server:
          f:solvers:
    Manager:      kubectl-client-side-apply
    Operation:    Update
    Time:         2023-02-26T21:31:16Z
    API Version:  cert-manager.io/v1
    Fields Type:  FieldsV1
    fieldsV1:
      f:status:
        .:
        f:acme:
          .:
          f:lastRegisteredEmail:
          f:uri:
        f:conditions:
          .:
          k:{"type":"Ready"}:
            .:
            f:lastTransitionTime:
            f:message:
            f:observedGeneration:
            f:reason:
            f:status:
            f:type:
    Manager:         cert-manager-clusterissuers
    Operation:       Update
    Subresource:     status
    Time:            2023-02-26T21:31:17Z
  Resource Version:  77175
  UID:               99cba466-0a53-4dc3-9b8f-83fd2df6037d
Spec:
  Acme:
    Email:            admin@kropalik.ru
    Preferred Chain:
    Private Key Secret Ref:
      Name:  letsencrypt-staging
    Server:  https://acme-staging-v02.api.letsencrypt.org/directory
    Solvers:
      http01:
        Ingress:
          Class:  nginx
Status:
  Acme:
    Last Registered Email:  admin@kropalik.ru
    Uri:                    https://acme-staging-v02.api.letsencrypt.org/acme/acct/90316644
  Conditions:
    Last Transition Time:  2023-02-26T21:31:17Z
    Message:               The ACME account was registered with the ACME server
    Observed Generation:   1
    Reason:                ACMEAccountRegistered
    Status:                True
    Type:                  Ready
Events:                    <none>
```


### chartmuseum

Кастомизируем установку chartmuseum

- Создадим директорию kubernetes-templating/chartmuseum/ и поместим туда файл values.yaml
- Изучим [содержимое](https://github.com/helm/charts/blob/master/stable/chartmuseum/values.yaml) оригинальный файла values.yaml
- Включим:
  - Создание ingress ресурса с корректным hosts.name (должен использоваться nginx-ingress)
  - Автоматическую генерацию Let's Encrypt сертификата

<https://github.com/helm/charts/tree/master/stable/chartmuseum>

Файл values.yaml для chartmuseum будет выглядеть следующим образом:

```yml
ingress:
 enabled: true
 annotations:
   kubernetes.io/ingress.class: nginx
   kubernetes.io/tls-acme: "true"
   cert-manager.io/cluster-issuer: "letsencrypt-production"
   cert-manager.io/acme-challenge-type: http01
 hosts:
   - name: chartmuseum.84.201.150.236.nip.io
     path: /
     tls: true
     tlsSecret: chartmuseum.84.201.150.236.nip.io
securityContext: {}
env:
  open:
    DISABLE_API: false
```

Установим chartmuseum:


```console
kubectl create ns chartmuseum
namespace/chartmuseum created
```

добавим свежий репозиторий
```console
helm repo add chartmuseum https://chartmuseum.github.io/charts
"chartmuseum" has been added to your repositories

helm repo update
Hang tight while we grab the latest from your chart repositories...
...Successfully got an update from the "chartmuseum" chart repository
...Successfully got an update from the "jetstack" chart repository
...Successfully got an update from the "stable" chart repository
Update Complete. ⎈Happy Helming!⎈

helm repo list
NAME            URL
stable          https://charts.helm.sh/stable
jetstack        https://charts.jetstack.io
chartmuseum     https://chartmuseum.github.io/charts
kirill@k8s-admin:~/kubernetes-templating/chartmuseum$ kubectl create ns chartmuseum
```


```console
helm install chartmuseum chartmuseum/chartmuseum --wait \
 --namespace=chartmuseum \
 --version 3.1.0 \
 -f values.yaml
NAME: chartmuseum
LAST DEPLOYED: Fri Mar 10 17:47:50 2023
NAMESPACE: chartmuseum
STATUS: deployed
REVISION: 1
TEST SUITE: None
NOTES:
** Please be patient while the chart is being deployed **

Get the ChartMuseum URL by running:

  export POD_NAME=$(kubectl get pods --namespace chartmuseum -l "app=chartmuseum" -l "release=chartmuseum" -o jsonpath="{.items[0].metadata.name}")
  echo http://127.0.0.1:8080/
  kubectl port-forward $POD_NAME 8080:8080 --namespace chartmuseum
 
```

Проверим, что release chartmuseum установился:

```console
helm ls -n chartmuseum
NAME            NAMESPACE       REVISION        UPDATED                                 STATUS          CHART                   APP VERSION
chartmuseum     chartmuseum     1               2023-03-10 15:01:32.664716979 +0000 UTC deployed        chartmuseum-3.1.0       0.13.1
```
![alt text](https://github.com/darkzorro79/darkzorro79_platform/raw/kubernetes-templating/kubernetes-templating/chartmuseum.png)
![alt text](https://github.com/darkzorro79/darkzorro79_platform/raw/kubernetes-templating/kubernetes-templating/chartmuseum_crt.png)

- **helm 2** хранил информацию о релизе в configMap'ах (kubectl get configmaps -n kube-system)
- **Helm 3** хранит информацию в secrets (kubectl get secrets - n chartmuseum)

```console
kubectl get secrets -n chartmuseum
NAME                                TYPE                                  DATA   AGE
chartmuseum                         Opaque                                0      4m32s
chartmuseum.84.201.150.236.nip.io   kubernetes.io/tls                     2      4m5s
default-token-vbhzb                 kubernetes.io/service-account-token   3      5m36s
sh.helm.release.v1.chartmuseum.v1   helm.sh/release.v1                    1      4m32s

```

### chartmuseum | Задание со ⭐

Научимся работать с chartmuseum и зальем в наш репозиторий - примеру frontend

- Добавяем наш репозитарий

```console
helm repo add my-chartmuseum https://chartmuseum.84.201.150.236.nip.io/
"my-chartmuseum" has been added to your repositories
```

- скачаем к примеру тот же helmchart для chartmuseum
```console
helm pull chartmuseum/chartmuseum --version 3.1.0
```
распаковываем в отдельную директорию и проверяем

- Проверяем линтером

```console
helm lint
==> Linting .
[INFO] Chart.yaml: icon is recommended

1 chart(s) linted, 0 chart(s) failed
```


- Пакуем

```console
helm package .
Successfully packaged chart and saved it to: /home/kirill/chartmuseum/chartmuseum-3.1.0.tgz
```

```console
 curl -L --data-binary "@chartmuseum-3.1.0.tgz" https://chartmuseum.84.201.150.236.nip.io/api/charts
{"saved":true}
```

- Обновляем список repo

```console
helm repo update
Hang tight while we grab the latest from your chart repositories...
...Successfully got an update from the "my-chartmuseum" chart repository
...Successfully got an update from the "jetstack" chart repository
...Successfully got an update from the "chartmuseum" chart repository
...Successfully got an update from the "stable" chart repository
Update Complete. ⎈Happy Helming!⎈
```

- Ищем наш frontend в репозитории

```console
helm search repo -l my-chartmuseum/
NAME                            CHART VERSION   APP VERSION     DESCRIPTION
my-chartmuseum/chartmuseum      3.1.0           0.13.1          Host your own Helm Chart Repository
```

- И выкатываем

```console
helm upgrade --install chartmuseum my-chartmuseum/chartmuseum --namespace chartmuseum

```

### Harbor

Установим [Harbor](https://github.com/goharbor/harbor-helm)

- Пишем values.yaml

```yml
expose:
  type: ingress
  tls:
    enabled: true
    certSource: secret
    secret:
      secretName: harbor-ingress-tls
  ingress:
    hosts:
      core: harbor.84.201.150.236.nip.io
    controller: nginx
    annotations:
      kubernetes.io/tls-acme: "true"
      cert-manager.io/cluster-issuer: "letsencrypt-production"
      cert-manager.io/acme-challenge-type: http01
      kubernetes.io/ingress.class: nginx
externalURL: https://harbor.84.201.150.236.nip.io/
notary:
  enabled: false
```


  
  
  
- Добавляем repo

```console
helm repo add harbor https://helm.goharbor.io
"harbor" has been added to your repositories
````


- Обновляем repo

```console
helm repo update
Hang tight while we grab the latest from your chart repositories...
...Successfully got an update from the "my-chartmuseum" chart repository
...Successfully got an update from the "jetstack" chart repository
...Successfully got an update from the "chartmuseum" chart repository
...Successfully got an update from the "harbor" chart repository
...Successfully got an update from the "stable" chart repository
Update Complete. ⎈Happy Helming!⎈
```

- Создаем ns

```console
kubectl create ns harbor
namespace/harbor created
```

- проверяем актуальную версию

```console
helm search repo -l harbor/harbor
NAME            CHART VERSION   APP VERSION     DESCRIPTION
harbor/harbor   1.11.1          2.7.1           An open source trusted cloud native registry th...
harbor/harbor   1.11.0          2.7.0           An open source trusted cloud native registry th...
harbor/harbor   1.10.4          2.6.4           An open source trusted cloud native registry th...
harbor/harbor   1.10.3          2.6.3           An open source trusted cloud native registry th...
harbor/harbor   1.10.2          2.6.2           An open source trusted cloud native registry th...
```

 Выкатывем

```console
helm upgrade --install harbor harbor/harbor --wait --namespace=harbor --version=1.11.1 -f values.yaml
NAME: harbor
LAST DEPLOYED: Fri Mar 10 21:30:46 2023
NAMESPACE: harbor
STATUS: deployed
REVISION: 1
TEST SUITE: None
NOTES:
Please wait for several minutes for Harbor deployment to complete.
Then you should be able to visit the Harbor portal at https://harbor.84.201.150.236.nip.io/
For more details, please visit https://github.com/goharbor/harbor
```


#### Tips & Tricks

- Формат описания переменных в файле values.yaml для **chartmuseum** и **harbor** отличается
- Helm3 не создает namespace в который будет установлен release
- Проще выключить сервис **notary**, он нам не понадобится
- Реквизиты по умолчанию - **admin/Harbor12345**
- nip.io может оказаться забанен в cert-manager. Если у вас есть собственный домен - лучше использовать его, либо попробовать xip.io, либо переключиться на staging ClusterIssuer
- Обратим внимание, как helm3 хранит информацию о release: kubectl get secrets -n harbor -l owner=helm

Проверяем: <https://harbor.84.201.150.236.nip.io/>

![alt text](https://github.com/darkzorro79/darkzorro79_platform/raw/kubernetes-templating/kubernetes-templating/harbor.png)
![alt text](https://github.com/darkzorro79/darkzorro79_platform/raw/kubernetes-templating/kubernetes-templating/harbor_crt.png)


### Используем helmfile | Задание со ⭐

Опишем установку **nginx-ingress**, **cert-manager** и **harbor** в helmfile

- Установим helmfile

```console
sudo apt install helmfile
```

> Для применения манифестов ClusterIssuers воспользуемся [incubator/raw](https://charts.helm.sh/incubator/raw/0.2.5) 

Создадим helmfile.yaml


```yml
repositories:
- name: stable
  url: https://charts.helm.sh/stable
- name: jetstack
  url: https://charts.jetstack.io
- name: harbor
  url: https://helm.goharbor.io
- name: chartmuseum
  url: https://chartmuseum.github.io/charts
- name: incubator
  url: https://charts.helm.sh/incubator

helmDefaults:
  wait: true

releases:
- name: cert-manager
  namespace: cert-manager
  chart: jetstack/cert-manager
  version: v1.11.0
  set:
  - name: installCRDs
    value: true

- name: cert-manager-issuers
  needs:
    - cert-manager/cert-manager
  namespace: cert-manager
  chart: incubator/raw
  version: 0.2.5
  values:
    - ./cert-manager/values.yaml

- name: harbor
  needs:
    - cert-manager/cert-manager
  namespace: harbor
  chart: harbor/harbor
  version: 1.11.1
  values:
    - ./harbor/values.yaml

- name: chartmuseum
  needs:
    - cert-manager/cert-manager
  namespace: chartmuseum
  chart: chartmuseum/chartmuseum
  version: 3.1.0
  values:
    - ./chartmuseum/values.yaml
```

- Удалим ns установленных ранее сервисов, а также CRD для cert-manager
- Проверим отсутствие ns наших сервисов

```console
kubectl get ns
NAME              STATUS   AGE
default           Active   2d2h
ingress-nginx     Active   2d1h
kube-node-lease   Active   2d2h
kube-public       Active   2d2h
kube-system       Active   2d2h
yandex-system     Active   2d2h
```

```console
kubectl get crd --all-namespaces
NAME                                             CREATED AT
volumesnapshotclasses.snapshot.storage.k8s.io    2023-03-10T12:58:26Z
volumesnapshotcontents.snapshot.storage.k8s.io   2023-03-10T12:58:26Z
volumesnapshots.snapshot.storage.k8s.io          2023-03-10T12:58:26Z
```


- Линтим

```console
helmfile lint
Adding repo stable https://charts.helm.sh/stable
"stable" has been added to your repositories

Adding repo jetstack https://charts.jetstack.io
"jetstack" has been added to your repositories

Adding repo harbor https://helm.goharbor.io
"harbor" has been added to your repositories

Adding repo chartmuseum https://chartmuseum.github.io/charts
"chartmuseum" has been added to your repositories

Adding repo incubator https://charts.helm.sh/incubator
"incubator" has been added to your repositories

Fetching chartmuseum/chartmuseum
Fetching jetstack/cert-manager
Fetching incubator/raw
Fetching harbor/harbor
Linting release=cert-manager, chart=/tmp/helmfile3245923513/cert-manager/cert-manager/jetstack/cert-manager/v1.11.0/cert-manager
==> Linting /tmp/helmfile3245923513/cert-manager/cert-manager/jetstack/cert-manager/v1.11.0/cert-manager

1 chart(s) linted, 0 chart(s) failed

Linting release=cert-manager-issuers, chart=/tmp/helmfile3245923513/cert-manager/cert-manager-issuers/incubator/raw/0.2.5/raw
==> Linting /tmp/helmfile3245923513/cert-manager/cert-manager-issuers/incubator/raw/0.2.5/raw
[INFO] Chart.yaml: icon is recommended

1 chart(s) linted, 0 chart(s) failed

Linting release=harbor, chart=/tmp/helmfile3245923513/harbor/harbor/harbor/harbor/1.11.1/harbor
==> Linting /tmp/helmfile3245923513/harbor/harbor/harbor/harbor/1.11.1/harbor

1 chart(s) linted, 0 chart(s) failed

Linting release=chartmuseum, chart=/tmp/helmfile3245923513/chartmuseum/chartmuseum/chartmuseum/chartmuseum/3.1.0/chartmuseum
==> Linting /tmp/helmfile3245923513/chartmuseum/chartmuseum/chartmuseum/chartmuseum/3.1.0/chartmuseum

1 chart(s) linted, 0 chart(s) failed
```

- Устанавлием cert-manager, chartmuseum и harbor


```console
helmfile sync
Adding repo stable https://charts.helm.sh/stable
"stable" has been added to your repositories

Adding repo jetstack https://charts.jetstack.io
"jetstack" has been added to your repositories

Adding repo harbor https://helm.goharbor.io
"harbor" has been added to your repositories

Adding repo chartmuseum https://chartmuseum.github.io/charts
"chartmuseum" has been added to your repositories

Adding repo incubator https://charts.helm.sh/incubator
"incubator" has been added to your repositories

Upgrading release=cert-manager, chart=jetstack/cert-manager
Release "cert-manager" does not exist. Installing it now.
NAME: cert-manager
LAST DEPLOYED: Sun Mar 12 16:40:23 2023
NAMESPACE: cert-manager
STATUS: deployed
REVISION: 1
TEST SUITE: None
NOTES:
cert-manager v1.11.0 has been deployed successfully!

In order to begin issuing certificates, you will need to set up a ClusterIssuer
or Issuer resource (for example, by creating a 'letsencrypt-staging' issuer).

More information on the different types of issuers and how to configure them
can be found in our documentation:

https://cert-manager.io/docs/configuration/

For information on how to configure cert-manager to automatically provision
Certificates for Ingress resources, take a look at the `ingress-shim`
documentation:

https://cert-manager.io/docs/usage/ingress/

Listing releases matching ^cert-manager$
cert-manager    cert-manager    1               2023-03-12 16:40:23.792714938 +0000 UTC deployed        cert-manager-v1.11.0    v1.11.0

Upgrading release=harbor, chart=harbor/harbor
Upgrading release=chartmuseum, chart=chartmuseum/chartmuseum
Upgrading release=cert-manager-issuers, chart=incubator/raw
Release "cert-manager-issuers" does not exist. Installing it now.
NAME: cert-manager-issuers
LAST DEPLOYED: Sun Mar 12 16:40:42 2023
NAMESPACE: cert-manager
STATUS: deployed
REVISION: 1
TEST SUITE: None

Listing releases matching ^cert-manager-issuers$
cert-manager-issuers    cert-manager    1               2023-03-12 16:40:42.695756636 +0000 UTC deployed        raw-0.2.5       0.2.3

Release "chartmuseum" does not exist. Installing it now.
NAME: chartmuseum
LAST DEPLOYED: Sun Mar 12 16:40:43 2023
NAMESPACE: chartmuseum
STATUS: deployed
REVISION: 1
TEST SUITE: None
NOTES:
** Please be patient while the chart is being deployed **

Get the ChartMuseum URL by running:

  export POD_NAME=$(kubectl get pods --namespace chartmuseum -l "app=chartmuseum" -l "release=chartmuseum" -o jsonpath="{.items[0].metadata.name}")
  echo http://127.0.0.1:8080/
  kubectl port-forward $POD_NAME 8080:8080 --namespace chartmuseum

Listing releases matching ^chartmuseum$
chartmuseum     chartmuseum     1               2023-03-12 16:40:43.062334462 +0000 UTC deployed        chartmuseum-3.1.0       0.13.1

Release "harbor" does not exist. Installing it now.
NAME: harbor
LAST DEPLOYED: Sun Mar 12 16:40:42 2023
NAMESPACE: harbor
STATUS: deployed
REVISION: 1
TEST SUITE: None
NOTES:
Please wait for several minutes for Harbor deployment to complete.
Then you should be able to visit the Harbor portal at https://harbor.84.201.150.236.nip.io/
For more details, please visit https://github.com/goharbor/harbor

Listing releases matching ^harbor$
harbor  harbor          1               2023-03-12 16:40:42.743255284 +0000 UTC deployed        harbor-1.11.1   2.7.1


UPDATED RELEASES:
NAME                   CHART                     VERSION
cert-manager           jetstack/cert-manager     v1.11.0
cert-manager-issuers   incubator/raw               0.2.5
chartmuseum            chartmuseum/chartmuseum     3.1.0
harbor                 harbor/harbor              1.11.1

```

- Проверяем:

```console
kubectl get certificate --all-namespaces
NAMESPACE     NAME                                READY   SECRET                              AGE
chartmuseum   chartmuseum.84.201.150.236.nip.io   True    chartmuseum.84.201.150.236.nip.io   77m
harbor        harbor-ingress-tls                  True    harbor-ingress-tls                  77m

kubectl get deployments --all-namespaces
NAMESPACE       NAME                       READY   UP-TO-DATE   AVAILABLE   AGE
cert-manager    cert-manager               1/1     1            1           78m
cert-manager    cert-manager-cainjector    1/1     1            1           78m
cert-manager    cert-manager-webhook       1/1     1            1           78m
chartmuseum     chartmuseum                1/1     1            1           78m
harbor          harbor-chartmuseum         1/1     1            1           78m
harbor          harbor-core                1/1     1            1           78m
harbor          harbor-jobservice          1/1     1            1           78m
harbor          harbor-portal              1/1     1            1           78m
harbor          harbor-registry            1/1     1            1           78m
ingress-nginx   ingress-nginx-controller   1/1     1            1           2d3h
kube-system     coredns                    2/2     2            2           2d5h
kube-system     kube-dns-autoscaler        1/1     1            1           2d5h
kube-system     metrics-server             1/1     1            1           2d5h
```

### Создаем свой helm chart

Типичная жизненная ситуация:

- У вас есть приложение, которое готово к запуску в Kubernetes
- У вас есть манифесты для этого приложения, но вам надо запускать его на разных окружениях с разными параметрами

Возможные варианты решения:

- Написать разные манифесты для разных окружений
- Использовать "костыли" - sed, envsubst, etc...
- Использовать полноценное решение для шаблонизации (helm, etc...)

Мы рассмотрим третий вариант. Возьмем готовые манифесты и подготовим их к релизу на разные окружения.

Использовать будем демо-приложение [hipster-shop](https://github.com/GoogleCloudPlatform/microservices-demo), представляющее собой типичный набор микросервисов.

Стандартными средствами helm инициализируем структуру директории с содержимым будущего helm chart

```console
helm create kubernetes-templating/hipster-shop
```

Изучите созданный в качестве примера файл values.yaml и шаблоны в директории templates, примерно так выглядит стандартный helm chart.

Мы будем создавать chart для приложения с нуля, поэтому удалим values.yaml и содержимое templates.

После этого перенесем [файл](https://github.com/express42/otus-platform-snippets/blob/master/Module-04/05-Templating/manifests/all-hipster-shop.yaml) all-hipster-shop.yaml в директорию templates.

В целом, helm chart уже готов, попробуем установить его:

```console
kubectl create ns hipster-shop
namespace/hipster-shop created

helm upgrade --install hipster-shop kubernetes-templating/hipster-shop --namespace hipster-shop
Release "hipster-shop" does not exist. Installing it now.
NAME: hipster-shop
LAST DEPLOYED: Sun Mar 12 19:20:43 2023
NAMESPACE: hipster-shop
STATUS: deployed
REVISION: 1
TEST SUITE: None
```

После этого можно зайти в UI используя сервис типа NodePort (создается из манифестов) и проверить, что приложение заработало.

```console
kubectl get svc -n hipster-shop -l app=frontend
NAME       TYPE       CLUSTER-IP      EXTERNAL-IP   PORT(S)        AGE
frontend   NodePort   10.233.33.216   <none>        80:30546/TCP   2m33s
```

> Добавим правило FW разрешающее доступ по порту 30546 на все worker хосты GKE.

Сейчас наш helm chart **hipster-shop** совсем не похож на настоящий. При этом, все микросервисы устанавливаются из одного файла all-hipster-shop.yaml

Давайте исправим это и первым делом займемся микросервисом frontend. Скорее всего он разрабатывается отдельной командой, а исходный код хранится в отдельном репозитории.

Поэтому, было бы логично вынести все что связано с frontend в отдельный helm chart.

Создадим заготовку:

```console
helm create kubernetes-templating/frontend
Creating kubernetes-templating/frontend
```

Аналогично чарту **hipster-shop** удалим файл values.yaml и файлы в директории templates, создаваемые по умолчанию.

Выделим из файла all-hipster-shop.yaml манифесты для установки микросервиса frontend.

В директории templates чарта frontend создадим файлы:

- deployment.yaml - должен содержать соответствующую часть из файла all-hipster-shop.yaml
- service.yaml - должен содержать соответствующую часть из файла all-hipster-shop.yaml
- ingress.yaml - должен разворачивать ingress с доменным именем shop.<IP-адрес>.nip.io

После того, как вынесем описание deployment и service для **frontend** из файла all-hipster-shop.yaml переустановим chart hipster-shop и проверим, что доступ к UI пропал и таких ресурсов больше нет.


```console
helm upgrade --install hipster-shop kubernetes-templating/hipster-shop --namespace hipster-shop
Release "hipster-shop" has been upgraded. Happy Helming!
NAME: hipster-shop
LAST DEPLOYED: Sun Mar 12 20:02:13 2023
NAMESPACE: hipster-shop
STATUS: deployed
REVISION: 2
TEST SUITE: None
```

Установим chart **frontend** в namespace **hipster-shop** и проверим, что доступ к UI вновь появился:

```console
helm upgrade --install frontend kubernetes-templating/frontend --namespace hipster-shop
Release "frontend" does not exist. Installing it now.
NAME: frontend
LAST DEPLOYED: Tue Mar 21 21:18:12 2023
NAMESPACE: hipster-shop
STATUS: deployed
REVISION: 1
TEST SUITE: None
```

Пришло время минимально шаблонизировать наш chart **frontend**

Для начала продумаем структуру файла values.yaml

- Docker образ из которого выкатывается frontend может пересобираться, поэтому логично вынести его тег в переменную **frontend.image.tag**

В values.yaml это будет выглядеть следующим образом:

```yml
image:
  tag: v0.1.3
```

> ❗Это значение по умолчанию и может (и должно быть) быть переопределено в CI/CD pipeline

Теперь в манифесте deployment.yaml надо указать, что мы хотим использовать это переменную.

Было:

```yml
image: gcr.io/google-samples/microservices-demo/frontend:v0.1.3
```

Стало:

```yml
image: gcr.io/google-samples/microservices-demo/frontend:{{ .Values.image.tag }}
```

Аналогичным образом шаблонизируем следующие параметры **frontend** chart

- Количество реплик в deployment
- **Port**, **targetPort** и **NodePort** в service
- Опционально - тип сервиса. Ключ **NodePort** должен появиться в манифесте только если тип сервиса - **NodePort**
- Другие параметры, которые на наш взгляд стоит шаблонизировать

> ❗Не забываем указывать в файле values.yaml значения по умолчанию

Как должен выглядеть минимальный итоговый файл values.yaml:

```yml
image:
  tag: v0.1.3

replicas: 1

service:
  type: NodePort
  port: 80
  targetPort: 8079
  NodePort: 30001
```

service.yaml:

```yml
spec:
  type: {{ .Values.service.type }}
  selector:
    app: frontend
  ports:
  - name: http
    port: {{ .Values.service.port }}
    targetPort: {{ .Values.service.targetPort }}
    nodePort: {{ .Values.service.NodePort }}
```

Теперь наш **frontend** стал немного похож на настоящий helm chart. Не стоит забывать, что он все еще является частью одного
большого микросервисного приложения **hipster-shop**.

Поэтому было бы неплохо включить его в зависимости этого приложения.

Для начала, удалим release frontend из кластера:

```console
helm delete frontend -n hipster-shop
release "frontend" uninstalled
```

В Helm 2 файл requirements.yaml содержал список зависимостей helm chart (другие chart).  
В Helm 3 список зависимостей рекомендуют объявлять в файле Chart.yaml.

> При указании зависимостей в старом формате, все будет работать, единственное выдаст предупреждение. [Подробнее](https://helm.sh/docs/faq/#consolidation-of-requirements-yaml-into-chart-yaml)

Добавим chart **frontend** как зависимость

```yml
dependencies:
  - name: frontend
    version: 0.1.0
    repository: "file://../frontend"
```

Обновим зависимости:

```console
helm dep update kubernetes-templating/hipster-shop
Hang tight while we grab the latest from your chart repositories...
...Successfully got an update from the "chartmuseum" chart repository
...Successfully got an update from the "my-chartmuseum" chart repository
...Successfully got an update from the "jetstack" chart repository
...Successfully got an update from the "harbor" chart repository
...Successfully got an update from the "incubator" chart repository
...Successfully got an update from the "stable" chart repository
Update Complete. ⎈Happy Helming!⎈
Saving 1 charts
Deleting outdated charts
```

В директории kubernetes-templating/hipster-shop/charts появился архив **frontend-0.1.0.tgz** содержащий chart frontend определенной версии и добавленный в chart hipster-shop как зависимость.

Обновим release **hipster-shop** и убедимся, что ресурсы frontend вновь созданы.

```console
helm upgrade --install hipster-shop kubernetes-templating/hipster-shop --namespace hipster-shop
Release "hipster-shop" has been upgraded. Happy Helming!
NAME: hipster-shop
LAST DEPLOYED: Tue Mar 21 22:34:29 2023
NAMESPACE: hipster-shop
STATUS: deployed
REVISION: 3
TEST SUITE: None
```

Осталось понять, как из CI-системы мы можем менять параметры helm chart, описанные в values.yaml.

Для этого существует специальный ключ **--set**

Изменим NodePort для **frontend** в release, не меняя его в самом chart:
```console
helm upgrade --install hipster-shop kubernetes-templating/hipster-shop --namespace hipster-shop --set frontend.service.NodePort=31234
```

> Так как как мы меняем значение переменной для зависимости - перед названием переменной указываем имя (название chart) этой зависимости.  
> Если бы мы устанавливали chart frontend напрямую, то команда выглядела бы как --set service.NodePort=31234

```console
helm upgrade --install hipster-shop kubernetes-templating/hipster-shop --namespace hipster-shop --set frontend.service.NodePort=31234
Release "hipster-shop" has been upgraded. Happy Helming!
NAME: hipster-shop
LAST DEPLOYED: Tue Mar 21 23:05:07 2023
NAMESPACE: hipster-shop
STATUS: deployed
REVISION: 4
TEST SUITE: None
```



### Создаем свой helm chart | Задание со ⭐

Выберем сервис, который можно установить как зависимость, используя community chart's. Например, это может быть **Redis**.

- Удалим из all-hipster-shop.yaml часть манифеста касательно redis
- Добавим repo с redis

```console
helm repo add bitnami https://charts.bitnami.com/bitnami
"bitnami" has been added to your repositories

helm repo update
Hang tight while we grab the latest from your chart repositories...
...Successfully got an update from the "jetstack" chart repository
...Successfully got an update from the "chartmuseum" chart repository
...Successfully got an update from the "harbor" chart repository
...Successfully got an update from the "my-chartmuseum" chart repository
...Successfully got an update from the "incubator" chart repository
...Successfully got an update from the "bitnami" chart repository
...Successfully got an update from the "stable" chart repository
Update Complete. ⎈Happy Helming!⎈

```

- дополняем наш Charts.yaml

```yml
dependencies:
  - name: redis
    version: 17.6.0
    repository: https://charts.bitnami.com/bitnami
```

- обновляем dep для hipster-shop: helm dep update kubernetes-templating/hipster-shop
- выкатываем:

```console
helm upgrade --install hipster-shop kubernetes-templating/hipster-shop --namespace hipster-shop
Release "hipster-shop" has been upgraded. Happy Helming!
NAME: hipster-shop
LAST DEPLOYED: Fri Mar 24 11:15:29 2023
NAMESPACE: hipster-shop
STATUS: deployed
REVISION: 5
TEST SUITE: None
```

- Проверяем создание pod

```console
kubectl get pods -n hipster-shop
NAME                                     READY   STATUS             RESTART
cartservice-65cf6686f9-9zgwc             1/1     Running   0          2m51s
checkoutservice-5b46dfd9bb-rdlrf         1/1     Running   0          2m51s
currencyservice-5fbf6cfcc6-qjfwc         1/1     Running   0          2m52s
emailservice-86bfdd6b48-jv9bw            1/1     Running   0          2m52s
frontend-69c6ff75c7-p5v49                1/1     Running   0          2m52s
hipster-shop-redis-master-0              1/1     Running   0          2m51s
hipster-shop-redis-replicas-0            1/1     Running   0          2m51s
hipster-shop-redis-replicas-1            1/1     Running   0          109s
hipster-shop-redis-replicas-2            1/1     Running   0          71s
productcatalogservice-7bf75c85b8-hswst   1/1     Running   0          2m51s
recommendationservice-5bcf9f88c6-hz9k7   1/1     Running   0          2m52s
redis-cart-78746d49dc-r4sd8              1/1     Running   0          2m52s

```

```console
ls -la kubernetes-templating/hipster-shop/charts/
total 104
drwxr-xr-x 2 kirill kirill  4096 Mar 24 12:43 .
drwxr-xr-x 4 kirill kirill  4096 Mar 24 12:48 ..
-rw-r--r-- 1 kirill kirill  1655 Mar 24 12:43 frontend-0.1.0.tgz
-rw-r--r-- 1 kirill kirill 92518 Mar 24 12:43 redis-17.6.0.tgz
```

### Работа с helm-secrets | Необязательное задание

Разберемся как работает плагин **helm-secrets**. Для этого добавим в Helm chart секрет и научимся хранить его в зашифрованном виде.

Начнем с того, что установим плагин и необходимые для него зависимости :
```console
helm plugin install https://github.com/futuresimple/helm-secrets --version 2.0.2
```

> В домашней работы мы будем использовать PGP, но также можно воспользоваться KMS.

Сгенерируем новый PGP ключ:

```console
gpg --full-generate-key
```

После этого командой gpg -k можно проверить, что ключ появился:

```console
gpg -k
pub   rsa3072 2023-03-26 [SC]
      DF89BB3326101DABE31CD2DD3E0F2D1B45522B8D
uid           [ultimate] Kirill (otus) <admin@kropalik.ru>
sub   rsa3072 2023-03-26 [E]

```


Создадим новый файл secrets.yaml в директории kubernetestemplating/frontend со следующим содержимым:

```yml
visibleKey: hiddenValue
```

И попробуем зашифровать его: sops -e -i --pgp <$ID> secrets.yaml

```console
sops -e -i --pgp DF89BB3326101DABE31CD2DD3E0F2D1B45522B8D secrets.yaml
```

Проверим, что файл `secrets.yaml` изменился. Сейчас его содержание выглядим примерно так:
```yaml
visibleKey: ENC[AES256_GCM,data:zAOjngE6tODZTd0=,iv:8hL/tujG6ZFYViR6qC0Uu/pzwboO/JHebsXMS5vZ8Jc=,tag:+AWVlwtNnjZwiKMVCA9F6g==,type:str]
sops:
    kms: []
    gcp_kms: []
    azure_kv: []
    hc_vault: []
    age: []
    lastmodified: "2023-03-26T13:39:10Z"
    mac: ENC[AES256_GCM,data:RJhn6g4YIg1vB397Ku9CiirZl5C5L58Vb04Jb0dsFVp0QwFa0bDtCzrhtovwfz6DyOdmNs+JrRBttOh/LS0LwrHO3Sy6tAnlqiMovdMSmQpZGAR4HmCLjnafsrfvXB6ZaP6akpBfJ3YXEMJkqKMyLAZDhetvBJ8AK7nvJCgvYvI=,iv:LxUfRrQH/7jv4VKzt3x48+6DiT2c6n1IjbyB/A3Ydow=,tag:ewzcyMfWnN0DEXmSXsRSHQ==,type:str]
    pgp:
        - created_at: "2023-03-26T13:39:10Z"
          enc: |
            -----BEGIN PGP MESSAGE-----

            hQGMA4M+dmxDR366AQv+LeuhN8Ja0k8R5T42xcfMieHtkXcAQFcOZyJ8UHo6MHTQ
            +oTLGwLmPxTQUQZ6Ol/MrQKjtMvAmgF1+XUyipXIPcSLjHhPRRwRSJjrPGZc2j4f
            8+C0uNIhXTWecYPQhftTPpVxCBW4jgum6JU2Bj/MAnt450dBIrMcAqNvMKwKpKmp
            R3LJbz4Z1e/pRPOQEiI+bUcSnQHhTE4kA7jqZI0JbR+1gTV8o5MJ2fqg0g49dExI
            N6PzgzdwKH6R4uJ9UAmxedxnqqsKaUfEt2ZAc63XGum2Tw03pcMY8BgEM49J/CE0
            O+JQJ8wVGzdsmAN2A/OPHKYW434eNkJKGXyMNstQjJdcO283ofqlUAhg+XsYkce4
            lPZjc+KKrAMQl2nuGJv3MSgHoQCOgJC8VGSaRi019ylwhaWgco9y59zRnqITN66C
            mAzZrSKU7xb9es0VXlCHnJSRJ2MeQ9Y55yWx2/4Bw17OjhmnZ3jK7J0mw/rvOeVC
            Dq6M4x0xfMVIOekXKlAx0l4B0R6NZx7Q7HA76ZwJueX1/Y+X6Y1RFaPAbQwu+2yB
            6IhbTVMUd/kpQ1sSKMvyXUbxluTNNc65uX+Zqp14frGZG6B8dk4g8o8pWmDG3Oe5
            ufPWzHwycSHNfmHGgHjk
            =aUJB
            -----END PGP MESSAGE-----
          fp: DF89BB3326101DABE31CD2DD3E0F2D1B45522B8D
    unencrypted_suffix: _unencrypted
    version: 3.7.3
```
В таком виде файл уже можно коммитить в Git, но для начала - научимся
расшифровывать его. Можно использовать любой из инструментов:
```console
echo $(helm secrets decrypt ./secrets.yaml)
visibleKey: hiddenValue
```
```console
sops -d secrets.yaml
visibleKey: hiddenValue
```
Теперь, если мы передадим в helm файл `secrets.yaml` как values файл плагин helm-secrets поймет, что его надо расшифровать, а значение ключа
`visibleKey` подставить в соответствующий шаблон секрета.
Выкатывем:

```console
helm secrets upgrade --install frontend ./frontend -n hipster-shop  -f ./frontend/values.yaml  -f ./frontend/secrets.yaml
[helm-secrets] Decrypt: ./frontend/secrets.yaml
Release "frontend" does not exist. Installing it now.
NAME: frontend
LAST DEPLOYED: Sun Mar 26 14:26:24 2023
NAMESPACE: hipster-shop
STATUS: deployed
REVISION: 1
TEST SUITE: None

[helm-secrets] Removed: ./frontend/secrets.yaml.dec
```

Проверим, что секрет создан, и его содержимое соответствует нашим ожиданиям:

```console
echo $(kubectl get secret secret -n hipster-shop -o yaml | grep visibleKey | awk '{print $2}' | base64 -d)
hiddenValue
```

- В CI/CD плагин helm-secrets можно использовать для подготовки авторизации на различных сервисах
- Как обезопасить себя от коммита файлов с секретами - <https://github.com/zendesk/helm-secrets#important-tips>

### Проверка

Поместим все получившиеся helm chart's в наш установленный harbor в публичный проект.

Установим helm-push

```console
helm plugin install https://github.com/chartmuseum/helm-push.git
```

Создадим файл kubernetes-templating/repo.sh со следующим содержанием:

```bash
#!/bin/bash
helm repo add templating https://harbor.84.201.150.236.nip.io/chartrepo/library
helm push frontend-0.1.0.tgz oci://harbor.84.201.150.236.nip.io//library
```

авторизуемся в репозитории
```console
helm registry login -u admin harbor.84.201.150.236.nip.io
Password:
Login Succeeded
```


```console
./repo.sh
Pushed: harbor.84.201.150.236.nip.io/library/frontend:0.1.0
Digest: sha256:7f76a14218e21ac9e1197f5ffd1a265cd52a31631ca30fd85e37132f75659dec
```
Проверим:

```console
helm pull oci://harbor.84.201.150.236.nip.io//library/frontend --version 0.1.0

```

И развернем:

```console
helm upgrade --install hipster-shop templating/hipster-shop --namespace hipster-shop
helm upgrade --install frontend templating/frontend --namespace hipster-shop
```




Представим, что одна из команд разрабатывающих сразу несколько микросервисов нашего продукта решила, что helm не подходит для ее нужд и попробовала использовать решение на основе **jsonnet - kubecfg**.

Посмотрим на возможности этой утилиты. Работать будем с сервисами paymentservice и shippingservice.

Для начала - вынесем манифесты описывающие **service** и **deployment** для этих микросервисов из файла all-hipstershop.yaml в директорию kubernetes-templating/kubecfg

В итоге должно получиться четыре файла:

```console
tree -L 1 kubecfg
kubecfg
├── paymentservice-deployment.yaml
├── paymentservice-service.yaml
├── shippingservice-deployment.yaml
└── shippingservice-service.yaml
```

Можно заметить, что манифесты двух микросервисов очень похожи друг на друга и может иметь смысл генерировать их из какого-то шаблона.  
Попробуем сделать это.

Обновим release hipster-shop, проверим, что микросервисы paymentservice и shippingservice исчезли из установки и магазин стал работать некорректно (при нажатии на кнопку Add to Cart).

```console
helm upgrade --install hipster-shop kubernetes-templating/hipster-shop --namespace hipster-shop
Release "hipster-shop" does not exist. Installing it now.
NAME: hipster-shop
LAST DEPLOYED: Tue Apr  4 12:19:06 2023
NAMESPACE: hipster-shop
STATUS: deployed
REVISION: 1
TEST SUITE: None
```


Проверим, что микросервисы `paymentservice` и `shippingservice` исчезли из установки и магазин стал работать некорректно (при нажатии на кнопку `Add to Cart`)
```console
kubectl get all -A -l app=paymentservice
No resources found
```
```console
kubectl get all -A -l app=shippingservice
No resources found
```

Установим [kubecfg](https://github.com/vmware-archive/kubecfg/releases)
```console
wget https://github.com/vmware-archive/kubecfg/releases/download/v0.22.0/kubecfg-linux-amd64
mv kubecfg-linux-amd64 /usr/local/bin/kubecfg
sudo chmod +x /usr/local/bin/kubecfg
kubecfg version
kubecfg version: v0.22.0
jsonnet version: v0.17.0
client-go version: v0.0.0-master+$Format:%h$
```

Kubecfg предполагает хранение манифестов в файлах формата .jsonnet и их генерацию перед установкой. Пример такого файла
можно найти в [официальном репозитории](https://github.com/bitnami/kubecfg/blob/master/examples/guestbook.jsonnet)

Напишем по аналогии свой .jsonnet файл - services.jsonnet.

Для начала в файле мы должны указать libsonnet библиотеку, которую будем использовать для генерации манифестов. В домашней работе воспользуемся [готовой от bitnami](https://github.com/bitnami-labs/kube-libsonnet/)

```console
wget https://github.com/bitnami-labs/kube-libsonnet/raw/52ba963ca44f7a4960aeae9ee0fbee44726e481f/kube.libsonnet
```
> ❗ В kube.libsonnet исправим версию api для Deploymens и Service на apps/v1

Импортируем ее:

```json
local kube = import "kube.libsonnet";
```

Перейдем к основной части

Общая логика происходящего следующая:

1. Пишем общий для сервисов [шаблон](https://raw.githubusercontent.com/express42/otus-platform-snippets/master/Module-04/05-Templating/hipster-shop-jsonnet/common.jsonnet), включающий описание service и deployment
2. [Наследуемся](https://raw.githubusercontent.com/express42/otus-platform-snippets/master/Module-04/05-Templating/hipster-shop-jsonnet/payment-shipping.jsonnet) от него, указывая параметры для конкретных

services.jsonnet:

```json
local kube = import "kube.libsonnet";

local common(name) = {

  service: kube.Service(name) {
    target_pod:: $.deployment.spec.template,
  },

  deployment: kube.Deployment(name) {
    spec+: {
      template+: {
        spec+: {
          containers_: {
            common: kube.Container("common") {
              env: [{name: "PORT", value: "50051"}],
              ports: [{containerPort: 50051}],
              securityContext: {
                readOnlyRootFilesystem: true,
                runAsNonRoot: true,
                runAsUser: 10001,
              },
              readinessProbe: {
                  initialDelaySeconds: 20,
                  periodSeconds: 15,
                  exec: {
                      command: [
                          "/bin/grpc_health_probe",
                          "-addr=:50051",
                      ],
                  },
              },
              livenessProbe: {
                  initialDelaySeconds: 20,
                  periodSeconds: 15,
                  exec: {
                      command: [
                          "/bin/grpc_health_probe",
                          "-addr=:50051",
                      ],
                  },
              },
            },
          },
        },
      },
    },
  },
};


{
  catalogue: common("paymentservice") {
    deployment+: {
      spec+: {
        template+: {
          spec+: {
            containers_+: {
              common+: {
                name: "server",
                image: "gcr.io/google-samples/microservices-demo/paymentservice:v0.1.3",
              },
            },
          },
        },
      },
    },
  },

  payment: common("shippingservice") {
    deployment+: {
      spec+: {
        template+: {
          spec+: {
            containers_+: {
              common+: {
                name: "server",
                image: "gcr.io/google-samples/microservices-demo/shippingservice:v0.1.3",
              },
            },
          },
        },
      },
    },
  },
}
```

Проверим, что манифесты генерируются корректно:

```console
kubecfg show services.jsonnet
---
apiVersion: apps/v1
kind: Deployment
metadata:
  annotations: {}
  labels:
    name: paymentservice
  name: paymentservice
spec:
  minReadySeconds: 30
  replicas: 1
  selector:
    matchLabels:
      name: paymentservice
  strategy:
    rollingUpdate:
      maxSurge: 25%
      maxUnavailable: 25%
    type: RollingUpdate
  template:
    metadata:
      annotations: {}
      labels:
        name: paymentservice
    spec:
      containers:
      - args: []
        env:
        - name: PORT
          value: "50051"
        image: gcr.io/google-samples/microservices-demo/paymentservice:v0.1.3
        imagePullPolicy: IfNotPresent
        livenessProbe:
          exec:
            command:
            - /bin/grpc_health_probe
            - -addr=:50051
          initialDelaySeconds: 20
          periodSeconds: 15
        name: server
        ports:
        - containerPort: 50051
        readinessProbe:
          exec:
            command:
            - /bin/grpc_health_probe
            - -addr=:50051
          initialDelaySeconds: 20
          periodSeconds: 15
        securityContext:
          readOnlyRootFilesystem: true
          runAsNonRoot: true
          runAsUser: 10001
        stdin: false
        tty: false
        volumeMounts: []
      imagePullSecrets: []
      initContainers: []
      terminationGracePeriodSeconds: 30
      volumes: []
---
apiVersion: v1
kind: Service
metadata:
  annotations: {}
  labels:
    name: paymentservice
  name: paymentservice
spec:
  ports:
  - port: 50051
    targetPort: 50051
  selector:
    name: paymentservice
  type: ClusterIP
---
apiVersion: apps/v1
kind: Deployment
metadata:
  annotations: {}
  labels:
    name: shippingservice
  name: shippingservice
spec:
  minReadySeconds: 30
  replicas: 1
  selector:
    matchLabels:
      name: shippingservice
  strategy:
    rollingUpdate:
      maxSurge: 25%
      maxUnavailable: 25%
    type: RollingUpdate
  template:
    metadata:
      annotations: {}
      labels:
        name: shippingservice
    spec:
      containers:
      - args: []
        env:
        - name: PORT
          value: "50051"
        image: gcr.io/google-samples/microservices-demo/shippingservice:v0.1.3
        imagePullPolicy: IfNotPresent
        livenessProbe:
          exec:
            command:
            - /bin/grpc_health_probe
            - -addr=:50051
          initialDelaySeconds: 20
          periodSeconds: 15
        name: server
        ports:
        - containerPort: 50051
        readinessProbe:
          exec:
            command:
            - /bin/grpc_health_probe
            - -addr=:50051
          initialDelaySeconds: 20
          periodSeconds: 15
        securityContext:
          readOnlyRootFilesystem: true
          runAsNonRoot: true
          runAsUser: 10001
        stdin: false
        tty: false
        volumeMounts: []
      imagePullSecrets: []
      initContainers: []
      terminationGracePeriodSeconds: 30
      volumes: []
---
apiVersion: v1
kind: Service
metadata:
  annotations: {}
  labels:
    name: shippingservice
  name: shippingservice
spec:
  ports:
  - port: 50051
    targetPort: 50051
  selector:
    name: shippingservice
  type: ClusterIP
```

И установим их:
```console
kubecfg update services.jsonnet --namespace hipster-shop
INFO  Validating deployments paymentservice
INFO  validate object "apps/v1, Kind=Deployment"
INFO  Validating services paymentservice
INFO  validate object "/v1, Kind=Service"
INFO  Validating deployments shippingservice
INFO  validate object "apps/v1, Kind=Deployment"
INFO  Validating services shippingservice
INFO  validate object "/v1, Kind=Service"
INFO  Fetching schemas for 4 resources
INFO  Creating services paymentservice
INFO  Creating services shippingservice
INFO  Creating deployments paymentservice
INFO  Creating deployments shippingservice
```

Через какое-то время магазин снова должен заработать и товары можно добавить в корзину

### Kustomize

Отпилим еще один (cartservice) микросервис из all-hipstershop.yaml.yaml и займемся его kustomизацией.

В минимальном варианте реализуем установку на три окружения - hipster-shop (namespace hipster-shop), hipster-shop-prod (namespace hipster-shop-prod) и hipster-shop-dev (namespace hipster-shop-dev) из одних манифестов deployment и service.

Окружения должны отличаться:

- Набором labels во всех манифестах
- Префиксом названий ресурсов
- Для dev окружения значением переменной окружения REDIS_ADDR

Установим kustomize:

```console
curl -s https://api.github.com/repos/kubernetes-sigs/kustomize/releases/latest | grep browser_download_url | grep linux | cut -d '"' -f 4 | xargs curl -O -L
tar -xfv kustomize_v5.0.1_linux_amd64.tar.gz
chmod +x kustomize_v5.0.1_linux_amd64
sudo mv kustomize_v5.0.1_linux_amd64 /usr/local/bin/kustomize
```

Для namespace hipster-shop:

```yml
kustomize build .

apiVersion: v1
kind: Service
metadata:
  name: cartservice
  namespace: hipster-shop
spec:
  ports:
  - name: grpc
    port: 7070
    targetPort: 7070
  selector:
    app: cartservice
  type: ClusterIP
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: cartservice
  namespace: hipster-shop
spec:
  selector:
    matchLabels:
      app: cartservice
  template:
    metadata:
      labels:
        app: cartservice
    spec:
      containers:
      - env:
        - name: REDIS_ADDR
          value: redis-cart-master:6379
        - name: PORT
          value: "7070"
        - name: LISTEN_ADDR
          value: 0.0.0.0
        image: gcr.io/google-samples/microservices-demo/cartservice:v0.1.3
        livenessProbe:
          exec:
            command:
            - /bin/grpc_health_probe
            - -addr=:7070
            - -rpc-timeout=5s
          initialDelaySeconds: 15
          periodSeconds: 10
        name: server
        ports:
        - containerPort: 7070
        readinessProbe:
          exec:
            command:
            - /bin/grpc_health_probe
            - -addr=:7070
            - -rpc-timeout=5s
          initialDelaySeconds: 15
        resources:
          limits:
            cpu: 300m
            memory: 128Mi
          requests:
            cpu: 200m
            memory: 64Mi
```

Для namespace hipster-shop-dev:

```yml
kustomize build .
apiVersion: v1
kind: Service
metadata:
  labels:
    environment: dev
  name: dev-cartservice
  namespace: hipster-shop-dev
spec:
  ports:
  - name: grpc
    port: 7070
    targetPort: 7070
  selector:
    app: cartservice
    environment: dev
  type: ClusterIP
---
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    environment: dev
  name: dev-cartservice
  namespace: hipster-shop-dev
spec:
  selector:
    matchLabels:
      app: cartservice
      environment: dev
  template:
    metadata:
      labels:
        app: cartservice
        environment: dev
    spec:
      containers:
      - env:
        - name: REDIS_ADDR
          value: redis-cart:6379
        - name: PORT
          value: "7070"
        - name: LISTEN_ADDR
          value: 0.0.0.0
        image: gcr.io/google-samples/microservices-demo/cartservice:v0.1.3
        livenessProbe:
          exec:
            command:
            - /bin/grpc_health_probe
            - -addr=:7070
            - -rpc-timeout=5s
          initialDelaySeconds: 15
          periodSeconds: 10
        name: server
        ports:
        - containerPort: 7070
        readinessProbe:
          exec:
            command:
            - /bin/grpc_health_probe
            - -addr=:7070
            - -rpc-timeout=5s
          initialDelaySeconds: 15
        resources:
          limits:
            cpu: 300m
            memory: 128Mi
          requests:
            cpu: 200m
            memory: 64Mi
```

Задеплоим и проверим работу UI:

```console
kustomize build . | kubectl apply -f -

Warning: kubectl apply should be used on resource created by either kubectl create --save-config or kubectl apply
service/cartservice created
deployment.apps/cartservice created
```

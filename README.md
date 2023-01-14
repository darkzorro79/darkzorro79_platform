# darkzorro79_platform
# Otus Kubernetes course


## Настройка локального окружения. Запуск первого контейнера. Работа с kubectl

### Установка kubectl

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



### Установка Minikube

**Minikube** - наиболее универсальный вариант для развертывания локального окружения.

Установим последнюю доступную версию Minikube на локальную машину. Инструкции по установке доступны по [ссылке](https://kubernetes.io/docs/tasks/tools/install-minikube/).

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

#### Проверим, что подключение к кластеру работает корректно:

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

### Minikube

При установке кластера с использованием Minikube будет создан контейнер docker в котором будут работать все системные компоненты кластера Kubernetes.  
Можем убедиться в этом, зайдем на ВМ по SSH и посмотрим запущенные Docker контейнеры:

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
```


Проверим, что Kubernetes обладает некоторой устойчивостью к отказам, удалим все контейнеры:

```console
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

### kubectl

Эти же компоненты, но уже в виде pod можно увидеть в namespace kube-system:

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

Расшифруем: данной командой мы запросили у API **вывести список** (get) всех **pod** (pods) в **namespace** (-n, сокращенное от --namespace) **kube-system**.

Можно устроить еще одну проверку на прочность и удалить все pod с системными компонентами:

```
PS C:\Windows\system32> kubectl delete pod --all -n kube-system
pod "coredns-6d4b75cb6d-wbhzp" deleted
pod "etcd-minikube" deleted
pod "kube-apiserver-minikube" deleted
pod "kube-controller-manager-minikube" deleted
pod "kube-proxy-v5ql5" deleted
pod "kube-scheduler-minikube" deleted
pod "storage-provisioner" deleted
```

Проверим, что кластер находится в рабочем состоянии, команды **kubectl get cs** или **kubectl get componentstatuses**.
выведут состояние системных компонентов:

```console
PS C:\Windows\system32> kubectl get componentstatuses
Warning: v1 ComponentStatus is deprecated in v1.19+
NAME                 STATUS    MESSAGE                         ERROR
scheduler            Healthy   ok
etcd-0               Healthy   {"health":"true","reason":""}
controller-manager   Healthy   ok
```



### Dockerfile

Для выполнения домашней работы создадим Dockerfile, в котором будет описан образ:

1. Запускающий web-сервер на порту 8000
2. Отдающий содержимое директории /app внутри контейнера (например, если в директории /app лежит файл homework.html, то при запуске контейнера данный файл должен быть доступен по URL [http://localhost:8000/homework.html])
3. Работающий с UID 1001


```Dockerfile
FROM nginx:latest
WORKDIR /app
COPY homework.html /app
COPY default.conf /etc/nginx/conf.d/
RUN touch /var/run/nginx.pid && \
  chown -R 1001:1001 /var/run/nginx.pid && \
  chown -R 1001:1001 /var/cache/nginx && \
  chown -R 1001:1001 /app 
USER 1001:1001
EXPOSE 8000
CMD ["nginx", "-g", "daemon off;"]
```



После того, как Dockerfile будет готов:

* В корне репозитория создадим директорию kubernetesintro/web и поместим туда готовый Dockerfile
* Соберем из Dockerfile образ контейнера и поместим его в публичный Container Registry (например, Docker Hub)

```console
docker build -t darkzorro/otusdz1:v3 .
docker push darkzorro/otusdz1:v3
```

### Манифест pod

Напишем манифест web-pod.yaml для создания pod **web** c меткой **app** со значением **web**, содержащего один контейнер с названием **web**. Необходимо использовать ранее собранный образ с Docker Hub.

```yml
apiVersion: v1 # Версия API
kind: Pod # Объект, который создаем
metadata:
  name: web # Название Pod
  labels: # Метки в формате key: value
    app: web
spec: # Описание Pod
  containers: # Описание контейнеров внутри Pod
  - name: web # Название контейнера
    image: darkzorro/otusdz1:v3 # Образ из которого создается контейнер
```

Поместим манифест web-pod.yaml в директорию kubernetesintro и применим его:

```console
kubectl apply -f web-pod.yaml

pod/web created
```

После этого в кластере в namespace default должен появиться запущенный pod web:

```console
kubectl get pods

NAME   READY   STATUS    RESTARTS   AGE
web    1/1     Running   0          10s
```

В Kubernetes есть возможность получить манифест уже запущенного в кластере pod.

В подобном манифесте помимо описания pod будутфигурировать служебные поля (например, различные статусы) и значения, подставленные по умолчанию:

```console
kubectl get pod web -o yaml
```

### kubectl describe

Другой способ посмотреть описание pod - использовать ключ **describe**. Команда позволяет отследить текущее состояние объекта, а также события, которые с ним происходили:

```console
kubectl describe pod web
```

Успешный старт pod в kubectl describe выглядит следующим образом:

* scheduler определил, на какой ноде запускать pod
* kubelet скачал необходимый образ и запустил контейнер

```console
Events:
  Type    Reason     Age   From               Message
  ----    ------     ----  ----               -------
  Normal  Scheduled  28s   default-scheduler  Successfully assigned default/web to minikube
  Normal  Pulled     26s   kubelet            Container image "darkzorro/otusdz1:v3" already present on machine
  Normal  Created    26s   kubelet            Created container web
  Normal  Started    26s   kubelet            Started container web
```

При этом **kubectl describe** - хороший старт для поиска причин проблем с запуском pod.

Укажем в манифесте несуществующий тег образа web и применим его заново (kubectl apply -f web-pod.yaml).

Статус pod (kubectl get pods) должен измениться на **ErrImagePull/ImagePullBackOff**, а команда **kubectl describe pod web** поможет понять причину такого поведения:

```console
Events:
  Type     Reason     Age   From               Message
  ----     ------     ----  ----               -------
  Normal   Scheduled  3s    default-scheduler  Successfully assigned default/web to minikube
  Normal   Pulling    3s    kubelet            Pulling image "darkzorro/otusdz1:v5"
  Warning  Failed     1s    kubelet            Failed to pull image "darkzorro/otusdz1:v5": rpc error: code = Unknown desc = Error response from daemon: manifest for darkzorro/otusdz1:v5 not found: manifest unknown: manifest unknown
  Warning  Failed     1s    kubelet            Error: ErrImagePull
  Normal   BackOff    0s    kubelet            Back-off pulling image "darkzorro/otusdz1:v5"
  Warning  Failed     0s    kubelet            Error: ImagePullBackOff
```

Вывод **kubectl describe pod web** если мы забыли, что Container Registry могут быть приватными:

```console
Events:
  Warning Failed 2s kubelet, minikube Failed to pull image "quay.io/example/web:1.0": rpc error: code = Unknown desc =Error response from daemon: unauthorized: access to the requested resource is not authorized
```


### Init контейнеры

Добавим в наш pod [init контейнер](https://kubernetes.io/docs/concepts/workloads/pods/init-containers/), генерирующий страницу index.html.

**Init контейнеры** описываются аналогично обычным контейнерам в pod. Добавим в манифест web-pod.yaml описание init контейнера, соответствующее следующим требованиям:

* **image** init контейнера должен содержать **wget** (например, можно использовать busybox:1.31.0 или любой другой busybox актуальной версии)
* command init контейнера (аналог ENTRYPOINT в Dockerfile) укажите следующую:

```console
['sh', '-c', 'wget -O- https://tinyurl.com/otus-k8s-intro | sh']
```

### Volumes

Для того, чтобы файлы, созданные в **init контейнере**, были доступны основному контейнеру в pod нам понадобится использовать **volume** типа **emptyDir**.

У контейнера и у **init контейнера** должны быть описаны **volumeMounts** следующего вида:

```yml
volumeMounts:
- name: app
  mountPath: /app
```

web-pod.yaml

```yml
apiVersion: v1 
kind: Pod 
metadata:
  name: web
  labels:
    app: web
spec:
  containers:
  - name: web
    image: darkzorro/otusdz1:v3
    readinessProbe:
      httpGet:
        path: /index.html
        port: 8000
    livenessProbe:
      tcpSocket: { port: 8000 }
    volumeMounts:
    - name: app
      mountPath: /app
  initContainers:
  - name: init-web
    image: busybox:1.31.1
    command: ['sh', '-c', 'wget -O- https://tinyurl.com/otus-k8s-intro | sh']
    volumeMounts:
    - name: app
      mountPath: /app
  volumes:
  - name: app
    emptyDir: {}
```

### Запуск pod

Удалим запущенный pod web из кластера **kubectl delete pod web** и примените обновленный манифест web-pod.yaml

Отслеживать происходящее можно с использованием команды **kubectl get pods -w**

Должен получиться аналогичный вывод:

```console
kubectl apply -f web-pod.yaml | kubectl get pods -w
NAME   READY   STATUS     RESTARTS   AGE
web    0/1     Init:0/1   0          0s
web    0/1     Init:0/1   0          1s
web    0/1     PodInitializing   0          2s
web    0/1     Running           0          3s
web    1/1     Running           0          3s
```

### Проверка работы приложения

Проверим работоспособность web сервера. Существует несколько способов получить доступ к pod, запущенным внутри кластера.

Мы воспользуемся командой [kubectl port-forward](https://kubernetes.io/docs/tasks/access-application-cluster/port-forward-access-application-cluster/)

```console
kubectl port-forward web 8000:8000
```

Если все выполнено правильно, на локальном компьютере по ссылке <http://localhost:8000/index.html> должна открыться страница.

```console
 curl http://localhost:8000/index.html


StatusCode        : 200
StatusDescription : OK
Content           : <html>
                    <head/>
                    <body>
                    <!-- IMAGE BEGINS HERE -->
                    <font size="-3">
                    <pre><font color=white>0111010011111011110010000111011000001110000110010011101000001100101011110010
                    10011101000111110100101100000111011...
RawContent        : HTTP/1.1 200 OK
                    Connection: keep-alive
                    Accept-Ranges: bytes
                    Content-Length: 83486
                    Content-Type: text/html
                    Date: Sat, 14 Jan 2023 18:14:08 GMT
                    ETag: "63c2f00a-1461e"
                    Last-Modified: Sat, 14 Jan 2...
Forms             : {}
Headers           : {[Connection, keep-alive], [Accept-Ranges, bytes], [Content-Length, 83486], [Content-Type, text/htm
                    l]...}
Images            : {}
InputFields       : {}
Links             : {}
ParsedHtml        : mshtml.HTMLDocumentClass
RawContentLength  : 83486
```


### Hipster Shop

Давайте познакомимся с [приложением](https://github.com/GoogleCloudPlatform/microservices-demo) поближе и попробуем запустить внутри нашего кластера его компоненты.

Начнем с микросервиса **frontend**. Его исходный код доступен по [адресу](https://github.com/GoogleCloudPlatform/microservices-demo).

* Склонируем [репозиторий](https://github.com/GoogleCloudPlatform/microservices-demo) и соберем собственный образ для **frontend** (используем готовый Dockerfile)
* Поместим собранный образ на Docker Hub

```console
git clone https://github.com/GoogleCloudPlatform/microservices-demo.git
docker build -t darkzorro/hipster-frontend:v0.0.1 .
docker push darkzorro/hipster-frontend:v0.0.1
```

Рассмотрим альтернативный способ запуска pod в нашем Kubernetes кластере.

Мы уже умеем работать с манифестами (и это наиболее корректный подход к развертыванию ресурсов в Kubernetes), но иногда бывает удобно использовать ad-hoc режим и возможности Kubectl для создания ресурсов.

Разберем пример для запуска **frontend** pod:

```console
kubectl run frontend --image darkzorro/hipster-frontend:v0.0.1 --restart=Never
```

* **kubectl run** - запустить ресурс
* **frontend** - с именем frontend
* **--image** - из образа darkzorro/hipster-frontend:v0.0.1 (подставьте свой образ)
* **--restart=Never** указываем на то, что в качестве ресурса запускаем pod. [Подробности](https://kubernetes.io/docs/reference/kubectl/conventions/)

Один из распространенных кейсов использования ad-hoc режима - генерация манифестов средствами kubectl:

```console
kubectl run frontend --image darkzorro/hipster-frontend:v0.0.1 --restart=Never --dryrun -o yaml > frontend-pod.yaml
```

Рассмотрим дополнительные ключи:

* **--dry-run** - вывод информации о ресурсе без его реального создания
* **-o yaml** - форматирование вывода в YAML
* **> frontend-pod.yaml** - перенаправление вывода в файл


### Hipster Shop | Задание со ⭐

* Выясним причину, по которой pod **frontend** находится в статусе **Error**
* Создадим новый манифест **frontend-pod-healthy.yaml**. При его применении ошибка должна исчезнуть. Подсказки можно найти:
  * В логах - **kubectl logs frontend**
  * В манифесте по [ссылке](https://github.com/GoogleCloudPlatform/microservices-demo/blob/master/kubernetes-manifests/frontend.yaml)
* В результате, после применения исправленного манифеста pod **frontend** должен находиться в статусе **Running**
* Поместим исправленный манифест **frontend-pod-healthy.yaml** в директорию **kubernetes-intro**

1. Проверив лог pod можно заметить, что не заданы переменные окружения. Добавим их.
2. Так же можно свериться со списком необходимых переменных окружения из готового манифеста.
3. Добавим отсутствующие переменные окружения в наш yaml файл и пересоздадим pod.

```yml
- name: PRODUCT_CATALOG_SERVICE_ADDR
  value: "productcatalogservice:3550"
- name: CURRENCY_SERVICE_ADDR
  value: "currencyservice:7000"
- name: CART_SERVICE_ADDR
  value: "cartservice:7070"
- name: RECOMMENDATION_SERVICE_ADDR
  value: "recommendationservice:8080"
- name: SHIPPING_SERVICE_ADDR
  value: "shippingservice:50051"
- name: CHECKOUT_SERVICE_ADDR
  value: "checkoutservice:5050"
- name: AD_SERVICE_ADDR
  value: "adservice:9555"
```

**frontend**  в статусе Running.

```console
kubectl get pods

NAME       READY   STATUS    RESTARTS   AGE
frontend   1/1     Running   0          13s
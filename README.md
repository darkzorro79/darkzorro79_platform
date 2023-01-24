# darkzorro79_platform

## Сетевое взаимодействие Pod, сервисы

### Добавление проверок Pod

- Откроем файл с описанием Pod из предыдущего ДЗ **kubernetes-intro/web-pod.yml**
- Добавим в описание пода **readinessProbe**

```yml
    readinessProbe:
      httpGet:
        path: /index.html
        port: 80
```

- Запустим наш под командой **kubectl apply -f webpod.yml**

```console
kubectl apply -f web-pod.yaml
pod/web created
```

- Теперь выполним команду **kubectl get pod/web** и убедимся, что под перешел в состояние Running

```console
kubectl get po web

NAME   READY   STATUS    RESTARTS   AGE
web    0/1     Running   0          50s
```

Теперь сделаем команду **kubectl describe pod/web** (вывод объемный, но в нем много интересного)

- Посмотрим в конце листинга на список **Conditions**:

```console
kubectl describe po web

Conditions:
  Type              Status
  Initialized       True
  Ready             False
  ContainersReady   False
  PodScheduled      True
```


Также посмотрим на список событий, связанных с Pod:


  Также посмотрим на список событий, связанных с Pod:

```console
Events:
  Type     Reason     Age               From               Message
  ----     ------     ----              ----               -------
 Warning  Unhealthy  6s (x13 over 93s)  kubelet            Readiness probe failed: Get "http://172.17.0.3:80/index.html": dial tcp 172.17.0.3:80: connect: connection refused
```

Из листинга выше видно, что проверка готовности контейнера завершается неудачно. Это неудивительно - вебсервер в контейнере слушает порт 8000 (по условиям первого ДЗ).

Пока мы не будем исправлять эту ошибку, а добавим другой вид проверок: **livenessProbe**.

- Добавим в манифест проверку состояния веб-сервера:

```yml
    livenessProbe:
      tcpSocket: { port: 8000 }
```

- Запустим Pod с новой конфигурацией:

```console
kubectl apply -f web-pod.yaml
pod/web created

kubectl get pod/web
NAME   READY   STATUS    RESTARTS   AGE
web    0/1     Running   0          17s
```

Вопрос для самопроверки:

- Почему следующая конфигурация валидна, но не имеет смысла?

```yml
livenessProbe:
  exec:
    command:
      - 'sh'
      - '-c'
      - 'ps aux | grep my_web_server_process'
```

> Данная конфигурация не имеет смысла, так как не означает, что работающий веб сервер без ошибок отдает веб страницы.

- Бывают ли ситуации, когда она все-таки имеет смысл?

> Возможно, когда требуется проверка работы сервиса без доступа к нему из вне.

### Создание Deployment

В процессе изменения конфигурации Pod, мы столкнулись с неудобством обновления конфигурации пода через **kubectl** (и уже нашли ключик **--force** ).

В любом случае, для управления несколькими однотипными подами такой способ не очень подходит.  
Создадим **Deployment**, который упростит обновление конфигурации пода и управление группами подов.

- Для начала, создадим новую папку **kubernetes-networks** в нашем репозитории
- В этой папке создадим новый файл **web-deploy.yaml**

Начнем заполнять наш файл-манифест для Deployment:

```yml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web
spec:
  replicas: 3
  selector:      
    matchLabels: 
      app: web   
  template:      
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

 Для начала удалим старый под из кластера:

```console
kubectl delete pod/web --grace-period=0 --force
warning: Immediate deletion does not wait for confirmation that the running resource has been terminated. The resource may continue to run on the cluster indefinitely.
pod "web" deleted
```

- И приступим к деплою:

```console
kubectl apply -f web-deploy.yaml
deployment.apps/web created
```

- Посмотрим, что получилось:

```console
kubectl describe deployment web
Conditions:
  Type           Status  Reason
  ----           ------  ------
  Available      False   MinimumReplicasUnavailable
  Progressing    True    ReplicaSetUpdated
OldReplicaSets:  <none>
NewReplicaSet:   web-59cf4b5799 (3/3 replicas created)
Events:
  Type    Reason             Age   From                   Message
  ----    ------             ----  ----                   -------
  Normal  ScalingReplicaSet  3s    deployment-controller  Scaled up replica set web-59cf4b5799 to 3
```


- Поскольку мы не исправили **ReadinessProbe** , то поды, входящие в наш **Deployment**, не переходят в состояние Ready из-за неуспешной проверки
- Это влияет На состояние всего **Deployment** (строчка Available в блоке Conditions)
- Теперь самое время исправить ошибку! Поменяем в файле web-deploy.yaml следующие параметры:
  - Увеличим число реплик до 3 ( replicas: 3 )
  - Исправим порт в readinessProbe на порт 8000

```yml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web
spec:
  replicas: 3
  selector:      
    matchLabels: 
      app: web   
  template:      
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

- Применим изменения командой kubectl apply -f webdeploy.yaml

```console
kubectl apply -f web-deploy.yaml
deployment.apps/web configured
```

- Теперь проверим состояние нашего **Deployment** командой kubectl describe deploy/web и убедимся, что условия (Conditions) Available и Progressing выполняются (в столбце Status значение true)

```console
kubectl describe deployment web

Conditions:
  Type           Status  Reason
  ----           ------  ------
  Available      True    MinimumReplicasAvailable
  Progressing    True    NewReplicaSetAvailable
```

- Добавим в манифест ( web-deploy.yaml ) блок **strategy** (можно сразу перед шаблоном пода)

```yml
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 0
      maxSurge: 100%
```
- Применим изменения

```console
kubectl apply -f web-deploy.yaml
deployment.apps/web configured
```

```console
 kubespy trace deploy web
[←[32mADDED←[0m ←[36;1mapps/v1/Deployment←[0m]  default/web/web
←[1m    Rolling out Deployment revision 1eate ReplicaSet
←[0m    ✅ Deployment is currently available
    ✅ Rollout successful: new ReplicaSet marked 'available'[32mADDED←[0m←[0m←[2m]  default/web-74575f558c
←[0m←[2m    ⌛ Waiting for ReplicaSet to scale to 0 Pods (3 currently exist)
←[36;1mROLLOUT STATUS:mReady←[0m←[0m←[2m] ←[36mweb-74575f558c-ptgzd←[0m
←[0m- [←[33;1mCurrent rollout←[0m | Revision 1] [←[32mADDED←[0m]  default/web-74575f558c
    ✅ ReplicaSet is available [3 Pods available of a 3 minimum]
       - [←[32mReady←[0m] ←[36mweb-74575f558c-gwpxv←[0m
       - [←[32mReady←[0m] ←[36mweb-74575f558c-ptgzd←[0m
       - [←[32mReady←[0m] ←[36mweb-74575f558c-z9jz6←[0m
```

> добавляются сразу 3 новых пода

- Попробуем разные варианты деплоя с крайними значениями maxSurge и maxUnavailable (оба 0, оба 100%, 0 и 100%)
- За процессом можно понаблюдать с помощью kubectl get events --watch или установить [kubespy](https://github.com/pulumi/kubespy) и использовать его **kubespy trace deploy**

```yml
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 0
      maxSurge: 0
```

```console
kubectl apply -f web-deploy.yaml
The Deployment "web" is invalid: spec.strategy.rollingUpdate.maxUnavailable: Invalid value: intstr.IntOrString{Type:0, IntVal:0, StrVal:""}: may not be 0 when `maxSurge` is 0
```

> оба значения не могут быть одновременно равны 0

```yml
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 100%
      maxSurge: 0
```

```console
←[36;1mROLLOUT STATUS:rollout←[0m | Revision 2] [←[32mMODIFIED←[0m]  default/web-5d7bf6564dh incomplete status: [init-we←[0m- [←[33;1mCurrent rollout←[0m | Revision 2] [←[32mMODIFIED←[0m]  default/web-5d7bf6564d
    ✅ ReplicaSet is available [3 Pods available of a 3 minimum]2 available of a 3 minimum)th incomplete status: [init-we       
	   - [←[32mReady←[0m] ←[36mweb-5d7bf6564d-bq799←[0m6564d-bq799←[0m containers with unready status: [web]us: [init-we       
	   - [←[32mReady←[0m] ←[36mweb-5d7bf6564d-zdtkn←[0m6564d-zdtkn←[0m containers with unready status: [web]us: [init-we       
	   - [←[32mReady←[0m] ←[36mweb-5d7bf6564d-hm7gx←[0m6564d-hm7gx←[0m containers with unready status: [web]
       - [←[31;1mContainersNotReady←[0m] ←[36mweb-5d7bf6564d-hm7gx←[0m containers with unready status: [web]
```

> удаление 3 старых подов и затем создание трех новых

```yml
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 100%
      maxSurge: 100%
```

```console
kubectl get events -w

20m         Normal   Scheduled           pod/web-5d7bf6564d-bq799    Successfully assigned default/web-5d7bf6564d-bq799 to minikube
20m         Normal   Pulled              pod/web-5d7bf6564d-bq799    Container image "busybox:1.31.1" already present on machine
20m         Normal   Created             pod/web-5d7bf6564d-bq799    Created container init-web
20m         Normal   Started             pod/web-5d7bf6564d-bq799    Started container init-web
20m         Normal   Pulling             pod/web-5d7bf6564d-bq799    Pulling image "darkzorro/otusdz1:v4"
20m         Normal   Pulled              pod/web-5d7bf6564d-bq799    Successfully pulled image "darkzorro/otusdz1:v4" in 4.432456598s
20m         Normal   Created             pod/web-5d7bf6564d-bq799    Created container web
20m         Normal   Started             pod/web-5d7bf6564d-bq799    Started container web
0s          Normal   Killing             pod/web-5d7bf6564d-bq799    Stopping container web
20m         Normal   Scheduled           pod/web-5d7bf6564d-hm7gx    Successfully assigned default/web-5d7bf6564d-hm7gx to minikube
20m         Normal   Pulled              pod/web-5d7bf6564d-hm7gx    Container image "busybox:1.31.1" already present on machine
20m         Normal   Created             pod/web-5d7bf6564d-hm7gx    Created container init-web
20m         Normal   Started             pod/web-5d7bf6564d-hm7gx    Started container init-web
20m         Normal   Pulling             pod/web-5d7bf6564d-hm7gx    Pulling image "darkzorro/otusdz1:v4"
20m         Normal   Pulled              pod/web-5d7bf6564d-hm7gx    Successfully pulled image "darkzorro/otusdz1:v4" in 3.01642832s
20m         Normal   Created             pod/web-5d7bf6564d-hm7gx    Created container web
20m         Normal   Started             pod/web-5d7bf6564d-hm7gx    Started container web
0s          Normal   Killing             pod/web-5d7bf6564d-hm7gx    Stopping container web
20m         Normal   Scheduled           pod/web-5d7bf6564d-zdtkn    Successfully assigned default/web-5d7bf6564d-zdtkn to minikube
20m         Normal   Pulled              pod/web-5d7bf6564d-zdtkn    Container image "busybox:1.31.1" already present on machine
20m         Normal   Created             pod/web-5d7bf6564d-zdtkn    Created container init-web
20m         Normal   Started             pod/web-5d7bf6564d-zdtkn    Started container init-web
20m         Normal   Pulling             pod/web-5d7bf6564d-zdtkn    Pulling image "darkzorro/otusdz1:v4"
20m         Normal   Pulled              pod/web-5d7bf6564d-zdtkn    Successfully pulled image "darkzorro/otusdz1:v4" in 1.541074247s
20m         Normal   Created             pod/web-5d7bf6564d-zdtkn    Created container web
20m         Normal   Started             pod/web-5d7bf6564d-zdtkn    Started container web
0s          Normal   Killing             pod/web-5d7bf6564d-zdtkn    Stopping container web
20m         Normal   SuccessfulCreate    replicaset/web-5d7bf6564d   Created pod: web-5d7bf6564d-bq799
20m         Normal   SuccessfulCreate    replicaset/web-5d7bf6564d   Created pod: web-5d7bf6564d-zdtkn
20m         Normal   SuccessfulCreate    replicaset/web-5d7bf6564d   Created pod: web-5d7bf6564d-hm7gx
0s          Normal   SuccessfulDelete    replicaset/web-5d7bf6564d   Deleted pod: web-5d7bf6564d-zdtkn
0s          Normal   SuccessfulDelete    replicaset/web-5d7bf6564d   Deleted pod: web-5d7bf6564d-hm7gx
0s          Normal   SuccessfulDelete    replicaset/web-5d7bf6564d   Deleted pod: web-5d7bf6564d-bq799
20m         Normal   Killing             pod/web-74575f558c-gwpxv    Stopping container web
0s          Normal   Scheduled           pod/web-74575f558c-kkwkr    Successfully assigned default/web-74575f558c-kkwkr to minikube
20m         Normal   Killing             pod/web-74575f558c-ptgzd    Stopping container web
0s          Normal   Scheduled           pod/web-74575f558c-t6g8m    Successfully assigned default/web-74575f558c-t6g8m to minikube
0s          Normal   Scheduled           pod/web-74575f558c-x4cdh    Successfully assigned default/web-74575f558c-x4cdh to minikube
20m         Normal   Killing             pod/web-74575f558c-z9jz6    Stopping container web
20m         Normal   SuccessfulDelete    replicaset/web-74575f558c   Deleted pod: web-74575f558c-ptgzd
20m         Normal   SuccessfulDelete    replicaset/web-74575f558c   Deleted pod: web-74575f558c-z9jz6
20m         Normal   SuccessfulDelete    replicaset/web-74575f558c   Deleted pod: web-74575f558c-gwpxv
0s          Normal   SuccessfulCreate    replicaset/web-74575f558c   Created pod: web-74575f558c-t6g8m
0s          Normal   SuccessfulCreate    replicaset/web-74575f558c   Created pod: web-74575f558c-x4cdh
0s          Normal   SuccessfulCreate    replicaset/web-74575f558c   Created pod: web-74575f558c-kkwkr
20m         Normal   ScalingReplicaSet   deployment/web              Scaled down replica set web-74575f558c to 0 from 3
20m         Normal   ScalingReplicaSet   deployment/web              Scaled up replica set web-5d7bf6564d to 3 from 0
0s          Normal   ScalingReplicaSet   deployment/web              Scaled up replica set web-74575f558c to 3 from 0
0s          Normal   ScalingReplicaSet   deployment/web              Scaled down replica set web-5d7bf6564d to 0 from 3
0s          Normal   Pulled              pod/web-74575f558c-x4cdh    Container image "busybox:1.31.1" already present on machine
0s          Normal   Created             pod/web-74575f558c-x4cdh    Created container init-web
0s          Normal   Pulled              pod/web-74575f558c-kkwkr    Container image "busybox:1.31.1" already present on machine
0s          Normal   Created             pod/web-74575f558c-kkwkr    Created container init-web
0s          Normal   Started             pod/web-74575f558c-x4cdh    Started container init-web
0s          Normal   Started             pod/web-74575f558c-kkwkr    Started container init-web
0s          Normal   Pulled              pod/web-74575f558c-t6g8m    Container image "busybox:1.31.1" already present on machine
0s          Normal   Created             pod/web-74575f558c-t6g8m    Created container init-web
0s          Normal   Started             pod/web-74575f558c-t6g8m    Started container init-web
0s          Normal   Killing             pod/web-5d7bf6564d-zdtkn    Stopping container web
0s          Warning   FailedKillPod       pod/web-5d7bf6564d-zdtkn    error killing pod: failed to "KillContainer" for "web" with KillContainerError: "rpc error: code = Unknown desc = Error response from daemon: No such container: ef8cb1de19de350d6a77ddbd8b35806afec4ea0876600dfeb0ede2fa884b8911"
0s          Normal    Pulled              pod/web-74575f558c-t6g8m    Container image "darkzorro/otusdz1:v3" already present on machine
0s          Normal    Pulled              pod/web-74575f558c-kkwkr    Container image "darkzorro/otusdz1:v3" already present on machine
0s          Normal    Pulled              pod/web-74575f558c-x4cdh    Container image "darkzorro/otusdz1:v3" already present on machine
0s          Normal    Created             pod/web-74575f558c-kkwkr    Created container web
0s          Normal    Created             pod/web-74575f558c-t6g8m    Created container web
0s          Normal    Created             pod/web-74575f558c-x4cdh    Created container web
0s          Normal    Started             pod/web-74575f558c-kkwkr    Started container web
0s          Normal    Started             pod/web-74575f558c-x4cdh    Started container web
0s          Normal    Started             pod/web-74575f558c-t6g8m    Started container web
```

> Одновременное удаление трех старых и создание трех новых подов

### Создание Service

Для того, чтобы наше приложение было доступно внутри кластера (а тем более - снаружи), нам потребуется объект типа **Service** . Начнем с самого распространенного типа сервисов - **ClusterIP**.

- ClusterIP выделяет для каждого сервиса IP-адрес из особого диапазона (этот адрес виртуален и даже не настраивается на сетевых интерфейсах)
- Когда под внутри кластера пытается подключиться к виртуальному IP-адресу сервиса, то нода, где запущен под меняет адрес получателя в сетевых пакетах на настоящий адрес пода.
- Нигде в сети, за пределами ноды, виртуальный ClusterIP не встречается.

ClusterIP удобны в тех случаях, когда:

- Нам не надо подключаться к конкретному поду сервиса
- Нас устраивается случайное расределение подключений между подами
- Нам нужна стабильная точка подключения к сервису, независимая от подов, нод и DNS-имен

Например:

- Подключения клиентов к кластеру БД (multi-read) или хранилищу
- Простейшая (не совсем, use IPVS, Luke) балансировка нагрузки внутри кластера

Итак, создадим манифест для нашего сервиса в папке kubernetes-networks.

- Файл web-svc-cip.yaml:

```yml
apiVersion: v1
kind: Service
metadata:
  name: web-svc-cip
spec:
  selector:
    app: web
  type: ClusterIP
  ports:
    - protocol: TCP
      port: 80
      targetPort: 8000
```

- Применим изменения: kubectl apply -f web-svc-cip.yaml

```console
kubectl apply -f web-svc-cip.yaml
service/web-svc-cip created
```

- Проверим результат (отметим назначенный CLUSTER-IP):

```console
kubectl get svc

NAME          TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)   AGE
kubernetes    ClusterIP   10.96.0.1       <none>        443/TCP   48m
web-svc-cip   ClusterIP   10.97.181.101   <none>        80/TCP    13s
```

Подключимся к ВМ Minikube (команда minikube ssh и затем sudo -i ):

- Сделаем curl <http://10.97.181.101/index.html> - работает!

```console
sudo -i
curl http://10.97.181.101/index.html
```

- Сделаем ping 10.97.181.101 - пинга нет

```console
ping 10.97.181.101 
PING 10.97.181.101 (10.97.181.101): 56 data bytes
```

- Сделаем arp -an , ip addr show - нигде нет ClusterIP
- Сделаем iptables --list -nv -t nat - вот где наш кластерный IP!

```console
iptables --list -nv -t nat | grep 10.97.181.101 -B 6 -A 3
Chain KUBE-SERVICES (2 references)
 pkts bytes target     prot opt in     out     source               destination
    0     0 KUBE-SVC-NPX46M4PTMTKRN6Y  tcp  --  *      *       0.0.0.0/0            10.96.0.1            /* default/kubernetes:https cluster IP */ tcp dpt:443
    0     0 KUBE-SVC-TCOU7JCQXEZGVUNU  udp  --  *      *       0.0.0.0/0            10.96.0.10           /* kube-system/kube-dns:dns cluster IP */ udp dpt:53
    0     0 KUBE-SVC-ERIFXISQEP7F7OF4  tcp  --  *      *       0.0.0.0/0            10.96.0.10           /* kube-system/kube-dns:dns-tcp cluster IP */ tcp dpt:53
    0     0 KUBE-SVC-JD5MR3NA4I4DYORP  tcp  --  *      *       0.0.0.0/0            10.96.0.10           /* kube-system/kube-dns:metrics cluster IP */ tcp dpt:9153
    1    60 KUBE-SVC-6CZTMAROCN3AQODZ  tcp  --  *      *       0.0.0.0/0            10.97.181.101        /* default/web-svc-cip cluster IP */ tcp dpt:80
  479 28724 KUBE-NODEPORTS  all  --  *      *       0.0.0.0/0            0.0.0.0/0            /* kubernetes service nodeports; NOTE: this must be the last rule in this chain */ ADDRTYPE match dst-type LOCAL

Chain KUBE-SVC-6CZTMAROCN3AQODZ (1 references)
 pkts bytes target     prot opt in     out     source               destination
    1    60 KUBE-MARK-MASQ  tcp  --  *      *      !10.244.0.0/16        10.97.181.101        /* default/web-svc-cip cluster IP */ tcp dpt:80
    1    60 KUBE-SEP-R7GFZ2Y4ZSCTFIRE  all  --  *      *       0.0.0.0/0            0.0.0.0/0            /* default/web-svc-cip -> 172.17.0.3:8000 */ statistic mode random probability 0.33333333349
    0     0 KUBE-SEP-Z6QHC4C2JAQDF7MX  all  --  *      *       0.0.0.0/0            0.0.0.0/0            /* default/web-svc-cip -> 172.17.0.4:8000 */ statistic mode random probability 0.50000000000
    0     0 KUBE-SEP-C5Q7WHV7ALQOOLAZ  all  --  *      *       0.0.0.0/0            0.0.0.0/0            /* default/web-svc-cip -> 172.17.0.5:8000 */
```

- Нужное правило находится в цепочке KUBE-SERVICES
- Затем мы переходим в цепочку KUBE-SVC-..... - здесь находятся правила "балансировки" между цепочками KUBE-SEP-..... (SVC - очевидно Service)
- В цепочках KUBE-SEP-..... находятся конкретные правила перенаправления трафика (через DNAT) (SEP - Service Endpoint)
```console
Chain KUBE-SEP-C5Q7WHV7ALQOOLAZ (1 references)
 pkts bytes target     prot opt in     out     source               destination
    0     0 KUBE-MARK-MASQ  all  --  *      *       172.17.0.5           0.0.0.0/0            /* default/web-svc-cip */
    0     0 DNAT       tcp  --  *      *       0.0.0.0/0            0.0.0.0/0            /* default/web-svc-cip */ tcp to:172.17.0.5:8000

Chain KUBE-SEP-R7GFZ2Y4ZSCTFIRE (1 references)
 pkts bytes target     prot opt in     out     source               destination
    0     0 KUBE-MARK-MASQ  all  --  *      *       172.17.0.3           0.0.0.0/0            /* default/web-svc-cip */
    1    60 DNAT       tcp  --  *      *       0.0.0.0/0            0.0.0.0/0            /* default/web-svc-cip */ tcp to:172.17.0.3:8000


Chain KUBE-SEP-Z6QHC4C2JAQDF7MX (1 references)
 pkts bytes target     prot opt in     out     source               destination
    0     0 KUBE-MARK-MASQ  all  --  *      *       172.17.0.4           0.0.0.0/0            /* default/web-svc-cip */
    0     0 DNAT       tcp  --  *      *       0.0.0.0/0            0.0.0.0/0            /* default/web-svc-cip */ tcp to:172.17.0.4:8000
```

> Подробное описание можно почитать [тут](https://msazure.club/kubernetes-services-and-iptables/)

### Включение IPVS

Итак, с версии 1.0.0 Minikube поддерживает работу kubeproxy в режиме IPVS. Попробуем включить его "наживую".

> При запуске нового инстанса Minikube лучше использовать ключ **--extra-config** и сразу указать, что мы хотим IPVS: **minikube start --extra-config=kube-proxy.mode="ipvs"**

- Включим IPVS для kube-proxy, исправив ConfigMap (конфигурация Pod, хранящаяся в кластере)
  - Выполним команду **kubectl --namespace kube-system edit configmap/kube-proxy**
  - Или minikube dashboard (далее надо выбрать namespace kube-system, Configs and Storage/Config Maps)
- Теперь найдем в файле конфигурации kube-proxy строку **mode: ""**
- Изменим значение **mode** с пустого на **ipvs** и добавим параметр **strictARP: true** и сохраним изменения

```yml
ipvs:
  strictARP: true
mode: "ipvs"
```

- Теперь удалим Pod с kube-proxy, чтобы применить новую конфигурацию (он входит в DaemonSet и будет запущен автоматически)

```console
kubectl --namespace kube-system delete pod --selector='k8s-app=kube-proxy'
pod "kube-proxy-g9749" deleted
```

> Описание работы и настройки [IPVS в K8S](https://github.com/kubernetes/kubernetes/blob/master/pkg/proxy/ipvs/README.md)  
> Причины включения strictARP описаны [тут](https://github.com/metallb/metallb/issues/153)

- После успешного рестарта kube-proxy выполним команду minikube ssh и проверим, что получилось
- Выполним команду **iptables --list -nv -t nat** в ВМ Minikube
- Что-то поменялось, но старые цепочки на месте (хотя у них теперь 0 references) �
  - kube-proxy настроил все по-новому, но не удалил мусор
  - Запуск kube-proxy --cleanup в нужном поде - тоже не помогает
  
 
 Полностью очистим все правила iptables:

- Создадим в ВМ с Minikube файл /tmp/iptables.cleanup

```console
*nat
-A POSTROUTING -s 172.17.0.0/16 ! -o docker0 -j MASQUERADE
COMMIT
*filter
COMMIT
*mangle
COMMIT
```


- Применим конфигурацию: iptables-restore /tmp/iptables.cleanup

```console
iptables-restore /tmp/iptables.cleanup
```

- Теперь надо подождать (примерно 30 секунд), пока kube-proxy восстановит правила для сервисов
- Проверим результат iptables --list -nv -t nat

```console
iptables --list -nv -t nat

Chain PREROUTING (policy ACCEPT 0 packets, 0 bytes)
 pkts bytes target     prot opt in     out     source               destination

Chain INPUT (policy ACCEPT 0 packets, 0 bytes)
 pkts bytes target     prot opt in     out     source               destination

Chain OUTPUT (policy ACCEPT 22 packets, 1320 bytes)
 pkts bytes target     prot opt in     out     source               destination

Chain POSTROUTING (policy ACCEPT 22 packets, 1320 bytes)
 pkts bytes target     prot opt in     out     source               destination
    0     0 MASQUERADE  all  --  *      !docker0  172.17.0.0/16        0.0.0.0/0
# iptables --list -nv -t nat
Chain PREROUTING (policy ACCEPT 0 packets, 0 bytes)
 pkts bytes target     prot opt in     out     source               destination
    0     0 KUBE-SERVICES  all  --  *      *       0.0.0.0/0            0.0.0.0/0            /* kubernetes service portals */

Chain INPUT (policy ACCEPT 0 packets, 0 bytes)
 pkts bytes target     prot opt in     out     source               destination

Chain OUTPUT (policy ACCEPT 47 packets, 2820 bytes)
 pkts bytes target     prot opt in     out     source               destination
  120  7216 KUBE-SERVICES  all  --  *      *       0.0.0.0/0            0.0.0.0/0            /* kubernetes service portals */

Chain POSTROUTING (policy ACCEPT 47 packets, 2820 bytes)
 pkts bytes target     prot opt in     out     source               destination
  120  7216 KUBE-POSTROUTING  all  --  *      *       0.0.0.0/0            0.0.0.0/0            /* kubernetes postrouting rules */
    0     0 MASQUERADE  all  --  *      !docker0  172.17.0.0/16        0.0.0.0/0

Chain KUBE-FIREWALL (0 references)
 pkts bytes target     prot opt in     out     source               destination
    0     0 KUBE-MARK-DROP  all  --  *      *       0.0.0.0/0            0.0.0.0/0

Chain KUBE-KUBELET-CANARY (0 references)
 pkts bytes target     prot opt in     out     source               destination

Chain KUBE-LOAD-BALANCER (0 references)
 pkts bytes target     prot opt in     out     source               destination
    0     0 KUBE-MARK-MASQ  all  --  *      *       0.0.0.0/0            0.0.0.0/0

Chain KUBE-MARK-DROP (1 references)
 pkts bytes target     prot opt in     out     source               destination
    0     0 MARK       all  --  *      *       0.0.0.0/0            0.0.0.0/0            MARK or 0x8000

Chain KUBE-MARK-MASQ (2 references)
 pkts bytes target     prot opt in     out     source               destination
    0     0 MARK       all  --  *      *       0.0.0.0/0            0.0.0.0/0            MARK or 0x4000

Chain KUBE-NODE-PORT (1 references)
 pkts bytes target     prot opt in     out     source               destination

Chain KUBE-POSTROUTING (1 references)
 pkts bytes target     prot opt in     out     source               destination
    0     0 MASQUERADE  all  --  *      *       0.0.0.0/0            0.0.0.0/0            /* Kubernetes endpoints dst ip:port, source ip for solving hairpin purpose */ match-set KUBE-LOOP-BACK dst,dst,src
   52  3120 RETURN     all  --  *      *       0.0.0.0/0            0.0.0.0/0            mark match ! 0x4000/0x4000
    0     0 MARK       all  --  *      *       0.0.0.0/0            0.0.0.0/0            MARK xor 0x4000
    0     0 MASQUERADE  all  --  *      *       0.0.0.0/0            0.0.0.0/0            /* kubernetes service traffic requiring SNAT */ random-fully

Chain KUBE-SERVICES (2 references)
 pkts bytes target     prot opt in     out     source               destination
    0     0 KUBE-MARK-MASQ  all  --  *      *      !10.244.0.0/16        0.0.0.0/0            /* Kubernetes service cluster ip + port for masquerade purpose */ match-set KUBE-CLUSTER-IP dst,dst
   36  2160 KUBE-NODE-PORT  all  --  *      *       0.0.0.0/0            0.0.0.0/0            ADDRTYPE match dst-type LOCAL
    0     0 ACCEPT     all  --  *      *       0.0.0.0/0            0.0.0.0/0            match-set KUBE-CLUSTER-IP dst,dst
```

- Итак, лишние правила удалены и мы видим только актуальную конфигурацию
  - kube-proxy периодически делает полную синхронизацию правил в своих цепочках)
- Как посмотреть конфигурацию IPVS? Ведь в ВМ нет утилиты ipvsadm ?
  - В ВМ выполним команду toolbox - в результате мы окажется в контейнере с Fedora
  - Теперь установим ipvsadm: dnf install -y ipvsadm && dnf clean all

Выполним ipvsadm --list -n и среди прочих сервисов найдем наш:

```console
ipvsadm --list -n

IP Virtual Server version 1.2.1 (size=4096)
Prot LocalAddress:Port Scheduler Flags
  -> RemoteAddress:Port           Forward Weight ActiveConn InActConn
TCP  10.96.0.1:443 rr
  -> 192.168.136.17:8443          Masq    1      0          0
TCP  10.96.0.10:53 rr
  -> 172.17.0.2:53                Masq    1      0          0
TCP  10.96.0.10:9153 rr
  -> 172.17.0.2:9153              Masq    1      0          0
TCP  10.97.181.101:80 rr
  -> 172.17.0.3:8000              Masq    1      0          0
  -> 172.17.0.4:8000              Masq    1      0          0
  -> 172.17.0.5:8000              Masq    1      0          0
UDP  10.96.0.10:53 rr
  -> 172.17.0.2:53                Masq    1      0          0
```

- Теперь выйдем из контейнера toolbox и сделаем ping кластерного IP:

```console
ping 10.97.181.101

PING 10.97.181.101 (10.97.181.101): 56 data bytes
64 bytes from 10.97.181.101: seq=0 ttl=64 time=0.054 ms
64 bytes from 10.97.181.101: seq=1 ttl=64 time=0.040 ms
64 bytes from 10.97.181.101: seq=2 ttl=64 time=0.055 ms
64 bytes from 10.97.181.101: seq=3 ttl=64 time=0.055 ms
```

Итак, все работает. Но почему пингуется виртуальный IP?

Все просто - он уже не такой виртуальный. Этот IP теперь есть на интерфейсе kube-ipvs0:

```console
 ip addr show kube-ipvs0
13: kube-ipvs0: <BROADCAST,NOARP> mtu 1500 qdisc noop state DOWN group default
    link/ether 8e:dd:9b:62:3f:37 brd ff:ff:ff:ff:ff:ff
    inet 10.96.0.10/32 scope global kube-ipvs0
       valid_lft forever preferred_lft forever
    inet 10.97.181.101/32 scope global kube-ipvs0
       valid_lft forever preferred_lft forever
    inet 10.96.0.1/32 scope global kube-ipvs0
       valid_lft forever preferred_lft forever
```


> Также, правила в iptables построены по-другому. Вместо цепочки правил для каждого сервиса, теперь используются хэш-таблицы (ipset). Можем посмотреть их, установив утилиту ipset в toolbox .

```console
ipset list

Name: KUBE-CLUSTER-IP
Type: hash:ip,port
Revision: 5
Header: family inet hashsize 1024 maxelem 65536
Size in memory: 512
References: 2
Number of entries: 5
Members:
10.96.0.10,udp:53
10.96.0.1,tcp:443
10.96.0.10,tcp:53
10.96.0.10,tcp:9153
10.97.181.101,tcp:80

Name: KUBE-LOOP-BACK
Type: hash:ip,port,ip
Revision: 5
Header: family inet hashsize 1024 maxelem 65536
Size in memory: 680
References: 1
Number of entries: 6
Members:
172.17.0.3,tcp:8000,172.17.0.3
172.17.0.2,udp:53,172.17.0.2
172.17.0.2,tcp:53,172.17.0.2
172.17.0.5,tcp:8000,172.17.0.5
172.17.0.2,tcp:9153,172.17.0.2
172.17.0.4,tcp:8000,172.17.0.4
```


### Работа с LoadBalancer и Ingress - Установка MetalLB

MetalLB позволяет запустить внутри кластера L4-балансировщик, который будет принимать извне запросы к сервисам и раскидывать их между подами. Установка его проста:

```console
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.9.3/manifests/namespace.yaml
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.9.3/manifests/metallb.yaml
kubectl create secret generic -n metallb-system memberlist --from-literal=secretkey="$(openssl rand -base64 128)"
```

> ❗ В продуктиве так делать не надо. Сначала стоит скачать файл и разобраться, что там внутри

Проверим, что были созданы нужные объекты:

```console
kubectl --namespace metallb-system get all

NAME                              READY   STATUS    RESTARTS   AGE
pod/controller-7696f658c8-dgp2x   1/1     Running   0          17m
pod/speaker-z4v6r                 1/1     Running   0          17m

NAME                     DESIRED   CURRENT   READY   UP-TO-DATE   AVAILABLE   NODE SELECTOR                 AGE
daemonset.apps/speaker   1         1         1       1            1           beta.kubernetes.io/os=linux   17m

NAME                         READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/controller   1/1     1            1           17m

NAME                                    DESIRED   CURRENT   READY   AGE
replicaset.apps/controller-7696f658c8   1         1         1       17m
```

Теперь настроим балансировщик с помощью ConfigMap

- Создадим манифест metallb-config.yaml в папке kubernetes-networks:

```yml
apiVersion: v1
kind: ConfigMap
metadata:
  namespace: metallb-system
  name: config
data:
  config: |
    address-pools:
      - name: default
        protocol: layer2
        addresses:
          - "172.17.255.1-172.17.255.255"
```


- В конфигурации мы настраиваем:
  - Режим L2 (анонс адресов балансировщиков с помощью ARP)
  - Создаем пул адресов 172.17.255.1-172.17.255.255 - они будут назначаться сервисам с типом LoadBalancer
- Теперь можно применить наш манифест: kubectl apply -f metallb-config.yaml
- Контроллер подхватит изменения автоматически

```console
kubectl apply -f metallb-config.yaml
configmap/config created
```

### MetalLB | Проверка конфигурации

Сделаем копию файла web-svc-cip.yaml в web-svc-lb.yaml и откроем его в редакторе:

```yml
apiVersion: v1
kind: Service
metadata:
  name: web-svc-lb
spec:
  selector:
    app: web
  type: LoadBalancer
  ports:
    - protocol: TCP
      port: 80
      targetPort: 8000
```

- Применим манифест

```console
kubectl apply -f web-svc-lb.yaml
service/web-svc-lb created
```

- Теперь посмотрим логи пода-контроллера MetalLB

```console
kubectl --namespace metallb-system logs $(kubectl --namespace metallb-system get po | findstr controller-).split(' ')[0]

{"caller":"service.go:114","event":"ipAllocated","ip":"172.17.255.1","msg":"IP address assigned by controller","service":"default/web-svc-lb","ts":"2023-01-21T10:55:15.175301092Z"}
```

Обратим внимание на назначенный IP-адрес (или посмотрим его в выводе kubectl describe svc websvc-lb)

```console
kubectl describe svc web-svc-lb

Name:                     web-svc-lb
Namespace:                default
Labels:                   <none>
Annotations:              <none>
Selector:                 app=web
Type:                     LoadBalancer
IP Family Policy:         SingleStack
IP Families:              IPv4
IP:                       10.97.235.18
IPs:                      10.97.235.18
LoadBalancer Ingress:     172.17.255.1
Port:                     <unset>  80/TCP
TargetPort:               8000/TCP
NodePort:                 <unset>  32363/TCP
Endpoints:                172.17.0.2:8000,172.17.0.4:8000,172.17.0.5:8000
Session Affinity:         None
External Traffic Policy:  Cluster
Events:                   <none>
```

- Если мы попробуем открыть URL <http://172.17.255.1/index.html>, то... ничего не выйдет.

- Это потому, что сеть кластера изолирована от нашей основной ОС (а ОС не знает ничего о подсети для балансировщиков)
- Чтобы это поправить, добавим статический маршрут:
  - В реальном окружении это решается добавлением нужной подсети на интерфейс сетевого оборудования
  - Или использованием L3-режима (что потребует усилий от сетевиков, но более предпочтительно)

- Найдем IP-адрес виртуалки с Minikube. Например так:

```console
minikube ssh

ip addr show eth0
2: eth0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc mq state UP group default qlen 1000
    link/ether 00:0c:29:5b:8e:f3 brd ff:ff:ff:ff:ff:ff
    inet 192.168.136.17/24 brd 192.168.136.255 scope global dynamic eth0
       valid_lft 1117sec preferred_lft 1117sec
````

- Добавим маршрут в вашей ОС на IP-адрес Minikube:

```console
route add 172.17.255.0/24 192.168.136.17
 ОК
```


DISCLAIMER:

Добавление маршрута может иметь другой синтаксис (например, ip route add 172.17.255.0/24 via 192.168.64.4 в ОС Linux) или вообще не сработать (в зависимости от VM Driver в Minkube).

В этом случае, не надо расстраиваться - работу наших сервисов и манифестов можно проверить из консоли Minikube, просто будет не так эффектно.

> P.S. - Самый простой способ найти IP виртуалки с minikube - minikube ip

Все получилось, можно открыть в браузере URL с IP-адресом нашего балансировщика и посмотреть, как космические корабли бороздят просторы вселенной.

Если пообновлять страничку с помощью Ctrl-F5 (т.е. игнорируя кэш), то будет видно, что каждый наш запрос приходит на другой под. Причем, порядок смены подов - всегда один и тот же.

Так работает IPVS - по умолчанию он использует **rr** (Round-Robin) балансировку.

К сожалению, выбрать алгоритм на уровне манифеста сервиса нельзя. Но когда-нибудь, эта полезная фича [появится](https://kubernetes.io/blog/2018/07/09/ipvs-based-in-cluster-load-balancing-deep-dive/).

> Доступные алгоритмы балансировки описаны [здесь](https://github.com/kubernetes/kubernetes/blob/1cb3b5807ec37490b4582f22d991c043cc468195/pkg/proxy/apis/config/types.go#L185) и появится [здесь](http://www.linuxvirtualserver.org/docs/scheduling.html).

### Задание со ⭐ | DNS через MetalLB

- Сделаем сервис LoadBalancer, который откроет доступ к CoreDNS снаружи кластера (позволит получать записи через внешний IP). Например, nslookup web.default.cluster.local 172.17.255.10.
- Поскольку DNS работает по TCP и UDP протоколам - учтем это в конфигурации. Оба протокола должны работать по одному и тому же IP-адресу балансировщика.
- Полученные манифесты положим в подкаталог ./coredns

> 😉 [Hint](https://metallb.universe.tf/usage/)

Для выполнения задания создадим манифест с двумя сервисами типа LB включающие размещение на общем IP:

- аннотацию **metallb.universe.tf/allow-shared-ip** равную для обоих сервисов
- spec.loadBalancerIP равный для обоих сервисов

coredns-svc-lb.yaml

```yml
apiVersion: v1
kind: Service
metadata:
  name: coredns-svc-lb-tcp
  annotations:
    metallb.universe.tf/allow-shared-ip: coredns
spec:
  loadBalancerIP: 172.17.255.2
  selector:
    k8s-app: kube-dns
  type: LoadBalancer
  ports:
    - protocol: TCP
      port: 53
      targetPort: 53
---
apiVersion: v1
kind: Service
metadata:
  name: coredns-svc-lb-udp
  annotations:
    metallb.universe.tf/allow-shared-ip: coredns
spec:
  loadBalancerIP: 172.17.255.2
  selector:
    k8s-app: kube-dns
  type: LoadBalancer
  ports:
    - protocol: UDP
      port: 53
      targetPort: 53
```

Применим манифест:

```console
kubectl apply -f coredns-svc-lb.yaml -n kube-system
service/coredns-svc-lb-tcp created
service/coredns-svc-lb-udp created
```


Проверим, что сервисы создались:

```console
kubectl get svc -n kube-system | grep coredns-svc
coredns-svc-lb-tcp   LoadBalancer   10.99.145.48   172.17.255.2   53:30803/TCP             7m30s
coredns-svc-lb-udp   LoadBalancer   10.96.43.246   172.17.255.2   53:31367/UDP             7m30s
```

Обратимся к DNS:

```console
nslookup web-svc-cip.default.svc.cluster.local 172.17.255.2

╤хЁтхЁ:  coredns-svc-lb-udp.kube-system.svc.cluster.local
Address:  172.17.255.2

╚ь :     web-svc-cip.default.svc.cluster.local
Address:  10.97.181.101
```

### Создание Ingress

Теперь, когда у нас есть балансировщик, можно заняться Ingress-контроллером и прокси:

- неудобно, когда на каждый Web-сервис надо выделять свой IP-адрес
- а еще хочется балансировку по HTTP-заголовкам (sticky sessions)

Для нашего домашнего задания возьмем почти "коробочный" **ingress-nginx** от проекта Kubernetes. Это "достаточно хороший" Ingress для умеренных нагрузок, основанный на OpenResty и пачке Lua-скриптов.

- Установка начинается с основного манифеста:

```console
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/master/deploy/static/provider/baremetal/deploy.yaml
namespace/ingress-nginx created
serviceaccount/ingress-nginx created
serviceaccount/ingress-nginx-admission created
role.rbac.authorization.k8s.io/ingress-nginx created
role.rbac.authorization.k8s.io/ingress-nginx-admission created
clusterrole.rbac.authorization.k8s.io/ingress-nginx created
clusterrole.rbac.authorization.k8s.io/ingress-nginx-admission created
rolebinding.rbac.authorization.k8s.io/ingress-nginx created
rolebinding.rbac.authorization.k8s.io/ingress-nginx-admission created
clusterrolebinding.rbac.authorization.k8s.io/ingress-nginx created
clusterrolebinding.rbac.authorization.k8s.io/ingress-nginx-admission created
configmap/ingress-nginx-controller created
service/ingress-nginx-controller created
service/ingress-nginx-controller-admission created
deployment.apps/ingress-nginx-controller created
job.batch/ingress-nginx-admission-create created
job.batch/ingress-nginx-admission-patch created
ingressclass.networking.k8s.io/nginx created
validatingwebhookconfiguration.admissionregistration.k8s.io/ingress-nginx-admission created
```

- После установки основных компонентов, в [инструкции](https://kubernetes.github.io/ingress-nginx/deploy/#bare-metal) рекомендуется применить манифест, который создаст NodePort -сервис. Но у нас есть MetalLB, мы можем сделать круче.

> Можно сделать просто minikube addons enable ingress , но мы не ищем легких путей

Проверим, что контроллер запустился:

```console
kubectl get pods -n ingress-nginx
NAME                                        READY   STATUS    RESTARTS   AGE
ingress-nginx-controller-6d685f94d4-ds49p   1/1     Running   0          35s
```

```yml
kind: Service
apiVersion: v1
metadata:
  name: ingress-nginx
  namespace: ingress-nginx
  labels:
    app.kubernetes.io/name: ingress-nginx
    app.kubernetes.io/part-of: ingress-nginx
spec:
  externalTrafficPolicy: Local
  type: LoadBalancer
  selector:
    app.kubernetes.io/name: ingress-nginx
    app.kubernetes.io/part-of: ingress-nginx
  ports:
    - name: http
      port: 80
      targetPort: http
    - name: https
      port: 443
      targetPort: https
```

- Теперь применим созданный манифест и посмотрим на IP-адрес, назначенный ему MetalLB

```console
kubectl apply -f nginx-lb.yaml
service/ingress-nginx created

kubectl get svc -n ingress-nginx
NAME                                 TYPE           CLUSTER-IP     EXTERNAL-IP    PORT(S)                      AGE
ingress-nginx                        LoadBalancer   10.109.16.26   172.17.255.3   80:31286/TCP,443:32378/TCP   4s

- Теперь можно сделать пинг на этот IP-адрес и даже curl


```console
curl 172.17.255.3
curl : 404 Not Found
nginx
строка:1 знак:1
+ curl 172.17.255.3
+ ~~~~~~~~~~~~~~~~~
    + CategoryInfo          : InvalidOperation: (System.Net.HttpWebRequest:HttpWebRequest) [Invoke-WebRequest], WebException
    + FullyQualifiedErrorId : WebCmdletWebResponseException,Microsoft.PowerShell.Commands.InvokeWebRequestCommand
```

Видим страничку 404 от Nginx - значит работает!

### Подключение приложение Web к Ingress

- Наш Ingress-контроллер не требует **ClusterIP** для балансировки трафика
- Список узлов для балансировки заполняется из ресурса Endpoints нужного сервиса (это нужно для "интеллектуальной" балансировки, привязки сессий и т.п.)
- Поэтому мы можем использовать **headless-сервис** для нашего вебприложения.
- Скопируем web-svc-cip.yaml в web-svc-headless.yaml
  - Изменим имя сервиса на **web-svc**
  - Добавим параметр **clusterIP: None**


```yml
apiVersion: v1
kind: Service
metadata:
  name: web-svc
spec:
  selector:
    app: web
  type: ClusterIP
  clusterIP: None
  ports:
    - protocol: TCP
      port: 80
      targetPort: 8000
```

- Теперь применим полученный манифест и проверим, что ClusterIP для сервиса web-svc действительно не назначен

```console
kubectl apply -f web-svc-headless.yaml
service/web-svc created

kubectl get svc
NAME          TYPE           CLUSTER-IP      EXTERNAL-IP    PORT(S)        AGE
kubernetes    ClusterIP      10.96.0.1       <none>         443/TCP        2d5h
web-svc       ClusterIP      None            <none>         80/TCP         10s
web-svc-cip   ClusterIP      10.97.181.101   <none>         80/TCP         2d4h
web-svc-lb    LoadBalancer   10.97.235.18    172.17.255.1   80:32363/TCP   29h
```

### Создание правил Ingress

Теперь настроим наш ingress-прокси, создав манифест с ресурсом Ingress (файл назовем web-ingress.yaml):

```yml
apiVersion: networking.k8s.io/v1beta1
kind: Ingress
metadata:
  name: web
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  rules:
  - http:
      paths:
      - path: /web
        backend:
          serviceName: web-svc
          servicePort: 8000
```

Применим манифест и проверим, что корректно заполнены Address и Backends:

```console
kubectl describe ingress/web
Name:             web
Labels:           <none>
Namespace:        default
Address:
Ingress Class:    <none>
Default backend:  <default>
Rules:
  Host        Path  Backends
  ----        ----  --------
  *
              /web   web-svc:8000 (172.17.0.2:8000,172.17.0.4:8000,172.17.0.5:8000)
Annotations:  nginx.ingress.kubernetes.io/rewrite-target: /
Events:       <none>
```


- Теперь можно проверить, что страничка доступна в браузере (<http://172.17.255.3/web/index.html)>
- Обратим внимание, что обращения к странице тоже балансируются между Podами. Только сейчас это происходит средствами nginx, а не IPVS

### Задания со ⭐ | Ingress для Dashboard

Добавим доступ к kubernetes-dashboard через наш Ingress-прокси:

- Cервис должен быть доступен через префикс /dashboard.
- Kubernetes Dashboard должен быть развернут из официального манифеста. Актуальная ссылка в [репозитории проекта](https://github.com/kubernetes/dashboard).
- Написанные манифесты положим в подкаталог ./dashboard


```console
kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.7.0/aio/deploy/recommended.yaml

namespace/kubernetes-dashboard created
serviceaccount/kubernetes-dashboard created
service/kubernetes-dashboard created
secret/kubernetes-dashboard-certs created
secret/kubernetes-dashboard-csrf created
secret/kubernetes-dashboard-key-holder created
configmap/kubernetes-dashboard-settings created
role.rbac.authorization.k8s.io/kubernetes-dashboard created
clusterrole.rbac.authorization.k8s.io/kubernetes-dashboard created
rolebinding.rbac.authorization.k8s.io/kubernetes-dashboard created
clusterrolebinding.rbac.authorization.k8s.io/kubernetes-dashboard created
deployment.apps/kubernetes-dashboard created
service/dashboard-metrics-scraper created
deployment.apps/dashboard-metrics-scraper created
```

dashboard-ingress.yaml

```yml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: dashboard
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
    nginx.ingress.kubernetes.io/backend-protocol: "HTTPS"
spec:
  rules:
  - http:
      paths:
      - path: /dashboard
        pathType: Prefix
        backend:
          service:
            name: kubernetes-dashboard
            port:
              number: 443
```


```console
kubectl apply -f dashboard-ingress.yaml
ingress.extensions/dashboard configured

kubectl get ingress -n kubernetes-dashboard
NAME        CLASS    HOSTS   ADDRESS        PORTS   AGE
dashboard   <none>   *       172.17.255.3   80      12h
```

Проверим работоспособность по ссылке: <https://172.17.255.3/dashboard/>

### Задания со ⭐ | Canary для Ingress

Реализуем канареечное развертывание с помощью ingress-nginx:

- Перенаправление части трафика на выделенную группу подов должно происходить по HTTP-заголовку.
- Документация [тут](https://github.com/kubernetes/ingress-nginx/blob/master/docs/user-guide/nginx-configuration/annotations.md#canary)
- Естественно, что нам понадобятся 1-2 "канареечных" пода. Написанные манифесты положим в подкаталог ./canary

Пишем манифесты для:

- namespace canary-ns.yaml
- deployment canary-deploy.yaml
- service canary-svc-headless.yaml
- ingress canary-ingress.yml


```yml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: web
  namespace: canary
  annotations:
    kubernetes.io/ingress.class: nginx
    nginx.ingress.kubernetes.io/rewrite-target:  /
    nginx.ingress.kubernetes.io/canary: "true"
    nginx.ingress.kubernetes.io/canary-by-header: "canary"
    nginx.ingress.kubernetes.io/canary-weight: "50"
spec:
  rules:
  - host: app.local
    http:
      paths:
      - path: /web
        pathType: Prefix
        backend:
          service:
            name: web-svc
            port:
              number: 8000
```


```console
kubectl get pods
NAME                   READY   STATUS    RESTARTS   AGE
web-74d744cb46-6hcfw   1/1     Running   0          17h
web-74d744cb46-jdtth   1/1     Running   0          17h
web-74d744cb46-vsst6   1/1     Running   0          17h

kubectl get pods -n canary
NAME                   READY   STATUS    RESTARTS   AGE
web-74d744cb46-2hnkb   1/1     Running   0          10m
web-74d744cb46-dsf87   1/1     Running   0          10m
```


И проверяем работу:

```console
curl -s -H "Host: app.local" http://192.168.136.17/web/index.html | grep "HOSTNAME"
export HOSTNAME='web-74d744cb46-vsst6'

curl -s -H "Host: app.local" -H "canary: always" http://192.168.136.17/web/index.html | grep "HOSTNAME"
export HOSTNAME='web-74d744cb46-dsf87'
```

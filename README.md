# darkzorro79_platform

## Volumes, Storages, StatefulSet

### Установка и запуск kind

**kind** - инструмент для запуска Kuberenetes при помощи Docker контейнеров.

Запуск: kind create cluster

### Применение StatefulSet

В этом ДЗ мы развернем StatefulSet c [MinIO](https://min.io/) - локальным S3 хранилищем.

Конфигурация [StatefulSet](https://raw.githubusercontent.com/express42/otus-platform-snippets/master/Module-02/Kuberenetes-volumes/minio-statefulset.yaml).

minio-statefulset.yaml

```yml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  # This name uniquely identifies the StatefulSet
  name: minio
spec:
  serviceName: minio
  replicas: 1
  selector:
    matchLabels:
      app: minio # has to match .spec.template.metadata.labels
  template:
    metadata:
      labels:
        app: minio # has to match .spec.selector.matchLabels
    spec:
      containers:
      - name: minio
        env:
        - name: MINIO_ACCESS_KEY
          value: "minio"
        - name: MINIO_SECRET_KEY
          value: "minio123"
        image: minio/minio:RELEASE.2019-07-10T00-34-56Z
        args:
        - server
        - /data 
        ports:
        - containerPort: 9000
        # These volume mounts are persistent. Each pod in the PetSet
        # gets a volume mounted based on this field.
        volumeMounts:
        - name: data
          mountPath: /data
        # Liveness probe detects situations where MinIO server instance
        # is not working properly and needs restart. Kubernetes automatically
        # restarts the pods if liveness checks fail.
        livenessProbe:
          httpGet:
            path: /minio/health/live
            port: 9000
          initialDelaySeconds: 120
          periodSeconds: 20
  # These are converted to volume claims by the controller
  # and mounted at the paths mentioned above. 
  volumeClaimTemplates:
  - metadata:
      name: data
    spec:
      accessModes:
        - ReadWriteOnce
      resources:
        requests:
          storage: 10Gi
```


### Применение Headless Service

Для того, чтобы наш StatefulSet был доступен изнутри кластера, создадим [Headless Service](https://raw.githubusercontent.com/express42/otus-platform-snippets/master/Module-02/Kuberenetes-volumes/minio-headless-service.yaml).

minio-headless-service.yaml

```yml
apiVersion: v1
kind: Service
metadata:
  name: minio
  labels:
    app: minio
spec:
  clusterIP: None
  ports:
    - port: 9000
      name: minio
  selector:
    app: minio
```

В результате применения конфигурации должно произойти следующее:

- Запуститься под с MinIO
- Создаться PVC
- Динамически создаться PV на этом PVC с помощью дефолотного StorageClass

```console
kubectl apply -f minio-statefulset.yaml
statefulset.apps/minio created

kubectl apply -f minio-headless-service.yaml
service/minio created
```


- Проверить работу Minio можно с помощью консольного клиента [mc](https://github.com/minio/mc)

```console
kubectl port-forward minio-0 9000:9000 &
 
mc config host add minio http://127.0.0.1:9000 minio minio123
Added `minio` successfully.
```

Также для проверки ресурсов k8s помогут команды:

```console
kubectl get statefulsets
kubectl get pods
kubectl get pvc
kubectl get pv
kubectl describe <resource> <resource_name>
```


```console
kubectl get statefulsets
NAME    READY   AGE
minio   1/1     3d
```

```console
kubectl get pods
NAME      READY   STATUS    RESTARTS   AGE
minio-0   1/1     Running   0          3d
```

```console
kubectl get pvc
NAME           STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS   AGE
data-minio-0   Bound    pvc-9395760f-450d-442f-a442-882cc19229ed   10Gi       RWO            standard       3d
```

```console
kubectl get pv
NAME                                       CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS   CLAIM                  STORAGECLASS   REASON   AGE
pvc-9395760f-450d-442f-a442-882cc19229ed   10Gi       RWO            Delete           Bound    default/data-minio-0   standard                3d
```


### Задание со ⭐

В конфигурации нашего StatefulSet данные указаны в открытом виде, что не безопасно.  
Поместим данные в [secrets](https://kubernetes.io/docs/concepts/configuration/secret/) и настроим конфигурацию на их использование.

Конвертируем username и password в base64:

```console
echo -n 'minio' | base64
bWluaW8=

echo -n 'minio123' | base64
bWluaW8xMjM=
```

Подготовим манифест с Secret:

```yml
apiVersion: v1
kind: Secret
metadata:
  name: minio
type: Opaque
data:
  username: bWluaW8=
  password: bWluaW8xMjM=
```

Применим изменения:

```console
kubectl apply -f minio-statefulset.yaml
statefulset.apps/minio configured
secret/minio created
```

Посмотрим на Secret:

```console
kubectl get secret minio -o yaml
apiVersion: v1
data:
  password: bWluaW8xMjM=
  username: bWluaW8=
kind: Secret
metadata:
  annotations:
    kubectl.kubernetes.io/last-applied-configuration: |
      {"apiVersion":"v1","data":{"password":"bWluaW8xMjM=","username":"bWluaW8="},"kind":"Secret","metadata":{"annotations":{},"name":"minio","namespace":"default"},"type":"Opaque"}
  creationTimestamp: "2023-01-27T15:53:36Z"
  name: minio
  namespace: default
  resourceVersion: "412350"
  uid: b0f5e6c8-74ad-4fd5-b060-e100aa940a06
type: Opaque

```

```console
kubectl describe statefulsets minio
Name:               minio
Namespace:          default
CreationTimestamp:  Tue, 24 Jan 2023 17:43:12 +0300
Selector:           app=minio
Labels:             <none>
Annotations:        <none>
Replicas:           1 desired | 1 total
Update Strategy:    RollingUpdate
  Partition:        0
Pods Status:        1 Running / 0 Waiting / 0 Succeeded / 0 Failed
Pod Template:
  Labels:  app=minio
  Containers:
   minio:
    Image:      minio/minio:RELEASE.2019-07-10T00-34-56Z
    Port:       9000/TCP
    Host Port:  0/TCP
    Args:
      server
      /data
    Liveness:  http-get http://:9000/minio/health/live delay=120s timeout=1s period=20s #success=1 #failure=3
    Environment:
      MINIO_ACCESS_KEY:  <set to the key 'username' in secret 'minio'>  Optional: false
      MINIO_SECRET_KEY:  <set to the key 'password' in secret 'minio'>  Optional: false
    Mounts:
      /data from data (rw)
  Volumes:  <none>
Volume Claims:
  Name:          data
  StorageClass:
  Labels:        <none>
  Annotations:   <none>
  Capacity:      10Gi
  Access Modes:  [ReadWriteOnce]
Events:
  Type    Reason            Age                   From                    Message
  ----    ------            ----                  ----                    -------
  Normal  SuccessfulDelete  5m12s                 statefulset-controller  delete Pod minio-0 in StatefulSet minio successful
  Normal  SuccessfulCreate  5m11s (x2 over 3d1h)  statefulset-controller  create Pod minio-0 in StatefulSet minio successful

```

## Удаление кластера

Удалить кластер можно командой: kind delete cluster
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
# darkzorro79_platform

## Kubernetes controllers. ReplicaSet, Deployment, DaemonSet

### Подготовка

Для начала установим Kind и создадим кластер. [Инструкция по быстрому старту](https://kind.sigs.k8s.io/docs/user/quick-start/).

```console
curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.17.0/kind-linux-amd64
chmod +x ./kind
sudo mv ./kind /usr/local/bin/kind
```

Будем использовать следующую конфигурацию нашего локального кластера kind-config.yml

```yml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
- role: worker
- role: worker
- role: worker
```

Создадим кластер kind:

```console
kind create cluster --config kind-config.yaml
Creating cluster "kind" ...
 ✓ Ensuring node image (kindest/node:v1.25.3) 🖼
 ✓ Preparing nodes 📦 📦 📦 📦
 ✓ Writing configuration 📜
 ✓ Starting control-plane 🕹️
 ✓ Installing CNI 🔌
 ✓ Installing StorageClass 💾
 ✓ Joining worker nodes 🚜
Set kubectl context to "kind-kind"
You can now use your cluster with:

kubectl cluster-info --context kind-kind

Have a nice day! 👋
```

После появления отчета об успешном создании убедимся, что развернут master и три worker ноды:

```console
kubectl get nodes
NAME                 STATUS   ROLES           AGE     VERSION
kind-control-plane   Ready    control-plane   2m58s   v1.25.3
kind-worker          Ready    <none>          2m22s   v1.25.3
kind-worker2         Ready    <none>          2m34s   v1.25.3
kind-worker3         Ready    <none>          2m34s   v1.25.3
```

### ReplicaSet

В предыдущем домашнем задании мы запускали standalone pod с микросервисом **frontend**. Пришло время доверить управление pod'ами данного микросервиса одному из контроллеров Kubernetes.

Начнем с ReplicaSet и запустим одну реплику микросервиса frontend.

Создадим и применим манифест frontend-replicaset.yaml

```yml
apiVersion: apps/v1
kind: ReplicaSet
metadata:
  name: frontend
  labels:
    app: frontend
spec:
  replicas: 1
  selector:
    matchLabels:
      app: frontend
  template:
    metadata:
      labels:
        app: frontend
    spec:
      containers:
      - name: server
        image: darkzorro/hipster-frontend:v0.0.1
        env:
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

```console
kubectl apply -f frontend-replicaset.yaml
```

В результате вывод команды **kubectl get pods -l app=frontend** должен показывать, что запущена одна реплика микросервиса **frontend**:

```console
kubectl get pods -l app=frontend
NAME             READY   STATUS    RESTARTS   AGE
frontend-hfh6l   1/1     Running   0          7m25s
```


Одна работающая реплика - это уже неплохо, но в реальной жизни, как правило, требуется создание нескольких инстансов одного и того же сервиса для:

- Повышения отказоустойчивости
- Распределения нагрузки между репликами

Давайте попробуем увеличить количество реплик сервиса ad-hoc командой:

```console
kubectl scale replicaset frontend --replicas=3
```

Проверить, что ReplicaSet контроллер теперь управляет тремя репликами, и они готовы к работе, можно следующим образом:

```console
kubectl get rs frontend

NAME       DESIRED   CURRENT   READY   AGE
frontend   3         3         3       8m53s
```

Проверим, что благодаря контроллеру pod'ы действительно восстанавливаются после их ручного удаления:

```console
kubectl delete pods -l app=frontend | kubectl get pods -l app=frontend -w

NAME             READY   STATUS    RESTARTS   AGE
frontend-hfh6l   1/1     Running   0          10m
frontend-tprcj   1/1     Running   0          2m3s
frontend-xswch   1/1     Running   0          2m3s
frontend-hfh6l   1/1     Terminating   0          10m
frontend-tprcj   1/1     Terminating   0          2m3s
frontend-n9wp8   0/1     Pending       0          0s
frontend-xswch   1/1     Terminating   0          2m3s
frontend-n9wp8   0/1     Pending       0          0s
frontend-g74rr   0/1     Pending       0          0s
frontend-g74rr   0/1     Pending       0          0s
frontend-jcj9k   0/1     Pending       0          0s
frontend-n9wp8   0/1     ContainerCreating   0          0s
frontend-jcj9k   0/1     Pending             0          0s
frontend-g74rr   0/1     ContainerCreating   0          0s
frontend-jcj9k   0/1     ContainerCreating   0          0s
frontend-xswch   0/1     Terminating         0          2m3s
frontend-tprcj   0/1     Terminating         0          2m3s
frontend-tprcj   0/1     Terminating         0          2m3s
frontend-xswch   0/1     Terminating         0          2m3s
frontend-tprcj   0/1     Terminating         0          2m3s
frontend-xswch   0/1     Terminating         0          2m3s
frontend-jcj9k   1/1     Running             0          0s
frontend-g74rr   1/1     Running             0          0s
frontend-hfh6l   0/1     Terminating         0          10m
frontend-hfh6l   0/1     Terminating         0          10m
frontend-hfh6l   0/1     Terminating         0          10m
frontend-n9wp8   1/1     Running             0          1s
```

- Повторно применим манифест frontend-replicaset.yaml
- Убедимся, что количество реплик вновь уменьшилось до одной

```console
kubectl apply -f frontend-replicaset.yaml

kubectl get rs frontend
NAME       DESIRED   CURRENT   READY   AGE
frontend   1         1         1       14m
```

- Изменим манифест таким образом, чтобы из манифеста сразу разворачивалось три реплики сервиса, вновь применим его

```console
kubectl apply -f frontend-replicaset.yaml

kubectl get rs frontend
NAME       DESIRED   CURRENT   READY   AGE
frontend   3         3         3       16m
```

### Обновление ReplicaSet

Давайте представим, что мы обновили исходный код и хотим выкатить новую версию микросервиса

- Добавим на DockerHub версию образа с новым тегом (**v0.0.2**, можно просто перетегировать старый образ)

```console
docker build -t darkzorro/hipster-frontend:v0.0.2 .
docker push darkzorro/hipster-frontend:v0.0.2
```

- Обновим в манифесте версию образа
- Применим новый манифест, параллельно запустите отслеживание происходящего:

```console
kubectl apply -f frontend-replicaset.yaml | kubectl get pods -l app=frontend -w

NAME             READY   STATUS    RESTARTS   AGE
frontend-75k4s   1/1     Running   0          9m32s
frontend-n9wp8   1/1     Running   0          15m
frontend-xs7mw   1/1     Running   0          9m32s
```

Давайте проверим образ, указанный в ReplicaSet:

```console
kubectl get replicaset frontend -o=jsonpath='{.spec.template.spec.containers[0].image}'

darkzorro/hipster-frontend:v0.0.2
```

И образ из которого сейчас запущены pod, управляемые контроллером:

```console
kubectl get pods -l app=frontend -o=jsonpath='{.items[0:3].spec.containers[0].image}'

darkzorro/hipster-frontend:v0.0.1 darkzorro/hipster-frontend:v0.0.1 darkzorro/hipster-frontend:v0.0.1
```

- Удалим все запущенные pod и после их пересоздания еще раз проверим, из какого образа они развернулись

```console
for i in `kubectl get po | grep frontend | awk '{print $1}'`; do kubectl delete po $i; done;
kubectl get pods -l app=frontend -o=jsonpath='{.items[0:3].spec.containers[0].image}'

darkzorro/hipster-frontend:v0.0.2 darkzorro/hipster-frontend:v0.0.2 darkzorro/hipster-frontend:v0.0.2
```

> Обновление ReplicaSet не повлекло обновление запущенных pod по причине того, что ReplicaSet не умеет рестартовать запущенные поды при обновлении шаблона

### Deployment

Для начала - воспроизведем действия, проделанные с микросервисом **frontend** для микросервиса **paymentService**.

Результат:

- Собранный и помещенный в Docker Hub образ с двумя тегами **v0.0.1** и **v0.0.2**
- Валидный манифест **paymentservice-replicaset.yaml** с тремя репликами, разворачивающими из образа версии v0.0.1

```console
docker build -t darkzorro/hipster-paymentservice:v0.0.1 .
docker build -t darkzorro/hipster-paymentservice:v0.0.2 .
docker push darkzorro/hipster-paymentservice:v0.0.1
docker push darkzorro/hipster-paymentservice:v0.0.2
```

Приступим к написанию Deployment манифеста для сервиса **payment**

- Скопируем содержимое файла **paymentservicereplicaset.yaml** в файл **paymentservice-deployment.yaml**
- Изменим поле **kind** с **ReplicaSet** на **Deployment**
- Манифест готов 😉 Применим его и убедимся, что в кластере Kubernetes действительно запустилось три реплики сервиса **payment** и каждая из них находится в состоянии **Ready**
- Обратим внимание, что помимо Deployment (kubectl get deployments) и трех pod, у нас появился новый ReplicaSet (kubectl get rs)

```yml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: paymentservice
  labels:
    app: paymentservice
spec:
  replicas: 3
  selector:
    matchLabels:
      app: paymentservice
  template:
    metadata:
      labels:
        app: paymentservice
    spec:
      containers:
      - name: paymentservice
        image: darkzorro/hipster-paymentservice:v0.0.1
        ports:
        - containerPort: 50051
        env:
        - name: PORT
          value: "50051"
        - name: DISABLE_PROFILER
          value: "1"
```

```console
kubectl apply -f paymentservice-deployment.yaml

kubectl get deploy
NAME             READY   UP-TO-DATE   AVAILABLE   AGE
paymentservice   3/3     3            3           100s

kubectl get rs
NAME                        DESIRED   CURRENT   READY   AGE
frontend                    3         3         3       93m
paymentservice-687c86c8bd   3         3         3       115s
```

### Обновление Deployment

Давайте попробуем обновить наш Deployment на версию образа **v0.0.2**

Обратим внимание на последовательность обновления pod. По умолчанию применяется стратегия **Rolling Update**:

- Создание одного нового pod с версией образа **v0.0.2**
- Удаление одного из старых pod
- Создание еще одного нового pod

```console
kubectl apply -f paymentservice-deployment.yaml | kubectl get pods -l app=paymentservice -w
NAME                              READY   STATUS    RESTARTS   AGE
paymentservice-687c86c8bd-gdlwj   1/1     Running   0          4m36s
paymentservice-687c86c8bd-qngpg   1/1     Running   0          4m36s
paymentservice-687c86c8bd-rbh7c   1/1     Running   0          4m36s
paymentservice-85cc4d4d9-br77j    0/1     Pending   0          0s
paymentservice-85cc4d4d9-br77j    0/1     Pending   0          0s
paymentservice-85cc4d4d9-br77j    0/1     ContainerCreating   0          0s
paymentservice-85cc4d4d9-br77j    1/1     Running             0          7s
paymentservice-687c86c8bd-gdlwj   1/1     Terminating         0          4m43s
paymentservice-85cc4d4d9-bl4w4    0/1     Pending             0          0s
paymentservice-85cc4d4d9-bl4w4    0/1     Pending             0          0s
paymentservice-85cc4d4d9-bl4w4    0/1     ContainerCreating   0          0s
paymentservice-85cc4d4d9-bl4w4    1/1     Running             0          7s
paymentservice-687c86c8bd-qngpg   1/1     Terminating         0          4m50s
paymentservice-85cc4d4d9-dblvs    0/1     Pending             0          0s
paymentservice-85cc4d4d9-dblvs    0/1     Pending             0          0s
paymentservice-85cc4d4d9-dblvs    0/1     ContainerCreating   0          0s
paymentservice-85cc4d4d9-dblvs    1/1     Running             0          7s
paymentservice-687c86c8bd-rbh7c   1/1     Terminating         0          4m57s
paymentservice-687c86c8bd-gdlwj   0/1     Terminating         0          5m16s
paymentservice-687c86c8bd-gdlwj   0/1     Terminating         0          5m16s
paymentservice-687c86c8bd-gdlwj   0/1     Terminating         0          5m16s
paymentservice-687c86c8bd-qngpg   0/1     Terminating         0          5m21s
paymentservice-687c86c8bd-qngpg   0/1     Terminating         0          5m21s
paymentservice-687c86c8bd-qngpg   0/1     Terminating         0          5m21s
paymentservice-687c86c8bd-rbh7c   0/1     Terminating         0          5m28s
paymentservice-687c86c8bd-rbh7c   0/1     Terminating         0          5m28s
paymentservice-687c86c8bd-rbh7c   0/1     Terminating         0          5m28s
```

Убедимся что:

- Все новые pod развернуты из образа **v0.0.2**
- Создано два ReplicaSet:
  - Один (новый) управляет тремя репликами pod с образом **v0.0.2**
  - Второй (старый) управляет нулем реплик pod с образом **v0.0.1**

Также мы можем посмотреть на историю версий нашего Deployment:

```console
kubectl get pods -l app=paymentservice -o=jsonpath='{.items[0:3].spec.containers[0].image}'

darkzorro/hipster-paymentservice:v0.0.2 darkzorro/hipster-paymentservice:v0.0.2 darkzorro/hipster-paymentservice:v0.0.2
```

```console
kubectl get rs
NAME                        DESIRED   CURRENT   READY   AGE
frontend                    3         3         3       101m
paymentservice-687c86c8bd   0         0         0       9m22s
paymentservice-85cc4d4d9    3         3         3       4m46s
```


```console
kubectl rollout history deployment paymentservice
deployment.apps/paymentservice
REVISION  CHANGE-CAUSE
1         <none>
2         <none>
```

### Deployment | Rollback

Представим, что обновление по каким-то причинам произошло неудачно и нам необходимо сделать откат. Kubernetes предоставляет такую возможность:

```console
kubectl rollout undo deployment paymentservice --to-revision=1 | kubectl get rs -l app=paymentservice -w
NAME                        DESIRED   CURRENT   READY   AGE
paymentservice-687c86c8bd   0         0         0       11m
paymentservice-85cc4d4d9    3         3         3       6m29s
paymentservice-687c86c8bd   0         0         0       11m
paymentservice-687c86c8bd   1         0         0       11m
paymentservice-687c86c8bd   1         0         0       11m
paymentservice-687c86c8bd   1         1         0       11m
paymentservice-687c86c8bd   1         1         1       11m
paymentservice-85cc4d4d9    2         3         3       6m30s
paymentservice-85cc4d4d9    2         3         3       6m30s
paymentservice-687c86c8bd   2         1         1       11m
paymentservice-85cc4d4d9    2         2         2       6m30s
paymentservice-687c86c8bd   2         1         1       11m
paymentservice-687c86c8bd   2         2         1       11m
paymentservice-687c86c8bd   2         2         2       11m
paymentservice-85cc4d4d9    1         2         2       6m31s
paymentservice-85cc4d4d9    1         2         2       6m31s
paymentservice-687c86c8bd   3         2         2       11m
paymentservice-85cc4d4d9    1         1         1       6m31s
paymentservice-687c86c8bd   3         2         2       11m
paymentservice-687c86c8bd   3         3         2       11m
paymentservice-687c86c8bd   3         3         3       11m
paymentservice-85cc4d4d9    0         1         1       6m33s
paymentservice-85cc4d4d9    0         1         1       6m33s
paymentservice-85cc4d4d9    0         0         0       6m33s
```

В выводе мы можем наблюдать, как происходит постепенное масштабирование вниз "нового" ReplicaSet, и масштабирование вверх "старого".

### Deployment | Задание со ⭐

С использованием параметров **maxSurge** и **maxUnavailable** самостоятельно реализуем два следующих сценария развертывания:

- Аналог blue-green:
  1. Развертывание трех новых pod
  2. Удаление трех старых pod
- Reverse Rolling Update:
  1. Удаление одного старого pod
  2. Создание одного нового pod
  
 [Документация](https://kubernetes.io/docs/concepts/workloads/controllers/deployment/#strategy) с описанием стратегий развертывания для Deployment.

maxSurge - определяет количество реплик, которое можно создать с превышением значения replicas  
Можно задавать как абсолютное число, так и процент. Default: 25%

maxUnavailable - определяет количество реплик от общего числа, которое можно "уронить"  
Аналогично, задается в процентах или числом. Default: 25%

В результате должно получиться два манифеста:

- paymentservice-deployment-bg.yaml

Для реализации аналога blue-green развертывания устанавливаем значения:

- maxSurge равным **3** для превышения количества требуемых pods
- maxUnavailable равным **0** для ограничения минимального количества недоступных pods

```yml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: paymentservice
  labels:
    app: paymentservice
spec:
  replicas: 3
  strategy:
    type: RollingUpdate
    rollingUpdate:
      # Количество реплик, которое можно создать с превышением значения replicas
      # Можно задавать как абсолютное число, так и процент. Default: 25%
      maxSurge: 3
      # Количество реплик от общего числа, которое можно "уронить"
      # Аналогично, задается в процентах или числом. Default: 25%
      maxUnavailable: 0
  selector:
    matchLabels:
      app: paymentservice
  template:
    metadata:
      labels:
        app: paymentservice
    spec:
      containers:
      - name: paymentservice
        image: darkzorro/hipster-paymentservice:v0.0.1
        ports:
        - containerPort: 50051
        env:
        - name: PORT
          value: "50051"
        - name: DISABLE_PROFILER
          value: "1"
```

 Применим манифест:

```console
kubectl apply -f paymentservice-deployment-bg.yaml
deployment.apps/paymentservice created

kubectl get po
NAME                              READY   STATUS    RESTARTS   AGE
frontend-4m2gr                    1/1     Running   0          56m
frontend-7c8j4                    1/1     Running   0          56m
frontend-x52zj                    1/1     Running   0          56m
paymentservice-687c86c8bd-cplj8   1/1     Running   0          13s
paymentservice-687c86c8bd-ldtf4   1/1     Running   0          13s
paymentservice-687c86c8bd-przht   1/1     Running   0          13s
```

В манифесте **paymentservice-deployment-bg.yaml** меняем версию образа на **v0.0.2** и применяем:


```console
kubectl apply -f paymentservice-deployment-bg.yaml
deployment.apps/paymentservice configured

kubectl get po -w
NAME                              READY   STATUS        RESTARTS   AGE
frontend-4m2gr                    1/1     Running       0          66m
frontend-7c8j4                    1/1     Running       0          66m
frontend-x52zj                    1/1     Running       0          66m
paymentservice-687c86c8bd-cplj8   1/1     Terminating   0          10m
paymentservice-687c86c8bd-ldtf4   1/1     Terminating   0          10m
paymentservice-687c86c8bd-przht   1/1     Terminating   0          10m
paymentservice-85cc4d4d9-fftbx    1/1     Running       0          9s
paymentservice-85cc4d4d9-l7gdr    1/1     Running       0          9s
paymentservice-85cc4d4d9-pcr65    1/1     Running       0          9s
paymentservice-687c86c8bd-cplj8   0/1     Terminating   0          10m
paymentservice-687c86c8bd-cplj8   0/1     Terminating   0          10m
paymentservice-687c86c8bd-cplj8   0/1     Terminating   0          10m
paymentservice-687c86c8bd-ldtf4   0/1     Terminating   0          10m
paymentservice-687c86c8bd-ldtf4   0/1     Terminating   0          10m
paymentservice-687c86c8bd-przht   0/1     Terminating   0          10m
paymentservice-687c86c8bd-ldtf4   0/1     Terminating   0          10m
paymentservice-687c86c8bd-przht   0/1     Terminating   0          10m
paymentservice-687c86c8bd-przht   0/1     Terminating   0          10m
```

> Как видно выше, сначала создаются три новых пода, а затем удаляются три старых.

- paymentservice-deployment-reverse.yaml

Для реализации Reverse Rolling Update устанавливаем значения:

- maxSurge равным **1** для превышения количества требуемых pods
- maxUnavailable равным **1** для ограничения минимального количества недоступных pods

```yml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: paymentservice
  labels:
    app: paymentservice
spec:
  replicas: 3
  strategy:
    type: RollingUpdate
    rollingUpdate:
      # Количество реплик, которое можно создать с превышением значения replicas
      # Можно задавать как абсолютное число, так и процент. Default: 25%
      maxSurge: 1
      # Количество реплик от общего числа, которое можно "уронить"
      # Аналогично, задается в процентах или числом. Default: 25%
      maxUnavailable: 1
  selector:
    matchLabels:
      app: paymentservice
  template:
    metadata:
      labels:
        app: paymentservice
    spec:
      containers:
      containers:
      - name: paymentservice
        image: darkzorro/hipster-paymentservice:v0.0.1
        ports:
        - containerPort: 50051
        env:
        - name: PORT
          value: "50051"
        - name: DISABLE_PROFILER
          value: "1"
```

Проверяем результат:

```console
kubectl apply -f paymentservice-deployment-reverse.yaml | kubectl get pods -w
NAME                              READY   STATUS    RESTARTS   AGE
frontend-4m2gr                    1/1     Running   0          129m
frontend-7c8j4                    1/1     Running   0          129m
frontend-x52zj                    1/1     Running   0          129m
paymentservice-687c86c8bd-d8k5p   1/1     Running   0          6m18s
paymentservice-687c86c8bd-pwx2m   1/1     Running   0          6m18s
paymentservice-687c86c8bd-swrhz   1/1     Running   0          6m18s
paymentservice-85cc4d4d9-lgvlt    0/1     Pending   0          0s
paymentservice-85cc4d4d9-lgvlt    0/1     Pending   0          0s
paymentservice-687c86c8bd-swrhz   1/1     Terminating   0          6m18s
paymentservice-85cc4d4d9-lgvlt    0/1     ContainerCreating   0          0s
paymentservice-85cc4d4d9-fdg4n    0/1     Pending             0          0s
paymentservice-85cc4d4d9-fdg4n    0/1     Pending             0          0s
paymentservice-85cc4d4d9-fdg4n    0/1     ContainerCreating   0          0s
paymentservice-85cc4d4d9-lgvlt    1/1     Running             0          1s
paymentservice-687c86c8bd-d8k5p   1/1     Terminating         0          6m19s
paymentservice-85cc4d4d9-fdg4n    1/1     Running             0          1s
paymentservice-85cc4d4d9-l7j98    0/1     Pending             0          0s
paymentservice-85cc4d4d9-l7j98    0/1     Pending             0          0s
paymentservice-85cc4d4d9-l7j98    0/1     ContainerCreating   0          0s
paymentservice-687c86c8bd-pwx2m   1/1     Terminating         0          6m19s
paymentservice-85cc4d4d9-l7j98    1/1     Running             0          2s
paymentservice-687c86c8bd-swrhz   0/1     Terminating         0          6m49s
paymentservice-687c86c8bd-swrhz   0/1     Terminating         0          6m49s
paymentservice-687c86c8bd-swrhz   0/1     Terminating         0          6m49s
paymentservice-687c86c8bd-pwx2m   0/1     Terminating         0          6m50s
paymentservice-687c86c8bd-pwx2m   0/1     Terminating         0          6m50s
paymentservice-687c86c8bd-pwx2m   0/1     Terminating         0          6m50s
paymentservice-687c86c8bd-d8k5p   0/1     Terminating         0          6m50s
paymentservice-687c86c8bd-d8k5p   0/1     Terminating         0          6m50s
paymentservice-687c86c8bd-d8k5p   0/1     Terminating         0          6m50s
```


### Probes

Мы научились разворачивать и обновлять наши микросервисы, но можем ли быть уверены, что они корректно работают после выкатки? Один из механизмов Kubernetes, позволяющий нам проверить это - [Probes](https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-startup-probes/).

Давайте на примере микросервиса **frontend** посмотрим на то, как probes влияют на процесс развертывания.

- Создадим манифест **frontend-deployment.yaml** из которого можно развернуть три реплики pod с тегом образа **v0.0.1**
- Добавим туда описание *readinessProbe*. Описание можно взять из манифеста по [ссылке](https://github.com/GoogleCloudPlatform/microservices-demo/blob/master/kubernetes-manifests/frontend.yaml).

Применим манифест с **readinessProbe**. Если все сделано правильно, то мы вновь увидим три запущенных pod в описании которых (**kubectl describe pod**) будет указание на наличие **readinessProbe** и ее параметры.

Давайте попробуем сымитировать некорректную работу приложения и посмотрим, как будет вести себя обновление:

- Заменим в описании пробы URL **/_healthz** на **/_health**
- Развернем версию **v0.0.2**

```console
kubectl apply -f frontend-deployment.yaml
```

Если посмотреть на текущее состояние нашего микросервиса, мы увидим, что был создан один pod новой версии, но его статус готовности **0/1**:

Команда kubectl describe pod поможет нам понять причину:

```console
for i in `kubectl get po | grep "0/1" | awk '{print $1}'`; do kubectl describe pod $i; done;

Events:
  Type     Reason     Age                  From               Message
  ----     ------     ----                 ----               -------
  Normal   Scheduled  6m12s                default-scheduler  Successfully assigned default/frontend-5bf5c6cc47-flx4x to kind-worker3
  Normal   Pulled     6m11s                kubelet            Container image "darkzorro/hipster-frontend:v0.0.2" already present on machine
  Normal   Created    6m11s                kubelet            Created container server
  Normal   Started    6m11s                kubelet            Started container server
  Warning  Unhealthy  61s (x35 over 6m1s)  kubelet            Readiness probe failed: HTTP probe failed with statuscode: 404
```

Как можно было заметить, пока **readinessProbe** для нового pod не станет успешной - Deployment не будет пытаться продолжить обновление.

На данном этапе может возникнуть вопрос - как автоматически отследить успешность выполнения Deployment (например для запуска в CI/CD).

В этом нам может помочь следующая команда:

```console
kubectl rollout status deployment/frontend
```

Таким образом описание pipeline, включающее в себя шаг развертывания и шаг отката, в самом простом случае может выглядеть так (синтаксис GitLab CI):

```yml
deploy_job:
  stage: deploy
  script:
    - kubectl apply -f frontend-deployment.yaml
    - kubectl rollout status deployment/frontend --timeout=60s

rollback_deploy_job:
  stage: rollback
  script:
    - kubectl rollout undo deployment/frontend
  when: on_failure
```

### DaemonSet

Рассмотрим еще один контроллер Kubernetes. Отличительная особенность DaemonSet в том, что при его применении на каждом физическом хосте создается по одному экземпляру pod, описанного в спецификации.

Типичные кейсы использования DaemonSet:

- Сетевые плагины
- Утилиты для сбора и отправки логов (Fluent Bit, Fluentd, etc...)
- Различные утилиты для мониторинга (Node Exporter, etc...)
- ...

### DaemonSet | Задание со ⭐

Опробуем DaemonSet на примере [Node Exporter](https://github.com/prometheus/node_exporter)

- Найдем в интернете [манифест](https://github.com/coreos/kube-prometheus/tree/master/manifests) **node-exporter-daemonset.yaml** для развертывания DaemonSet с Node Exporter
- После применения данного DaemonSet и выполнения команды: kubectl port-forward <имя любого pod в DaemonSet> 9100:9100 доступны на localhost: curl localhost:9100/metrics

Подготовим манифесты и развернем Node Exporter как DaemonSet:

```console
kubectl create ns monitoring
namespace/monitoring created

kubectl apply -f node-exporter-serviceAccount.yaml
serviceaccount/node-exporter created

kubectl apply -f node-exporter-clusterRole.yaml
clusterrole.rbac.authorization.k8s.io/node-exporter created

kubectl apply -f node-exporter-clusterRoleBinding.yaml
clusterrolebinding.rbac.authorization.k8s.io/node-exporter created

kubectl apply -f node-exporter-daemonset.yaml
daemonset.apps/node-exporter created

kubectl apply -f node-exporter-service.yaml
service/node-exporter created
```

Проверим созданные pods:

```console
kubectl get po -n monitoring -o wide
NAME                  READY   STATUS    RESTARTS   AGE   IP           NODE           NOMINATED NODE   READINESS GATES
node-exporter-f9rxd   2/2     Running   0          12s   172.19.0.4   kind-worker    <none>           <none>
node-exporter-mj9z8   2/2     Running   0          12s   172.19.0.5   kind-worker3   <none>           <none>
node-exporter-vrrsx   2/2     Running   0          12s   172.19.0.3   kind-worker2   <none>           <none>

```

запустим проброс порта:

```console
kubectl port-forward node-exporter-f9rxd 9100:9100 -n monitoring &

Forwarding from 127.0.0.1:9100 -> 9100
Forwarding from [::1]:9100 -> 9100
```

И убедимся, что мы можем получать метрики:

```console
curl localhost:9100/metrics

Handling connection for 9100
# HELP go_gc_duration_seconds A summary of the GC invocation durations.
# TYPE go_gc_duration_seconds summary
go_gc_duration_seconds{quantile="0"} 0
go_gc_duration_seconds{quantile="0.25"} 0
go_gc_duration_seconds{quantile="0.5"} 0
go_gc_duration_seconds{quantile="0.75"} 0
go_gc_duration_seconds{quantile="1"} 0
go_gc_duration_seconds_sum 0
go_gc_duration_seconds_count 0
# HELP go_goroutines Number of goroutines that currently exist.
# TYPE go_goroutines gauge
go_goroutines 6
# HELP go_info Information about the Go environment.
# TYPE go_info gauge
go_info{version="go1.12.5"} 1
# HELP go_memstats_alloc_bytes Number of bytes allocated and still in use.
# TYPE go_memstats_alloc_bytes gauge
go_memstats_alloc_bytes 913648
# HELP go_memstats_alloc_bytes_total Total number of bytes allocated, even if freed.
# TYPE go_memstats_alloc_bytes_total counter
go_memstats_alloc_bytes_total 913648
...
# TYPE process_cpu_seconds_total counter
process_cpu_seconds_total 0
# HELP process_max_fds Maximum number of open file descriptors.
# TYPE process_max_fds gauge
process_max_fds 1.048576e+06
# HELP process_open_fds Number of open file descriptors.
# TYPE process_open_fds gauge
process_open_fds 7
# HELP process_resident_memory_bytes Resident memory size in bytes.
# TYPE process_resident_memory_bytes gauge
process_resident_memory_bytes 1.1718656e+07
# HELP process_start_time_seconds Start time of the process since unix epoch in seconds.
# TYPE process_start_time_seconds gauge
process_start_time_seconds 1.67330140145e+09
# HELP process_virtual_memory_bytes Virtual memory size in bytes.
# TYPE process_virtual_memory_bytes gauge
process_virtual_memory_bytes 1.178624e+08
# HELP process_virtual_memory_max_bytes Maximum amount of virtual memory available in bytes.
# TYPE process_virtual_memory_max_bytes gauge
process_virtual_memory_max_bytes -1
# HELP promhttp_metric_handler_requests_in_flight Current number of scrapes being served.
# TYPE promhttp_metric_handler_requests_in_flight gauge
promhttp_metric_handler_requests_in_flight 1
# HELP promhttp_metric_handler_requests_total Total number of scrapes by HTTP status code.
# TYPE promhttp_metric_handler_requests_total counter
promhttp_metric_handler_requests_total{code="200"} 0
promhttp_metric_handler_requests_total{code="500"} 0
promhttp_metric_handler_requests_total{code="503"} 0
```

### DaemonSet | Задание с ⭐⭐

- Как правило, мониторинг требуется не только для worker, но и для master нод. При этом, по умолчанию, pod управляемые DaemonSet на master нодах не разворачиваются
- Найдем способ модернизировать свой DaemonSet таким образом, чтобы Node Exporter был развернут как на master, так и на worker нодах (конфигурацию самих нод изменять нельзя)
- Отразим изменения в манифесте

Материал по теме: [Taint and Toleration](https://kubernetes.io/docs/concepts/scheduling-eviction/taint-and-toleration/).

Решение: для развертывания DaemonSet на master нодах нам необходимо выдать **допуск** поду.  
Правим наш **node-exporter-daemonset.yaml**:

```yml
tolerations:
- operator: Exists
```

Применяем манифест и проверяем, что DaemonSet развернулся на master нодах.

```console
kubectl apply -f node-exporter-daemonset.yaml
daemonset.apps/node-exporter configured

kubectl get po -n monitoring -o wide
NAME                  READY   STATUS    RESTARTS   AGE   IP           NODE                 NOMINATED NODE   READINESS GATES
node-exporter-7rm45   2/2     Running   0          15s   172.19.0.2   kind-control-plane   <none>           <none>
node-exporter-bkhl8   2/2     Running   0          11s   172.19.0.4   kind-worker          <none>           <none>
node-exporter-dzqr7   2/2     Running   0          7s    172.19.0.3   kind-worker2         <none>           <none>
node-exporter-tgt56   2/2     Running   0          3s    172.19.0.5   kind-worker3         <none>           <none>
````
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
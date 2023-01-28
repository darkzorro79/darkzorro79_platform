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

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
# darkzorro79_platform
## Kubernetes controllers. ReplicaSet, Deployment, DaemonSet
### Подготовка
Для начала установим Kind и создадим кластер. [Инструкция по быстрому старту](https://kind.sigs.k8s.io/docs/user/quick-start/). ```console curl -Lo 
./kind https://kind.sigs.k8s.io/dl/v0.17.0/kind-linux-amd64 chmod +x ./kind sudo mv ./kind /usr/local/bin/kind ``` Будем использовать следующую 
конфигурацию нашего локального кластера kind-config.yml ```yml kind: Cluster apiVersion: kind.x-k8s.io/v1alpha4 nodes: - role: control-plane - role: 
worker - role: worker - role: worker ``` Создадим кластер kind: ```console kind create cluster --config kind-config.yaml Creating cluster "kind" ...
 ✓ Ensuring node image (kindest/node:v1.25.3) 🖼 ✓ Preparing nodes 📦 📦 📦 📦 ✓ Writing configuration 📜 ✓ Starting control-plane 🕹️ ✓ Installing CNI 🔌 
 ✓ Installing StorageClass 💾 ✓ Joining worker nodes 🚜
Set kubectl context to "kind-kind" You can now use your cluster with: kubectl cluster-info --context kind-kind Have a nice day! 👋 ``` После появления 
отчета об успешном создании убедимся, что развернут master и три worker ноды: ```console kubectl get nodes NAME STATUS ROLES AGE VERSION 
kind-control-plane Ready control-plane 2m58s v1.25.3 kind-worker Ready <none> 2m22s v1.25.3 kind-worker2 Ready <none> 2m34s v1.25.3 kind-worker3 Ready 
<none> 2m34s v1.25.3 ```
### ReplicaSet
В предыдущем домашнем задании мы запускали standalone pod с микросервисом **frontend**. Пришло время доверить управление pod'ами данного микросервиса 
одному из контроллеров Kubernetes. Начнем с ReplicaSet и запустим одну реплику микросервиса frontend. Создадим и применим манифест 
frontend-replicaset.yaml ```yml apiVersion: apps/v1 kind: ReplicaSet metadata:
  name: frontend labels: app: frontend spec: replicas: 1 selector: matchLabels: app: frontend template: metadata: labels: app: frontend spec: 
      containers: - name: server
        image: darkzorro/hipster-frontend:v0.0.1 env: - name: PRODUCT_CATALOG_SERVICE_ADDR value: "productcatalogservice:3550" - name: 
          CURRENCY_SERVICE_ADDR
            value: "currencyservice:7000" - name: CART_SERVICE_ADDR value: "cartservice:7070" - name: RECOMMENDATION_SERVICE_ADDR value: 
            "recommendationservice:8080"
          - name: SHIPPING_SERVICE_ADDR value: "shippingservice:50051" - name: CHECKOUT_SERVICE_ADDR value: "checkoutservice:5050" - name: 
          AD_SERVICE_ADDR
            value: "adservice:9555" ``` ```console kubectl apply -f frontend-replicaset.yaml ``` В результате вывод команды **kubectl get pods -l 
app=frontend** должен показывать, что запущена одна реплика микросервиса **frontend**: ```console kubectl get pods -l app=frontend NAME READY STATUS 
RESTARTS AGE frontend-hfh6l 1/1 Running 0 7m25s ``` Одна работающая реплика - это уже неплохо, но в реальной жизни, как правило, требуется создание 
нескольких инстансов одного и того же сервиса для: - Повышения отказоустойчивости - Распределения нагрузки между репликами Давайте попробуем увеличить 
количество реплик сервиса ad-hoc командой: ```console kubectl scale replicaset frontend --replicas=3 ``` Проверить, что ReplicaSet контроллер теперь 
управляет тремя репликами, и они готовы к работе, можно следующим образом: ```console kubectl get rs frontend NAME DESIRED CURRENT READY AGE frontend 3 
3 3 8m53s ``` Проверим, что благодаря контроллеру pod'ы действительно восстанавливаются после их ручного удаления: ```console kubectl delete pods -l 
app=frontend | kubectl get pods -l app=frontend -w NAME READY STATUS RESTARTS AGE frontend-hfh6l 1/1 Running 0 10m frontend-tprcj 1/1 Running 0 2m3s 
frontend-xswch 1/1 Running 0 2m3s frontend-hfh6l 1/1 Terminating 0 10m frontend-tprcj 1/1 Terminating 0 2m3s frontend-n9wp8 0/1 Pending 0 0s 
frontend-xswch 1/1 Terminating 0 2m3s frontend-n9wp8 0/1 Pending 0 0s frontend-g74rr 0/1 Pending 0 0s frontend-g74rr 0/1 Pending 0 0s frontend-jcj9k 
0/1 Pending 0 0s frontend-n9wp8 0/1 ContainerCreating 0 0s frontend-jcj9k 0/1 Pending 0 0s frontend-g74rr 0/1 ContainerCreating 0 0s frontend-jcj9k 0/1 
ContainerCreating 0 0s frontend-xswch 0/1 Terminating 0 2m3s frontend-tprcj 0/1 Terminating 0 2m3s frontend-tprcj 0/1 Terminating 0 2m3s frontend-xswch 
0/1 Terminating 0 2m3s frontend-tprcj 0/1 Terminating 0 2m3s frontend-xswch 0/1 Terminating 0 2m3s frontend-jcj9k 1/1 Running 0 0s frontend-g74rr 1/1 
Running 0 0s frontend-hfh6l 0/1 Terminating 0 10m frontend-hfh6l 0/1 Terminating 0 10m frontend-hfh6l 0/1 Terminating 0 10m frontend-n9wp8 1/1 Running 
0 1s ``` - Повторно применим манифест frontend-replicaset.yaml - Убедимся, что количество реплик вновь уменьшилось до одной ```console kubectl apply -f 
frontend-replicaset.yaml kubectl get rs frontend NAME DESIRED CURRENT READY AGE frontend 1 1 1 14m ``` - Изменим манифест таким образом, чтобы из 
манифеста сразу разворачивалось три реплики сервиса, вновь применим его ```console kubectl apply -f frontend-replicaset.yaml kubectl get rs frontend 
NAME DESIRED CURRENT READY AGE frontend 3 3 3 16m ```
### Обновление ReplicaSet
Давайте представим, что мы обновили исходный код и хотим выкатить новую версию микросервиса - Добавим на DockerHub версию образа с новым тегом 
(**v0.0.2**, можно просто перетегировать старый образ) ```console docker build -t darkzorro/hipster-frontend:v0.0.2 . docker push 
darkzorro/hipster-frontend:v0.0.2 ``` - Обновим в манифесте версию образа - Применим новый манифест, параллельно запустите отслеживание происходящего: 
```console kubectl apply -f frontend-replicaset.yaml | kubectl get pods -l app=frontend -w NAME READY STATUS RESTARTS AGE frontend-75k4s 1/1 Running 0 
9m32s frontend-n9wp8 1/1 Running 0 15m frontend-xs7mw 1/1 Running 0 9m32s ``` Давайте проверим образ, указанный в ReplicaSet: ```console kubectl get 
replicaset frontend -o=jsonpath='{.spec.template.spec.containers[0].image}' darkzorro/hipster-frontend:v0.0.2 ``` И образ из которого сейчас запущены 
pod, управляемые контроллером: ```console kubectl get pods -l app=frontend -o=jsonpath='{.items[0:3].spec.containers[0].image}' 
darkzorro/hipster-frontend:v0.0.1 darkzorro/hipster-frontend:v0.0.1 darkzorro/hipster-frontend:v0.0.1 ``` - Удалим все запущенные pod и после их 
пересоздания еще раз проверим, из какого образа они развернулись ```console for i in `kubectl get po | grep frontend | awk '{print $1}'`; do kubectl 
delete po $i; done; kubectl get pods -l app=frontend -o=jsonpath='{.items[0:3].spec.containers[0].image}' darkzorro/hipster-frontend:v0.0.2 
darkzorro/hipster-frontend:v0.0.2 darkzorro/hipster-frontend:v0.0.2 ```
> Обновление ReplicaSet не повлекло обновление запущенных pod по причине того, что ReplicaSet не умеет рестартовать запущенные поды при обновлении 
> шаблона
### Deployment
Для начала - воспроизведем действия, проделанные с микросервисом **frontend** для микросервиса **paymentService**. Результат: - Собранный и помещенный 
в Docker Hub образ с двумя тегами **v0.0.1** и **v0.0.2** - Валидный манифест **paymentservice-replicaset.yaml** с тремя репликами, разворачивающими из 
образа версии v0.0.1 ```console docker build -t darkzorro/hipster-paymentservice:v0.0.1 . docker build -t darkzorro/hipster-paymentservice:v0.0.2 . 
docker push darkzorro/hipster-paymentservice:v0.0.1 docker push darkzorro/hipster-paymentservice:v0.0.2 ``` Приступим к написанию Deployment манифеста 
для сервиса **payment** - Скопируем содержимое файла **paymentservicereplicaset.yaml** в файл **paymentservice-deployment.yaml** - Изменим поле 
**kind** с **ReplicaSet** на **Deployment** - Манифест готов 😉 Применим его и убедимся, что в кластере Kubernetes действительно запустилось три 
реплики сервиса **payment** и каждая из них находится в состоянии **Ready** - Обратим внимание, что помимо Deployment (kubectl get deployments) и трех 
pod, у нас появился новый ReplicaSet (kubectl get rs) ```yml apiVersion: apps/v1 kind: Deployment metadata:
  name: paymentservice labels: app: paymentservice spec: replicas: 3 selector: matchLabels: app: paymentservice template: metadata: labels: app: 
        paymentservice
    spec: containers: - name: paymentservice image: darkzorro/hipster-paymentservice:v0.0.1 ports: - containerPort: 50051 env: - name: PORT value: 
          "50051"
        - name: DISABLE_PROFILER value: "1" ``` ```console kubectl apply -f paymentservice-deployment.yaml kubectl get deploy NAME READY UP-TO-DATE 
AVAILABLE AGE paymentservice 3/3 3 3 100s kubectl get rs NAME DESIRED CURRENT READY AGE frontend 3 3 3 93m paymentservice-687c86c8bd 3 3 3 115s ```
### Обновление Deployment
Давайте попробуем обновить наш Deployment на версию образа **v0.0.2** Обратим внимание на последовательность обновления pod. По умолчанию применяется 
стратегия **Rolling Update**: - Создание одного нового pod с версией образа **v0.0.2** - Удаление одного из старых pod - Создание еще одного нового pod 
```console kubectl apply -f paymentservice-deployment.yaml | kubectl get pods -l app=paymentservice -w NAME READY STATUS RESTARTS AGE 
paymentservice-687c86c8bd-gdlwj 1/1 Running 0 4m36s paymentservice-687c86c8bd-qngpg 1/1 Running 0 4m36s paymentservice-687c86c8bd-rbh7c 1/1 Running 0 
4m36s paymentservice-85cc4d4d9-br77j 0/1 Pending 0 0s paymentservice-85cc4d4d9-br77j 0/1 Pending 0 0s paymentservice-85cc4d4d9-br77j 0/1 
ContainerCreating 0 0s paymentservice-85cc4d4d9-br77j 1/1 Running 0 7s paymentservice-687c86c8bd-gdlwj 1/1 Terminating 0 4m43s 
paymentservice-85cc4d4d9-bl4w4 0/1 Pending 0 0s paymentservice-85cc4d4d9-bl4w4 0/1 Pending 0 0s paymentservice-85cc4d4d9-bl4w4 0/1 ContainerCreating 0 
0s paymentservice-85cc4d4d9-bl4w4 1/1 Running 0 7s paymentservice-687c86c8bd-qngpg 1/1 Terminating 0 4m50s paymentservice-85cc4d4d9-dblvs 0/1 Pending 0 
0s paymentservice-85cc4d4d9-dblvs 0/1 Pending 0 0s paymentservice-85cc4d4d9-dblvs 0/1 ContainerCreating 0 0s paymentservice-85cc4d4d9-dblvs 1/1 Running 
0 7s paymentservice-687c86c8bd-rbh7c 1/1 Terminating 0 4m57s paymentservice-687c86c8bd-gdlwj 0/1 Terminating 0 5m16s paymentservice-687c86c8bd-gdlwj 
0/1 Terminating 0 5m16s paymentservice-687c86c8bd-gdlwj 0/1 Terminating 0 5m16s paymentservice-687c86c8bd-qngpg 0/1 Terminating 0 5m21s 
paymentservice-687c86c8bd-qngpg 0/1 Terminating 0 5m21s paymentservice-687c86c8bd-qngpg 0/1 Terminating 0 5m21s paymentservice-687c86c8bd-rbh7c 0/1 
Terminating 0 5m28s paymentservice-687c86c8bd-rbh7c 0/1 Terminating 0 5m28s paymentservice-687c86c8bd-rbh7c 0/1 Terminating 0 5m28s ``` Убедимся что: - 
Все новые pod развернуты из образа **v0.0.2** - Создано два ReplicaSet:
  - Один (новый) управляет тремя репликами pod с образом **v0.0.2** - Второй (старый) управляет нулем реплик pod с образом **v0.0.1** Также мы можем 
посмотреть на историю версий нашего Deployment: ```console kubectl get pods -l app=paymentservice -o=jsonpath='{.items[0:3].spec.containers[0].image}' 
darkzorro/hipster-paymentservice:v0.0.2 darkzorro/hipster-paymentservice:v0.0.2 darkzorro/hipster-paymentservice:v0.0.2 ``` ```console kubectl get rs 
NAME DESIRED CURRENT READY AGE frontend 3 3 3 101m paymentservice-687c86c8bd 0 0 0 9m22s paymentservice-85cc4d4d9 3 3 3 4m46s ``` ```console kubectl 
rollout history deployment paymentservice deployment.apps/paymentservice REVISION CHANGE-CAUSE 1 <none> 2 <none> ```
### Deployment | Rollback
Представим, что обновление по каким-то причинам произошло неудачно и нам необходимо сделать откат. Kubernetes предоставляет такую возможность: 
```console kubectl rollout undo deployment paymentservice --to-revision=1 | kubectl get rs -l app=paymentservice -w NAME DESIRED CURRENT READY AGE 
paymentservice-687c86c8bd 0 0 0 11m paymentservice-85cc4d4d9 3 3 3 6m29s paymentservice-687c86c8bd 0 0 0 11m paymentservice-687c86c8bd 1 0 0 11m 
paymentservice-687c86c8bd 1 0 0 11m paymentservice-687c86c8bd 1 1 0 11m paymentservice-687c86c8bd 1 1 1 11m paymentservice-85cc4d4d9 2 3 3 6m30s 
paymentservice-85cc4d4d9 2 3 3 6m30s paymentservice-687c86c8bd 2 1 1 11m paymentservice-85cc4d4d9 2 2 2 6m30s paymentservice-687c86c8bd 2 1 1 11m 
paymentservice-687c86c8bd 2 2 1 11m paymentservice-687c86c8bd 2 2 2 11m paymentservice-85cc4d4d9 1 2 2 6m31s paymentservice-85cc4d4d9 1 2 2 6m31s 
paymentservice-687c86c8bd 3 2 2 11m paymentservice-85cc4d4d9 1 1 1 6m31s paymentservice-687c86c8bd 3 2 2 11m paymentservice-687c86c8bd 3 3 2 11m 
paymentservice-687c86c8bd 3 3 3 11m paymentservice-85cc4d4d9 0 1 1 6m33s paymentservice-85cc4d4d9 0 1 1 6m33s paymentservice-85cc4d4d9 0 0 0 6m33s ``` 
В выводе мы можем наблюдать, как происходит постепенное масштабирование вниз "нового" ReplicaSet, и масштабирование вверх "старого".
### Deployment | Задание со ⭐
С использованием параметров **maxSurge** и **maxUnavailable** самостоятельно реализуем два следующих сценария развертывания: - Аналог blue-green: 1. 
  Развертывание трех новых pod 2. Удаление трех старых pod
- Reverse Rolling Update: 1. Удаление одного старого pod 2. Создание одного нового pod
  
 [Документация](https://kubernetes.io/docs/concepts/workloads/controllers/deployment/#strategy) с описанием стратегий развертывания для Deployment. 
maxSurge - определяет количество реплик, которое можно создать с превышением значения replicas Можно задавать как абсолютное число, так и процент. 
Default: 25% maxUnavailable - определяет количество реплик от общего числа, которое можно "уронить" Аналогично, задается в процентах или числом. 
Default: 25% В результате должно получиться два манифеста: - paymentservice-deployment-bg.yaml Для реализации аналога blue-green развертывания 
устанавливаем значения: - maxSurge равным **3** для превышения количества требуемых pods - maxUnavailable равным **0** для ограничения минимального 
количества недоступных pods ```yml apiVersion: apps/v1 kind: Deployment metadata:
  name: paymentservice labels: app: paymentservice spec: replicas: 3 strategy: type: RollingUpdate rollingUpdate:
      # Количество реплик, которое можно создать с превышением значения replicas Можно задавать как абсолютное число, так и процент. Default: 25%
      maxSurge: 3
      # Количество реплик от общего числа, которое можно "уронить" Аналогично, задается в процентах или числом. Default: 25%
      maxUnavailable: 0 selector: matchLabels: app: paymentservice template: metadata: labels: app: paymentservice spec: containers: - name: 
      paymentservice
        image: darkzorro/hipster-paymentservice:v0.0.1 ports: - containerPort: 50051 env: - name: PORT value: "50051" - name: DISABLE_PROFILER value: 
          "1"
``` Применим манифест: ```console kubectl apply -f paymentservice-deployment-bg.yaml deployment.apps/paymentservice created kubectl get po NAME READY 
STATUS RESTARTS AGE frontend-4m2gr 1/1 Running 0 56m frontend-7c8j4 1/1 Running 0 56m frontend-x52zj 1/1 Running 0 56m paymentservice-687c86c8bd-cplj8 
1/1 Running 0 13s paymentservice-687c86c8bd-ldtf4 1/1 Running 0 13s paymentservice-687c86c8bd-przht 1/1 Running 0 13s ``` В манифесте 
**paymentservice-deployment-bg.yaml** меняем версию образа на **v0.0.2** и применяем: ```console kubectl apply -f paymentservice-deployment-bg.yaml 
deployment.apps/paymentservice configured kubectl get po -w NAME READY STATUS RESTARTS AGE frontend-4m2gr 1/1 Running 0 66m frontend-7c8j4 1/1 Running 
0 66m frontend-x52zj 1/1 Running 0 66m paymentservice-687c86c8bd-cplj8 1/1 Terminating 0 10m paymentservice-687c86c8bd-ldtf4 1/1 Terminating 0 10m 
paymentservice-687c86c8bd-przht 1/1 Terminating 0 10m paymentservice-85cc4d4d9-fftbx 1/1 Running 0 9s paymentservice-85cc4d4d9-l7gdr 1/1 Running 0 9s 
paymentservice-85cc4d4d9-pcr65 1/1 Running 0 9s paymentservice-687c86c8bd-cplj8 0/1 Terminating 0 10m paymentservice-687c86c8bd-cplj8 0/1 Terminating 0 
10m paymentservice-687c86c8bd-cplj8 0/1 Terminating 0 10m paymentservice-687c86c8bd-ldtf4 0/1 Terminating 0 10m paymentservice-687c86c8bd-ldtf4 0/1 
Terminating 0 10m paymentservice-687c86c8bd-przht 0/1 Terminating 0 10m paymentservice-687c86c8bd-ldtf4 0/1 Terminating 0 10m 
paymentservice-687c86c8bd-przht 0/1 Terminating 0 10m paymentservice-687c86c8bd-przht 0/1 Terminating 0 10m ```
> Как видно выше, сначала создаются три новых пода, а затем удаляются три старых.
- paymentservice-deployment-reverse.yaml Для реализации Reverse Rolling Update устанавливаем значения: - maxSurge равным **1** для превышения 
количества требуемых pods - maxUnavailable равным **1** для ограничения минимального количества недоступных pods ```yml apiVersion: apps/v1 kind: 
Deployment metadata:
  name: paymentservice labels: app: paymentservice spec: replicas: 3 strategy: type: RollingUpdate rollingUpdate:
      # Количество реплик, которое можно создать с превышением значения replicas Можно задавать как абсолютное число, так и процент. Default: 25%
      maxSurge: 1
      # Количество реплик от общего числа, которое можно "уронить" Аналогично, задается в процентах или числом. Default: 25%
      maxUnavailable: 1 selector: matchLabels: app: paymentservice template: metadata: labels: app: paymentservice spec: containers: containers: - 
      name: paymentservice
        image: darkzorro/hipster-paymentservice:v0.0.1 ports: - containerPort: 50051 env: - name: PORT value: "50051" - name: DISABLE_PROFILER value: 
          "1"
``` Проверяем результат: ```console kubectl apply -f paymentservice-deployment-reverse.yaml | kubectl get pods -w NAME READY STATUS RESTARTS AGE 
frontend-4m2gr 1/1 Running 0 129m frontend-7c8j4 1/1 Running 0 129m frontend-x52zj 1/1 Running 0 129m paymentservice-687c86c8bd-d8k5p 1/1 Running 0 
6m18s paymentservice-687c86c8bd-pwx2m 1/1 Running 0 6m18s paymentservice-687c86c8bd-swrhz 1/1 Running 0 6m18s paymentservice-85cc4d4d9-lgvlt 0/1 
Pending 0 0s paymentservice-85cc4d4d9-lgvlt 0/1 Pending 0 0s paymentservice-687c86c8bd-swrhz 1/1 Terminating 0 6m18s paymentservice-85cc4d4d9-lgvlt 0/1 
ContainerCreating 0 0s paymentservice-85cc4d4d9-fdg4n 0/1 Pending 0 0s paymentservice-85cc4d4d9-fdg4n 0/1 Pending 0 0s paymentservice-85cc4d4d9-fdg4n 
0/1 ContainerCreating 0 0s paymentservice-85cc4d4d9-lgvlt 1/1 Running 0 1s paymentservice-687c86c8bd-d8k5p 1/1 Terminating 0 6m19s 
paymentservice-85cc4d4d9-fdg4n 1/1 Running 0 1s paymentservice-85cc4d4d9-l7j98 0/1 Pending 0 0s paymentservice-85cc4d4d9-l7j98 0/1 Pending 0 0s 
paymentservice-85cc4d4d9-l7j98 0/1 ContainerCreating 0 0s paymentservice-687c86c8bd-pwx2m 1/1 Terminating 0 6m19s paymentservice-85cc4d4d9-l7j98 1/1 
Running 0 2s paymentservice-687c86c8bd-swrhz 0/1 Terminating 0 6m49s paymentservice-687c86c8bd-swrhz 0/1 Terminating 0 6m49s 
paymentservice-687c86c8bd-swrhz 0/1 Terminating 0 6m49s paymentservice-687c86c8bd-pwx2m 0/1 Terminating 0 6m50s paymentservice-687c86c8bd-pwx2m 0/1 
Terminating 0 6m50s paymentservice-687c86c8bd-pwx2m 0/1 Terminating 0 6m50s paymentservice-687c86c8bd-d8k5p 0/1 Terminating 0 6m50s 
paymentservice-687c86c8bd-d8k5p 0/1 Terminating 0 6m50s paymentservice-687c86c8bd-d8k5p 0/1 Terminating 0 6m50s ```
### Probes
Мы научились разворачивать и обновлять наши микросервисы, но можем ли быть уверены, что они корректно работают после выкатки? Один из механизмов 
Kubernetes, позволяющий нам проверить это - 
[Probes](https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-startup-probes/). Давайте на примере микросервиса 
**frontend** посмотрим на то, как probes влияют на процесс развертывания. - Создадим манифест **frontend-deployment.yaml** из которого можно развернуть 
три реплики pod с тегом образа **v0.0.1** - Добавим туда описание *readinessProbe*. Описание можно взять из манифеста по 
[ссылке](https://github.com/GoogleCloudPlatform/microservices-demo/blob/master/kubernetes-manifests/frontend.yaml). Применим манифест с 
**readinessProbe**. Если все сделано правильно, то мы вновь увидим три запущенных pod в описании которых (**kubectl describe pod**) будет указание на 
наличие **readinessProbe** и ее параметры. Давайте попробуем сымитировать некорректную работу приложения и посмотрим, как будет вести себя обновление: 
- Заменим в описании пробы URL **/_healthz** на **/_health** - Развернем версию **v0.0.2** ```console kubectl apply -f frontend-deployment.yaml ``` 
Если посмотреть на текущее состояние нашего микросервиса, мы увидим, что был создан один pod новой версии, но его статус готовности **0/1**: Команда 
kubectl describe pod поможет нам понять причину: ```console for i in `kubectl get po | grep "0/1" | awk '{print $1}'`; do kubectl describe pod $i; 
done; Events:
  Type Reason Age From Message ---- ------ ---- ---- ------- Normal Scheduled 6m12s default-scheduler Successfully assigned 
  default/frontend-5bf5c6cc47-flx4x to kind-worker3 Normal Pulled 6m11s kubelet Container image "darkzorro/hipster-frontend:v0.0.2" already present on 
  machine Normal Created 6m11s kubelet Created container server Normal Started 6m11s kubelet Started container server Warning Unhealthy 61s (x35 over 
  6m1s) kubelet Readiness probe failed: HTTP probe failed with statuscode: 404
``` Как можно было заметить, пока **readinessProbe** для нового pod не станет успешной - Deployment не будет пытаться продолжить обновление. На данном 
этапе может возникнуть вопрос - как автоматически отследить успешность выполнения Deployment (например для запуска в CI/CD). В этом нам может помочь 
следующая команда: ```console kubectl rollout status deployment/frontend ``` Таким образом описание pipeline, включающее в себя шаг развертывания и шаг 
отката, в самом простом случае может выглядеть так (синтаксис GitLab CI): ```yml deploy_job:
  stage: deploy script: - kubectl apply -f frontend-deployment.yaml - kubectl rollout status deployment/frontend --timeout=60s rollback_deploy_job: 
  stage: rollback script:
    - kubectl rollout undo deployment/frontend when: on_failure ```
### DaemonSet
Рассмотрим еще один контроллер Kubernetes. Отличительная особенность DaemonSet в том, что при его применении на каждом физическом хосте создается по 
одному экземпляру pod, описанного в спецификации. Типичные кейсы использования DaemonSet: - Сетевые плагины - Утилиты для сбора и отправки логов 
(Fluent Bit, Fluentd, etc...) - Различные утилиты для мониторинга (Node Exporter, etc...) - ...
### DaemonSet | Задание со ⭐
Опробуем DaemonSet на примере [Node Exporter](https://github.com/prometheus/node_exporter) - Найдем в интернете 
[манифест](https://github.com/coreos/kube-prometheus/tree/master/manifests) **node-exporter-daemonset.yaml** для развертывания DaemonSet с Node 
Exporter - После применения данного DaemonSet и выполнения команды: kubectl port-forward <имя любого pod в DaemonSet> 9100:9100 доступны на localhost: 
curl localhost:9100/metrics Подготовим манифесты и развернем Node Exporter как DaemonSet: ```console kubectl create ns monitoring namespace/monitoring 
created kubectl apply -f node-exporter-serviceAccount.yaml serviceaccount/node-exporter created kubectl apply -f node-exporter-clusterRole.yaml 
clusterrole.rbac.authorization.k8s.io/node-exporter created kubectl apply -f node-exporter-clusterRoleBinding.yaml 
clusterrolebinding.rbac.authorization.k8s.io/node-exporter created kubectl apply -f node-exporter-daemonset.yaml daemonset.apps/node-exporter created 
kubectl apply -f node-exporter-service.yaml service/node-exporter created ``` Проверим созданные pods: ```console kubectl get po -n monitoring -o wide 
NAME READY STATUS RESTARTS AGE IP NODE NOMINATED NODE READINESS GATES node-exporter-f9rxd 2/2 Running 0 12s 172.19.0.4 kind-worker <none> <none> 
node-exporter-mj9z8 2/2 Running 0 12s 172.19.0.5 kind-worker3 <none> <none> node-exporter-vrrsx 2/2 Running 0 12s 172.19.0.3 kind-worker2 <none> <none> 
``` запустим проброс порта: ```console kubectl port-forward node-exporter-f9rxd 9100:9100 -n monitoring & Forwarding from 127.0.0.1:9100 -> 9100 
Forwarding from [::1]:9100 -> 9100 ``` И убедимся, что мы можем получать метрики: ```console curl localhost:9100/metrics Handling connection for 9100
# HELP go_gc_duration_seconds A summary of the GC invocation durations. TYPE go_gc_duration_seconds summary
go_gc_duration_seconds{quantile="0"} 0 go_gc_duration_seconds{quantile="0.25"} 0 go_gc_duration_seconds{quantile="0.5"} 0 
go_gc_duration_seconds{quantile="0.75"} 0 go_gc_duration_seconds{quantile="1"} 0 go_gc_duration_seconds_sum 0 go_gc_duration_seconds_count 0
# HELP go_goroutines Number of goroutines that currently exist. TYPE go_goroutines gauge
go_goroutines 6
# HELP go_info Information about the Go environment. TYPE go_info gauge
go_info{version="go1.12.5"} 1
# HELP go_memstats_alloc_bytes Number of bytes allocated and still in use. TYPE go_memstats_alloc_bytes gauge
go_memstats_alloc_bytes 913648
# HELP go_memstats_alloc_bytes_total Total number of bytes allocated, even if freed. TYPE go_memstats_alloc_bytes_total counter
go_memstats_alloc_bytes_total 913648 ...
# TYPE process_cpu_seconds_total counter
process_cpu_seconds_total 0
# HELP process_max_fds Maximum number of open file descriptors. TYPE process_max_fds gauge
process_max_fds 1.048576e+06
# HELP process_open_fds Number of open file descriptors. TYPE process_open_fds gauge
process_open_fds 7
# HELP process_resident_memory_bytes Resident memory size in bytes. TYPE process_resident_memory_bytes gauge
process_resident_memory_bytes 1.1718656e+07
# HELP process_start_time_seconds Start time of the process since unix epoch in seconds. TYPE process_start_time_seconds gauge
process_start_time_seconds 1.67330140145e+09
# HELP process_virtual_memory_bytes Virtual memory size in bytes. TYPE process_virtual_memory_bytes gauge
process_virtual_memory_bytes 1.178624e+08
# HELP process_virtual_memory_max_bytes Maximum amount of virtual memory available in bytes. TYPE process_virtual_memory_max_bytes gauge
process_virtual_memory_max_bytes -1
# HELP promhttp_metric_handler_requests_in_flight Current number of scrapes being served. TYPE promhttp_metric_handler_requests_in_flight gauge
promhttp_metric_handler_requests_in_flight 1
# HELP promhttp_metric_handler_requests_total Total number of scrapes by HTTP status code. TYPE promhttp_metric_handler_requests_total counter
promhttp_metric_handler_requests_total{code="200"} 0 promhttp_metric_handler_requests_total{code="500"} 0 
promhttp_metric_handler_requests_total{code="503"} 0 ```
### DaemonSet | Задание с ⭐⭐
- Как правило, мониторинг требуется не только для worker, но и для master нод. При этом, по умолчанию, pod управляемые DaemonSet на master нодах не 
разворачиваются - Найдем способ модернизировать свой DaemonSet таким образом, чтобы Node Exporter был развернут как на master, так и на worker нодах 
(конфигурацию самих нод изменять нельзя) - Отразим изменения в манифесте Материал по теме: [Taint and 
Toleration](https://kubernetes.io/docs/concepts/scheduling-eviction/taint-and-toleration/). Решение: для развертывания DaemonSet на master нодах нам 
необходимо выдать **допуск** поду. Правим наш **node-exporter-daemonset.yaml**: ```yml tolerations: - operator: Exists ``` Применяем манифест и 
проверяем, что DaemonSet развернулся на master нодах. ```console kubectl apply -f node-exporter-daemonset.yaml daemonset.apps/node-exporter configured 
kubectl get po -n monitoring -o wide NAME READY STATUS RESTARTS AGE IP NODE NOMINATED NODE READINESS GATES node-exporter-7rm45 2/2 Running 0 15s 
172.19.0.2 kind-control-plane <none> <none> node-exporter-bkhl8 2/2 Running 0 11s 172.19.0.4 kind-worker <none> <none> node-exporter-dzqr7 2/2 Running 
0 7s 172.19.0.3 kind-worker2 <none> <none> node-exporter-tgt56 2/2 Running 0 3s 172.19.0.5 kind-worker3 <none> <none>
````


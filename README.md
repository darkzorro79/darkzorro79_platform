# darkzorro79_platform

## Security

### task01

- Создадим Service Account **bob** и дади ему роль **admin** в рамках всего кластера

01-serviceaccount-bob.yaml:

```yml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: bob
  namespace: default
```

02-role.yaml:

```yml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: bob
roleRef:
  kind: ClusterRole
  name: admin
  apiGroup: rbac.authorization.k8s.io
subjects:
- kind: ServiceAccount
  name: bob
  namespace: default
```

- Создадим Service Account **dave** без доступа к кластеру

03-serviceaccount-dave.yaml:

```yml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: dave
  namespace: default
```

### task02

- Создадим Namespace prometheus

01-namespace.yaml:

```yml
apiVersion: v1
kind: Namespace
metadata:
  name: prometheus
```

- Создадим Service Account **carol** в этом Namespace

02-serviceaccount-carol.yaml

```yml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: carol
  namespace: prometheus
```

- Дадим всем Service Account в Namespace prometheus возможность делать **get, list, watch** в отношении Pods всего кластера

03-clusterrole.yaml

```yml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: prometheus
rules:
- apiGroups: [""]
  verbs: ["get", "list", "watch"]
  resources: ["pods"]
```

04-clusterrolebinding.yaml

```yml
kind: ClusterRoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: prometheus
roleRef:
  kind: ClusterRole
  name: prometheus
  apiGroup: rbac.authorization.k8s.io
subjects:
- kind: Group
  name: system:serviceaccounts:prometheus
  apiGroup: rbac.authorization.k8s.io
```

### task03

- Создадим Namespace **dev**

01-namespace.yaml

```yml
apiVersion: v1
kind: Namespace
metadata:
  name: dev
```

- Создадим Service Account **jane** в Namespace **dev**

02-serviceaccount-jane.yaml

```yml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: jane
  namespace: dev
```

- Дадим **jane** роль **admin** в рамках Namespace **dev**

03-jane-rb.yaml

```yml
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: jane
  namespace: dev
roleRef:
  kind: ClusterRole
  name: admin
  apiGroup: rbac.authorization.k8s.io
subjects:
- kind: ServiceAccount
  name: jane
  namespace: dev
```

- Создадим Service Account **ken** в Namespace **dev**

04-serviceaccount-ken.yaml

```yml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: ken
  namespace: dev
```

- Дадим **ken** роль **view** в рамках Namespace **dev**

05-ken-rb.yaml

```yml
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: ken
  namespace: dev
roleRef:
  kind: ClusterRole
  name: view
  apiGroup: rbac.authorization.k8s.io
subjects:
- kind: ServiceAccount
  name: ken
  namespace: dev
```

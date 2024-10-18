# patchmoney-docker

A solution for running patchmonkeyctl prometheus-exporter in OKD. 

## Workflow Overview
The `Dockerfile` defines the steps to clone the patchmonkeyctl source code, build the binary, and package it into a distroless Docker image. The resulting image contains only the patchmonkeyctl binary. GitLab CI/CD automates the image build process and publishes the final image to the GitLab Container Registry for deployment in Kubernetes.

Once the Docker images are stored in GitLab's container registry, the OKD platform will need to pull those images to create a `DeploymentConfig`. Since the registry is currently private, OKD must authenticate with the GitLab server to pull the images. This authentication process requires creating two secrets: one for the registry container and one for the GitLab server.

```bash
$ oc create secret docker-registry <secret_name1> --docker-server=gitlab-registry.oit.duke.edu --docker-username=<gitlab_uname> --docker-password=<gitlab_user_pwd>
$ oc create secret docker-registry <secret_name2> --docker-server=gitlab.oit.duke.edu --docker-username=<gitlab_uname> --docker-password=<gitlab_user_pwd>
```

After creating the secrets, link them to the pull service

```bash
$ oc secrets link default <secret_name1> --for=pull
$ oc secrets link default <secret_name2> --for=pull
```

In OKD, begin by creating a secret to store the authentication token. Then, create a `DeploymentConfig` for patchmonkeyctl. A sample manifest YAML is provided below.

```yaml
apiVersion: apps.openshift.io/v1
kind: DeploymentConfig
metadata:
  namespace: patchmonkey-test
  name: patchmonkeyctl
spec:
  selector:
    app: patchmonkeyctl
  replicas: 3
  template:
    metadata:
      labels:
        app: patchmonkeyctl
    spec:
      containers:
        - name: container
          image: 'gitlab-registry.oit.duke.edu/vn74/patchmoney-docker:latest'
          imagePullPolicy: Always
          command:
            - ./patchmonkeyctl
          env:
            - name: TOKEN          
              valueFrom:
                secretKeyRef:            # The authentication token should be created 
                  name: auth-token       # manually in OKD as a secret.
                  key: auth-token
          args:
            - prometheus-exporter
            - '--token'
            - $(TOKEN)
            - '--address'
            - '0.0.0.0:9633'
            - '--verbose'
            - '--timestamps'
          ports:
            - containerPort: 8080
              protocol: TCP
    type: Rolling
    rollingParams:
      updatePeriodSeconds: 1
      intervalSeconds: 1
      timeoutSeconds: 600
      maxUnavailable: 25%
      maxSurge: 25%
  triggers:
    - type: ConfigChange
```

> **Optional:** In order to configure a liveness and a readiness probe for the containers, include the following under `containers` definition in the `DeploymentConfig`. Visit [Kubernetes Documentation](https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-startup-probes/) for additional information
```yaml
livenessProbe:
  httpGet:
    path: /metrics
    port: 9633                 # Under the current binary, this is the port that 
  initialDelaySeconds: 10      # patchmonkey prometheus-exporter listen on.
  periodSeconds: 15

readinessProbe:                # Configurations for the readiness probes are similar
  httpGet:                     # to those for liveness probes.   
    path: /metrics
    port: 9633                 
  initialDelaySeconds: 10      
  periodSeconds: 15
```
Ensure that you are logged into OKD and have the correct Kubernetes context set. To apply the `DeploymentConfig`, use the following command:

```bash
oc apply -f DEPLOYMENTCONFIG_FILE_NAME
```

> **Note:** We are using `oc` here because `DeploymentConfig` is specific to OKD. If you're working with a standard Kubernetes environment, you can replace `DeploymentConfig` with `Deployment` and use the `kubectl` command with the same syntax.

Once the `DeploymentConfig` is up and running, you can verify that the patchmonkeyctl prometheus-exporter is working as expected by checking the logs of one of the pods. The logs should display output similar to the following:
```bash
INFO patchmonkeyctl 🐵 : starting listener address=:9633 endpoint=/metrics poll-interval=5m0
```

Next, create a `Service` for the `DeploymentConfig`. A sample YAML file is provided below:
```yaml
apiVersion: v1
kind: Service
metadata:
  name: patchmonkeyctl
  namespace: patchmonkey-test
  labels:
    app: patchmonkeyctl 
spec:
  selector:
    app: patchmonkeyctl
  ports:
    - name: patchmonkeyctl        # This should be a named port for the monitoring service
      protocol: TCP
      port: 9633
      targetPort: 9633            
```

To apply the `Service`, use the following command:

```bash
oc apply -f SERVICE_FILE_NAME
```

Next, create a `Route` for the `Service`. A sample manifest is provided below:
```yaml
kind: Route
apiVersion: route.openshift.io/v1
metadata:
  name: patchmonkeyctl
  namespace: patchmonkey-test
  labels:
    app: patchmonkeyctl
spec:
  to:
    kind: Service
    name: patchmonkeyctl
  tls: {}
  path: /metrics
  port:
    targetPort: 9633
```
To apply the `Route`, run:

```bash
oc apply -f ROUTE_FILE_NAME
```
> **Note:** Similar to `DeploymentConfig`, `Route` is specific to OKD. In a standard Kubernetes environment, you can use `Ingress` instead.

Once configured, you can verify the `Route` by running a curl command against the route URL to view the metrics:
```bash
curl http://my-route-patchmonkey-test.apps.dev.okd4.fitz.cloud.duke.edu/metrics
```

Finally, to collect all metrics into Prometheus, create a monitoring service. For more details, refer to the [Duke OKD Documentation](https://okd-docs.cloud.duke.edu/examples/prometheus-user-defined-monitoring/).
```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: demo-servicemonitor
  namespace: patchmonkey-test
spec:
  jobLabel: patchmonkeyctl
  endpoints:
      - path: /metrics
        port: patchmonkeyctl
  namespaceSelector:
    matchNames:
        - patchmonkey-test
  selector:
    matchLabels:
      app: patchmonkeyctl
```
To apply the monitoring service, use:
```bash
oc apply -f MONITORING_FILE_NAME
```
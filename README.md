# patchmoney-docker

A solution for running patchmonkeyctl prometheus-exporter in OKD. 

## Workflow Overview
The Dockerfile defines the steps to clone the patchmonkeyctl source code, build the binary, and package it into a distroless Docker image. The resulting image contains only the patchmonkeyctl binary. GitLab CI/CD automates the image build process and publishes the final image to the GitLab Container Registry for deployment in Kubernetes.

Once the Docker images are stored in GitLab's container registry, the OKD platform will need to pull those images to create a DeploymentConfig. Since the registry is currently private, OKD must authenticate with the GitLab server to pull the images. This authentication process requires creating two secrets: one for the registry container and one for the GitLab server.

```bash
$ oc create secret docker-registry <secret_name1> --docker-server=gitlab-registry.oit.duke.edu --docker-username=<gitlab_uname> --docker-password=<gitlab_user_pwd>
$ oc create secret docker-registry <secret_name2> --docker-server=gitlab.oit.duke.edu --docker-username=<gitlab_uname> --docker-password=<gitlab_user_pwd>
```

After creating the secrets, link them to the pull service

```bash
$ oc secrets link default <secret_name1> --for=pull
$ oc secrets link default <secret_name2> --for=pull
```

In OKD, start by creating a secret to store the authentication token. Next, create a `DeploymentConfig` that pulls the image from `gitlab-registry.oit.duke.edu/vn74/patchmoney-docker:latest`.

Within the `DeploymentConfig` YAML, under the `containers` section, include the following configuration to run the Prometheus exporter and authenticate with the server using the injected token:

```yaml
apiVersion: apps.openshift.io/v1
kind: DeploymentConfig
metadata:
  namespace: demo-namespace  
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
                  name: auth-token       # manually in OKD as a secret
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
  strategy:
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
Once the `DeploymentConfig` is up and running, you can verify that the patchmonkeyctl prometheus-exporter is working as expected by checking the logs of one of the pods. The logs should display output similar to the following:
```bash
INFO patchmonkeyctl 🐵 : starting listener address=:9633 endpoint=/metrics poll-interval=5m0
```

Next, using the OKD interface, create a `Service` for the `DeploymentConfig`. Ensure that both the `port` and `targetPort` are set to `9633`. After that, create a route that also listens on port `9633`, with the endpoint set to `/metrics`.

Once configured, you can verify it by running a curl command against the route URL to view the metrics:

Sample curl command:
```bash
curl http://my-route-patchmonkey-test.apps.dev.okd4.fitz.cloud.duke.edu/metrics
```
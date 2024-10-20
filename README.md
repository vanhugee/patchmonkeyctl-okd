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

In order to deploy patchmonkeyctl onto OKD, begin by creating a secret to store the authentication token. Next, use the `patchmonkeyctl_yaml` file which contains the configuration for the following resources: DeploymentConfig, Service, Route, and Monitoring Service. 

To apply the resources, run the following command:
```bash
$ oc apply -f patchmonkeyctl.yaml
```

> **Note:** We are using `oc` here because `DeploymentConfig` and `Route` is specific to OKD. If you're working with a standard Kubernetes environment, you can replace `DeploymentConfig` with `Deployment` and `Route` with `Ingress`, and use the `kubectl` command with the same syntax.

You can verify the `DeploymentConfig` by checking the logs of one of the pods. The logs should display output similar to the following:
```bash
INFO patchmonkeyctl 🐵 : starting listener address=:9633 endpoint=/metrics poll-interval=5m0
```
You can also run a curl command against the route URL to view the metrics:
```bash
$ curl <ROUTE_URL>
```
The deployment includes a Monitoring Service that collects the metrics into Prometheus. For more details, refer to the [Duke OKD Documentation](https://okd-docs.cloud.duke.edu/examples/prometheus-user-defined-monitoring/).

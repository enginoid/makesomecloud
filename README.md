# FAQ

## What are some good buzzwords to describe this project?

I'm proud to state that this project incorporates all of these buzzwords:

  - [x] Cloud Computing
  - [x] Continuous Deployment
  - [x] Containers
  - [x] Container Orchestration
  - [x] Google Infrastructure for Everyone Else
  - [x] Microservices
  - [x] Monorepo
  - [x] Infrastructure as Code
  - [x] Phoenix Environments

## More concretely, what does this project actually offer?

It's a way to Bootstrap a microservices infrastructure...

  * ...on Google Cloud Platform
  * ...in a reproducible way (via Terraform files + Kubernetes manifests + Concourse pipeline files)
  * ...freeing you from spending time on tedious essentials (e.g., setting up a bastion host)
  * ...but letting you continuously deploy (with Concourse)
  * ...a Finagle microservice (more languages to come!)
  * ...that runs on Kubernetes
  * ...and is stored in a monorepo (backed by Pants as a build system)
  * ...is relatively cost-effective (thanks to GCP pricing and Kubernetes)

## What should I do with this?

Right now, it's very bare-bones and is missing some important pieces of a production infrastructure, but you could:

  * Clone this as a base for your infrastructure.
  * Look at how the pieces are put together for inspiration.
  * Deploy it for a few hours as a chance to play with GCP/Terraform/Kubernetes/Concourse/Finagle.

## Why did you build this?

Scaling systems brings many organizational and technical scaling challenges. This project is meant to codify some good practices when setting up a distributed service infrastructure.

Some of these practices can be important to growing organizations building complex systems (e.g., microservices, infrastructure as code, a monorepo for server-side development, and continuous deployments). These practices may not work perfectly for everyone, but they can be a good starting point for projects with similar requirements.

It's also an experiment in building a production-ready infrastructure from scratch using open-source pieces and a public cloud. There are many examples for Terraform and Kubernetes, but there are few projects that tie everything together into something you can actually use as a foundation for a new project.

Lastly, it let me play with some technologies that show great promise and I've wanted to work with (Kubernetes, Concourse and GCP).

## I need a backend infrastructure. Should I use this?

Like everything, it depends. There are some compelling reasons for why you might not want to use this.

**You might not need a distributed infrastructure.** I would definitely think very hard about whether your requirements are covered by App Engine, Firebase, Heroku, AWS Lambda, Google Cloud Functions, or similar platforms. They may not be the most cost-effective, feature-complete or flexible, but they sure will help you get the biggest bang for your product development buck.

Particularly, if it's not a priority for your organization to solve these challenges, you will both have lower product turnaround times and waste engineering time and product quality on properly running a distributed infrastructure. This foundation is meant to get you started quickly, but remember that distributed architecture is not a "fire-and-forget" product; it requires engineers that can allocate time to understanding deeply how the infrastructure works and how to operate it on a day-to-day basis and during operational incidents.

**The components are production-ready, but not very mature.**  Kubernetes, Terraform, Pants, and Concourse in particular are all evolving very quickly. You might run into limitations or quirks, such as:

  * Kubernetes
    * Does not easily support stateful services.
    * It solves service discovery for its own services, but you still need something else for the rest.
    * Secrets management does not appear to be guarding the secrets very tightly.
  * GCP
    * AWS has some pretty useful managed services that GCP does not (e.g., hosted Postgres).
    * Many GCP features are in alpha, so they're not production-recommended.
    * Docs are sometimes a slightly tricky to navigate compared to AWS.
  * Terraform:
    * Due to community size, GCP support is limited and not as battle-tested as AWS.

If the risk outweighs the reward, this is not a good starting point.

# Deployment

## High-level steps

  1. Clone the project
  2. Configure (set up GCP project, )
  3. Install `gcloud` and `terraform`

(The plan is to eliminate steps (4) and (7) redundant.)

## Low-level steps

> **WARNING:** This will cost you money unless it's all covered by your GCP trial. Although Terraform limits this risk, it's possible that operations interfere with pre-existing infastructure. I expect you to know what you're doing, and I don't take responsibility for anything!

#### 1. Clone the project

  1. Clone the source repository.
  2. Clone the secrets repository.

#### 2. Configure

  1. **Create your GCP project.** If you don't have an account, sign up for one. After that, create your first project and take note of the project name.

  2. **Configure some variables.**

    * Set the variables in the [`config`](/config) directory. You can see what each one does in the directory's [README](/config/README.md).

    * Set the variables in [`terraform/infrastructure/terraform.tfvars`](terraform/infrastructure/terraform.tfvars). Each of the values is documented in that file.

  3. **Perform the setup steps that can't be codified in manifests.** The aspiration of this project is to require no manual steps beyond what's reasonable to effect changes to the system; essentially, applying manifests. However, it's currently not possible to automate every single step, so you'll need to perform a few manual steps for now:

    1. **Create a service account for Concourse.** (This step is a workaround, and is probably temporary.) Once you've configured everything, run the following scripts to create a service account for Concourse that has access to the project's Google Container Registry:

    ```
    gcloud iam service-accounts create concourse
    ./scripts/iam-create-service-account.sh concourse
    ./scripts/gcr-grant-service-account.sh concourse
    ```

    2. **Create a service account for the Concourse worker.** Support for creating service accounts has not been added to Terraform at this stage, so we'll create it manually for now:

    ```
    gcloud iam service-accounts create concourse
    ```

    3. **Download a keyfile for the Concourse worker.** This keyfile is used by the CI pipeline to authenticate with the docker registry for pushing and pulling containers. We inject this file into the Concourse pipeline when we create it.

    ```
    gcloud iam service-accounts keys create \
      ../<secrets_directory>/concourse_worker/service-account-keyfile.json \
      --iam-account concourse@<gcp_project_name>.iam.gserviceaccount.com
    ```

    4. **Allow the concourse worker to read to and write from the container registry.** These steps are necessary because a nonempty registry is a prerequisite for setting registry permissions:

    ```
    # Push to the repo from a privileged account. We can't grant permissions on the
    # bucket until it exists, and we can't create the bucket manually either, so we
    # need to push a small docker image to it to make it possible to set permissions
    # correctly.
    docker pull alpine
    docker tag alpine <gcr_continent>.gcr.io/<project_name>/alpine
    docker push alpine <gcr_continent>.gcr.io/<project_name>/alpine

    # This is saying two things:
    #  - let the service account own (read+write) everything in this bucket
    #  - all new objects created in the future should have this service account as owner
    gsutil acl ch -ru concourse@<gcp_project_name>.iam.gserviceaccount.com:OWNER gs://<gcr_continent>.artifacts.<gcp_project_name>.appspot.com
    gsutil defacl ch -u concourse@<gcp_project_name>.iam.gserviceaccount.com:OWNER gs://<gcr_continent>.artifacts.<gcp_project_name>.appspot.com
    ```

#### 3. Set up `gcloud`, `kubectl`, and `terraform`

  * **Install tools.** You'll need the following tools for now:

    * `Google Cloud SDK`. [Installation instructions.](https://cloud.google.com/sdk/)
    * `Terraform`. [Installation instructions.](https://www.terraform.io/intro/getting-started/install.html)

  * **Initialize Google Cloud SDK.** `gcloud init` will log you in and let you set the default project to the one you just created. If you already use GCP, make sure to set the project to the one you'll be using for this tutorial via `gcloud config set project <project_name>`.

  * **Set up kubectl.** `gcloud components install kubectl`

#### 3. Build your infrastructure

Navigate to `infrastructure/terraform`. To see what resources Terraform will create, run this:

```
terraform plan
```

To execute those changes, run this:

```
terraform apply
```

> **About the bastion host.** The default network for GCP allows external access to all services on the network. This project creates a new network that's more restrictive. Internal machines on that network can communicate with each other, but they cannot be reached from the outside world unless you create a specific firewall rule to allow that access (alternatively, they may be exposed through a load balancer). This reduces the attack surface of the infrastructure, but imposes a requirement to access internal services through SSH tunnels via the bastion host. The bastion host is configured to be accessible on port 22 to outsiders, but has access to all machines in the internal network.

After the command has run, you will get the IP of your Kubernetes cluster. To exercise that both the bastion and the Kubernetes are working properly, you can execute this command that gets a list of available services from Kubernetes through the bastion host:

```
./scripts/kubectl.sh get services
```

> **About `scripts/kubectl.sh`.** `kubectl.sh` takes care of discovering the bastion host and Kubernetes cluster, creating a tunnel from your computer to the Kubernetes cluster, and executing an arbitrary `kubectl` command through that tunnel.

#### 4. Deploy some Kubernetes containers

There will be more stuff running on Kubernetes going forward (e.g., Consul, Vault). Right now, it's just Concourse, the continuous integration system. To set it up, first we have to make our secrets available to Kubernetes. Because our secrets are stored in a separate directory, we'll apply them like this:

```
scripts/kubectl.sh apply -f ../makesomecloud-secrets/concourse_kubernetes/
```

Then, we'll apply the manifests for the `concourse-web` and `concourse-postgresql` workers.

```
scripts/kubectl.sh apply -f infrastructure/kubernetes/concourse/manifests/
```

Our two services should now be right there:

```
$ ./scripts/kubectl.sh get services
NAME                   CLUSTER-IP     EXTERNAL-IP       PORT(S)             AGE
concourse-postgresql   10.27.252.72   <nodes>           5432/TCP            1d
concourse-web          10.27.241.23   104.199.4.134     80/TCP,2222/TCP     1d
kubernetes             10.27.240.1    <none>            443/TCP             1d
```

To verify that everything is working, browse to the Concourse web console using the external IP of `concourse-web`. In this case, you would go to http://104.199.4.134/.

(If you ran `kubectl get services` quickly after running `terraform apply`, you might see the external IP for `concourse-web` as `<pending>`. This is because a forwarding rule hasn't been created on GCP yet. You'll need to keep querying until the IP address shows up.)

#### 5. Activate the Concourse worker

When you run a continuous integration pipeline, the work in that pipeline is performed by a Concourse worker. This worker will fetch your source code and orchestrate containers to make sure that your CI job can run. Because this orchestrates Docker containers and would need privileged container access on Kubernetes, it runs in an instance group rather than in Kubernetes containers.

Because this project does not include service discovery yet, the workers discover the `concourse-web` hosts through instance metadata. A startup script reads that metadata and sets it as an environment variable accessible to the service. In order to allow the worker instances to communicate with `concourse-web`, we have to update the instance metadata with the external IP of the `concourse-web` Kubernetes service that we just created.

To do this, change the `concourse_tsa_host` in `terraform.tfvars` to be the external IP we just received:

```
concourse_tsa_host = "104.199.4.134"
```

Then, run `terraform plan` to see what the change will do. The output will look like the following:

```
~ module.gcp.google_compute_instance_group_manager.concourse_worker
    instance_template: "https://www.googleapis.com/compute/v1/projects/make-some-cloud/global/instanceTemplates/concourse-worker20160915180725193964436w3v" => "${google_compute_instance_template.concourse_worker.self_link}"

-/+ module.gcp.google_compute_instance_template.concourse_worker
    ...
    ...
    metadata.concourse-tsa-host:                "1.1.1.1" => "104.199.4.134" (forces new resource)
    ...
    ...
```

This is saying two things:

  * The change we made to the instance template is going to trigger a new instance template to be created.
  * The instance group manager that uses this template will be modified to use a new instance template.

When an instance group is updated, the default Terraform behavior is to recreate the instances. This will cause the instance metadata to be updated, which in turn will allow the startup script to read the correct IP address of the `concourse-web` host.

Run `terraform apply` to execute this change.

#### 6. Set up the CI pipeline and build the service

Navigate to the Concourse web console to obtain the right version of the `fly` binary that you'll use to manage the continuous integration pipelines. Look for the small icons that represent Mac OS X, Linux, and Windows, and click the one for your OS to download the binary. Make this binary accessible on your path.

You can now log in:

```
fly --target "monorepo" login --concourse-url "http://104.199.4.134/"
```

The default username and password are `ci` and `password`, respectively. This information comes from the Kubernetes secrets file for `concourse-web`.

Now we can set up the pipeline. The YAML files that describe the continuous integration pipelines are templates, so you'll have to pass along any variables in the tempalte through the `fly` command. The `./scripts/set-pipeline.sh` takes care of setting these variables to the correct values given your configuration in `config/` and secrets in the secrets directory, so you should use that instead of using `fly` directly.

Let's start by creating the CI pipeline for `pants-builder`. This is a pipeline that creates the `pants-builder` docker image

```
./scripts/set-pipeline.sh pants-builder
```

> **About the `pants-builder` docker image.** This image as the base image to build services in the `services` pipeline. The `pants-builder` has the right system dependencies to compile your tools, but it also containers a compilation cache for your entire project that's used when building services. This means that every time you run a service build, your packages will all have been compiled recently so the build will be incremental and therefore very fast for the common case where only a few files have been changed. This is similar to the approach of using a shared build cache, but prevents maintenance and locking issues due to mutable state shared between multiple workers.

Now that your pipeline has been created, this is what you'll see in the console:

![image](https://cloud.githubusercontent.com/assets/62200/18583049/d6d1c4aa-7bf7-11e6-96e4-a227565cacf2.png)

You need to unpause this pipeline to start the first build. After you've unpaused it, your first build will start and look something like this once it's finished running:

![image](https://cloud.githubusercontent.com/assets/62200/18583103/0bc18d4e-7bf8-11e6-89e0-9484e12e10ff.png)

Wait for the build to finish and for the image to be pushed to the registry before proceeding.

After the `pants-builder` image has been created and pushed, create the pipeline that builds services:

```
./scripts/set-pipeline.sh services
```

When this build has passed, you're ready to deploy the service.

#### 7. Deploy the service

Using the commit ID from the last run, deploy your service.

```
./scripts/deploy.sh helloworld <service>
```

Get the IP of the load balancer for the service:

```
$ scripts/kubectl.sh get service helloworld -o template --template='{{(index .status.loadBalancer.ingress 0).ip}}'
104.155.105.113
```

Get in touch with the service:

```
curl http://104.155.105.113/hello
Hello, World!
```

#### 8. Build out your infrastructure

You now have an infrastructure that's almost entirely set up through declarative configuration. You can:

  * Work on the `helloworld` service and push it. Once it has built, you can deploy it with `deploy.sh`.
  * Create more CI pipelines.
  * Make changes to your infrastructure via Terraform:
    * Deploy more instances.
    * A performant pub/sub service via `google_pubsub_topic` and `google_pubsub_subscription`.
    * A managed MySQL database via the `google_sql_*` resources.
    * An HTTPS load balancer via `google_compute_ssl_certificate` and `google_compute_target_https_proxy`.
    * Hook up your domain via the `google_dns_*` resources.
  * Deploy almost anything on Kubernetes.

#### 9. (Optional) Destroy your infrastructure

To delete everything that was created in this project, run `terraform destroy`.

# Aspirations

Obviously, this project only provides the bare minimum. In order to effectively help bootstrap good infrastructure, we need:

  * A CI pipeline that builds any service.
  * Automatic deployments.
  * RPC between services.
  * Examples of services in more programming languages.
  * Structured logging for each service.
  * All logs sent to a centralized place (e.g. Stackdriver Logging).
  * Metric collection (e.g. Stackdriver, Prometheus)
  * Proper service discovery of internal and external services (Consul).
  * Secrets management that doesn't use a folder, and allows restricted access for services (Vault).
  * ...

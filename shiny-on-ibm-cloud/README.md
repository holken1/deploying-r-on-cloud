# Deploying Shiny apps on IBM Cloud

Holger Hellebro, IBM Global Business Services

2018-08-27

## Introduction

In this tutorial we will create a Kubernetes cluster and a container
registry on IBM Cloud. We will build and push a demonstration Shiny
application using Docker. We will then deploy the application to
Kubernetes and exposed it to the Internet.

We will use a free account on IBM Cloud and a free Kubernetes
cluster. A free cluster is aimed at evaluation and have certain
limitations but we can still use it to host a few Shiny
applications. The main drawback is that the cluster will be deleted
after a month. However, we are free to create a new one, and
re-deploying the application is only a few commands.

But of course, for any production work I would strongly recommend
upgrading to a standard cluster. It doesn't have to be a big and
expensive cluster, provided your workload is limited.

Disclaimer: This tutorial including the comments around costs and
pricing is based on the current conditions. Since the terms and
policies change regularly, you should always check the terms when you
sign up, and before you create services on the cloud.

## Prerequisites

The Shiny app you want to deploy needs to be packaged as a Docker
image. In this tutorial we'll deploy an already packaged application,
but when you want to use your own, you'll have to make sure it can run
as a Docker container.

## Setting up the IBM Cloud environment

Before we can begin the actual deployment we need to register and set
up a few things on IBM Cloud.

### Registering on IBM Cloud

https://www.ibm.com/cloud/

Click `Sign up` and enter your details. Verify your mail address by
clicking the link in the mail you receive. Now log in and accept the
privacy agreement.

### Creating a Kubernetes Cluster

The cluster is where your application will run. In the free tier we
are restricted to using one server only, but it's enough to get
started, and for small applications with not too many users, it might
be just what you need.

Click "Catalog" in the top navigation bar and select the "IBM Cloud
Kubernetes Service" under the "Containers" heading.

At this point you need to upgrade your account and enter a credit
card, but rest assured, the cluster we will use is free and won't
generate any costs. To be sure, read the terms carefully on as they
could have changed after this tutorial was written.

After upgrading your account you can create a cluster. Note that by
the default, the "Standard" cluster is selected (not free), and we
need to select the "Free" cluster before moving on.

![Creating a container registry](https://github.com/holken1/deploying-r-on-cloud/blob/master/shiny-on-ibm-cloud/img/Creating%20a%20new%20cluster.png?raw=true "Creating a free cluster")

So select the "Free" cluster, choose a geographical region that makes
sense to you, and feel free to give your cluster a name. I'll go with
the default `mycluster` in this example. Now hit the "Create Cluster"
button.

It will take several minutes for the cluster to get created. If you
don't see the instructions "Gain access to your cluster", wait for a
while, then refresh the page. You will need to go through the steps
listed in the "Gain access to your cluster" page, to connect to the
cluster before you can deploy any applications.

While you wait, you may want to move forward with the next section and
come back and complete the "gain access" steps later.

### Creating a Container Registry

The docker images that contain the actual code to be run on the
cluster you actually don't upload to the cluster upon
deployment. Instead, you make the images available in a registry, and
Kubernetes will download (pull) them at deployment time.

The registry could be the public Docker Hub for instance, however images
stored there are generally publicly available unless you pay for a
subscription. IBM Cloud contains a container registry, where you can
store Docker images that you don't want publicly exposed.

In the IBM Cloud console, click the create resource button, and in the
catalog that appears, select "IBM Cloud Container Registry" under the
"Containers" heading.

![Creating a container registry](https://github.com/holken1/deploying-r-on-cloud/blob/master/shiny-on-ibm-cloud/img/Catalog%20-%20Container%20Registry.png?raw=true "Creating a container registry")

Click "Getting Started" and walk through the steps that will have you
installing some software on your workstation, create a "namespace" where
your images will reside, and finally test it out using the Docker
`hello-world` app to see that it's working.

Make note of the namespace you create as we will use it later.

I will use `shiny-tutorial` as my namespace.

```
$ ibmcloud cr namespace-add shiny-tutorial
```


## Preparing for deployment

Now we're not far from making the deployment, but we first need to
make the app available as a Docker image in the container registry.

### Packaging the app as a Docker image

Even though we won't develop a custom app in this tutorial, instead of
just deploying a sample app we'll make our own image based on a
ready-made image. This will provide a better starting-point for you to
add your own code or just play around with.

To get started, create an empty directory somewhere where we will
build the Docker image. And enter that directory.

```
$ mkdir shiny-docker
$ cd shiny-docker
```

Using your favourite text editor, create a file called
`Dockerfile` (no extension) with the following contents

```
FROM rocker/shiny:latest
WORKDIR /srv/shiny-server/
COPY . .
```

Since we don't need to add any custom files (we're just going to use
the sample) that's enough for a docker file. The `COPY` command will
ensure that all files in the current directory will be copied into the
image. That's not needed for this sample but you'll need it when
adding your own code later.

The reason why this file is so short is because the good people at the
`rocker` project has prepared a shiny image already, that has R and
the essential packages pre-installed and `shiny-server` configured to
launch on start-up. And we're building on top of that image.

Now we can ask Docker to build this to an image. The `-t` option
creates a tag that we can later use to more easily refer to it.

```
$ docker build . -t shiny-docker
```

It's a good practice to test the image locally before trying to deploy
it. To start it locally on the default port 3838, run the following:

```
$ docker run -p 3838:3838 shiny-docker
[2018-07-08T09:30:43.191] [INFO] shiny-server - Shiny Server v1.5.7.883 (Node.js v6.10.3)
[2018-07-08T09:30:43.194] [INFO] shiny-server - Using config file "/etc/shiny-server/shiny-server.conf"
[2018-07-08T09:30:43.236] [WARN] shiny-server - Running as root unnecessarily is a security risk! You could be running more securely as non-root.
[2018-07-08T09:30:43.240] [INFO] shiny-server - Starting listener on 0.0.0.0:3838
```

Now the Shiny app is running in a Docker container on your local
machine. At this point, start a browser and point it to `http://localhost:3838`
and you should see the page containing a sample Shiny app.

Press `Ctrl-C` in the terminal to stop the container.

Great, now we have a working Docker image we want to deploy to the
cluster.

## Pushing the image to the Container Registry

The software Kubernetes is managing our cluster, and we will shortly
ask it to deploy our application. However, there is no way of directly
uploading the Docker image to the cluster. Instead, we need to upload
it to the container registry we created earlier. Kubernetes will then
download the image from there, at the time of deployment.

Before we push the image we need to give it an appropriate tag,
specific to the container registry. If you went through the quick
start steps of the container registry using the hello-world app, this
should be familiar.

To tag the image I'll type the following:
```
$ docker tag shiny-docker registry.eu-de.bluemix.net/shiny-tutorial/shiny-docker:latest
```

Note that your domain (especially the `eu-de` part might be different,
check the info on the Container Registry quick start page to be sure.

The first `shiny-docker` (directly after `tag`) is the tag of the
image we gave earlier, when we built it. We're using it here to tell
Docker what image we want to add a tag to. Note also the
`shiny-tutorial` part which is the namespace we created earlier.

With this special tag added we can push the image to the container
registry.

```
$ docker push registry.eu-de.bluemix.net/shiny-tutorial/shiny-docker:latest
```

If you get a message about being unauthorized or not having an active
account, sign in using `ibmcloud cr login`.

Pushing this image the first time will take a while, but subsequent
pushes will be much faster as the infrastructure is pretty intelligent
in terms of caching things that haven't changed.

## Deploying the app to Kubernetes

Now when the image is residing in the registry it's time to ask
Kubernetes to deploy it. To do this we create what's called a
"deployment". Lots of configuration can be done on the deployment, but
as a minimum, it is given a name, the image, and the number of
replicas to run. In this simple example we'll only have one replica
but you can increase this to scale your app if needed.

There are multiple ways to create a deployment but I recommend writing
a YAML file. Having the definition in a file helps re-create it later
if needed.

In this case our yaml is quite simple. You can place the file anywhere
you want but I recommend keeping it in your app directory which makes
it easy to find. It could have any name as well. I will name mine
`deployment.yaml`.

Here's what we put in the YAML file. Be careful with spaces as the
indentation needs to be strictly correct for this to work. Note again
that you may need to change the URL to the container registry
depending on your region.

```
apiVersion: apps/v1beta1
kind: Deployment
metadata:
  name: shiny-docker-deployment
spec:
  replicas: 1
  template:
    metadata:
      labels:
        app: shiny-docker
    spec:
      containers:
      - name: shiny-docker
        image: registry.eu-de.bluemix.net/shiny-tutorial/shiny-docker:latest
```

With this file in the current directory we can tell Kubernetes to
create the deployment by the following command:

```
$ kubectl apply -f deployment.yaml
deployment "shiny-docker-deployment" created
```

Kubernetes will now pull the image from the container registry and
start it in something called a `pod` - a pod is a name for a runnable
unit consisting of one or more docker containers.

## Verifying the deployment

At this point we should check that the deployment was successful and
that no errors are preventing the pod from running correctly.

One way to do this is to open the Kubernetes Dashboard which is a web
page where all aspects of the cluster can be inspected and controlled.

There is a blue button on the cluster overview page that opens this
user interface.

![Cluster overview](https://github.com/holken1/deploying-r-on-cloud/blob/master/shiny-on-ibm-cloud/img/My%20cluster%20overview.png?raw=true "Cluster overview")

Clicking the button "Kubernetes Dashboard" will take you to the
dashboard. If all is well you will see a green status for your
deployment. If not, open the pod in question and check its logs for
clues.

![Kubernetes Dashboard](https://github.com/holken1/deploying-r-on-cloud/blob/master/shiny-on-ibm-cloud/img/Dashboard%20-%20successful%20overview.png?raw=true "Kubernetes Dashboard")

When you have confirmed that the app is started correctly (green
status), it's time to expose it to the internet so that you can try it
out.

## Exposing the app

Kubernetes uses a concept called "services" to control exposure of
apps to the Internet. There are various kinds of services, but for the
free cluster that we are focusing on here, only NodePort services are
available.

The NodePort service allows opening one port on the worker node to the
Internet, mapping it to a port on our running container. This will
allow us to access the app.

To create a service, we'll again use a YAML file.

```
apiVersion: v1
kind: Service
metadata:
  name: shiny-docker-service
spec:
  ports:
  - port: 3838
    protocol: TCP
  type: NodePort
  selector:
    app: shiny-docker
```

The file identifies the app in question and what port should be used
to communicate with the container. However, another port will be
opened to the Internet.

```
$ kubectl apply -f service-nodeport.yaml
service "shiny-docker-service" created
```

This should now be set up but in order to access the app we need two things:

1. The Node's IP number
2. The generated port

To get the IP number we can use the following command:

```
$ ibmcloud ks workers mycluster
OK
ID                                                 Public IP         Private IP      Machine Type   State    Status   Zone    Version
kube-mil01-pabd915da391d549098f68c3b52ae2dba8-w1   159.122.178.195   10.144.180.17   free           normal   Ready    mil01   1.10.5_1519
```

The IP number we need is listed under "Public IP"

To get the port number we need to inspect the created service:

```
$ kubectl get services
NAME                   TYPE        CLUSTER-IP     EXTERNAL-IP   PORT(S)          AGE
kubernetes             ClusterIP   172.21.0.1     <none>        443/TCP          1h
shiny-docker-service   NodePort    172.21.67.37   <none>        3838:31274/TCP   19s
```

Checking PORT(S) for our `shiny-docker-service` we see two ports. The
first (3838) is the one that the cluster is using to connect to our
Docker container. The second (31274 in my case) is the NodePort that
should now be exposed.

Combining these two into a URL we get
`http://159.122.178.195:31274`. Opening this in a browser, you should
see the demo application loading correctly.

![Shiny](https://github.com/holken1/deploying-r-on-cloud/blob/master/shiny-on-ibm-cloud/img/shiny.png?raw=true "Shiny")

The NodePort service works but is a little fiddly. The IP number can
also change when the worker node is removed or re-created. If you
upgrade to a Standard cluster (not free) you can use the LoadBalancer
or Ingress type of service instead. Not only will it give you an IP
and port number directly, it will also balance the load when you have
multiple instances of your app running, which greatly helps with
performance for Shiny applications.

## Summary

So in this short tutorial we have created a Kubernetes cluster and
container registry on IBM Cloud. We have built and pushed a demo Shiny
application using Docker. We have then deployed the application to
Kubernetes and exposed it to the Internet.


# Deploying Shiny apps on IBM Cloud

Holger Hellebro, IBM Global Business Services
2018-08-22


## Prerequisites

The Shiny app you want to deploy needs to be packaged as a Docker
image. In this tutorial we'll deploy an already packaged application,
but if you want to use your own, you'll have to make sure it can run
as a Docker container. (This might be the topic of a future tutorial.)

## Setting up the IBM Cloud environment

### Registering on IBM Cloud

https://www.ibm.com/cloud/

Click `Sign up` and enter your details. Verify your mail address by
clicking the link in the mail you receive. Now log in and accept the
privacy agreement.


### Creating a Kubernetes Cluster

The cluster is where your application will run. In the free tier we
are restricted to using one server but it's enough to get started, and
for small applications with not too many users, it might be just what
you need.

Click Catalog again and this time select the "IBM Cloud Kubernetes
Service" under the "Containers" heading.

At this point you need to upgrade your account and enter a credit
card, but rest assured, the cluster we will use is free and won't
generate any costs. (Also this won't use any of the $200 credit you
get when upgrading your account.)

After upgrading your account you can create a cluster. Note, however,
that by the default, the "Standard" cluster is selected (not free),
and we need to select the "Free" cluster before moving on.

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

The registry can be the public Docker Hub for instance, however images
stored there are publicly available unless you pay for a
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
```

Since we don't need to add any custom files (we're just going to use
the sample) that's enough for a docker file.

Now we can ask Docker to build this to an image. The `-t` option
creates a tag that we can later use to more easily refer to the image.

```
$ docker build . -t shiny-docker
```

It's a good practice to test the image locally before trying to deploy
it. To start it locally on the default port 3838, type the following:

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

Press `Ctrl-C` to stop the container.

Great, now we have a working Docker image we want to deploy to the
cluster.

## Pushing the app to the Container Registry

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
Deployment shiny-docker-deployment created.
```

At this point, Kubernetes will pull the image from the container
registry and start it in something called a `pod` - a pod is a
name for a runnable unit consisting of one or more docker containers.

## Verifying the deployment




## Exposing the app

Creating a Kubernetes "service"

Can we create a LoadBalancer service with the free cluster?
No, but it can be accessed using a NodePort although the IP/Port may
change in some situations.


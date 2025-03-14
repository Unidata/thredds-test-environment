# THREDDS Test Environment

A packer + ansible project to build Docker images for use by the various THREDDS projects at Unidata for running automated tests.
The Docker images are used as the basis for Jenkins build nodes as well as a custom GitHub action for testing the various THREDDS projects.
The image is based off the latest available image for `ubuntu 24.04`.
The docker images produced by packer are called "thredds-test-environment" (for use by Jenkins) of `thredds-test-action` (for use by the GitHub action).

## Requirements

* Packer ([download](https://www.packer.io/downloads))
* Docker, for building the Docker images ([download](https://www.docker.com/products/docker-desktop))

If this is your first time running the build, you will need to initialize packer using:

~~~
packer init .
~~~

While this project's packer configuration relies heavily on Ansible, you do not need to have Ansible installed locally.
We utilize the `ansible-local` provisioner of Packer, which means Ansible is run on the remote/guest machine, and not on the build machine (the machine running packer).
This does mean that part of the Packer build process includes installing Ansible on the remote/guest machine (see `packer/provisioners/scripts/bootstrap-common.sh`), which does add some time to the total build process (approximately two minutes).
However, Since Ansible does not support the use of Windows systems as a control node, the ability create the THREDDS test environment images across all major platforms outweighs the extra cost in time.

## Building the images

To generate the golden Docker images, start off by validating the packer configuration by first moving into the `packer/` directory and then running:

~~~bash
packer validate .
~~~

Once validated, you may run the build using:

~~~bash
packer build --only=<type> thredds-test-env.pkr.hcl
~~~

`<type>` will one or more (separated by commas) of the following:
* `docker.docker-jenkins`: Provision a Docker container and generate and tag a local Docker image (`docker.unidata.ucar.edu/thredds-test-environment:20.04`).
* `docker.docker-github-action`: Provision a Docker container for use with GitHub Actions and tag a local docker image (`ghcr.io/unidata/thredds-test-action:v3`).
* `docker.docker-export`: Provision a Docker container and generate a local Docker image as a file (`image.tar`).

Typically, we would run the following to update the Jenkins and Github Action Docker images at the same time:

~~~bash
packer build --only=docker.docker-jenkins,docker.docker-github-action thredds-test-env.pkr.hcl
~~~

The Docker image builds takes about 30 minutes to create on MacOS.
Packer will run the builders in parallel, so the total time to create the `thredds-test-environment` images is around an hour.

If using `docker-jenkins`, then once the image is built you can test out the environment by using:

~~~bash
docker run -i -t --rm docker.unidata.ucar.edu/thredds-test-environment:24.04
~~~

These images are built using the multiplatform feature of Docker, and only `linux/amd64` images are produced.
If you are on a `arm64` based mac, you will need to run:

~~~bash
DOCKER_DEFAULT_PLATFORM=linux/amd64 docker run -i -t --rm docker.unidata.ucar.edu/thredds-test-environment:24.04
~~~

Note that images are not pushed as part of this build process.
Pushes can be done via the normal docker mechanisms, e.g. `docker image push docker.unidata.ucar.edu/thredds-test-environment:24.04` and `docker image push ghcr.io/unidata/thredds-test-action:v3`.

## Project layout

Inside the packer directory is a file called `thredds-test-env.pkr.hcl`.
This contains the packer configuration for the builders (docker builder), the provisioners (shell scripts, ansible playbooks), and the post-processors (tagging the docker image).

The provisioners directory contains the provisioner configurations used by packer.
There are three types of provisioners used by the packer configuration: ansible, file, and scripts.

The `files/` directory contains Docker entrypoint scripts:

* `entrypoint.sh`: drives the GitHub Action.
* `jenkins-agent.sh`: connects a container to the jenkins control .

The `scripts/` directory contains the following shell scripts:

* `bootstrap-common.sh`: Install and configure ansible (common to both builders)
* `cleanup.sh`: Runs after the ansible provisioner and cleans up the `apt` cache, as well as some general build environment things.

The `ansible/` directory contains the ansible playbooks that are used to configure the testing environment.
The `ansible/` directory is laid out as follows:

* `site.yml`: The main ansible playbook that references all other playbooks used by the build
* `roles/`: Playbooks organized by common tasks

We use the following roles when provisioning our images:

* `cleanup`: General cleanup related tasks, such as remove the temporary build directory and running `ldconfig`
* `corretto`: Obtain and install LTS versions of Corretto.
* `general-packages`: Install general packages needed for the build environment using the OS package manager.
* `init`: Initialize the build environment by ensuring the temporary ansible build directory exists.
* `libnetcdf-and-deps`: Configure, build, and install `zlib`, `HDF5`, and `netCDF-C`.
* `maven`: Obtain and install the Apache Maven software project management and comprehension tool. 
* `security`:
  * Add the `ubuntu` user.
  * Add a default `maven-settings.xml` file configured to publish to the Unidata artifacts server.
  * Configure `ssh` (uses modified version of a task from Jeff Geerling's [ansible-role-security](https://github.com/geerlingguy/ansible-role-security) project - see `packer/provisioners/ansible/roles/security/README.md`).
  * Configure a system wide bash environment.
* `temurin`: Obtain and install LTS versions of Temurin.
* `test-data-mount-prep`: Prepare the environment to mount the `thredds-test-data` datasets when available (currently used on Jenkins worker nodes).
* `zulu`: Obtain and install LTS versions of Zulu.

## THREDDS Test Environment Highlights

### netCDF-C
 * location: `/usr/thredds-test-environment`
 * version: `4.9.2`
 * dependencies (same location):
   * zlib version: `1.3.1`
   * hdf5 version: `1.14.6`

### maven:
 * location: `/usr/thredds-test-environment/mvn`
 * version: `3.6.3`

### Java:
 * Temurin (latest version available from adoptium.net)
   * 8 (`/usr/thredds-test-environment/temurin8`)
   * 11 (`/usr/thredds-test-environment/temurin11`)
   * 17 (`/usr/thredds-test-environment/temurin17`)
   * 21 (`/usr/thredds-test-environment/temurin21`)

 * Zulu (latest version available from azul.com)
   * 8 (`/usr/thredds-test-environment/zulu8`)
   * 11 (`/usr/thredds-test-environment/zulu11`)
   * 17 (`/usr/thredds-test-environment/zulu17`)
   * 21 (`/usr/thredds-test-environment/zulu21`)

 * Corretto (latest version available from docs.aws.amazon.com/corretto/)
   * 8 (`/usr/thredds-test-environment/corretto8`)
   * 11 (`/usr/thredds-test-environment/corretto11`)
   * 17 (`/usr/thredds-test-environment/corretto17`)
   * 21 (`/usr/thredds-test-environment/corretto21`)

### Bash functions:
 * `select-java <vendor> <version>` (where version is 8, 11, 17, or 21, and vendor is `temurin`, `zulu`, or `corretto`)
 * `get_pw <key>`

### Latest version available via the OS Package Manager
  * sed
  * dos2unix
  * git
  * fonts-dejavu
  * fontconfig
  * openssh-server

## Example Timings

### Docker Image

~~~
    docker.docker-jenkins: Saturday 08 March 2025  01:34:12 +0000 (0:00:02.971)       0:25:25.026 ********
    docker.docker-jenkins: ===============================================================================
    docker.docker-jenkins: Wait for the HDF5 async test task to complete. ------------------------ 483.06s
    docker.docker-jenkins: libnetcdf-and-deps : Make hdf5. --------------------------------------- 327.68s
    docker.docker-jenkins: libnetcdf-and-deps : Configure netCDF-c. ------------------------------ 174.98s
    docker.docker-jenkins: libnetcdf-and-deps : Configure hdf5. ---------------------------------- 148.53s
    docker.docker-jenkins: temurin : Fetch latest Temurin Java builds. ---------------------------- 53.85s
    docker.docker-jenkins: zulu : Unpack Zulu Java Installations. --------------------------------- 39.85s
    docker.docker-jenkins: general-packages : Install os managed tools. --------------------------- 39.50s
    docker.docker-jenkins: general-packages : Install os managed tools. --------------------------- 34.55s
    docker.docker-jenkins: libnetcdf-and-deps : Install netCDF-c. --------------------------------- 32.28s
    docker.docker-jenkins: corretto : Unpack Corretto Java Installations. ------------------------- 28.85s
    docker.docker-jenkins: temurin : Unpack Temurin Java Installations. --------------------------- 28.05s
    docker.docker-jenkins: zulu : Fetch latest Zulu Java builds. ---------------------------------- 27.61s
    docker.docker-jenkins: corretto : Fetch latest Corretto Java builds. -------------------------- 16.80s
    docker.docker-jenkins: general-packages : Install os managed tools. --------------------------- 11.56s
    docker.docker-jenkins: libnetcdf-and-deps : Download and unpack hdf5. -------------------------- 9.03s
    docker.docker-jenkins: libnetcdf-and-deps : Install zlib. -------------------------------------- 6.08s
    docker.docker-jenkins: security : Update SSH configuration to be more secure. ------------------ 5.03s
    docker.docker-jenkins: libnetcdf-and-deps : Configure zlib. ------------------------------------ 4.44s
    docker.docker-jenkins: zulu : Read versions of installed Zulu. --------------------------------- 4.24s
    docker.docker-jenkins: cleanup : Remove packages that are not needed in final environment. ----- 3.46s
~~~

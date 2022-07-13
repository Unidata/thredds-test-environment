# THREDDS Test Environment

A packer + ansible project to build and deploy an Amazon Machine Image and Docker Container for use by the various THREDDS projects at Unidata for running automated tests.
The AMI is used by our Jenkins server to launch worker nodes for running tests.
The Docker Image will be used as the basis for a custom GitHub action for testing the various THREDDS projects.
Both image types are based off the latest available image, AMI or Docker, for `ubuntu 20.04`.
The AMI and docker images produced by packer are both called "thredds-test-environment".

## Requirements

* Packer ([download](https://www.packer.io/downloads))
* Docker, for building the Docker Image ([download](https://www.docker.com/products/docker-desktop))
* AWS EC2 Credentials, for building the AMI.
  * The packer configuration expects the AWS credentials to be stored under a profile named `ucar-unidata-profile`
    One way of setting this up would be to have an entry in the file `<home-directory>/.aws/credentials` that looks like the following:
    ~~~
    [ucar-unidata-profile]
    aws_access_key_id=XXXXXXXXX
    aws_secret_access_key=XXXXXXXXX
    ~~~
    See the [packer docs](https://www.packer.io/docs/builders/amazon#authentication) for more information.

While this project's packer configuration relies heavily on Ansible, you do not need to have Ansible installed locally.
We utilize the `ansible-local` provisioner of Packer, which means Ansible is run on the remote/guest machine, and not on the build machine (the machine running packer).
This does mean that part of the Packer build process includes installing Ansible on the remote/guest machine (see `packer/provisioners/scripts/bootstrap-common.sh`), which does add some time to the total build process (approximately two minutes).
However, Since Ansible does not support the use of Windows systems as a control node, the ability create the THREDDS test environment images across all major platforms outweighs the extra cost in time.

## Building the images

To generate the golden AMI and Docker images, start off by validating the packer configuration by first moving into the `packer/` directory and then running:

~~~bash
packer validate thredds-test-env.json
~~~

Once validated, you may run the build using:

~~~bash
packer build --only=<type> thredds-test-env.json
~~~

`<type>` will one or more (separated by commas) of the following:
* `ami`: Provision an AWS EC2 instance and generate an AMI (`thredds-test-environment-<iso-timestamp>`)
* `docker-commit`: Provision a Docker container and generate and tag a local Docker Image (`docker.unidata.ucar.edu/thredds-test-environment:latest`).
* `docker-export`: Provision a Docker container and generate a local Docker Image as a file (`image.tar`).
* `docker-github-action`: Provision a Docker container for use with GitHub Actions and publish to the GitHub Package Repository (runs using manual `workflow_dispatch` trigger on github actions).
* `docker-github-action-nexus`: Same as `docker-github-action`, but publish to the Unidata Nexus Repository.

Typically, we would run the following to update the AMI and Github Action Docker Image (hosted on Nexus) at the same time:

~~~bash
packer build --only=ami,docker-github-action-nexus thredds-test-env.json
~~~

The Docker Image build takes about 1 hour to create, where as the AMI build takes around 30 minutes.
Packer will run the builders in parallel, so the total time to create the `thredds-test-environment` images is around an hour.

If using `docker-commit`, then once the image is built you can test out the environment by using:

~~~bash
docker run -i -t --rm docker.unidata.ucar.edu/thredds-test-environment:latest
~~~

## Project layout

Inside the packer directory is a file called `thredds-test-env.json`.
This contains the packer configuration for the builders (amazon-ebs builder, docker builder), the provisioners (shell scripts, ansible playbooks), and the post-processors (tagging the docker image).

The provisioners directory contains the provisioner configurations used by packer.
There are two types of provisioners used by the packer configuration: ansible and scripts.
The `scripts/` directory contains the following shell scripts:

* `bootstrap-common.sh`: Install and configure ansible (common to both builders)
* `bootstrap_first_aws.sh`: This will run first on AWS. Waits for cloud-init to finish before running `bootstrap-common.sh`.
* `bootstrap_last_aws.sh`: This runs immediately after `bootstrap-common.sh` on AWS. Installs a system-wide JRE, which is needed when using the AMS as a Jenkins worker node.
* `cleanup.sh`: Runs after the ansible provisioner and cleans up the `apt` cache, as well as some general build environment things.

The `ansible/` directory contains the ansible playbooks that are used to configure the testing environment.
The `ansible/` directory is laid out as follows:

* `site.yml`: The main ansible playbook that references all other playbooks used by the build
* `roles/`: Playbooks organized by common tasks

We use the following roles when provisioning our images:

* `cleanup`: General cleanup related tasks, such as remove the temporary build directory and running `ldconfig`
* `general-packages`: Install general packages needed for the build environment using the OS package manager.
* `gradle-builds-cache-bootstrap`: Pull in and build netCDF-Java to populate the gradle cache for user ubuntu.
* `init`: Initialize the build environment by ensuring the temporary ansible build directory exists. 
* `libnetcdf-and-deps`: Configure, build, and install `zlib`, `HDF5`, and `netCDF-C`.
* `maven`: Obtain and install the Apache Maven software project management and comprehension tool. 
* `miniconda`: Obtain and install the Anaconda miniconda python distribution.
* `security`:
  * Add the `ubuntu` user.
  * Add a default `maven-settings.xml` file configured to publish to the Unidata artifacts server.
  * Configure `ssh` (uses modified version of a task from Jeff Geerling's [ansible-role-security](https://github.com/geerlingguy/ansible-role-security) project - see `packer/provisioners/ansible/roles/security/README.md`).
  * Configure a system wide bash environment.
* `temurin`: Obtain and install Temurin 8, 11, and 14.
* `test-data-mount-prep`: Prepare the environment to mount the `thredds-test-data` datasets when available (currently used on Jenkins worker nodes).
* `zulu`: Obtain and install Zulu 8, 11, and 14.

We also use a role from [Ansible Galaxy](https://galaxy.ansible.com/) to setup a Ruby environment ([geerlingguy.ruby](https://galaxy.ansible.com/geerlingguy/ruby)).

## THREDDS Test Environment Highlights

### netCDF-C
 * location: `/usr/thredds-test-environment`
 * version: `4.8.1`
 * dependencies (same location):
   * zlib version: `1.2.11`
   * hdf5 version: `1.12.1`

### miniconda
 * location: `/usr/thredds-test-environment/miniconda3`
 * version: `Miniconda3-latest-Linux-x86_64`

### maven:
 * location: `/usr/thredds-test-environment/mvn`
 * version: `3.6.3`

### Java:
 * Temurin (latest version available from adoptium.net)
   * 8 (`/usr/thredds-test-environment/temurin8`)
   * 11 (`/usr/thredds-test-environment/temurin11`)
   * 16 (`/usr/thredds-test-environment/temurin16`)
 * Zulu (latest version available from azul.com)
   * 8 (`/usr/thredds-test-environment/zulu8`)
   * 11 (`/usr/thredds-test-environment/zulu11`)
   * 14 (`/usr/thredds-test-environment/zulu14`)
   * 16 (`/usr/thredds-test-environment/zulu16`)

### Ruby
  * ruby (via [geerlingguy.ruby](https://galaxy.ansible.com/geerlingguy/ruby) from [Ansible Galaxy](https://galaxy.ansible.com/))

### Bash functions:
 * `select-java <vendor> <version>` (where version is 8, 11, 14, or 16, and vendor is `temurin` or `zulu`)
   * note that Temurin does not have a version 14 binary at this time.
 * `activate-conda`
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
  docker-commit: Tuesday 26 January 2021  02:31:10 +0000 (0:00:02.518)       0:27:27.982 *******
  docker-commit: ===============================================================================
  docker-commit: Wait for the gradle builds to complete. ------------------------------- 502.58s
  docker-commit: libnetcdf-and-deps : Install hdf5. ------------------------------------ 196.71s
  docker-commit: general-packages : Install os managed tools. -------------------------- 156.95s
  docker-commit: general-packages : Install os managed tools. -------------------------- 147.62s
  docker-commit: temurin : Fetch latest Temurin Java builds. ------------------------- 142.41s
  docker-commit: general-packages : Install os managed tools. -------------------------- 129.50s
  docker-commit: geerlingguy.ruby : Install ruby and other required dependencies. ------- 85.59s
  docker-commit: libnetcdf-and-deps : Configure netCDF-c. ------------------------------- 47.61s
  docker-commit: temurin : Unpack Temurin Java Installations. ------------------------- 47.37s
  docker-commit: maven : Fetch Latest Maven. -------------------------------------------- 32.04s
  docker-commit: gradle-builds-cache-bootstrap : Fetch latest commits from github. ------ 31.14s
  docker-commit: libnetcdf-and-deps : Download and unpack hdf5. ------------------------- 21.72s
  docker-commit: libnetcdf-and-deps : Configure hdf5. ----------------------------------- 20.46s
  docker-commit: libnetcdf-and-deps : Download and unpack zlib. ------------------------- 17.42s
  docker-commit: miniconda : Download and unpack miniconda. ----------------------------- 11.38s
  docker-commit: libnetcdf-and-deps : Install netCDF-c. --------------------------------- 10.12s
  docker-commit: cleanup : Remove packages that are not needed in final environment. ----- 4.45s
  docker-commit: geerlingguy.ruby : Install rubygems. ------------------------------------ 3.31s
  docker-commit: security : Update SSH configuration to be more secure. ------------------ 2.93s
  docker-commit: libnetcdf-and-deps : Download and unpack netcdf-c. ---------------------- 2.69s
~~~

### AMI

~~~
  ami: Tuesday 26 January 2021  02:32:50 +0000 (0:00:00.709)       0:29:56.463 *******
  ami: ===============================================================================
  ami: Wait for the gradle builds to complete. ------------------------------- 606.89s
  ami: Wait for the HDF5 async test task to complete. ------------------------ 455.60s
  ami: libnetcdf-and-deps : Install hdf5. ------------------------------------ 335.69s
  ami: temurin : Unpack Temurin Java Installations. ------------------------- 55.85s
  ami: temurin : Fetch latest Temurin Java builds. -------------------------- 38.67s
  ami: gradle-builds-cache-bootstrap : Fetch latest commits from github. ------ 32.56s
  ami: geerlingguy.ruby : Install ruby and other required dependencies. ------- 31.75s
  ami: Wait for netcdf-c async test task to complete. ------------------------- 31.35s
  ami: general-packages : Install os managed tools. --------------------------- 28.81s
  ami: libnetcdf-and-deps : Install netCDF-c. --------------------------------- 26.35s
  ami: libnetcdf-and-deps : Configure netCDF-c. ------------------------------- 20.54s
  ami: general-packages : Install os managed tools. --------------------------- 16.75s
  ami: libnetcdf-and-deps : Configure hdf5. ----------------------------------- 16.54s
  ami: maven : Fetch Latest Maven. -------------------------------------------- 12.57s
  ami: libnetcdf-and-deps : Download and unpack hdf5. -------------------------- 7.72s
  ami: security : Update SSH configuration to be more secure. ------------------ 6.17s
  ami: libnetcdf-and-deps : Test HDF5. ----------------------------------------- 5.53s
  ami: libnetcdf-and-deps : Install zlib. -------------------------------------- 4.84s
  ami: cleanup : Remove packages that are not needed in final environment. ----- 4.82s
  ami: general-packages : Install os managed tools. ---------------------------- 3.44s
~~~

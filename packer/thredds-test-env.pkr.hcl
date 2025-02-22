packer {
  required_plugins {
    ansible = {
      source  = "github.com/hashicorp/ansible"
      version = "~> 1"
    }
    docker = {
      source  = "github.com/hashicorp/docker"
      version = "~> 1"
    }
  }
}

locals {
  base_docker_image = "ubuntu:24.04"
  thredds_test_user = "jenkins"
}

source "docker" "docker-jenkins" {
  changes  = ["USER ${local.thredds_test_user}",
              "ENTRYPOINT [\"/home/${local.thredds_test_user}/jenkins-agent.sh\"]",
              ]
  commit   = true
  image    = "${local.base_docker_image}"
  platform = "linux/amd64"
}

source "docker" "docker-export" {
  changes     = ["USER ${local.thredds_test_user}",
                 "ENTRYPOINT [\"/bin/bash\"]",
                 ]
  export_path = "image.tar"
  image       = "${local.base_docker_image}"
  platform    = "linux/amd64"
}

source "docker" "docker-github-action" {
  changes  = ["USER root", "ENV GITHUB_ACTIONS=\"YEP\"",
              "ENTRYPOINT [\"/entrypoint.sh\"]",
              ]
  commit   = true
  image    = "${local.base_docker_image}"
  platform = "linux/amd64"
}

build {
  sources = ["source.docker.docker-jenkins",
             "source.docker.docker-export",
             "source.docker.docker-github-action",
             ]

  provisioner "shell" {
    script = "provisioners/scripts/bootstrap-common.sh"
  }

  provisioner "file" {
    destination = "/entrypoint.sh"
    source      = "provisioners/file/entrypoint.sh"
    only        = ["docker.docker-github-action",]
  }

  provisioner "ansible-local" {
    clean_staging_directory = true
    command                 = "ANSIBLE_CONFIG=/ansible_config/ansible.cfg ANSIBLE_FORCE_COLOR=1 PYTHONUNBUFFERED=1 ansible-playbook"
    extra_arguments         = ["--extra-vars", "\"thredds_test_user=${local.thredds_test_user}\""]
    galaxy_file             = "provisioners/ansible/requirements.yml"
    group_vars              = "provisioners/ansible/group_vars"
    playbook_file           = "provisioners/ansible/site.yml"
    role_paths              = ["provisioners/ansible/roles/cleanup",
                               "provisioners/ansible/roles/general-packages",
                               "provisioners/ansible/roles/init",
                               "provisioners/ansible/roles/libnetcdf-and-deps",
                               "provisioners/ansible/roles/maven",
                               "provisioners/ansible/roles/miniconda",
                               "provisioners/ansible/roles/security",
                               "provisioners/ansible/roles/temurin",
                               "provisioners/ansible/roles/thredds-test-data-mount-prep",
                               "provisioners/ansible/roles/zulu",
                               ]
  }

  provisioner "file" {
    destination = "/home/${local.thredds_test_user}/jenkins-agent.sh"
    source      = "provisioners/file/jenkins-agent.sh"
    only        = ["docker.docker-jenkins",]
  }

  provisioner "shell" {
    inline = ["dos2unix /home/${local.thredds_test_user}/jenkins-agent.sh",
              "chown ${local.thredds_test_user}:${local.thredds_test_user} /home/${local.thredds_test_user}/jenkins-agent.sh",
              "chmod 755 /home/${local.thredds_test_user}/jenkins-agent.sh",
              ]
    only   = ["docker.docker-jenkins",]
  }

  provisioner "shell" {
    inline = ["wget https://jenkins.unidata.ucar.edu/jnlpJars/agent.jar -P /home/${local.thredds_test_user}",
              "chown ${local.thredds_test_user}:${local.thredds_test_user} /home/${local.thredds_test_user}/agent.jar",
              ]
    only   = ["docker.docker-jenkins",]
  }

  provisioner "shell" {
    inline = ["dos2unix /entrypoint.sh"]
    only   = ["docker.docker-github-action",
              ]
  }

  provisioner "shell" {
    script = "provisioners/scripts/cleanup.sh"
  }

  post-processor "docker-tag" {
    only       = ["docker.docker-jenkins"]
    repository = "docker.unidata.ucar.edu/thredds-test-environment"
    tags       = ["latest",]
  }
  post-processor "docker-tag" {
    only       = ["docker.docker-github-action"]
    repository = "ghcr.io/unidata/thredds-test-action"
    tags       = ["v3",]
  }
}

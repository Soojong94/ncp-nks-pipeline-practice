# =============================================================
# pipeline 스택 — 트랙 A: NCP 네이티브 CI/CD (spec.md §6.2)
# SourceCommit -> SourceBuild -> SourceDeploy -> SourcePipeline
#
# ⚠️ DRAFT: 이 스택은 M9 에서 live API 값으로 마지막 조정이 필요하다.
#    - SourceBuild env(compute/os/docker_engine) id 는 data source 로 해석되지만
#      platform.type / build_command 세부는 콘솔에서 한 번 만들어보고 맞추는 게 빠름
#    - SourceDeploy scenario 의 manifest/이미지 치환 방식은 NKS 대상 기준으로 확정
#    validate 는 통과. plan 단계에서 필드 조정 예상.
# =============================================================

locals {
  cluster_uuid = data.terraform_remote_state.cluster.outputs.cluster_uuid
  cluster_name = data.terraform_remote_state.cluster.outputs.cluster_name
}

# ---------- 스펙 조회 ----------
data "ncloud_sourcebuild_project_computes" "c" {}
data "ncloud_sourcebuild_project_os" "os" {}
data "ncloud_sourcebuild_project_docker_engines" "de" {}

locals {
  compute_id       = try(tonumber(data.ncloud_sourcebuild_project_computes.c.computes[0].id), null)
  os_id            = try(tonumber(data.ncloud_sourcebuild_project_os.os.os[0].id), null)
  docker_engine_id = try(tonumber(data.ncloud_sourcebuild_project_docker_engines.de.docker_engines[0].id), null)
}

# ---------- SourceCommit ----------
resource "ncloud_sourcecommit_repository" "app" {
  name        = "${var.name_prefix}-app"
  description = "nks-demo source (track A)"
}

# ---------- SourceBuild ----------
resource "ncloud_sourcebuild_project" "build" {
  name        = "${var.name_prefix}-build"
  description = "Dockerfile -> NCR push"

  source {
    type = "SourceCommit"
    config {
      repository_name = ncloud_sourcecommit_repository.app.name
      branch          = var.source_branch
    }
  }

  env {
    compute {
      id = local.compute_id
    }
    platform {
      # M9 에서 확인: Dockerfile 빌드는 보통 type="SourceBuild" + os 지정.
      type = "SourceBuild"
      config {
        os {
          id = local.os_id
        }
      }
    }
    docker_engine {
      use = true
      id  = local.docker_engine_id
    }
    env_var {
      key   = "APP_VERSION"
      value = "manual" # 파이프라인 실행 시 커밋 해시로 오버라이드 (M9)
    }
    env_var {
      key   = "NCLOUD_ACCESS_KEY"
      value = var.ncp_access_key
    }
    env_var {
      key   = "NCLOUD_SECRET_KEY"
      value = var.ncp_secret_key
    }
  }

  build_command {
    docker_image_build {
      use        = true
      dockerfile = "app/Dockerfile"
      registry   = var.ncr_name
      image      = "nks-demo"
      tag        = "$${APP_VERSION}"
      latest     = true
    }
  }

  build_image_upload {
    use                     = true
    container_registry_name = var.ncr_name
    image_name              = "nks-demo"
    tag                     = "$${APP_VERSION}"
    latest                  = true
  }
}

# ---------- SourceDeploy ----------
resource "ncloud_sourcedeploy_project" "deploy" {
  name = "${var.name_prefix}-deploy"
}

resource "ncloud_sourcedeploy_project_stage" "nks" {
  project_id  = ncloud_sourcedeploy_project.deploy.id
  name        = "nks"
  target_type = "KubernetesService"

  config {
    cluster_uuid = local.cluster_uuid
  }
}

resource "ncloud_sourcedeploy_project_stage_scenario" "rollout" {
  project_id = ncloud_sourcedeploy_project.deploy.id
  stage_id   = ncloud_sourcedeploy_project_stage.nks.id
  name       = "rollout"

  config {
    strategy = "normal"

    manifest {
      type            = "SourceCommit"
      repository_name = ncloud_sourcecommit_repository.app.name
      branch          = var.source_branch
      path            = ["k8s/deployment.yaml", "k8s/service.yaml", "k8s/ingress.yaml"]
    }
  }
}

# ---------- SourcePipeline ----------
resource "ncloud_sourcepipeline_project" "pipe" {
  name        = "${var.name_prefix}-pipeline"
  description = "build -> deploy"

  task {
    name         = "build"
    type         = "SourceBuild"
    linked_tasks = []
    config {
      project_id = ncloud_sourcebuild_project.build.id
    }
  }

  task {
    name         = "deploy"
    type         = "SourceDeploy"
    linked_tasks = ["build"]
    config {
      project_id  = ncloud_sourcedeploy_project.deploy.id
      stage_id    = ncloud_sourcedeploy_project_stage.nks.id
      scenario_id = ncloud_sourcedeploy_project_stage_scenario.rollout.id
    }
  }

  triggers {
    repository {
      type   = "SourceCommit"
      name   = ncloud_sourcecommit_repository.app.name
      branch = var.source_branch
    }
  }
}

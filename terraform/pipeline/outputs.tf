output "sourcecommit_https_url" {
  value = ncloud_sourcecommit_repository.app.git_https_url
}

output "sourcebuild_project_id" {
  value = ncloud_sourcebuild_project.build.id
}

output "sourcedeploy_project_id" {
  value = ncloud_sourcedeploy_project.deploy.id
}

output "sourcepipeline_project_id" {
  value = ncloud_sourcepipeline_project.pipe.id
}

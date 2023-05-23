repo = "spritsail/drone-runner-docker"
architectures = ["amd64", "arm64"]
branches = ["master"]

def main(ctx):
  builds = []
  depends_on = []

  for arch in architectures:
    key = "build-%s" % arch
    builds.append(step(arch, key))
    depends_on.append(key)
  if ctx.build.branch in branches:
    builds.append(publish(depends_on))

  return builds

def step(arch, key):
  return {
    "kind": "pipeline",
    "name": key,
    "platform": {
      "os": "linux",
      "arch": arch,
    },
    "steps": [
      {
        "name": "build-bin",
        "pull": "always",
        "image": "golang:alpine",
        "environment": {
          "CGO_ENABLED": 0,
        },
        "commands": [
          "go build -o release/linux/%s/drone-runner-docker" % arch,
        ],
      },
      {
        "name": "build-image",
        "pull": "always",
        "image": "spritsail/docker-build",
        "settings": {
          "dockerfile": "docker/Dockerfile.linux.%s" % arch,
        },
      },
      {
        "name": "publish",
        "pull": "always",
        "image": "spritsail/docker-publish",
        "settings": {
          "registry": {"from_secret": "registry_url"},
          "login": {"from_secret": "registry_login"},
        },
        "when": {
          "branch": branches,
          "event": ["push"],
        },
      },
    ],
  }

def publish(depends_on):
  return {
    "kind": "pipeline",
    "name": "publish-manifest",
    "depends_on": depends_on,
    "platform": {
      "os": "linux",
    },
    "steps": [
      {
        "name": "publish",
        "image": "spritsail/docker-multiarch-publish",
        "pull": "always",
        "settings": {
          "tags": [
            "latest",
          ],
          "src_registry": {"from_secret": "registry_url"},
          "src_login": {"from_secret": "registry_login"},
          "dest_repo": repo,
          "dest_login": {"from_secret": "docker_login"},
        },
        "when": {
          "branch": branches,
          "event": ["push"],
        },
      },
    ],
  }

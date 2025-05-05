repo = "spritsail/drone-runner-docker"
architectures = ["amd64", "arm64"]
branches = ["master"]
events = ["push"]

def main(ctx):
  builds = []
  depends_on = []

  for arch in architectures:
    key = "build-%s" % arch
    builds.append(step(arch, key))
    depends_on.append(key)
  if ctx.build.branch in branches and ctx.build.event in events:
    builds.extend(publish(depends_on))

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
        "image": "registry.spritsail.io/spritsail/docker-build",
        "pull": "always",
        "settings": {
          "dockerfile": "docker/Dockerfile.linux.%s" % arch,
        },
      },
      {
        "name": "publish",
        "image": "registry.spritsail.io/spritsail/docker-publish",
        "pull": "always",
        "settings": {
          "registry": {"from_secret": "registry_url"},
          "login": {"from_secret": "registry_login"},
        },
        "when": {
          "branch": branches,
          "event": events,
        },
      },
    ],
  }

def publish(depends_on):
  return [
    {
      "kind": "pipeline",
      "name": "publish-manifest-%s" % name,
      "depends_on": depends_on,
      "platform": {
        "os": "linux",
      },
      "steps": [
        {
          "name": "publish",
          "image": "registry.spritsail.io/spritsail/docker-multiarch-publish",
          "pull": "always",
          "settings": {
            "tags": [
              "latest",
            ],
            "src_registry": {"from_secret": "registry_url"},
            "src_login": {"from_secret": "registry_login"},
            "dest_registry": registry,
            "dest_repo": repo,
            "dest_login": {"from_secret": login_secret},
          },
          "when": {
            "branch": branches,
            "event": events,
          },
        },
      ],
    }
    for name, registry, login_secret in [
      ("dockerhub", "index.docker.io", "docker_login"),
      ("spritsail", "registry.spritsail.io", "spritsail_login"),
      ("ghcr", "ghcr.io", "ghcr_login"),
    ]
  ]

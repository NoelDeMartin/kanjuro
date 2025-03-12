# Kanjuro ![CI](https://github.com/noeldemartin/kanjuro/actions/workflows/ci.yml/badge.svg)

Collection of bash scripts that I use to manage headless deployments with Docker.

## Upkeep

Using this architecture can sometimes eat up a lot of space, given that each update downloads new Docker images. In order to improve that, make sure to run the following command from time to time:

```sh
    docker system prune
```

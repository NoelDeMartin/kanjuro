# Kanjuro ![CI](https://github.com/noeldemartin/kanjuro/actions/workflows/ci.yml/badge.svg)

Collection of bash scripts that I use to manage headless deployments with Docker.

Learn more about my self-hosting set up here: [Programming Patterns: Self-hosting](https://noeldemartin.com/blog/programming-patterns-self-hosting).

## Upkeep

Using this architecture can sometimes eat up a lot of space, given that each update downloads new Docker images. In order to improve that, make sure to run the following command from time to time:

```sh
docker system prune
```

You can also configure a cron job that runs once a week:

```sh
0 4 * * * /usr/bin/docker system prune -f
```

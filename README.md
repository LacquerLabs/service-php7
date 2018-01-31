# service-php7
Quick and dirty nginx => PHP7fpm server running on alpine 3.7

Use `make` in the directory to see your options.

Make your php app in `/code`

## Make Options
* `build` Build it
* `buildnocache` Build it without using cache
* `tag` tag the container with the current VERSION (used for doing a release)
* `run` run it as a normal container
* `runvolume` run the container with the `./code` mounted as a volume (for development)
* `runshell` run the container with an interactive shell instead of default CMD
* `connect` Start a shell on the running container
* `watchlog` connect to running containers logs
* `kill` kill the running container
* `test` Simple tests
* `release` Create and push release to docker hub
* `help` Shows this makefile

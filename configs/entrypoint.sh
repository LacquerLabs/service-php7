#!/usr/bin/dumb-init /bin/sh
# ----------------------------------------------------------------------------
# entrypoint for container
# ----------------------------------------------------------------------------
set -e

# sigterm_handler: Called when SIGTERM is handled through dumb-init from a container stop
sigterm_handler(){
	echo
	echo "container stopped with SIGTERM..."
	echo
	for script in /container-stop.d/*; do
		case "$script" in
			*.sh)     echo "... running $script"; . "$script" ;;
			*)        echo "... ignoring $script" ;;
		esac
		echo
	done
	exit 0
}
trap 'sigterm_handler' SIGTERM

HOST_IP=`/bin/grep $HOSTNAME /etc/hosts | /usr/bin/cut -f1`
export HOST_IP=${HOST_IP}
echo
echo "container started with ip: ${HOST_IP}..."
echo
for script in /container-init.d/*; do
	case "$script" in
		*.sh)     echo "... running $script"; . "$script" ;;
		*)        echo "... ignoring $script" ;;
	esac
	echo
done

if [ "$1" == "service" ]; then
	echo "starting php-fpm with nginx..."
	exec nginx &
	exec php-fpm7
elif [ "$1" == "shell" ]; then
	echo "starting /bin/sh..."
	/bin/sh
else
	echo "Running something else ($@)"
	exec "$@"
fi

#!/bin/bash
#
# Magento 2 deploy
#
# Developed by Sofokus Group (www.sofokus.com)
#
# MIT License
#

# Stop on error (this is disabled when deploying to target)
set -e

echo
echo "*** Starting configuration ***"
echo

# Arguments
TARGET=${1:-"staging"}
MODE=${2:-"default"}

# Measure time
measure_timer() {
    local step=$1
    delta=$SECONDS
    echo
    echo "# ${step} complete in $((delta / 60)) minutes and $((delta % 60)) seconds"
    echo
}
reset_timer() {
    SECONDS=0
}
reset_timer

# Merge paths
merge_paths() {
	local path1=$1
	local path2=$2
	local path1end=${path1: -1}
	local path2start=${path2:0:1}
	local result=""
	if [[ $path1end == "/" ]] && [[ $path2start == "/" ]];
	then
		result="${path1::-1}${path2}"
	elif [[ $path1end == "/" ]] && [[ $path2start != "/" ]];
	then
		result="${path1}${path2}"
	elif [[ $path1end != "/" ]] && [[ $path2start == "/" ]];
	then
		result="${path1}${path2}"
	elif [[ $path1end != "/" ]] && [[ $path2start != "/" ]];
	then
		result="${path1}/${path2}"
	fi
	echo "$result"
}
merge_multiple_paths() {
	local path=''
	for var in "$@"
	do
		path=$(merge_paths "$path" "$var")
	done
	echo path
}

get_git_branch() {
	local path=$1
	local git_path=$(merge_paths "$path" .git)
	local result=$(git --git-dir="${git_path}" --work-tree="${path}" rev-parse --revs-only --abbrev-ref HEAD)
	echo "${result}"
}

flush_redis() {
	local db=$1
	local host=$2
	local port=$3
	command -v redis-cli \
    && sudo redis-cli \
      -n "${db}" \
      -h "${host}" \
      -p "${port}" \
       FLUSHDB \
    || echo 'redis-cli not found or command failed'
  echo
}

# Settings
# Override custom settings in config/config.sh
declare -A TARGET_DIR_MAP=()
declare -A DEPLOY_DIR_MAP=()
declare -A PHP_CMD_MAP=()
DEPLOY_ROOT="/var/www/magento/deploy/"
TARGET_ROOT="/var/www/magento/"
LOCALES=("fi_FI" "en_US")
ADMIN_LOCALES=("fi_FI" "en_US")
PHP_CMD="php"
DB_TABLES="core_config_data store store_group store_website theme theme_file design_change design_config_grid_flat"

ALLOWED_IP="127.0.0.1"

# include config
script_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
# shellcheck disable=SC1090
. "$script_dir/config/config.sh"

PHP_CMD="${PHP_CMD_MAP[$TARGET]:-$PHP_CMD}"

mapped_target_dir="${TARGET_DIR_MAP[$TARGET]:-$TARGET}"
TARGET_DIR=$(merge_paths "${TARGET_ROOT}" "$mapped_target_dir")
mapped_deploy_dir="${DEPLOY_DIR_MAP[$TARGET]:-$TARGET}"
DEPLOY_DIR=$(merge_paths "${DEPLOY_ROOT}" "$mapped_deploy_dir")

DEFAULT_USER="$(stat -c "%U" "$TARGET_DIR/var")"
DEFAULT_GROUP="$(stat -c "%G" "$TARGET_DIR/var")"

USER_HOME="$(eval echo ~$DEFAULT_USER)"

TARGET_GIT_BRANCH=$(get_git_branch "${TARGET_DIR}")
DEPLOY_GIT_BRANCH=$(get_git_branch "${DEPLOY_DIR}")

# Display warning, if git branches are different
if [[ $TARGET_GIT_BRANCH != "$DEPLOY_GIT_BRANCH" ]] ;
then
	echo "WARNING! Deploy git branch ${DEPLOY_GIT_BRANCH} is not same as target git branch ${TARGET_GIT_BRANCH}"
	read -p "Do you want to continue or exit (y/n)? " -n 1 -r
	echo    # (optional) move to a new line
	if [[ $REPLY =~ ^[Nn]$ ]]
	then
		exit 1;
	fi
fi

TEMP=$(merge_multiple_paths "${TMPDIR:-/tmp}" "/m2deploy/" "$TARGET_DIR")

sudo mkdir -p "$TEMP"
sudo chown "${USER}":"${USER}" "$TEMP"

SUDO_USR="sudo -H -u $DEFAULT_USER -i"
COMPOSER_CMD="$SUDO_USR $PHP_CMD $(command -v composer)"
DEPLOY_MAGECMD="$SUDO_USR $PHP_CMD $(merge_paths "${DEPLOY_DIR}" '/bin/magento')"
TARGET_MAGEBIN="$(merge_paths "${TARGET_DIR}" '/bin/magento')"
TARGET_MAGECMD="$SUDO_USR $PHP_CMD $TARGET_MAGEBIN"
GIT_CMD="$SUDO_USR git --git-dir=$DEPLOY_DIR/.git --work-tree=$DEPLOY_DIR/"

sudo cp "$TARGET_DIR"/app/etc/env.php "$TEMP"/target_env.php
sudo cp "$DEPLOY_DIR"/app/etc/env.php "$TEMP"/deploy_env.php
sudo chown "${USER}":"${USER}" "$TEMP"/{target,deploy}_env.php

ENV_CMD="$PHP_CMD $script_dir/env_read.php"
TARGET_ENV="$ENV_CMD $TEMP/target_env.php"
DEPLOY_ENV="$ENV_CMD $TEMP/deploy_env.php"

TARGET_CACHE_BACKEND="$($TARGET_ENV cache/frontend/default/backend)"
if [[ $TARGET_CACHE_BACKEND == "Cm_Cache_Backend_Redis" ]] ;
then
  TARGET_CACHE_REDIS_HOST="$($TARGET_ENV cache/frontend/default/backend_options/server localhost)"
  TARGET_CACHE_REDIS_PORT="$($TARGET_ENV cache/frontend/default/backend_options/port 6379)"
  TARGET_CACHE_REDIS_DB="$($TARGET_ENV cache/frontend/default/backend_options/database)"
fi
TARGET_FPC_BACKEND="$($TARGET_ENV cache/frontend/page_cache/backend)"
if [[ $TARGET_FPC_BACKEND == "Cm_Cache_Backend_Redis" ]] ;
then
	TARGET_FPC_REDIS_HOST="$($TARGET_ENV cache/frontend/page_cache/backend_options/server localhost)"
	TARGET_FPC_REDIS_PORT="$($TARGET_ENV cache/frontend/page_cache/backend_options/port 6379)"
	TARGET_FPC_REDIS_DB="$($TARGET_ENV cache/frontend/page_cache/backend_options/database)"
fi

TARGET_DB="$($TARGET_ENV db/connection/default/dbname "$TARGET")"
TARGET_DB_HOST="$($TARGET_ENV db/connection/default/host localhost)"
TARGET_DB_PORT="$($TARGET_ENV db/connection/default/port 3306)"
TARGET_DB_USER="$($TARGET_ENV db/connection/default/username root)"
TARGET_DB_PASS="$($TARGET_ENV db/connection/default/password)"

DEPLOY_DB="$($DEPLOY_ENV db/connection/default/dbname "${TARGET_DB}"_deploy)"
DEPLOY_DB_HOST="$($DEPLOY_ENV db/connection/default/host "$TARGET_DB_HOST")"
DEPLOY_DB_PORT="$($DEPLOY_ENV db/connection/default/port "$TARGET_DB_PORT")"
DEPLOY_DB_USER="$($DEPLOY_ENV db/connection/default/username "$TARGET_DB_USER")"
DEPLOY_DB_PASS="$($DEPLOY_ENV db/connection/default/password "$TARGET_DB_PASS")"

sudo rm "$TEMP"/{target,deploy}_env.php

TARGET_ENV_INFO="${TARGET} (${TARGET_GIT_BRANCH}) in ${MODE} mode"

echo
echo "*** Preparing deployment to ${TARGET_ENV_INFO} ***"
echo

echo "# Copying $DB_TABLES to $DEPLOY_DB"
sudo mysqldump -h"$TARGET_DB_HOST" -P"$TARGET_DB_PORT" -u"$TARGET_DB_USER" -p"$TARGET_DB_PASS" --single-transaction \
        "$TARGET_DB" $DB_TABLES > "$TEMP/prod_core.sql" \
    && sudo mysql -h"$DEPLOY_DB_HOST" -P"$DEPLOY_DB_PORT" -u"$DEPLOY_DB_USER" -p"$DEPLOY_DB_PASS" \
        "$DEPLOY_DB" < "$TEMP/prod_core.sql"
sudo rm "$TEMP/prod_core.sql"

set_permissions_base() {
    local dir=$1
    echo "# Setting permissions of $dir as $DEFAULT_USER:$DEFAULT_GROUP"
    sudo chmod o-rwx "$dir"/app/etc/env.php
    sudo chmod u+x "$dir"/bin/magento
    echo
}

set_permissions() {
    local dir=$1
    set_permissions_base "$dir"
    sudo chown -R "$DEFAULT_USER":"$DEFAULT_GROUP" "$dir"
    sudo chmod -R u+w,o-w "$dir"/.
}

set_permissions_no_media() {
    local dir=$1
    set_permissions_base "$dir"
    sudo find "$dir"/. \
       -path "$dir"/pub -prune \
       -o -exec chown "$DEFAULT_USER":"$DEFAULT_GROUP" {} +
    sudo find "$dir"/. \
       -path "$dir"/pub -prune \
       -o -exec chmod u+w,o-w {} +
}

set_permissions_media_only() {
    local dir="$1/pub"
    set_permissions "$dir"
}

set_permissions "$DEPLOY_DIR"

echo "# Git reset, clean, pull into $DEPLOY_DIR"
# Reset branch
$GIT_CMD reset --hard HEAD
# Remove all untracked files and directories
$GIT_CMD clean -fd
$GIT_CMD pull
echo

# Run only in default mode
if [ "$MODE" = "default" ]
then
	$COMPOSER_CMD install -d "$DEPLOY_DIR"
	sudo rm -rf "$DEPLOY_DIR"/var/cache/*
	# initial compile needed, because setup:upgrade might fail without it
	$DEPLOY_MAGECMD setup:di:compile -v
	$DEPLOY_MAGECMD setup:upgrade -v
	# second compile needed, because the initial compile might not generate
	# code for modules enabled by the upgrade
	$DEPLOY_MAGECMD setup:di:compile -v
	$COMPOSER_CMD --working-dir=$DEPLOY_DIR dump-autoload -o --apcu
	echo
fi

# Check for removed modules
sudo cp "$TARGET_DIR"/app/etc/config.php "$TEMP"/target_config.php
sudo cp "$DEPLOY_DIR"/app/etc/config.php "$TEMP"/deploy_config.php
sudo chown "$USER":"$USER" "$TEMP"/{target,deploy}_config.php

if [ -f "$TARGET_MAGEBIN" ]
then
    removed_modules=$($PHP_CMD "$script_dir"/module_removed.php \
        "$TEMP"/target_config.php "$TEMP"/deploy_config.php | xargs)
else
    removed_modules=''
fi

sudo rm "$TEMP"/{target,deploy}_config.php

# First remove old static content which might prevent generation of new content
sudo rm -rf "$DEPLOY_DIR"/{var/view_preprocessed/*,pub/static/*}

# Run static-content:deploy for all locales
for LOCALE in "${LOCALES[@]}"
do
	$DEPLOY_MAGECMD setup:static-content:deploy -j 1 "$LOCALE" --area frontend -f
done
for LOCALE in "${ADMIN_LOCALES[@]}"
do
	$DEPLOY_MAGECMD setup:static-content:deploy -j 1 "$LOCALE" --area adminhtml -f
done
echo

RSYNC_CMD="sudo rsync --recursive --links --delete --checksum $DEPLOY_DIR/ ${TARGET_DIR%/}"
RSYNC_FILTER_FILE="${script_dir}/config/rsync_filter"
if [ ! -f "$RSYNC_FILTER_FILE" ]; then
    RSYNC_FILTER_FILE="${script_dir}/config.sample/rsync_filter"
fi
RSYNC_CMD_MEDIA="sudo rsync --recursive --links --update --checksum $DEPLOY_DIR/pub/media/ ${TARGET_DIR}/pub/media"

# ensure that we don't get massive list of files due to all changing permissions
set_permissions "$DEPLOY_DIR"
set_permissions "$TARGET_DIR"

echo '--- Files to deploy start ---'
$RSYNC_CMD --filter="merge ${RSYNC_FILTER_FILE}" --dry-run --verbose
echo
echo '--- Files to deploy media ---'
echo
$RSYNC_CMD_MEDIA --dry-run --verbose
echo '--- Files to deploy end ---'

echo
echo "Modules to be removed: $removed_modules"

measure_timer 'Preparation'

while true; do
    prompt="Please verify that above output looks OK. Continue deployment to ${TARGET_ENV_INFO} (y/n)?"
    read -r -n 1 -p "$prompt" yn
    case $yn in
        [Yy]* ) break 2;;
        [Nn]* ) exit 1;;
        * );;
    esac
done
echo

reset_timer

echo
echo "*** Deploying to ${TARGET_ENV_INFO} ***"
echo

# Don't stop on error. We want to reach maintenance:disable
set +e

# uninstall command enables maintenance mode separately
if [[ -n $removed_modules ]]
then
    echo "# Uninstall modules $removed_modules"
    # https://community.magento.com/t5/Magento-2-x-Technical-Issues/Custom-module-uninstall/m-p/50114/highlight/true#M1430
    $SUDO_USR ln -s ~$USER_HOME/.config/composer/auth.json "$TARGET_DIR"/
    $TARGET_MAGECMD module:uninstall -v $removed_modules
    sudo unlink "$TARGET_DIR"/auth.json
else
    echo "# No modules to uninstall"
fi

if [ -f "$TARGET_MAGEBIN" ]
then
    $TARGET_MAGECMD maintenance:enable --ip=$ALLOWED_IP
fi

$TARGET_MAGECMD -v cache:flush
echo

if [[ -n $TARGET_CACHE_REDIS_DB ]]
then
  flush_redis \
    "${TARGET_CACHE_REDIS_DB}" \
    "${TARGET_CACHE_REDIS_HOST}" \
    "${TARGET_CACHE_REDIS_PORT}"
fi
if [[ -n $TARGET_FPC_REDIS_DB ]]
then
  flush_redis \
    "${TARGET_FPC_REDIS_DB}" \
    "${TARGET_FPC_REDIS_HOST}" \
    "${TARGET_FPC_REDIS_PORT}"
fi
sudo rm -rf "$TARGET_DIR"/var/{page_,}cache/*

echo "# Rsync changes to ${TARGET_ENV_INFO}"
$RSYNC_CMD --filter="merge ${RSYNC_FILTER_FILE}"
$RSYNC_CMD_MEDIA
echo

set_permissions_no_media "$TARGET_DIR"

echo "# Run setup upgrade"
if [ "$MODE" = "default" ]
then
    # ensure that config.php is writable
    sudo chown "$DEFAULT_USER":"$DEFAULT_GROUP" "$TARGET_DIR/app/etc/config.php"
    sudo chmod ug+rw "$TARGET_DIR/app/etc/config.php"
	$TARGET_MAGECMD setup:upgrade -v --keep-generated
fi
echo

PHP_VERSION=$(${PHP_CMD} -v | head -n1 | cut -d' ' -f2 | cut -d'.' -f1-2)
echo "# Reload php${PHP_VERSION}"
sudo service "php${PHP_VERSION}-fpm" reload

$TARGET_MAGECMD maintenance:disable
echo

set_permissions_media_only "$TARGET_DIR"

measure_timer "Deployment to ${TARGET_ENV_INFO}"

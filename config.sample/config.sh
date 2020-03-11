#!/usr/bin/env bash

DEPLOY_ROOT="/var/www/magento/deploy/"
TARGET_ROOT="/var/www/magento/"
LOCALES=("fi_FI")

# uncomment to use custom values
#PHP_CMD_MAP=(["production"]=php7.1 ["staging"]=php7.2)
#DEPLOY_DIR_MAP=(["production"]=production ["staging"]=staging)
#TARGET_DIR_MAP=(["production"]=production ["staging"]=staging)
#PHP_CMD="php"
#ADMIN_LOCALES=("fi_FI" "en_US")
#DB_TABLES="core_config_data"
#ALLOWED_IP="127.0.0.1"
#TEMP="/tmp"

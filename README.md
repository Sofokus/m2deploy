# Magento 2 Deploy
Faster and more reliable Magento 2 deployments.

This script uses a seperate directory to create deployment files and rsync deploys files to production. It also has a faster theme mode that only deploys theme changes.

### Deployment steps

The script performs the following steps:

1. Runs git reset, clean and pull
2. Runs composer install
3. Copies core config from production database to cloned database
4. Runs setup:di:compile (skipped in theme mode)
5. Runs setup:upgrade (skipped in theme mode)
6. Runs static-content:deploy for all configured locales
7. Shows changes and ask permission to run deploy to target
8. Enables maintenance mode
9. Rsyncs files form deploy to target
10. Runs setup:upgrade
11. Flushes caches
12. Disables maintenance mode

## Setup

1. Clone **m2deploy** to your chosen deployment directory.
2. Set up your config/config.sh for your evironment.
3. Clone target database to deployment database and anonymize it.
4. Create deployment directory with same git branch as your target environment.
5. Copy all non-git files form target to deployment directory and remove pub/media from deploy directory.
6. Create config/config.sh and setup its settings.

### Configs

Configuration file is located in `config/config.sh`.

Deploy directory map contains deploy directories mapped to deployment alias.

    DEPLOY_DIR_MAP=(["production"]=production ["staging"]=staging)

Target directory map contains target directories mapped to deployment alias.

    TARGET_DIR_MAP=(["production"]=production ["staging"]=staging)

Deploy root directory is where deployment files are located before deployment.

    DEPLOY_ROOT="/var/www/deploy/"

Target root is default evironment root directory.

    TARGET_ROOT="/var/www/magento/"

Locales defines which Magento theme locales are deployed.

    LOCALES=("fi_FI")

Environment specific php command.

    PHP_CMD="php"

Admin locales defines which Magento admin theme locales are deployed.

    ADMIN_LOCALES=("fi_FI" "en_US")

Database tables which are copied from target to deploy database before deployment.

    DB_TABLES="core_config_data"

Allowed IP addresses when Magento maintanace mode is enabled.

    ALLOWED_IP="127.0.0.1"

Linux temp directory.

    TEMP="/tmp"

### Requirements:

- Magento 2.x
- PHP 7.x
- Linux
- rsync (daemon not needed)
- Git
- redis-cli (if redis is used for cache)
- `service` utility (for reloading php)

### Usage

Default	mode deploys everything: `deploy.sh production`

Theme mode deploys only theme changes: `deploy.sh production theme`

## Support and development

To get support or request new features create github issue. Pull requests are welcome.

### Open source

m2deply is an open source project distributed under the MIT license.

### Project developers

Eero Rikalainen
Aleksi Lahtinen
Jali Rainio

## DISCLAIMER

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

set -x

apk add gettext

DEPLOY_SSH_USERNAME="$1"
DEPLOY_SSH_HOST="$2"
DEPLOY_SSH_PORT="$3"
DEPLOY_SSH_KEY="$4"
PROJECT_NAME="$5"
DEPLOY_STAGE="$6"
DOCKER_REGISTRY="$7"
DOCKER_REGISTRY_USER="$8"
DOCKER_REGISTRY_PASSWORD="$9"

export SSH_HOST="${DEPLOY_SSH_USERNAME}@${DEPLOY_SSH_HOST}"

ssh:keyfile() {
    DEPLOY_SSH_KEY_PATH="${HOME}/.ssh"
    if [ ! -d "$DEPLOY_SSH_KEY_PATH" ]
    then
        mkdir -p "$DEPLOY_SSH_KEY_PATH"
        chmod 700 "$DEPLOY_SSH_KEY_PATH"
    fi
    echo "$DEPLOY_SSH_KEY_PATH/id_rsa_${PROJECT_NAME}_${DEPLOY_STAGE}"
}

ssh:login() {
DEPLOY_SSH_KEY_FILENAME="$( ssh:keyfile )"
    (
        set +x
        echo "$DEPLOY_SSH_KEY" > "$DEPLOY_SSH_KEY_FILENAME"
        chmod 600 "$DEPLOY_SSH_KEY_FILENAME"
    )
    ssh:run uname -a
}

ssh:options() {
    echo "-o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -i $( ssh:keyfile )"
}

ssh:run() {
    ssh $( ssh:options ) "$SSH_HOST" -p "$DEPLOY_SSH_PORT" -- "$@"
}

scp:run() {
    scp -P "$DEPLOY_SSH_PORT" $( ssh:options ) "$@"
}

ssh:login

# copy docker-compose.yml
LOCAL_COMPOSE_FILE_NAME="build/docker/deploy/${DEPLOY_STAGE}/docker-compose.yml"
REMOTE_COMPOSE_FILE_NAME="${PROJECT_NAME}.${DEPLOY_STAGE}.docker-compose.yml"

TMP_PATH="${HOME}/ci/tmp"
mkdir -p "$TMP_PATH"
PRE_RENDERED_COMPOSE_FILE_NAME="${TMP_PATH}/docker-compose.yml"
echo "$(cat "$LOCAL_COMPOSE_FILE_NAME" | envsubst)" > "$PRE_RENDERED_COMPOSE_FILE_NAME"
scp:run "$PRE_RENDERED_COMPOSE_FILE_NAME" "${SSH_HOST}:~/${REMOTE_COMPOSE_FILE_NAME}"

# log into Docker registry
ssh:run "docker login -u $DOCKER_REGISTRY_USER -p $DOCKER_REGISTRY_PASSWORD $DOCKER_REGISTRY"

# ssh:run "docker-compose -f ${REMOTE_COMPOSE_FILE_NAME} -p ${PROJECT_NAME}_${DEPLOY_STAGE} down --remove-orphans"
ssh:run "docker-compose -f ${REMOTE_COMPOSE_FILE_NAME} -p ${PROJECT_NAME}_${DEPLOY_STAGE} up -d"

sleep 30
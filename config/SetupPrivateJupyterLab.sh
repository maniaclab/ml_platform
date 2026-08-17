if [ "$1" != "" ]; then
    echo "Git Repo $1 requested..."
    cd /workspace/
    git clone $1
fi

export SHELL=/bin/bash

# setting up users
if [ "$OWNER" != "" ] && [ "$CONNECT_GROUP" != "" ]; then
    PATH=$PATH:/usr/sbin
    #/sync_users_debian.sh -u root."$CONNECT_GROUP" -g root."$CONNECT_GROUP" -e https://api.ci-connect.net:18080
    groupadd $CONNECT_GROUP -g $CONNECT_GID
    useradd -M -u $OWNER_UID -G $CONNECT_GROUP $OWNER
    # Do not leak some important tokens
    unset API_TOKEN
    # Ensure the owner owns their home directory ## Commented out 7/17 by L.B., causing issues with taking too long
    #chown -R $OWNER: /home/$OWNER
    # Set the user's $DATA dir
    export DATA=/data/$OWNER
    # Match PS1 as we have it on the login nodes
    echo 'export PS1="[\A] \H:\w $ "' >> /etc/bash.bashrc
    # Chown the /workspace directory so users can create notebooks
    chown -R $OWNER: /workspace
    # Change to the user's homedir
    cd /home/$OWNER

    unset JUPYTER_PATH
    unset JUPYTER_CONFIG_DIR
    cd /home/$OWNER

    # Invoke Jupyter lab as the user
    su $OWNER -c "pixi run jupyter lab --ServerApp.root_dir=/home/${OWNER} --no-browser --config=/usr/local/etc/jupyter_notebook_config.py --NotebookApp.token=${JUPYTER_TOKEN} --ServerApp.token=${JUPYTER_TOKEN}"

fi

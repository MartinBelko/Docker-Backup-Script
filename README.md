# Docker-Backup-Script

Meant to serve as my primary way to backup important docker containers to the cloud. I do not trust anybody, even Hetzner, therefore i encrypt the data before it is stored in another location. The script is expected to have the docker data and docker compose file within the same folder. The folder is compressed, encrypted to a seperate folder, then synced to the cloud using RSYNC, then keeping last 5 copies both locally and on the remote storage. I personally liked this method as once i need to make a recovery, i can just decrypt, extract the folder and just run the ```docker compose up -d``` command to get back up and running. The Discord notifications are for me a nice to have, as i can get a quick look whether it was successfull. Script is also designed to cleanup in case of a failure in one of its commands, it will delete temporary files and start the docker container. 

⚠️**Important:** You are the one responsible for the encryption passphrase creation, usage and storing. You are free to use the script, but i cannot take responsibility in case you lose the passphrase and is unable to recover your data. I personally use Bitwarden (client) and Vaultwarden (as it's backend) to store my passphrases, and i always have a worst case scenario planned, make sure YOU plan accordingly aswell. 

The script is intended for Linux and has been tested on the following platforms:
- Rocky Linux 9 on AMD/Intel x64
- Rocky Linux 9 on ARM64 (running in UTM on a MacBook Air M1, 2020)

ℹ️**Note:** The script itself is basic and should in theory work on most of the primary distros, such as Ubuntu, Red Hat, Debian, Fedora etc.
ℹ️**Note:** Log file is created that only keeps the last run.

Required packages:
- RSYNC (transferring data to cloud)
- Curl (sending notifications to Discord webhook)
- Tar (compressing the data)
- GPG (encrypting the data)
- Docker compose plugin

Variables you need to change, in the script itself, there are examples:
- SOURCE_DIR: Location to your ```docker-compose.yml``` file. Data for the docker container is expected to be here.
- BACKUP_TEMP_DIR: Temporary location for the tar to be compressed in. Suggest just using ```/tmp``` folder.
- LOCAL_ENCRYPTED_BACKUP_DIR: Where locally encrypted backups will be, this will be a mirrored version to the cloud copy.
- Discord_WEBHOOK_URL: Pretty self explanatory. The full Discord webhook link, enclosed in double quotation marks ("example").
- GPG_PASSPHRASE: The passphrase used for encryption. ⚠️**Important: Keep this somewhere safe, loosing this means losing backup data.**
- REMOTE_USER: The user for the SSH storage server.
- REMOTE_HOST: The dns or ip of the SSH server.
- REMOTE_DIR: Folder in which to put the backups in.
- SSH_KEY_PATH: Path to the SSH key.
- BACKUPS_TO_KEEP: Amount of backups to keep.
- LOG_FILE: Location to the log file
- HOSTNAME: Set the hostname of the server, this is used to tell in Discord which server sent the message. I use ```$1``` here to set a hostname from the command. Example could be ```./script.sh "server1"```.

ℹ️**Note:** The rest of the variables are automatic and do not need to be changed. 

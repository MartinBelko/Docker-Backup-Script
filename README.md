# Docker Backup Script

This script is designed to be my primary method for backing up important Docker containers to the cloud. I don't trust any single provider, including Hetzner, so I **encrypt the data before it's stored remotely**.

The script expects the Docker data and `docker-compose.yml` file to be located within the same directory. This directory is then:
1.  **Compressed** using `tar`.
2.  **Encrypted** to a separate temporary location using GPG.
3.  **Synced to the cloud** using RSYNC.
4.  **Keeps the last 5 copies** both locally and on the remote storage.

I prefer this method because, in case of a recovery, I can simply decrypt, extract the folder, and run `docker compose up -d` to get back up and running quickly. Discord notifications provide a convenient way for me to monitor the success of backups.

The script also includes **cleanup mechanisms**: in case of a command failure, it will delete temporary files and restart the Docker container to ensure minimal disruption.

---

⚠️ **Important:** You are solely responsible for creating, using, and securely storing your encryption passphrase. While you are free to use this script, I cannot be held responsible if you lose your passphrase and are unable to recover your data. I personally use Bitwarden (client) with Vaultwarden (backend) to store my passphrases and always have a worst-case scenario plan; I highly recommend you do the same.

---

### 💻 Compatibility

The script is intended for **Linux** environments and has been successfully tested on the following platforms:
* **Rocky Linux 9** on AMD/Intel x64
* **Rocky Linux 9** on ARM64 (running in UTM on a MacBook Air M1, 2020)

ℹ️ **Note:** The script is intentionally basic and should, in theory, work on most major Linux distributions like Ubuntu, Red Hat, Debian, and Fedora.

ℹ️ **Note:** A log file is created for each run, overwriting the previous one, ensuring you always have the most recent execution log.

---

### ✅ Requirements

The following packages are required for the script to function:
* **RSYNC**: For transferring data to cloud storage.
    * [RSYNC Documentation](https://rsync.samba.org/documentation.html)
* **Curl**: For sending notifications to a Discord webhook.
    * [Curl Man Page](https://curl.se/docs/manpage.html)
* **Tar**: For compressing the Docker data.
    * [Tar Manual](https://www.gnu.org/software/tar/manual/tar.html)
* **GPG**: For encrypting the data.
    * [GnuPG (GPG) Documentation](https://www.gnupg.org/documentation/)
* **Docker Compose Plugin**: Essential for managing Docker containers.
    * [Docker Compose Overview](https://docs.docker.com/compose/)

You can ensure that the packages rsync, curl, tar, and gpg are installed—or will be installed—by running the following command on Rocky Linux:
```
sudo dnf install rsync curl tar gpg -y
```

I usually install and run docker with Rocky Linux and with the following commands:
```
sudo dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
sudo dnf update
sudo dnf install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin -y
sudo systemctl enable --now docker
```

---

### 🔧 Configuration Variables

You need to modify the following variables directly within the script. Examples are provided in the script itself.

* `SOURCE_DIR`: The absolute path to your `docker-compose.yml` file. The Docker container's persistent data is expected to reside in this same directory.
* `BACKUP_TEMP_DIR`: A temporary location where the compressed `.tar` file will be created. `/tmp` is generally a good suggestion.
* `LOCAL_ENCRYPTED_BACKUP_DIR`: The local directory where encrypted backups will be stored. This directory will mirror the cloud copy.
* `DISCORD_WEBHOOK_URL`: Your full Discord webhook URL. ℹ️ **Note:** Enclosed in double quotation marks (e.g., `"https://discord.com/api/webhooks/..."`).
* `GPG_PASSPHRASE`: The passphrase used for encryption. ⚠️ **Important: Store this securely; losing it means losing access to your backup data.** ℹ️ **Note:** Enclosed in single quotation marks to avoid special characters escaping (e.g., `'secretpassphrase1234/%&#'`).
* `REMOTE_USER`: The username for your SSH storage server.
* `REMOTE_HOST`: The DNS name or IP address of your SSH server.
* `REMOTE_DIR`: The directory on the remote server where backups will be stored.
* `SSH_KEY_PATH`: The absolute path to your SSH private key.
* `BACKUPS_TO_KEEP`: The number of backup copies to retain both locally and remotely.
* `LOG_FILE`: The absolute path for the log file.
* `HOSTNAME`: Set the hostname of the server. This value is used in Discord notifications to identify the sending server. You can pass this as an argument when running the script (e.g., `./script.sh "server1"` uses `$1` for the hostname).

ℹ️ **Note:** All other variables are automatically managed by the script and typically do not require manual adjustment.

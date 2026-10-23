# lamp-pod

This repository holds only the container setup for our local LAMP environment. The site code isn't in it. You bring your own files, and the containers serve them: PHP 8.3 on Apache in one container, MariaDB in the other.

## Getting started

You need Podman with a compose provider, or Docker Desktop. The commands below use `docker`, and they work the same through Podman's `docker` alias.

1. **Clone the repository**, then put your site files in `www/`. Apache serves that folder at http://localhost, so a WordPress install in `www/wordpress/` shows up at http://localhost/wordpress/.
2. **Set your database password.** Run `cp .env.example .env` and change `DB_ROOT_PASSWORD` in the new file. Git ignores `.env`, so your password stays on your machine. If you skip this step, the password is `password`.
3. **Start the containers** with `docker compose up -d --build`. The first build takes a few minutes.
4. **Point your site at the database.** Inside the containers, the database host is `webdb`, the user is `root`, and the password is the one from your `.env`. From your Mac, connect to `localhost:3306`. MariaDB creates an empty `root_db` database on first start. Create any other database you need, such as `wordpress`, before you import into it.

The database port is published on `127.0.0.1` only, so nobody else on your network can reach it. The web server is not limited the same way: macOS lets only root listen on port 80 at a single address, so port 80 is open on all interfaces and others on your network can see your local site.

**`www/`, `share/` and `db_data/` are ignored by git**, so nothing you put there is ever committed. `share/` is mounted at `/home/docker/share` inside the web container, which makes it a handy place for import files. `db_data/` holds the database files, so deleting it wipes the database.

## Day to day

Apache runs as a `docker` user (uid 1000), so WordPress can write uploads and install plugins. WP-CLI is installed, and it runs as that same user even from a root shell, so files it creates keep the right owner:

```sh
docker exec -w /var/www/html/wordpress lamp-web wp plugin list
```

## Changing the database password later

MariaDB reads `DB_ROOT_PASSWORD` only when it first creates `db_data/`. If your database already exists, changing `.env` does not change its password. To change it, run this with your current password, then put the new password in `.env`:

```sh
docker exec -it lamp-db mariadb -uroot -p'current-password' \
  -e "ALTER USER 'root'@'%' IDENTIFIED BY 'new-password'; ALTER USER 'root'@'localhost' IDENTIFIED BY 'new-password';"
```

Remember to update your site's config too, such as `DB_PASSWORD` in `wp-config.php`.

## Keeping PHP patched

The image follows the latest PHP 8.3 release, so picking up a security fix is a rebuild, not a restart. **Restarting the container does not update PHP.**

```sh
docker compose build --pull webserver && docker compose up -d webserver
docker exec lamp-web php -v
```

PHP 8.3 gets security fixes through the end of 2027. Before then, we should move the `FROM` line in the Dockerfile to a newer version.

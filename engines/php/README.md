# PHP app made with Alpha

Upload this folder to any PHP 8.1+ host (with the `pdo_sqlite` and `curl` extensions), or run it with Docker:

    docker build -t app . && docker run -p 8080:80 -v $PWD/data:/var/www/html/data app

Then put the address in Alpha (project > settings > server address) and build the Android app: it opens this server.

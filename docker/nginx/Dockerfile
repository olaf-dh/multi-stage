FROM nginx:1.25-alpine

COPY docker/nginx/default.conf /etc/nginx/conf.d/default.conf
COPY --from=my-symfony-app:prod /var/www/html/public /var/www/html/public

FROM nginx:1.27-alpine

COPY deploy/web/nginx.conf /etc/nginx/nginx.conf
COPY build/web/ /usr/share/nginx/html/

RUN chown -R nginx:nginx /usr/share/nginx/html /var/cache/nginx /var/run \
    && mkdir -p /tmp/client_temp /tmp/proxy_temp /tmp/fastcgi_temp /tmp/uwsgi_temp /tmp/scgi_temp \
    && chown -R nginx:nginx /tmp

USER nginx
EXPOSE 8080
HEALTHCHECK --interval=15s --timeout=3s --start-period=5s --retries=5 \
  CMD wget -q -O /dev/null http://127.0.0.1:8080/healthz || exit 1

ENTRYPOINT ["nginx", "-g", "daemon off;"]

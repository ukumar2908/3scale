FROM ubi8:8.4-213

LABEL summary="3scale's API gateway (APIcast) is an OpenResty application which consists of two parts: Nginx configuration and Lua files." \
      description="APIcast is not a standalone API gateway therefore it needs connection to the 3scale API management platform. The container includes OpenResty and uses LuaRocks to install dependencies (rocks are installed in the application folder)." \
      io.k8s.description="APIcast is not a standalone API gateway therefore it needs connection to the 3scale API management platform. The container includes OpenResty and uses LuaRocks to install dependencies (rocks are installed in the application folder)." \
      io.k8s.display-name="3scale API gateway (APIcast)" \
      io.openshift.expose-services="8080:apicast" \
      io.openshift.tags="integration, nginx, lua, openresty, api, gateway, 3scale, rhamp"

# Labels consumed by Red Hat build service
LABEL com.redhat.component="3scale-amp-apicast-gateway-container" \
      name="3scale-amp2/apicast-gateway-rhel8" \
    version="1.20.1"\
      maintainer="3scale-engineering@redhat.com"

ENV AUTO_UPDATE_INTERVAL=0 \
    # The $HOME is not set by default, but some applications needs this variable
    HOME=/opt/app-root/src \
    PATH=/opt/app-root/src/bin:/opt/app-root/bin:$PATH

EXPOSE 8080

WORKDIR /tmp

ARG BUILD_TYPE=brew

# We cannot use a .repo in images that will be shipped as it causes unsigned RPMs to be installed
# We must use the signed compose created by ODCS by specifying the RPMs used in container.yaml
# No need to specify the dependencies, ODCS will take care of that
# USE THE BELOW ONLY FOR LOCAL BUILDS: brew.repo should always be empty.
COPY $BUILD_TYPE.repo /etc/yum.repos.d/

# Copy *.rpm files to /tmp/ so we can inject local rpms for local build
ADD apicast-*.tar.gz /tmp/

RUN PKGS='openresty-resty luarocks gateway-rockspecs opentracing-cpp-devel jaegertracing-cpp-client openresty-opentracing' && \
    mkdir -p "$HOME" && \
    yum -y --setopt=tsflags=nodocs install $PKGS && \
    rpm -V $PKGS && \
    yum clean all -y

RUN mkdir -p /opt/app-root/src/logs && \
    useradd -u 1001 -r -g 0 -d ${HOME} -s /sbin/nologin -c "Default Application User" default && \
    rm -r /usr/local/openresty/nginx/logs && \
    ln -s /opt/app-root/src/logs /usr/local/openresty/nginx/logs && \
    ln -s /dev/stdout /opt/app-root/src/logs/access.log && \
    ln -s /dev/stderr /opt/app-root/src/logs/error.log && \
    mkdir -p /usr/local/share/lua/ && \
    chmod g+w /usr/local/share/lua/ && \
    mkdir -p /usr/local/openresty/nginx/{client_body_temp,fastcgi_temp,proxy_temp,scgi_temp,uwsgi_temp} && \
    chown -R 1001:0 /opt/app-root /usr/local/share/lua/ /usr/local/openresty/nginx/{client_body_temp,fastcgi_temp,proxy_temp,scgi_temp,uwsgi_temp}

RUN mkdir -p /root/licenses/3scale-amp-apicast-gateway && \
    cp /usr/share/licenses/gateway-rockspecs/licenses.xml /root/licenses/3scale-amp-apicast-gateway/licenses.xml

RUN mv /tmp/apicast-*/gateway/* /opt/app-root/src && \
    mv /tmp/apicast-*/gateway/.s2i/bin/run /opt/app-root/src/bin/ && \
    rm -rf /tmp/apicast-*

COPY s2i/bin/ /usr/local/bin/

RUN ln --verbose --symbolic /opt/app-root/src /opt/app-root/app && \
    ln --verbose --symbolic /opt/app-root/bin /opt/app-root/scripts

ENV LD_LIBRARY_PATH="$LD_LIBRARY_PATH:/opt/app-root/lib"

WORKDIR /opt/app-root/app

RUN \
    ln --verbose --symbolic /opt/app-root/src/bin /opt/app-root/bin && \
    ln --verbose --symbolic /opt/app-root/src/http.d /opt/app-root/http.d && \
    ln --verbose --symbolic --force /etc/ssl/certs/ca-bundle.crt "/opt/app-root/src/conf" && \
    chmod --verbose g+w "${HOME}" "${HOME}"/* "${HOME}/http.d" && \
    chown -R 1001:0 /opt/app-root

USER 1001

ENV LUA_CPATH "./?.so;/usr/lib64/lua/5.1/?.so;/usr/lib64/lua/5.1/loadall.so;/usr/local/lib64/lua/5.1/?.so"
ENV LUA_PATH "/usr/lib64/lua/5.1/?.lua;/usr/local/share/lua/5.1/?.lua;/usr/local/share/lua/5.1/*/?.lua;"

WORKDIR /opt/app-root
ENTRYPOINT ["container-entrypoint"]
CMD ["scripts/run"]

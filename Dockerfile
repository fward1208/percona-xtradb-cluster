FROM debian:latest
MAINTAINER fward <fredrick.ward@gmail.com>

RUN groupadd -g 1001 mysql
RUN useradd -u 1001 -r -g 1001 -s /sbin/nologin -c "Default Application User" mysql

RUN apt-get update -qq && apt-get install -qqy --no-install-recommends apt-transport-https ca-certificates pwgen wget curl lsb-release iproute gnupg && rm -rf /var/lib/apt/lists/*

RUN wget https://repo.percona.com/apt/percona-release_0.1-6.$(lsb_release -sc)_all.deb && dpkg -i percona-release_0.1-6.$(lsb_release -sc)_all.deb

# the "/var/lib/mysql" stuff here is because the mysql-server postinst doesn't have an explicit way to disable the mysql_install_db codepath besides having a database already "configured" (ie, stuff in /var/lib/mysql/mysql)
# also, we set debconf keys to make APT a little quieter

ENV DEBIAN_FRONTEND noninteractive

RUN apt-get update -qq && apt-get install -qqy --force-yes percona-xtradb-cluster-57 curl pmm-client -y && rm -rf /var/lib/apt/lists/* \

# comment out any "user" entires in the MySQL config ("docker-entrypoint.sh" or "--user" will handle user switching) && sed -ri 's/^user\s/#&/' /etc/mysql/my.cnf \

# purge and re-create /var/lib/mysql with appropriate ownership
        && rm -rf /var/lib/mysql && mkdir -p /var/lib/mysql /var/run/mysqld \
        && chown -R mysql:mysql /var/lib/mysql /var/run/mysqld \

# ensure that /var/run/mysqld (used for socket and lock files) is writable regardless of the UID our mysqld instance ends up having at runtime
        && chmod 777 /var/run/mysqld

RUN sed -ri 's/^bind-address/#&/' /etc/mysql/my.cnf

#       && echo 'skip-host-cache\nskip-name-resolve' | awk '{ print } $1 == "[mysqld]" && c == 0 { c = 1; system("cat") }' /etc/mysql/my.cnf > /tmp/my.cnf \
#       && mv /tmp/my.cnf /etc/mysql/my.cnf


VOLUME ["/var/lib/mysql", "/var/log/mysql"]

RUN sed -ri 's/^log_error/#&/' /etc/mysql/my.cnf

ADD node.cnf /etc/mysql/conf.d/node.cnf

COPY entrypoint.sh /entrypoint.sh
COPY pmm_setup.sh /usr/bin/pmm_setup.sh
COPY jq /usr/bin/jq
COPY clustercheckcron /usr/bin/clustercheckcron
RUN chmod a+x /usr/bin/jq
RUN chown root:root /usr/bin/pmm_setup.sh && chmod +x /usr/bin/pmm_setup.sh 
RUN chmod a+x /usr/bin/clustercheckcron

EXPOSE 3306 4567 4568

LABEL vendor=Percona
LABEL com.percona.package="Percona XtraDB Cluster"
LABEL com.percona.version="5.7"

ENTRYPOINT ["/entrypoint.sh"]

EXPOSE 3306
USER 1001 
CMD [""]

FROM alpine:3.12.1

LABEL maintainer="Adrien Ferrand <ferrand.ad@gmail.com>"

ENV BACKUPPC_VERSION 4.4.0
ENV BACKUPPC_XS_VERSION 0.62
ENV RSYNC_BPC_VERSION 3.1.2.2
ENV PAR2_VERSION v0.8.1

# Install backuppc runtime dependencies
RUN apk --no-cache --update add \
        rsync tar bash shadow ca-certificates \
        supervisor \
        perl perl-archive-zip perl-xml-rss perl-cgi perl-file-listing perl-json-xs \
        expat samba-client iputils openssh openssl rrdtool ttf-dejavu \
        msmtp lighttpd lighttpd-mod_auth gzip apache2-utils tzdata libstdc++ libgomp \
 && apk --no-cache --update -X http://dl-cdn.alpinelinux.org/alpine/edge/community add par2cmdline \
# Install backuppc build dependencies
 && apk --no-cache --update --virtual build-dependencies add \
        gcc g++ autoconf automake make git perl-dev acl-dev curl \
# Compile and install BackupPC:XS
 && git clone https://github.com/backuppc/backuppc-xs.git /root/backuppc-xs --branch $BACKUPPC_XS_VERSION \
 && cd /root/backuppc-xs \
 && perl Makefile.PL && make && make test && make install \
# Compile and install Rsync (BPC version)
 && git clone https://github.com/backuppc/rsync-bpc.git /root/rsync-bpc --branch $RSYNC_BPC_VERSION \
 && cd /root/rsync-bpc && ./configure && make reconfigure && make && make install \
# Configure MSMTP for mail delivery (initially sendmail is a sym link to busybox)
 && rm -f /usr/sbin/sendmail \
 && ln -s /usr/bin/msmtp /usr/sbin/sendmail \
# Disable strict host key checking
 && sed -i -e 's/^# Host \*/Host */g' /etc/ssh/ssh_config \
 && sed -i -e 's/^#   StrictHostKeyChecking ask/    StrictHostKeyChecking no/g' /etc/ssh/ssh_config \
# Get BackupPC, it will be installed at runtime to allow dynamic upgrade of existing config/pool
 && curl -o /root/BackupPC-$BACKUPPC_VERSION.tar.gz -L https://github.com/backuppc/backuppc/releases/download/$BACKUPPC_VERSION/BackupPC-$BACKUPPC_VERSION.tar.gz \
# Prepare backuppc home
 && mkdir -p /home/backuppc && cd /home/backuppc \
# Mark the docker as not run yet, to allow entrypoint to do its stuff
 && touch /firstrun \
# Clean
 && rm -rf /root/backuppc-xs /root/rsync-bpc /root/par2cmdline \
 && apk del build-dependencies

COPY files/lighttpd.conf /etc/lighttpd/lighttpd.conf
COPY files/auth.conf /etc/lighttpd/auth.conf
COPY files/auth-ldap.conf /etc/lighttpd/auth-ldap.conf
COPY files/entrypoint.sh /entrypoint.sh
COPY files/supervisord.conf /etc/supervisord.conf

EXPOSE 8080

WORKDIR /home/backuppc

VOLUME ["/etc/backuppc", "/home/backuppc", "/data/backuppc"]

ENTRYPOINT ["/entrypoint.sh"]

CMD ["/usr/bin/supervisord", "-c", "/etc/supervisord.conf"]

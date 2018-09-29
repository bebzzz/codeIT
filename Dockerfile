FROM centos:7.5.1804

# Install packages, required for RPM build
RUN yum clean all \ 
	&& rm -r /var/cache/yum \
	&& yum update -y \
	&& yum --enablerepo=updates clean metadata \
	&& yum groupinstall -y "Development Tools" \
	&& yum install -y \
	rpmdevtools \
	yum-utils \
	redhat-lsb-core \
	wget

# Create new user for build
RUN useradd builder \
        && usermod -a -G builder builder \
	&& usermod -aG wheel builder \
	&& su - builder \
        && rpmdev-setuptree

# Download Nginx Source RPM
WORKDIR /home/builder 
RUN wget http://nginx.org/packages/mainline/centos/7/SRPMS/nginx-1.15.4-1.el7_4.ngx.src.rpm \
	&& rpm -Uvh nginx*.src.rpm

# Install dependencies for Nginx build
COPY nginx.repo /etc/yum.repos.d/nginx.repo
RUN  yum update -y \
	&& yum-builddep -y nginx

# Download OpenSSL-1.1.1 source code
WORKDIR /usr/src/
RUN wget https://www.openssl.org/source/openssl-1.1.1.tar.gz \
	&& tar -xvzf openssl-1.1.1.tar.gz

# Add OpenSSL to  SPEC file of Nginx
WORKDIR /home/builder/
RUN sed -i 's/\(BASE\_CONFIGURE\_ARGS\)\(.*\)\(\")\)/\1\2 --with-openssl=\/usr\/src\/openssl-1.1.1\3/' /root/rpmbuild/SPECS/nginx.spec

# Build Nginx RPM package
RUN rpmbuild -ba /root/rpmbuild/SPECS/nginx.spec

# Install new Nginx RPM
WORKDIR /root/rpmbuild/RPMS/
RUN yum install openssl -y \
	&& rpm -Uvh /root/rpmbuild/RPMS/x86_64/nginx-1*.rpm

EXPOSE 80 443
VOLUME /usr/share/nginx/html

ENTRYPOINT ["nginx", "-g", "daemon off;"]


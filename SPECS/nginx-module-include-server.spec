#
%global debug_package %{nil}
%global _debuginfo_subpackages 0

%define nginx_user nginx
%define nginx_group nginx

%if 0%{?rhel} || 0%{?amzn}
%define _group System Environment/Daemons
BuildRequires: openssl-devel
%endif

%if 0%{?suse_version} == 1315
%define _group Productivity/Networking/Web/Servers
BuildRequires: libopenssl-devel
%endif

%if 0%{?rhel} == 7
BuildRequires: redhat-lsb-core
%define epoch 1
Epoch: %{epoch}
%define os_minor %(lsb_release -rs | cut -d '.' -f 2)
%if %{os_minor} >= 4
%define dist .el7_4
%else
%define dist .el7
%endif
%endif

%if 0%{?rhel} == 8
%define epoch 1
Epoch: %{epoch}
%endif

%if 0%{?rhel} == 9
%define epoch 2
Epoch: %{epoch}
%endif

%if 0%{?rhel} == 10
%define epoch 2
Epoch: %{epoch}
%endif



%define base_version 1.29.6
%define base_release 1%{?dist}.ngx
%define main_version 1.29.6
%define main_release 1

%define bdir %{_builddir}/%{name}-%{base_version}

Summary: nginx enable support to include_server derective in nginx.conf.
Name: nginx-module-include-server
Version: 1.29.6+0.01
Release: 1%{?dist}.ngx
Vendor: Georgy Shelkovy [RekGRpth]
URL: https://github.com/RekGRpth
Group: %{_group}

Source0: nginx-%{main_version}.tar.gz
Source1: COPYRIGHT




License: MIT

BuildRoot: %{_tmppath}/%{name}-%{main_version}-%{main_release}-root
BuildRequires: zlib-devel
BuildRequires: pcre2-devel
Requires: nginx = %{?epoch:%{epoch}:}1.29.6-1%{?dist}.ngx

%description
nginx enable support to include_server derective in nginx.conf..

%define WITH_CC_OPT $(echo %{optflags} $(pcre2-config --cflags))
%define WITH_LD_OPT -Wl,-z,relro -Wl,-z,now

%define BASE_CONFIGURE_ARGS $(echo "--prefix=%{_sysconfdir}/nginx --sbin-path=%{_sbindir}/nginx --modules-path=%{_libdir}/nginx/modules --conf-path=%{_sysconfdir}/nginx/nginx.conf --error-log-path=%{_localstatedir}/log/nginx/error.log --http-log-path=%{_localstatedir}/log/nginx/access.log --pid-path=%{_localstatedir}/run/nginx.pid --lock-path=%{_localstatedir}/run/nginx.lock --http-client-body-temp-path=%{_localstatedir}/cache/nginx/client_temp --http-proxy-temp-path=%{_localstatedir}/cache/nginx/proxy_temp --http-fastcgi-temp-path=%{_localstatedir}/cache/nginx/fastcgi_temp --http-uwsgi-temp-path=%{_localstatedir}/cache/nginx/uwsgi_temp --http-scgi-temp-path=%{_localstatedir}/cache/nginx/scgi_temp --user=%{nginx_user} --group=%{nginx_group} --with-compat --with-file-aio --with-threads --with-http_addition_module --with-http_auth_request_module --with-http_dav_module --with-http_flv_module --with-http_gunzip_module --with-http_gzip_static_module --with-http_mp4_module --with-http_random_index_module --with-http_realip_module --with-http_secure_link_module --with-http_slice_module --with-http_ssl_module --with-http_stub_status_module --with-http_sub_module --with-http_v2_module --with-mail --with-mail_ssl_module --with-stream --with-stream_realip_module --with-stream_ssl_module --with-stream_ssl_preread_module")
%define MODULE_CONFIGURE_ARGS $(echo "--add-dynamic-module=ngx_http_include_server_module")

%prep
%setup -qcTn %{name}-%{main_version}
tar --strip-components=1 -zxf %{SOURCE0}

git clone https://github.com/vados-dev/ngx_http_include_server_module.git || true


%build

cd %{bdir}

./configure %{BASE_CONFIGURE_ARGS} %{MODULE_CONFIGURE_ARGS} \
	--with-cc-opt="%{WITH_CC_OPT}" \
	--with-ld-opt="%{WITH_LD_OPT}" \
	--with-debug
make %{?_smp_mflags} modules
for so in `find %{bdir}/objs/ -type f -name "*.so"`; do
debugso=`echo $so | sed -e "s|.so|-debug.so|"`
mv $so $debugso
done
./configure %{BASE_CONFIGURE_ARGS} %{MODULE_CONFIGURE_ARGS} \
	--with-cc-opt="%{WITH_CC_OPT}" \
	--with-ld-opt="%{WITH_LD_OPT}"
make %{?_smp_mflags} modules

%install
cd %{bdir}
%{__rm} -rf $RPM_BUILD_ROOT
%{__mkdir} -p $RPM_BUILD_ROOT%{_datadir}/doc/nginx-module-include-server
%{__install} -m 644 -p %{SOURCE1} \
    $RPM_BUILD_ROOT%{_datadir}/doc/nginx-module-include-server/



%{__mkdir} -p $RPM_BUILD_ROOT%{_libdir}/nginx/modules
for so in `find %{bdir}/objs/ -maxdepth 1 -type f -name "*.so"`; do
%{__install} -m755 $so \
   $RPM_BUILD_ROOT%{_libdir}/nginx/modules/
done

%clean
%{__rm} -rf $RPM_BUILD_ROOT

%files
%defattr(-,root,root)
%{_libdir}/nginx/modules/*
%dir %{_datadir}/doc/nginx-module-include-server
%{_datadir}/doc/nginx-module-include-server/*


%post
if [ $1 -eq 1 ]; then
cat <<BANNER
----------------------------------------------------------------------

The enable support to include_server derective in nginx.conf. for nginx have been installed.
To enable these modules, add the following to /etc/nginx/nginx.conf
and reload nginx:

    load_module modules/ngx_http_include_server_module.so;

----------------------------------------------------------------------
BANNER
fi

%changelog
* Tue Oct 17 2017 Konstantin Pavlov <thresh@nginx.com>
- base version updated to 1.12.2

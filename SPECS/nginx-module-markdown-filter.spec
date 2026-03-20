#
%define nginx_user nginx
%define nginx_group nginx

#%define __arch_install_post   /usr/lib/rpm/check-rpaths   /usr/lib/rpm/check-buildroot






%if 0%{?rhel}
%define _group System Environment/Daemons
%endif


# end of distribution specific definitions

%define base_version 1.29.6
%define base_release 1%{?dist}.ngx

%define bdir %{_builddir}/%{name}-%{base_version}

Summary: nginx markdown filter module
Name: nginx-module-markdown-filter
Version: 1.29.6+0.1.6f
Release: 1%{?dist}.ngx
Vendor: Karim Ulzhabayev <nginx-packaging@f5.com>
URL: https://github.com/ukarim
Group: %{_group}
Requires: cmark-devel


Source0: https://nginx.org/download/nginx-%{base_version}.tar.gz
Source1: ../contrib/src/ngx_markdown_filter_module
Source100: nginx-acme-0.3.1.tar.gz
Source101: nginx-acme-0.3.1-vendor.tar.gz



License: 2-clause BSD-like license

BuildRoot: %{_tmppath}/%{name}-%{base_version}-%{base_release}-root
BuildRequires: zlib-devel
BuildRequires: pcre2-devel

Provides: webserver
Provides: %{name}-r%{base_version}

%if !(0%{?rhel} == 7)
Recommends: logrotate
%endif

%description
nginx module-markdown-filter.
nginx [engine x] is an HTTP and reverse proxy server, as well as
a mail proxy server.

%if ( 0%{?suse_version} && 0%{?suse_version} < 1600 )
%debug_package
%endif

%define WITH_CC_OPT $(echo %{optflags} $(pcre2-config --cflags))
%define WITH_LD_OPT -Wl,-z,relro -Wl,-z,now -Wl,-as-needed

%define BASE_CONFIGURE_ARGS $(echo "--prefix=%{_sysconfdir}/nginx --sbin-path=%{_sbindir}/nginx --modules-path=%{_libdir}/nginx/modules --conf-path=%{_sysconfdir}/nginx/nginx.conf --error-log-path=%{_localstatedir}/log/nginx/error.log --http-log-path=%{_localstatedir}/log/nginx/access.log --pid-path=%{_localstatedir}/run/nginx.pid --lock-path=%{_localstatedir}/run/nginx.lock --http-client-body-temp-path=%{_localstatedir}/cache/nginx/client_temp --http-proxy-temp-path=%{_localstatedir}/cache/nginx/proxy_temp --http-fastcgi-temp-path=%{_localstatedir}/cache/nginx/fastcgi_temp --http-uwsgi-temp-path=%{_localstatedir}/cache/nginx/uwsgi_temp --http-scgi-temp-path=%{_localstatedir}/cache/nginx/scgi_temp --user=%{nginx_user} --group=%{nginx_group} --with-compat --with-file-aio --with-threads --with-http_addition_module --with-http_auth_request_module --with-http_dav_module --with-http_flv_module --with-http_gunzip_module --with-http_gzip_static_module --with-http_mp4_module --with-http_random_index_module --with-http_realip_module --with-http_secure_link_module --with-http_slice_module --with-http_ssl_module --with-http_stub_status_module --with-http_sub_module --with-http_v2_module $( if [ 0%{?rhel} -eq 7 ] || [ 0%{?suse_version} -eq 1315 ]; then continue; else echo "--with-http_v3_module"; fi; ) --with-mail --with-mail_ssl_module --with-stream --with-stream_realip_module --with-stream_ssl_module --with-stream_ssl_preread_module")
%define MODULE_CONFIGURE_ARGS $(echo "--add-dynamic-module=%{SOURCE1}/")

%prep
%setup -qcTn %{name}-%{base_version}
tar --strip-components=1 -zxf %{SOURCE0}

ln -s . nginx%{?base_suffix}


#tar xvzfo %{SOURCE100}
#ln -s nginx-acme-* nginx-acme
#tar xvzfo %{SOURCE101}
#ln -s nginx-acme-* nginx-acme

%install
cd %{bdir}
%{__rm} -rf $RPM_BUILD_ROOT
%{__mkdir} -p $RPM_BUILD_ROOT%{_libdir}/nginx/modules
for so in `find %{bdir}/objs/ -maxdepth 1 -type f -name "*.so"`; do
%{__install} -m755 $so \
   $RPM_BUILD_ROOT%{_libdir}/nginx/modules/
done

%check
%{__rm} -rf $RPM_BUILD_ROOT/usr/src
cd %{bdir}
grep -v 'usr/src' debugfiles.list > debugfiles.list.new && mv debugfiles.list.new debugfiles.list
cat /dev/null > debugsources.list
%if 0%{?suse_version} >= 1500
cat /dev/null > debugsourcefiles.list
%endif

%clean
%{__rm} -rf $RPM_BUILD_ROOT

%files
%defattr(-,root,root)
%{_libdir}/nginx/modules/*

%post
if [ $1 -eq 1 ]; then
cat <<BANNER
----------------------------------------------------------------------

The markdown-filter-module for nginx most be installed.
To enable this module, add the following to /etc/nginx/modules-enabled/module-markdown-filter.conf
and reload nginx:

 load_module modules/ngx_markdown_filter_module.so;

----------------------------------------------------------------------
BANNER
fi

%changelog
* Tue Mar 20 2026 vados-dev <192440777+vados-dev@users.noreply.github.com>
- module-markdown-filter updated to 0.1.6f (fixed)

* Tue Mar 10 2026 Nginx Packaging <nginx-packaging@f5.com> - 1.29.6-1%{?dist}.ngx
- 1.29.6-1

* Wed Feb  4 2026 Nginx Packaging <nginx-packaging@f5.com> - 1.29.5-1%{?dist}.ngx
- 1.29.5-1


 %{!?_module_dir:%define _module_dir /home/builder/ngx_markdown_filter_module}

%define BASE_CONFIGURE_ARGS $(echo "--prefix=%{_sysconfdir}/nginx --sbin-path=%{_sbindir}/nginx --modules-path=%{_libdir}/nginx/modules --conf-path=%{_sysconfdir}/nginx/nginx.conf --error-log-path=%{_localstatedir}/log/nginx/error.log --http-log-path=%{_localstatedir}/log/nginx/access.log --pid-path=%{_localstatedir}/run/nginx.pid --lock-path=%{_localstatedir}/run/nginx.lock --http-client-body-temp-path=%{_localstatedir}/cache/nginx/client_temp --http-proxy-temp-path=%{_localstatedir}/cache/nginx/proxy_temp --http-fastcgi-temp-path=%{_localstatedir}/cache/nginx/fastcgi_temp --http-uwsgi-temp-path=%{_localstatedir}/cache/nginx/uwsgi_temp --http-scgi-temp-path=%{_localstatedir}/cache/nginx/scgi_temp --user=%{nginx_user} --group=%{nginx_group} --with-compat --with-file-aio --with-threads --with-http_addition_module --with-http_auth_request_module --with-http_dav_module --with-http_flv_module --with-http_gunzip_module --with-http_gzip_static_module --with-http_mp4_module --with-http_random_index_module --with-http_realip_module --with-http_secure_link_module --with-http_slice_module --with-http_ssl_module --with-http_stub_status_module --with-http_sub_module --with-http_v2_module $( if [ 0%{?rhel} -eq 7 ] || [ 0%{?suse_version} -eq 1315 ]; then continue; else echo "--with-http_v3_module"; fi; ) --with-mail --with-mail_ssl_module --with-stream --with-stream_realip_module --with-stream_ssl_module --with-stream_ssl_preread_module --add-dynamic-module=%{_module_dir}")
nginx module-markdown-filter.
nginx [engine x] is an HTTP and reverse proxy server, as well as
a mail proxy server.
 
%package module-markdown-filter
Summary: nginx markdown filter module
Version: 1.29.6+0.1.6f
Release: 1%{?dist}.ngx
Group: %{_group}
Requires: cmark-devel
Requires: nginx-r%{base_version}
Provides: %{name}-r%{base_version}
 


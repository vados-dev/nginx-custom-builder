#
%define nginx_user nginx
%define nginx_group nginx

%define __arch_install_post   /usr/lib/rpm/check-rpaths   /usr/lib/rpm/check-buildroot

%if 0%{?rhel} || 0%{?amzn} || 0%{?fedora}
%define _group System Environment/Daemons
%if 0%{?amzn} == 2
BuildRequires: openssl11-devel
%else
BuildRequires: openssl-devel
%endif
%endif

%if 0%{?suse_version} >= 1315
%define _group Productivity/Networking/Web/Servers
BuildRequires: libopenssl-devel
%define _debugsource_template %{nil}
%endif

%if (0%{?rhel} == 7) && (0%{?amzn} == 0)
%define epoch 1
Epoch: %{epoch}
%define dist .el7
%endif

%if (0%{?rhel} == 7) && (0%{?amzn} == 2)
%define epoch 1
Epoch: %{epoch}
%endif

%if 0%{?rhel} == 8
%define epoch 1
Epoch: %{epoch}
%define _debugsource_template %{nil}
%endif

%if 0%{?rhel} == 9
%define epoch 1
Epoch: %{epoch}
%define _debugsource_template %{nil}
%endif

%if 0%{?rhel} == 10
%define epoch 1
Epoch: %{epoch}
%define _debugsource_template %{nil}
%endif

%if 0%{?fedora}
%define _debugsource_template %{nil}
%global _hardened_build 1
%endif

BuildRequires: cmake
BuildRequires: pkgconfig(re2) pkgconfig(libcares)
%if 0%{?suse_version} >= 1500
BuildRequires: grpc-devel protobuf-devel
%endif

%define base_version 1.30.0
%define base_release 1%{?dist}.ngx

%define bdir %{_builddir}/%{name}-%{base_version}

Summary: nginx OpenTelemetry dynamic module
Name: nginx-module-otel
Version: 1.30.0+0.1.2
Release: 1%{?dist}.ngx
Vendor: NGINX Inc.
URL: 
Group: %{_group}

Source0: https://nginx.org/download/nginx-%{base_version}.tar.gz
Source1: nginx-module-otel.copyright

Source100: nginx-otel-0.1.2-72d8eed53af4c2cd6f3e30a2efe0e38d66f5e176.tar.gz
Source101: abseil-cpp-20211102.0.tar.gz
Source102: grpc-1.46.7.tar.gz
Source103: opentelemetry-cpp-1.26.0.tar.gz
Source104: opentelemetry-proto-1.10.0.tar.gz
Source105: protobuf-3.19.5.tar.gz


Patch100: abseil-cpp_b957f0ccd00481cd4fd663d8320aa02ae0564f18.patch
Patch101: abseil-cpp_4500c2fada4e952037c59bd65e8be1ba0b29f21e.patch
Patch102: grpc_grpc-cmake-no-re2.patch

License: MIT

BuildRoot: %{_tmppath}/%{name}-%{base_version}-%{base_release}-root
BuildRequires: zlib-devel
BuildRequires: pcre2-devel
Requires: nginx-r%{base_version}
Provides: %{name}-r%{base_version}

%description
nginx OpenTelemetry dynamic module.

%if ( 0%{?suse_version} && 0%{?suse_version} < 1600 )
%debug_package
%endif

%define WITH_CC_OPT $(echo %{optflags} $(pcre2-config --cflags))
%define WITH_LD_OPT -Wl,-z,relro -Wl,-z,now -Wl,-as-needed

%define BASE_CONFIGURE_ARGS $(echo "--prefix=%{_sysconfdir}/nginx --sbin-path=%{_sbindir}/nginx --modules-path=%{_libdir}/nginx/modules --conf-path=%{_sysconfdir}/nginx/nginx.conf --error-log-path=%{_localstatedir}/log/nginx/error.log --http-log-path=%{_localstatedir}/log/nginx/access.log --pid-path=%{_localstatedir}/run/nginx.pid --lock-path=%{_localstatedir}/run/nginx.lock --http-client-body-temp-path=%{_localstatedir}/cache/nginx/client_temp --http-proxy-temp-path=%{_localstatedir}/cache/nginx/proxy_temp --http-fastcgi-temp-path=%{_localstatedir}/cache/nginx/fastcgi_temp --http-uwsgi-temp-path=%{_localstatedir}/cache/nginx/uwsgi_temp --http-scgi-temp-path=%{_localstatedir}/cache/nginx/scgi_temp --user=%{nginx_user} --group=%{nginx_group} --with-compat --with-file-aio --with-threads --with-http_addition_module --with-http_auth_request_module --with-http_dav_module --with-http_flv_module --with-http_gunzip_module --with-http_gzip_static_module --with-http_mp4_module --with-http_random_index_module --with-http_realip_module --with-http_secure_link_module --with-http_slice_module --with-http_ssl_module --with-http_stub_status_module --with-http_sub_module --with-http_v2_module --with-http_v3_module --with-mail --with-mail_ssl_module --with-stream --with-stream_realip_module --with-stream_ssl_module --with-stream_ssl_preread_module ")
%define MODULE_CONFIGURE_ARGS $(echo "--add-dynamic-module=nginx-otel-72d8eed53af4c2cd6f3e30a2efe0e38d66f5e176/")

%prep
%setup -qcTn %{name}-%{base_version}
tar --strip-components=1 -zxf %{SOURCE0}

ln -s . nginx%{?base_suffix}


tar -xf %{SOURCE100}
ln -sfn nginx-otel-* nginx-otel || true
tar -xf %{SOURCE101}
ln -sfn abseil-cpp-* abseil-cpp || true
tar -xf %{SOURCE102}
ln -sfn grpc-* grpc || true
tar -xf %{SOURCE103}
ln -sfn opentelemetry-cpp-* opentelemetry-cpp || true
tar -xf %{SOURCE104}
ln -sfn opentelemetry-proto-* opentelemetry-proto || true
tar -xf %{SOURCE105}
ln -sfn protobuf-* protobuf || true

%patch100 -p1
%patch101 -p1
%patch102 -p1

%build

_nproc=`getconf _NPROCESSORS_ONLN`
if [ $_nproc -gt 1 ]; then
	_make_opts="-j$_nproc"
fi

cd %{bdir} && mkdir prebuilt
%if ! 0%{defined suse_version}
cd %{bdir}/abseil-cpp-20211102.0 && mkdir build && cd build && cmake -DCMAKE_CXX_STANDARD=17 -DCMAKE_CXX_EXTENSIONS=OFF -DCMAKE_CXX_VISIBILITY_PRESET=hidden -DCMAKE_POLICY_DEFAULT_CMP0063=NEW -DCMAKE_PREFIX_PATH=%{bdir}/prebuilt/ -DCMAKE_INSTALL_PREFIX:STRING=%{bdir}/prebuilt/ -DCMAKE_INSTALL_LIBDIR:STRING=lib -DCMAKE_POSITION_INDEPENDENT_CODE=ON -DBUILD_TESTING=OFF -DWITH_BENCHMARK=OFF -DCMAKE_BUILD_TYPE=RelWithDebInfo ../ && make $_make_opts install && cd %{bdir}/protobuf-3.19.5 && mkdir build && cd build && cmake -DCMAKE_CXX_STANDARD=17 -DCMAKE_CXX_EXTENSIONS=OFF -DCMAKE_CXX_VISIBILITY_PRESET=hidden -DCMAKE_POLICY_DEFAULT_CMP0063=NEW -DCMAKE_PREFIX_PATH=%{bdir}/prebuilt/ -DCMAKE_INSTALL_PREFIX:STRING=%{bdir}/prebuilt/ -DCMAKE_INSTALL_LIBDIR:STRING=lib -DCMAKE_POSITION_INDEPENDENT_CODE=ON -Dprotobuf_BUILD_TESTS=OFF -DCMAKE_BUILD_TYPE=RelWithDebInfo ../cmake/ && make $_make_opts install && cd %{bdir}/grpc-1.46.7 && mkdir build && cd build && CXXFLAGS='-DGRPC_NO_XDS -DGRPC_NO_RLS' cmake -DCMAKE_CXX_STANDARD=17 -DCMAKE_CXX_EXTENSIONS=OFF -DCMAKE_CXX_VISIBILITY_PRESET=hidden -DCMAKE_POLICY_DEFAULT_CMP0063=NEW -DCMAKE_PREFIX_PATH=%{bdir}/prebuilt/ -DCMAKE_INSTALL_PREFIX:STRING=%{bdir}/prebuilt/ -DCMAKE_INSTALL_LIBDIR:STRING=lib -DCMAKE_POSITION_INDEPENDENT_CODE=ON -DgRPC_BUILD_GRPC_RUBY_PLUGIN=OFF -DgRPC_BUILD_GRPC_PYTHON_PLUGIN=OFF -DgRPC_BUILD_GRPC_PHP_PLUGIN=OFF -DgRPC_BUILD_GRPC_OBJECTIVE_C_PLUGIN=OFF -DgRPC_BUILD_GRPC_NODE_PLUGIN=OFF -DgRPC_BUILD_GRPC_CSHARP_PLUGIN=OFF -DgRPC_BUILD_CSHARP_EXT=OFF -DgRPC_BUILD_CODEGEN=ON -DgRPC_SSL_PROVIDER=package -DgRPC_ZLIB_PROVIDER=package -DgRPC_CARES_PROVIDER=package -DgRPC_ABSL_PROVIDER=package -DgRPC_PROTOBUF_PROVIDER=package -DgRPC_PROTOBUF_PACKAGE_TYPE=CONFIG -DgRPC_USE_PROTO_LITE=ON -DCMAKE_BUILD_TYPE=RelWithDebInfo ../ && make $_make_opts install
%endif
cd %{bdir}/opentelemetry-cpp-1.26.0 && mkdir build && cd build && cmake -DCMAKE_CXX_STANDARD=17 -DCMAKE_CXX_EXTENSIONS=OFF -DCMAKE_CXX_VISIBILITY_PRESET=hidden -DCMAKE_POLICY_DEFAULT_CMP0063=NEW -DCMAKE_PREFIX_PATH=%{bdir}/prebuilt/ -DCMAKE_INSTALL_PREFIX:STRING=%{bdir}/prebuilt/ -DCMAKE_INSTALL_LIBDIR:STRING=lib -DCMAKE_POSITION_INDEPENDENT_CODE=ON -DBUILD_TESTING=OFF -DWITH_BENCHMARK=OFF -DWITH_EXAMPLES=OFF -DCMAKE_BUILD_TYPE=RelWithDebInfo ../ && make $_make_opts install || exit 1
cd %{bdir}
export PATH=%{bdir}/prebuilt/bin/:$PATH
export NGX_OTEL_PROTO_DIR=%{bdir}/opentelemetry-proto-1.10.0
export CMAKE_PREFIX_PATH=%{bdir}/prebuilt/
export NGX_OTEL_CMAKE_OPTS="-DNGX_OTEL_GRPC=package -DNGX_OTEL_SDK=package -DNGX_OTEL_PROTO_DIR=$NGX_OTEL_PROTO_DIR"
./configure %{BASE_CONFIGURE_ARGS} %{MODULE_CONFIGURE_ARGS} \
	--with-cc-opt="%{WITH_CC_OPT} " \
	--with-ld-opt="%{WITH_LD_OPT} " \
	--with-debug
make %{?_smp_mflags} modules
for so in `find %{bdir}/objs/ -type f -name "*.so"`; do
debugso=`echo $so | sed -e 's|\.so$|-debug.so|'`
mv $so $debugso
done
export PATH=%{bdir}/prebuilt/bin/:$PATH
export NGX_OTEL_PROTO_DIR=%{bdir}/opentelemetry-proto-1.10.0
export CMAKE_PREFIX_PATH=%{bdir}/prebuilt/
export NGX_OTEL_CMAKE_OPTS="-DNGX_OTEL_GRPC=package -DNGX_OTEL_SDK=package -DNGX_OTEL_PROTO_DIR=$NGX_OTEL_PROTO_DIR"
./configure %{BASE_CONFIGURE_ARGS} %{MODULE_CONFIGURE_ARGS} \
	--with-cc-opt="%{WITH_CC_OPT} " \
	--with-ld-opt="%{WITH_LD_OPT} "
make %{?_smp_mflags} modules

%install
cd %{bdir}
%{__rm} -rf $RPM_BUILD_ROOT
%{__mkdir} -p $RPM_BUILD_ROOT%{_datadir}/doc/nginx-module-otel
%{__install} -m 644 -p %{SOURCE1} \
    $RPM_BUILD_ROOT%{_datadir}/doc/nginx-module-otel/COPYRIGHT



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
%dir %{_datadir}/doc/nginx-module-otel
%{_datadir}/doc/nginx-module-otel/*


%post
if [ $1 -eq 1 ]; then
cat <<BANNER
----------------------------------------------------------------------

The OpenTelemetry dynamic module for nginx has been installed.
To enable this module, add the following to /etc/nginx/nginx.conf
and reload nginx:

    load_module modules/ngx_otel_module.so;

----------------------------------------------------------------------
BANNER
fi

%changelog
* Tue Oct 17 2017 Konstantin Pavlov <thresh@nginx.com>
- base version updated to 1.12.2

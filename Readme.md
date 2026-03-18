# RPMBuild Nginx Markdown Filter

## References

### RPM and Key
- [Package RPM Nginx Instructions](https://www.dmosk.ru/miniinstruktions.php?mini=package-rpm-nginx)

### CentOS Packages and Repos
- [nginx Mainline CentOS 10 SRPMS](https://nginx.org/packages/mainline/centos/10/SRPMS/)

### Markdown Modules
1. [Markdown Module 1](https://nginx-extras.getpagespeed.com/modules/markdown/)
2. [Markdown Filter Module](https://github.com/bet0x/ngx_markdown_filter_module)

## Signing

Sign the RPM package:

```bash
rpm --addsign rpmbuild/RPMS/x86_64/nginx-1.29.5-1.el10.ngx.x86_64.rpm
```
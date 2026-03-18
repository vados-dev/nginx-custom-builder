Makefile

help:
    @make -C rpmbuild/SPECS/
%:
    @make -C rpmbuild/SPECS/ $@

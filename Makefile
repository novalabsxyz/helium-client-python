PROJECT=helium_client
LIB_HELIUM_CLIENT=${PROJECT}/_helium.so

all: ${LIB_HELIUM_CLIENT}


.PHONY: ci
ci: all


.PHONY: install
install: ${LIB_HELIUM_CLIENT}
	pip install -e .


.PHONY: uninstall
uninstall:
	pip uninstall ${PROJECT}


helium_client/_helium.c: helium_client/_helium.pxd helium_client/_helium.pyx
	cython -I helium-client helium_client/_helium.pyx -o helium_client/_helium.c


.PHONY: ${LIB_HELIUM_CLIENT}
${LIB_HELIUM_CLIENT}: helium_client/_helium.c
	python setup.py build_ext -i


.PHONY: version
version: check_dirty check_version
	git tag -as -m "Version ${VERSION}" ${VERSION}
	git push origin master --tags


.PHONY: docs
docs: ${LIB_HELIUM_CLIENT}
	$(MAKE) -C docs clean html
	touch docs/_build/html/.nojekyll


.PHONY: clean
clean:
	$(MAKE) -C docs clean
	rm -rf build ${LIB_HELIUM_CLIENT} *.pyc ${PROJECT}/*.pyc


.PHONY: check_dirty
check_dirty:
ifeq ($(GIT_TREE_STATE),dirty)
	$(error git state is not clean)
endif


.PHONY: check_version
check_version:
ifeq ($(VERSION),)
	$(error VERSION is not set)
endif

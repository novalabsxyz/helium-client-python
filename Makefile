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

.PHONY: docs
docs: ${LIB_HELIUM_CLIENT}
	$(MAKE) -C docs clean html

.PHONY: clean
clean:
	$(MAKE) -C docs clean
	rm -rf build ${LIB_HELIUM_CLIENT} *.pyc ${PROJECT}/*.pyc

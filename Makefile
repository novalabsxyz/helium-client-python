PROJECT=helium_client
LIB_HELIUM_CLIENT=${PROJECT}.so

all: ${LIB_HELIUM_CLIENT}

.PHONY: ci
ci: all

.PHONY: install
install: ${LIB_HELIUM_CLIENT}
	python setup.py install

.PHONY: uninstall
uninstall:
	pip uninstall -y -q ${PROJECT}

src/${PROJECT}.c: src/c${PROJECT}.pxd src/${PROJECT}.pyx
	cython -I helium-client src/${PROJECT}.pyx -o src/${PROJECT}.c

.PHONY: ${LIB_HELIUM_CLIENT}
${LIB_HELIUM_CLIENT}: src/${PROJECT}.c
	python setup.py build_ext --inplace

.PHONY: clean
clean:
	rm -rf build ${LIB_HELIUM_CLIENT}

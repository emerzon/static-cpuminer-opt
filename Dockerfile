FROM clearlinux

ENV BUILD_PACKAGES="c-basic curl git diffutils python-basic"

ENV GLIBC_URL https://ftp.gnu.org/gnu/glibc/glibc-2.30.tar.bz2
ENV OPENSSL_URL https://www.openssl.org/source/openssl-1.1.1d.tar.gz
ENV GMP_URL https://gmplib.org/download/gmp/gmp-6.1.2.tar.bz2
ENV CURL_URL https://curl.haxx.se/download/curl-7.66.0.tar.bz2
ENV ZLIB_URL https://www.zlib.net/zlib-1.2.11.tar.gz
ENV CPUMINER_URL https://github.com/JayDDee/cpuminer-opt


RUN set -xe; \
    swupd bundle-add ${BUILD_PACKAGES}; \
	mkdir -p /usr/src; \
	cd /usr/src; \
    for i in ${OPENSSL_URL} ${ZLIB_URL}; \
    do curl ${i} | tar xvz; \
    done; \
    for i in ${GLIBC_URL} ${GMP_URL} ${CURL_URL}; \
    do curl ${i} | tar xvj; \
    done; \
    git clone ${CPUMINER_URL}

ENV CFLAGS "-Ofast -march=native -funroll-loops -fno-stack-protector -no-pie"
ENV CXXFLAGS "${CFLAGS}"
ENV LDFLAGS "-L/usr/local/lib"
ENV AR "gcc-ar"
ENV RANLIB "gcc-ranlib"
ENV NM "gcc-nm"

# Build Glibc
RUN set -xe; \
    cd /usr/src/glib*; \
    mkdir build; cd build; \
    CFLAGS="-O3 -march=native" ../configure --disable-sanity-checks --enable-static-nss; \
    make -j $(nproc) && make install

# Build Zlib
RUN set -xe; \
    cd /usr/src/zlib*; \
    ./configure; \
    make -j $(nproc) && make install

# Build OpenSSL
RUN set -xe; \
    cd /usr/src/openssl*; \
    ./Configure no-shared linux-x86_64; \
    make -j $(nproc) && make install_sw

# Build Curl
RUN set -xe; \
    cd /usr/src/curl*; \
    ./configure; \
    make -j $(nproc) && make install

# Build gmp
RUN set -xe; \
    cd /usr/src/gmp*; \
    ./configure --with-pic; \
    make -j $(nproc) && make install

# Build Cpuminer
RUN set -xe; \
	export LDFLAGS="-static-libstdc++ -static-libgcc ${LDFLAGS}"; \
    cd /usr/src/cpu*; \
    sh autogen.sh; \
    ./configure --with-curl; \
    make -j $(nproc) && make install
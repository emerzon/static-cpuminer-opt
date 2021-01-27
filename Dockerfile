FROM clearlinux

ENV BUILD_PACKAGES="c-basic curl git diffutils python-basic"
ENV GLIBC_URL https://github.com/bminor/glibc
#ENV GLIBC_URL http://ftp.gnu.org/gnu/libc/glibc-2.32.tar.bz2
#ENV OPENSSL_URL https://www.openssl.org/source/openssl-1.1.1h.tar.gz
ENV OPENSSL_URL https://github.com/openssl/openssl
ENV GMP_URL https://gmplib.org/download/gmp/gmp-6.2.0.tar.bz2
#ENV CURL_URL https://curl.haxx.se/download/curl-7.73.0.tar.bz2
ENV CURL_URL https://github.com/curl/curl
ENV ZLIB_URL https://github.com/zlib-ng/zlib-ng/
ENV CPUMINER_URL https://github.com/JayDDee/cpuminer-opt
ENV LIBUV_URL https://github.com/libuv/libuv.git
ENV LIBHWLOC_URL https://github.com/open-mpi/hwloc
ENV XMRIG_URL https://github.com/xmrig/xmrig/
ENV XMRIGUPX_URL https://github.com/uPlexa/xmrig-upx.git

ENV AR "gcc-ar"
ENV RANLIB "gcc-ranlib"
ENV NM "gcc-nm"

RUN set -xe; \
    swupd bundle-add ${BUILD_PACKAGES};

RUN	set -xe; \
    mkdir -p /usr/src; \
	cd /usr/src; \
    for i in ${GMP_URL}; \
    do curl ${i} | tar xvj; \
    done; \
    for i in ${GLIBC_URL} ${ZLIB_URL} ${CPUMINER_URL} ${LIBUV_URL} ${LIBHWLOC_URL} ${XMRIG_URL} ${XMRIGUPX_URL} ${CURL_URL} ${OPENSSL_URL}; \
    do git clone --depth 1 ${i} & \
    done; wait

# Build Glibc
RUN set -xe; \
    cd /usr/src/glib*; \
    mkdir build; cd build; \
    CFLAGS="-O3 -march=native -mtune=native" \
    CXXFLAGS=$CFLAGS \
    CPPFLAGS="" \
    ../configure \
    --disable-silent-rules \
    --disable-dependency-tracking \
    --disable-profile \
    --disable-debug \
    --disable-timezone-tools \
    --disable-sanity-checks \
    --disable-nscd \
    --disable-build-nscd \
    --without-cvs \
    --without-gd  \
    --without-selinux \
    --enable-static-nss \
    --enable-kernel=5.4; \
    make -j $(nproc) && make install

ENV CFLAGS "-Ofast \
-pipe \
-march=native \
-mtune=native \
-fno-exceptions \
-fno-stack-protector \
-fgraphite-identity \
-ftree-loop-distribution \
-floop-nest-optimize \
-fipa-pta \
-ftree-vectorize \
-fno-semantic-interposition \
-fno-math-errno \
-Wl,-z,max-page-size=0x1000 \
-Wa,-mbranches-within-32B-boundaries"

ENV CXXFLAGS "${CFLAGS}"
ENV CPPFLAGS "-D_FORTIFY_SOURCE=0"
ENV LDFLAGS "-L/usr/local/lib -Wl,-O1 -Wl,-s"
ENV LTO_CFLAGS "-flto -fno-fat-lto-objects -fdevirtualize-at-ltrans -flto-compression-level=1"

# Build Zlib-NG
RUN set -xe; \
    cd /usr/src/zlib*; \
    CFLAGS="${CFLAGS} ${LTO_CFLAGS}" CXXFLAGS="${CXXFLAGS} ${LTO_CFLAGS}" \
    ./configure --native --zlib-compat --static || cat configure.log; \
    make -j $(nproc) && make install

# Build OpenSSL
RUN set -xe; \
    cd /usr/src/openssl*; \
    CFLAGS="${CFLAGS} ${LTO_CFLAGS}" CXXFLAGS="${CXXFLAGS} ${LTO_CFLAGS}" \
    ./Configure -DDSO_NONE no-dso no-shared no-err no-weak-ssl-ciphers no-srp no-dtls1 no-dtls no-idea linux-x86_64; \
    make -j $(nproc) && make install_sw

# Build Curl
RUN set -xe; \
    cd /usr/src/curl*; \
    CFLAGS="${CFLAGS} ${LTO_CFLAGS}" CXXFLAGS="${CXXFLAGS} ${LTO_CFLAGS}" \
    ./buildconf && ./configure --enable-shared=no; \
    make -j $(nproc) && make install

# Build gmp
RUN set -xe; \
    cd /usr/src/gmp*; \
    CFLAGS="${CFLAGS} ${LTO_CFLAGS}" CXXFLAGS="${CXXFLAGS} ${LTO_CFLAGS}" \
    ./configure --with-pic; \
    make -j $(nproc) && make install

# Build Cpuminer
RUN set -xe; \
	export LDFLAGS="--static ${LDFLAGS}"; \
    cd /usr/src/cpuminer-opt; \
    sh autogen.sh; \
    ./configure --with-curl; \
    make -j $(nproc) && make install

# Build LibUV
RUN set -xe; \
    cd /usr/src/libuv; \
    sh autogen.sh; \
    ./configure --enable-static=yes --enable-shared=no; \
    make -j $(nproc) && make install

# Build LibHWLOC
RUN set -xe; \
    cd /usr/src/hwloc; \
    sh autogen.sh; \
    CFLAGS="${CFLAGS} ${LTO_CFLAGS}" \
    ./configure --enable-static=yes --enable-shared=no; \
    make -j $(nproc) && make install

# Build Xmrig
RUN set -xe; \
    cd /usr/src/xmrig; \
    # Dirty; \
    cp /usr/local/lib/*.{a,la} /usr/lib64; \
    sed -Ei 's/^(.*DonateLevel = )(.*)$/\10;/g' src/donate.h; \
    mkdir build; cd build; \
    LDFLAGS="-fuse-ld=gold" \
    CFLAGS="${CFLAGS} -fpie -pthread" \
    CXXFLAGS="${CXXFLAGS} -fpie -pthread" \
    cmake .. -DBUILD_STATIC=ON; \
    make -j $(nproc);

# Build Xmrig-UPX
RUN set -xe; \
    cd /usr/src/xmrig-upx; \
    # Dirty; \
    sed -Ei 's/^(.*DonateLevel = )(.*)$/\10;/g' src/donate.h; \
    sed -i '36 a #include <string>' src/net/strategies/DonateStrategy.cpp; \
    mkdir build; cd build; \
    LDFLAGS="-fuse-ld=gold" \
    CFLAGS="${CFLAGS} -fpie -pthread" \
    CXXFLAGS="${CXXFLAGS} -fpie -pthread" \
    cmake .. -DBUILD_STATIC=ON -DWITH_HTTPD=OFF; \
    make -j $(nproc);

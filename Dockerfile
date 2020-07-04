FROM clearlinux

ENV BUILD_PACKAGES="c-basic curl git diffutils python-basic"
ENV GLIBC_URL https://github.com/bminor/glibc
ENV OPENSSL_URL https://www.openssl.org/source/openssl-1.1.1g.tar.gz
ENV GMP_URL https://gmplib.org/download/gmp/gmp-6.2.0.tar.bz2
ENV CURL_URL https://curl.haxx.se/download/curl-7.70.0.tar.bz2
ENV ZLIB_URL https://www.zlib.net/zlib-1.2.11.tar.gz
ENV CPUMINER_URL https://github.com/JayDDee/cpuminer-opt
ENV LIBUV_URL https://github.com/libuv/libuv.git
ENV LIBHWLOC_URL https://github.com/open-mpi/hwloc
ENV XMRIG_URL https://github.com/xmrig/xmrig/

ENV AR "gcc-ar"
ENV RANLIB "gcc-ranlib"
ENV NM "gcc-nm"

RUN set -xe; \
    swupd bundle-add ${BUILD_PACKAGES};

RUN	set -xe; \
    mkdir -p /usr/src; \
	cd /usr/src; \
    for i in ${OPENSSL_URL} ${ZLIB_URL}; \
    do curl ${i} | tar xvz; \
    done; \
    for i in ${GMP_URL} ${CURL_URL}; \
    do curl ${i} | tar xvj; \
    done; \
    for i in ${GLIBC_URL} ${CPUMINER_URL} ${LIBUV_URL} ${LIBHWLOC_URL} ${XMRIG_URL}; \
    do git clone --depth 1 ${i}; \
    done

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
-falign-functions=32 \
-falign-jumps=32 \
-falign-loops=32 \
-flimit-function-alignment \
-fira-hoist-pressure \
-fira-loop-pressure \
-fbranch-target-load-optimize2 \
-fweb \
-fno-plt \
-fgraphite-identity \
-floop-nest-optimize \
-fsched2-use-superblocks \
-fipa-pta \
-fno-semantic-interposition \
-fno-math-errno \
-fno-trapping-math \
-ffast-math \
-fno-exceptions \
-fno-stack-protector \
-fpie \
-Wl,-z,max-page-size=0x1000 \
-Wa,-mbranches-within-32B-boundaries"

ENV CXXFLAGS "${CFLAGS}"
ENV CPPFLAGS "-D_FORTIFY_SOURCE=0"
ENV LDFLAGS "-L/usr/local/lib"
ENV LTO_CFLAGS "-flto -fno-fat-lto-objects -fdevirtualize-at-ltrans"

# Build Zlib
RUN set -xe; \
    cd /usr/src/zlib*; \
    CFLAGS="${CFLAGS} ${LTO_CFLAGS}" CXXFLAGS="${CXXFLAGS} ${LTO_CFLAGS}" \
    ./configure || cat configure.log; \
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
	export LDFLAGS="--static -static-libstdc++ -static-libgcc ${LDFLAGS}"; \
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
    cd /usr/src/xmrig*; \
    # Dirty; \
    cp /usr/local/lib/*.{a,la} /usr/lib64; \
    sed -Ei 's/^(.*DonateLevel = )(.*)$/\10;/g' src/donate.h; \
    mkdir build; cd build; \
    LDFLAGS="-fuse-ld=gold" \
    CFLAGS="${CFLAGS} -fpie -pthread" \
    CXXFLAGS="${CXXFLAGS} -fpie -pthread" \
    cmake .. -DBUILD_STATIC=ON; \
    make -j $(nproc);
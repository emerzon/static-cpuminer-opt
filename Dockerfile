FROM clearlinux

ENV BUILD_PACKAGES="c-basic curl git diffutils python-basic" \
    AR="gcc-ar" \
    RANLIB="gcc-ranlib" \
    NM="gcc-nm" \
    GITHUB_REPOS="\
bminor/glibc:release/2.33/master \
openssl/openssl:OpenSSL_1_1_1-stable \
curl/curl:master \
zlib-ng/zlib-ng:develop \
JayDDee/cpuminer-opt:master \
npq7721/cpuminer-gr:master \
libuv/libuv:master \
open-mpi/hwloc:master \
xmrig/xmrig:master \
uPlexa/xmrig-upx:master" \
    DOWNLOAD_URLS="https://gmplib.org/download/gmp/gmp-6.2.1.tar.bz2"

RUN set -xe; \
    swupd bundle-add ${BUILD_PACKAGES};

RUN	set -xe; \
    mkdir -p /usr/src; \
	cd /usr/src; \
    for i in ${DOWNLOAD_URLS}; \
        do curl ${i} | tar xvj & \
    done; \
    for i in ${GITHUB_REPOS}; \
        do git clone --depth 1 -b ${i#*:} https://github.com/${i%:*} & \
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
    --enable-kernel=5.4 \
    --enable-memory-tagging; \
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
-falign-functions=32 \
-Wa,-mbranches-within-32B-boundaries"

ENV CXXFLAGS="${CFLAGS}" \
    CPPFLAGS="-D_FORTIFY_SOURCE=0" \
    LDFLAGS="-L/usr/local/lib -Wl,-O1 -Wl,-z,max-page-size=0x1000 " \
    LTO_CFLAGS="-flto -fno-fat-lto-objects -fdevirtualize-at-ltrans -flto-compression-level=1"

# Build Zlib-NG
RUN set -xe; \
    cd /usr/src/zlib*; \
    CFLAGS="${CFLAGS} ${LTO_CFLAGS}" CXXFLAGS="${CXXFLAGS} ${LTO_CFLAGS}" \
    ./configure --native --zlib-compat --static || cat configure.log; \
    make -j$(nproc) && make install

# Build OpenSSL
RUN set -xe; \
    cd /usr/src/openssl*; \
    CFLAGS="${CFLAGS} ${LTO_CFLAGS}" CXXFLAGS="${CXXFLAGS} ${LTO_CFLAGS}" \
    ./Configure -DDSO_NONE no-dso no-shared no-err no-weak-ssl-ciphers no-srp no-dtls1 no-dtls no-idea linux-x86_64; \
    make -j$(nproc) && make install_sw

# Build Curl
RUN set -xe; \
    cd /usr/src/curl*; \
    CFLAGS="${CFLAGS} ${LTO_CFLAGS}" CXXFLAGS="${CXXFLAGS} ${LTO_CFLAGS}" \
    autoreconf -vi && ./configure --enable-shared=no --with-openssl=/usr/local; \
    make -j$(nproc) && make install

# Build gmp
RUN set -xe; \
    cd /usr/src/gmp*; \
    CFLAGS="${CFLAGS} ${LTO_CFLAGS}" CXXFLAGS="${CXXFLAGS} ${LTO_CFLAGS}" \
    ./configure --with-pic; \
    make -j$(nproc) && make install

# Build Cpuminer
RUN set -xe; \
    export LDFLAGS="--static ${LDFLAGS}"; \
    cd /usr/src/cpuminer-opt; \
    sh autogen.sh; autoupdate; \
    ./configure --with-curl || cat config.log; \
    make -j$(nproc) && make install

# Build Cpuminer-GR
RUN set -xe; \
    export LDFLAGS="--static ${LDFLAGS}"; \
    cd /usr/src/cpuminer-gr; \
    sh autogen.sh; \
    CFLAGS="${CFLAGS} -fcommon" ./configure --with-curl; \
    make -j$(nproc) && make install

# Build LibUV
RUN set -xe; \
    cd /usr/src/libuv; \
    sh autogen.sh; \
    ./configure --enable-static=yes --enable-shared=no; \
    make -j$(nproc) && make install

# Build LibHWLOC
RUN set -xe; \
    cd /usr/src/hwloc; \
    sh autogen.sh; \
    CFLAGS="${CFLAGS} ${LTO_CFLAGS}" \
    ./configure --enable-static=yes --enable-shared=no; \
    make -j$(nproc) && make install

# Build Xmrig
RUN set -xe; \
    cd /usr/src/xmrig; \
    # Dirty; \
    cp /usr/local/lib/*.{a,la} /usr/lib64; \
    sed -Ei 's/^(.*DonateLevel = )(.*)$/\10;/g' src/donate.h; \
    mkdir build; cd build; \
    CFLAGS="${CFLAGS} -fpie -pthread" \
    CXXFLAGS="${CXXFLAGS} -fpie -pthread" \
    cmake .. -DBUILD_STATIC=ON; \
    make -j$(nproc);

# Build Xmrig-UPX
RUN set -xe; \
    cd /usr/src/xmrig-upx; \
    # Dirty; \
    sed -Ei 's/^(.*DonateLevel = )(.*)$/\10;/g' src/donate.h; \
    sed -i '36 a #include <string>' src/net/strategies/DonateStrategy.cpp; \
    mkdir build; cd build; \
    CFLAGS="${CFLAGS} -fpie -pthread" \
    CXXFLAGS="${CXXFLAGS} -fpie -pthread" \
    cmake .. -DBUILD_STATIC=ON -DWITH_HTTPD=OFF; \
    make -j$(nproc);

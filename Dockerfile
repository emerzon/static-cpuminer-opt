FROM clearlinux

ENV BUILD_PACKAGES="c-basic curl git diffutils python-basic"

ENV GLIBC_URL https://ftp.gnu.org/gnu/glibc/glibc-2.31.tar.bz2
ENV OPENSSL_URL https://www.openssl.org/source/openssl-1.1.1d.tar.gz
ENV GMP_URL https://gmplib.org/download/gmp/gmp-6.2.0.tar.bz2
ENV CURL_URL https://curl.haxx.se/download/curl-7.66.0.tar.bz2
ENV ZLIB_URL https://www.zlib.net/zlib-1.2.11.tar.gz
ENV CPUMINER_URL https://github.com/JayDDee/cpuminer-opt
ENV CPUMINER_RKZ_URL https://github.com/RickillerZ/cpuminer-RKZ
ENV LIBUV_URL https://github.com/libuv/libuv.git
ENV LIBHWLOC_URL https://github.com/open-mpi/hwloc
ENV XMRIG_URL https://github.com/xmrig/xmrig/

RUN set -xe; \
    swupd bundle-add ${BUILD_PACKAGES};

RUN	set -xe; \
    mkdir -p /usr/src; \
	cd /usr/src; \
    for i in ${OPENSSL_URL} ${ZLIB_URL}; \
    do curl ${i} | tar xvz; \
    done; \
    for i in ${GLIBC_URL} ${GMP_URL} ${CURL_URL}; \
    do curl ${i} | tar xvj; \
    done; \
    for i in ${CPUMINER_URL} ${CPUMINER_RKZ_URL} ${LIBUV_URL} ${LIBHWLOC_URL} ${XMRIG_URL}; \
    do git clone $i; \
    done

ENV CFLAGS "-Ofast -march=native -mtune=native \
-ffast-math -fno-semantic-interposition -fno-trapping-math -fno-exceptions \
-ftree-vectorize \
-fno-stack-protector -fpie \
-Wl,-z,max-page-size=0x1000 \
-falign-functions=32 -Wa,-mbranches-within-32B-boundaries"

ENV CXXFLAGS "${CFLAGS}"
ENV CPPFLAGS "-D_FORTIFY_SOURCE=0"
ENV LDFLAGS "-L/usr/local/lib"

# Build Glibc
RUN set -xe; \
    cd /usr/src/glib*; \
    mkdir build; cd build; \
    CFLAGS="-O3 -march=native" CXXFLAGS=$CFLAGS CPPFLAGS="" ../configure \
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
    --enable-kernel="$(uname -r | cut -f 1-2 -d \.)"; \
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
    ./buildconf && ./configure --enable-shared=no; \
    make -j $(nproc) && make install

# Build gmp
RUN set -xe; \
    cd /usr/src/gmp*; \
    ./configure --with-pic; \
    make -j $(nproc) && make install

# Build Cpuminer
RUN set -xe; \
	export LDFLAGS="--static -static-libstdc++ -static-libgcc ${LDFLAGS}"; \
    cd /usr/src/cpuminer-opt; \
    sh autogen.sh; \
    ./configure --with-curl; \
    make -j $(nproc) && make install

# Build Cpuminer-RKZ
RUN set -xe; \
	export LDFLAGS="--static -static-libstdc++ -static-libgcc ${LDFLAGS}"; \
    cd /usr/src/cpuminer-RKZ*; \
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
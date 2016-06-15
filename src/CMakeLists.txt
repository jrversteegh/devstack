cmake_minimum_required(VERSION 2.8)

# Author: Jaap Versteegh <j.r.versteegh@gmail.com>

# Create external projects for contributions
include(ExternalProject)
include(CheckIncludeFiles)
include(CheckCSourceCompiles)

set(PRE_FLAGS --prefix=${CMAKE_INSTALL_PREFIX})
set(GO_FLAGS ${PRE_FLAGS} --disable-gtk-doc-html --disable-man)
set(GNU_MIRROR http://mirror.inode.at/gnu/)
set(BOOST_CFLAGS -I${CMAKE_INSTALL_PREFIX}/include)
set(BOOST_CXXFLAGS -I${CMAKE_INSTALL_PREFIX}/include)
set(BOOST_LDFLAGS -L${CMAKE_INSTALL_PREFIX}/lib)
set(CMAKE_COMPILERS -D CMAKE_C_COMPILER=gcc -D CMAKE_CXX_COMPILER=g++)

check_include_files(CL/opencl.h HAVE_OPENCL_INC)
check_include_files(GL/gl.h HAVE_OPENGL_INC)
check_include_files(GLES2/gl2.h HAVE_GLES2_INC)
check_c_source_compiles(
"
#include <X11/Xlib.h>
#include <X11/extensions/XShm.h>
#include <X11/extensions/XInput2.h>
#include <X11/extensions/Xrandr.h>
int main() { return 0;}
" 
HAVE_X_INC
)

if (HAVE_OPENGL_INC) 
  set(CMAKE_REQUIRED_LIBRARIES -lGL)
  check_c_source_compiles("#include <GL/gl.h>
  int main() { return 0; }
  " 
  HAVE_OPENGL_LIB
  )
endif()

if(HAVE_OPENGL_INC) 
  if(NOT HAVE_OPENGL_LIB) 
    message(FATAL_ERROR "Have OpenGL headers, but can't use -lGL")
  endif()
endif()

# Handle having X headers or not
if(NOT HAVE_X_INC)
  message(FATAL_ERROR "X11 header files are required")
endif()

# Have opencl for gdal ?
if(HAVE_OPENCL_INC)
  message( "OpenCL headers found. Enabling for libgdal")
  set(OPENCL_FLAGS --with-opencl)
else()
  message( "No OpenCL headers found.")
  set(OPENCL_FLAGS "")
endif()

# OpenGL (ES) headers for cairo and qt
if(HAVE_GLES2_INC)
  set(CAIRO_GL_FLAGS --enable-glesv2=yes)
  set(QT_GL_FLAGS -opengl es2)
elseif(HAVE_OPENGL_INC)
  set(CAIRO_GL_FLAGS --enable-gl=yes)
  set(QT_GL_FLAGS -opengl desktop)
else()
  set(CAIRO_GL_FLAGS "")
  set(QT_GL_FLAGS "")
endif()

# First build gcc 
ExternalProject_Add(
  gmp
  SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/gmp
  BUILD_IN_SOURCE 1
  CONFIGURE_COMMAND ./configure ${PRE_FLAGS}
)

ExternalProject_Add(
  mpfr
  DEPENDS gmp
  SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/mpfr
  BUILD_IN_SOURCE 1
  CONFIGURE_COMMAND ./configure ${PRE_FLAGS}
)

ExternalProject_Add(
  mpc
  DEPENDS mpfr
  SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/mpc
  BUILD_IN_SOURCE 1
  CONFIGURE_COMMAND ./configure ${PRE_FLAGS}
)

ExternalProject_Add(
  gcc
  DEPENDS mpc
  SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/gcc
  BUILD_IN_SOURCE 1
  CONFIGURE_COMMAND ./configure ${PRE_FLAGS} --disable-multilib --enable-ld --enable-gold --enable-lto
)

ExternalProject_Add_Step(
  gcc
  after_install
  DEPENDEES install
  COMMAND cd ${CMAKE_INSTALL_PREFIX}/bin && ln -sf gcc cc
)

ExternalProject_Add(
  perl
  DEPENDS gcc
  SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/perl
  BUILD_IN_SOURCE 1
  CONFIGURE_COMMAND ./Configure -des -Dprefix=${CMAKE_INSTALL_PREFIX}
)

ExternalProject_Add(
  texinfo
  DEPENDS perl
  SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/texinfo
  BUILD_IN_SOURCE 1
  CONFIGURE_COMMAND ./configure ${PRE_FLAGS}
)

ExternalProject_Add(
  gdb
  DEPENDS texinfo
  SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/gdb
  BUILD_IN_SOURCE 1
  CONFIGURE_COMMAND ./configure ${PRE_FLAGS}
)

# Then autotools

ExternalProject_Add(
  autoconf
  DEPENDS gdb
  SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/autoconf
  BUILD_IN_SOURCE 1
  CONFIGURE_COMMAND ./configure ${PRE_FLAGS}
)

ExternalProject_Add(
  automake
  DEPENDS autoconf
  SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/automake
  BUILD_IN_SOURCE 1
  CONFIGURE_COMMAND ./configure ${PRE_FLAGS}
)

ExternalProject_Add(
  libtool
  DEPENDS automake
  SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/libtool
  BUILD_IN_SOURCE 1
  CONFIGURE_COMMAND ./configure ${PRE_FLAGS}
)

ExternalProject_Add(
  libunistring
  DEPENDS libtool
  SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/libunistring
  BUILD_IN_SOURCE 1
  CONFIGURE_COMMAND ./configure ${PRE_FLAGS}
)

ExternalProject_Add(
  libatomic_ops
  DEPENDS libtool
  SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/libatomic_ops
  BUILD_IN_SOURCE 1
  CONFIGURE_COMMAND ./configure ${PRE_FLAGS}
)

ExternalProject_Add(
  gc
  DEPENDS libatomic_ops libunistring
  SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/gc
  BUILD_IN_SOURCE 1
  CONFIGURE_COMMAND ./configure ${PRE_FLAGS}
)


# Some libraries first that don't depend on anything else

ExternalProject_Add(
  zlib
  DEPENDS gc
  SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/zlib
  BUILD_IN_SOURCE 1
  CONFIGURE_COMMAND ./configure ${PRE_FLAGS}
)

ExternalProject_Add(
  openssl
  DEPENDS zlib
  SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/openssl
  BUILD_IN_SOURCE 1
  CMAKE_COMMAND = ""
  CONFIGURE_COMMAND ${CMAKE_CURRENT_SOURCE_DIR}/openssl/config ${PRE_FLAGS} threads zlib-dynamic shared --libdir=lib
  BUILD_COMMAND make depend && make
  # Allow some sleep after install, so installed libraries won't be picked up too soon.
  INSTALL_COMMAND $(MAKE) install && sleep 2 && sync && sleep 2 && echo "*** Installed openssl"
)

ExternalProject_Add(
  libffi
  DEPENDS openssl
  SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/libffi
  CONFIGURE_COMMAND ${CMAKE_CURRENT_SOURCE_DIR}/libffi/configure ${PRE_FLAGS} 
)

ExternalProject_Add(
  bzip2
  DEPENDS libffi
  SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/bzip2
  BUILD_IN_SOURCE 1
  # Arcane build procedure for bzip2...
  CONFIGURE_COMMAND ""
  BUILD_COMMAND $(MAKE) && $(MAKE) -f Makefile-libbz2_so
  INSTALL_COMMAND $(MAKE) PREFIX=${CMAKE_INSTALL_PREFIX} install
)

ExternalProject_Add(
  pcre
  DEPENDS libffi
  SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/pcre
  CONFIGURE_COMMAND ${CMAKE_CURRENT_SOURCE_DIR}/pcre/configure ${PRE_FLAGS} --enable-unicode-properties --enable-jit --enable-pcre16 --enable-pcre32
)

ExternalProject_Add(
  guile
  DEPENDS gc libffi
  SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/guile
  BUILD_IN_SOURCE 1
  CONFIGURE_COMMAND ./configure ${PRE_FLAGS}
)

ExternalProject_Add(
  autogen
  DEPENDS guile
  SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/autogen
  BUILD_IN_SOURCE 1
  CONFIGURE_COMMAND ./configure ${PRE_FLAGS}
)

ExternalProject_Add(
  expat
  DEPENDS libffi
  SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/expat
  CONFIGURE_COMMAND ${CMAKE_CURRENT_SOURCE_DIR}/expat/configure ${PRE_FLAGS}
)

ExternalProject_Add(
  libpng
  DEPENDS libffi
  SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/libpng
  CONFIGURE_COMMAND ${CMAKE_CURRENT_SOURCE_DIR}/libpng/configure ${PRE_FLAGS} 
  BUILD_COMMAND $(MAKE) INCLUDES=-I${CMAKE_INSTALL_PREFIX}/include
)

ExternalProject_Add(
  jpeg
  DEPENDS libffi
  SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/jpeg
  BUILD_IN_SOURCE 1
  CONFIGURE_COMMAND ./configure ${PRE_FLAGS} --enable-shared
)

ExternalProject_Add(
  json-c
  DEPENDS libffi
  SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/json-c
  CONFIGURE_COMMAND ${CMAKE_CURRENT_SOURCE_DIR}/json-c/configure ${PRE_FLAGS} 
)

ExternalProject_Add(
  icu
  DEPENDS libffi
  SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/icu/source
  CONFIGURE_COMMAND ${CMAKE_CURRENT_SOURCE_DIR}/icu/source/configure ${PRE_FLAGS} 
)

ExternalProject_Add(
  fam
  DEPENDS libffi
  SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/fam
  BUILD_IN_SOURCE 1
  CONFIGURE_COMMAND ./configure ${PRE_FLAGS}
  BUILD_COMMAND ${MAKE}
  INSTALL_COMMAND $(MAKE) install install-data
)


ExternalProject_Add(
  OpenBLAS
  DEPENDS libffi
  SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/OpenBLAS
  BUILD_IN_SOURCE 1
  CONFIGURE_COMMAND ""
  INSTALL_COMMAND $(MAKE) PREFIX=${CMAKE_INSTALL_PREFIX} install 
)

ExternalProject_Add_Step(
  OpenBLAS
  after_install
  DEPENDEES install
  COMMAND cd ${CMAKE_INSTALL_PREFIX}/lib && ln -sf libopenblas.so libblas.so && ln -sf libopenblas.so liblapack.so && ln -sf libopenblas.so libatlas.so
)

# The python interpreter. Get that up soon
ExternalProject_Add(
  Python
  DEPENDS libffi 
  SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/Python
  CONFIGURE_COMMAND ${CMAKE_CURRENT_SOURCE_DIR}/Python/configure ${PRE_FLAGS} --enable-shared --with-ensurepip
)

ExternalProject_Add_Step(
  Python
  after_install
  DEPENDEES install
  COMMAND cd ${CMAKE_INSTALL_PREFIX}/bin && ln -sf python3 python && ln -sf python3-config python-config && ln -sf pip3 pip
)

ExternalProject_Add(
  xz
  DEPENDS Python
  SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/xz
  CONFIGURE_COMMAND ${CMAKE_CURRENT_SOURCE_DIR}/xz/configure ${PRE_FLAGS}
)

ExternalProject_Add(
  tiff
  DEPENDS xz
  SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/tiff
  CONFIGURE_COMMAND ${CMAKE_CURRENT_SOURCE_DIR}/tiff/configure ${PRE_FLAGS}
)

ExternalProject_Add(
  libxml2
  DEPENDS xz icu
  SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/libxml2
  CONFIGURE_COMMAND ${CMAKE_CURRENT_SOURCE_DIR}/libxml2/configure ${PRE_FLAGS} --with-python=${CMAKE_INSTALL_PREFIX} --with-icu --with-xpath LDFLAGS=$(LDFLAGS)
  INSTALL_COMMAND $(MAKE) install
)

ExternalProject_Add(
  libxslt
  DEPENDS libxml2
  SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/libxslt
  CONFIGURE_COMMAND ${CMAKE_CURRENT_SOURCE_DIR}/libxslt/configure ${PRE_FLAGS}
  INSTALL_COMMAND $(MAKE) install 
)

ExternalProject_Add(
  openmpi
  DEPENDS Python
  SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/openmpi
  # Disable vt because of compile error in combination with cuda
  CONFIGURE_COMMAND ${CMAKE_CURRENT_SOURCE_DIR}/openmpi/configure ${PRE_FLAGS} --enable-cxx-exceptions --disable-vt
)

ExternalProject_Add(
  boost
  DEPENDS openmpi
  SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/boost
  BUILD_IN_SOURCE 1
  CONFIGURE_COMMAND ./bootstrap.sh ${PRE_FLAGS} --with-icu=${CMAKE_INSTALL_PREFIX}
  # Force boost to link to the right libbstdc++ etc
  BUILD_COMMAND ./b2 -q stage variant=release link=shared runtime-link=shared threading=multi cxxflags=${BOOST_CXXFLAGS} cflags=${BOOST_CFLAGS} linkflags=${BOOST_LDFLAGS}
  INSTALL_COMMAND ./b2 -q install variant=release link=shared runtime-link=shared threading=multi cxxflags=${BOOST_CXXFLAGS} cflags=${BOOST_CFLAGS} linkflags=${BOOST_LDFLAGS}
)

ExternalProject_Add(
  libarchive
  DEPENDS libxml2
  SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/libarchive
  CONFIGURE_COMMAND ${CMAKE_CURRENT_SOURCE_DIR}/libarchive/configure ${PRE_FLAGS}
)

ExternalProject_Add(
  curl
  DEPENDS libarchive
  SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/curl
  CONFIGURE_COMMAND ${CMAKE_CURRENT_SOURCE_DIR}/curl/configure ${PRE_FLAGS} --enable-http --enable-ftp --enable-file --with-ssl=${CMAKE_INSTALL_PREFIX}
)


ExternalProject_Add(
  bison
  DEPENDS Python
  SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/bison
  CONFIGURE_COMMAND ${CMAKE_CURRENT_SOURCE_DIR}/bison/configure ${PRE_FLAGS}
)

ExternalProject_Add(
  flex
  DEPENDS bison
  SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/flex
  CONFIGURE_COMMAND ${CMAKE_CURRENT_SOURCE_DIR}/flex/configure ${PRE_FLAGS}
)


ExternalProject_Add(
  swig
  DEPENDS Python pcre
  SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/swig
  CONFIGURE_COMMAND ${CMAKE_CURRENT_SOURCE_DIR}/swig/configure ${PRE_FLAGS} --with-python=${CMAKE_INSTALL_PREFIX}/bin/python
)

ExternalProject_Add(
  cppunit
  DEPENDS Python
  SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/cppunit
  CONFIGURE_COMMAND ${CMAKE_CURRENT_SOURCE_DIR}/cppunit/configure ${PRE_FLAGS} 
)

ExternalProject_Add(
  pixman
  DEPENDS libpng
  SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/pixman
  CONFIGURE_COMMAND ${CMAKE_CURRENT_SOURCE_DIR}/pixman/configure ${PRE_FLAGS} 
)

ExternalProject_Add(
  gettext
  DEPENDS libxml2 bzip2
  SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/gettext
  CONFIGURE_COMMAND ${CMAKE_CURRENT_SOURCE_DIR}/gettext/configure ${PRE_FLAGS} 
)

ExternalProject_Add(
  glib
  DEPENDS Python fam libxslt pcre gettext
  SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/glib
  CONFIGURE_COMMAND ${CMAKE_CURRENT_SOURCE_DIR}/glib/configure ${GO_FLAGS} --disable-selinux --with-pcre=system 
)

ExternalProject_Add(
  gobject-introspection
  DEPENDS glib 
  SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/gobject-introspection
  CONFIGURE_COMMAND ${CMAKE_CURRENT_SOURCE_DIR}/gobject-introspection/configure ${GO_FLAGS} PYTHON=${CMAKE_INSTALL_PREFIX}/bin/python
)

ExternalProject_Add(
  freetype
  DEPENDS gobject-introspection libxml2 libpng tiff
  SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/freetype
  CONFIGURE_COMMAND ${CMAKE_CURRENT_SOURCE_DIR}/freetype/configure ${PRE_FLAGS}
)

ExternalProject_Add(
  harfbuzz
  DEPENDS freetype
  SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/harfbuzz
  CONFIGURE_COMMAND ${CMAKE_CURRENT_SOURCE_DIR}/harfbuzz/configure ${PRE_FLAGS} --with-gobject
)

ExternalProject_Add(
  freetype2
  DEPENDS harfbuzz
  SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/freetype
  CONFIGURE_COMMAND ${CMAKE_CURRENT_SOURCE_DIR}/freetype/configure ${PRE_FLAGS}
)


ExternalProject_Add(
  fontconfig
  DEPENDS freetype2
  SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/fontconfig
  CONFIGURE_COMMAND ${CMAKE_CURRENT_SOURCE_DIR}/fontconfig/configure ${PRE_FLAGS} --enable-libxml2 --disable-docs
)

ExternalProject_Add(
  cairo
  DEPENDS pixman gobject-introspection fontconfig
  SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/cairo
  CONFIGURE_COMMAND ${CMAKE_CURRENT_SOURCE_DIR}/cairo/configure ${PRE_FLAGS} --enable-ft=yes --enable-fc=yes ${CAIRO_GL_FLAGS} --disable-static
)

ExternalProject_Add(
  atk
  DEPENDS gobject-introspection
  SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/atk
  CONFIGURE_COMMAND ${CMAKE_CURRENT_SOURCE_DIR}/atk/configure ${GO_FLAGS}
)

ExternalProject_Add(
  pango
  DEPENDS cairo 
  SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/pango
  CONFIGURE_COMMAND ${CMAKE_CURRENT_SOURCE_DIR}/pango/configure ${GO_FLAGS}
)

ExternalProject_Add(
  gdk-pixbuf 
  DEPENDS gobject-introspection libpng jpeg tiff
  SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/gdk-pixbuf
  # Problems building out of source
  BUILD_IN_SOURCE 1
  CONFIGURE_COMMAND ./configure ${GO_FLAGS} BASE_DEPENDENCIES_CFLAGS=$(CFLAGS)
)

ExternalProject_Add(
  gtk+
  DEPENDS gobject-introspection cairo pango atk gdk-pixbuf
  SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/gtk+
  CONFIGURE_COMMAND ${CMAKE_CURRENT_SOURCE_DIR}/gtk+/configure ${GO_FLAGS} --without-atk-bridge
)

ExternalProject_Add(
  python_modules
  DEPENDS Python gtk+
  SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/python_modules
  BUILD_IN_SOURCE 1
  CONFIGURE_COMMAND ""
  CMAKE_COMMAND ""
  BUILD_COMMAND ""
  INSTALL_COMMAND ./install.sh
)

ExternalProject_Add(
  pycairo
  DEPENDS Python cairo
  SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/pycairo
  BUILD_IN_SOURCE 1
  CONFIGURE_COMMAND ./waf configure ${PRE_FLAGS}
  BUILD_COMMAND ./waf build
  INSTALL_COMMAND ./waf install
)

ExternalProject_Add(
  pygobject
  DEPENDS gtk+ pycairo
  SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/pygobject
  CONFIGURE_COMMAND ${CMAKE_CURRENT_SOURCE_DIR}/pygobject/configure ${PRE_FLAGS}
)

ExternalProject_Add(
  Boost.NumPy 
  DEPENDS boost  python_modules
  SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/Boost.NumPy
  BUILD_IN_SOURCE 1
  CMAKE_ARGS -D BOOST_ROOT=${CMAKE_INSTALL_PREFIX} -D PYTHON_EXECUTABLE=${CMAKE_INSTALL_PREFIX}/bin/python -D CMAKE_INSTALL_PREFIX=${CMAKE_INSTALL_PREFIX} ${CMAKE_COMPILERS} .
)

ExternalProject_Add(
  cmake
  # Just make sure it gets built last
  DEPENDS Boost.Numpy
  SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/cmake
  CONFIGURE_COMMAND ${CMAKE_CURRENT_SOURCE_DIR}/cmake/configure ${PRE_FLAGS}
)


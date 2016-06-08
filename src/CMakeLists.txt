cmake_minimum_required(VERSION 2.8)

# Use gnu compilers found on the path
execute_process(COMMAND which gcc OUTPUT_VARIABLE CMAKE_C_COMPILER)
execute_process(COMMAND which g++ OUTPUT_VARIABLE CMAKE_CXX_COMPILER)
string(STRIP ${CMAKE_C_COMPILER} CMAKE_C_COMPILER)
string(STRIP ${CMAKE_CXX_COMPILER} CMAKE_CXX_COMPILER)

# Create external projects for contributions
include(ExternalProject)
include(CheckIncludeFiles)
include(CheckCSourceCompiles)

set(PRE_FLAGS --prefix=${CMAKE_INSTALL_PREFIX})
set(GO_FLAGS ${PRE_FLAGS} --disable-gtk-doc-html --disable-man)
set(GNU_MIRROR http://mirror.inode.at/gnu/)

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
  CONFIGURE_COMMAND ./configure ${PRE_FLAGS} --disable-multilib
)


# Then autotools

ExternalProject_Add(
  autoconf
  DEPENDS gcc
  SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/autoconf
  BUILD_IN_SOURCE 1
  CONFIGURE_COMMAND ./configure ${PRE_FLAGS}
)

ExternalProject_Add(
  automake
  DEPENDS gcc
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
  DEPENDS libatomic_ops
  SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/gc
  BUILD_IN_SOURCE 1
  CONFIGURE_COMMAND ./configure ${PRE_FLAGS}
)

ExternalProject_Add(
  guile
  DEPENDS libtool libunistring gc
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

# Some libraries first that don't depend on anything else

ExternalProject_Add(
  zlib
  DEPENDS autogen
  SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/zlib
  BUILD_IN_SOURCE 1
  CONFIGURE_COMMAND ./configure ${PRE_FLAGS}
)

ExternalProject_Add(
  bzip2
  DEPENDS autogen
  SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/bzip2
  BUILD_IN_SOURCE 1
  # Arcane build procedure for bzip2...
  CONFIGURE_COMMAND ""
  BUILD_COMMAND $(MAKE) && $(MAKE) -f Makefile-libbz2_so
  INSTALL_COMMAND $(MAKE) PREFIX=${CMAKE_INSTALL_PREFIX} install
)

ExternalProject_Add(
  pcre
  DEPENDS autogen
  SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/pcre
  CONFIGURE_COMMAND ${CMAKE_CURRENT_SOURCE_DIR}/pcre/configure ${PRE_FLAGS} --enable-unicode-properties --enable-jit --enable-pcre16 --enable-pcre32
)

ExternalProject_Add(
  libffi
  DEPENDS autogen
  SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/libffi
  CONFIGURE_COMMAND ${CMAKE_CURRENT_SOURCE_DIR}/libffi/configure ${PRE_FLAGS} 
)

ExternalProject_Add(
  expat
  DEPENDS autogen
  SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/expat
  CONFIGURE_COMMAND ${CMAKE_CURRENT_SOURCE_DIR}/expat/configure ${PRE_FLAGS}
)

ExternalProject_Add(
  libpng
  DEPENDS zlib
  SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/libpng
  CONFIGURE_COMMAND ${CMAKE_CURRENT_SOURCE_DIR}/libpng/configure ${PRE_FLAGS} 
  BUILD_COMMAND $(MAKE) INCLUDES=-I${CMAKE_INSTALL_PREFIX}/include
)

if(0)
ExternalProject_Add(
  json-c
  DEPENDS autogen
  SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/json-c
  CONFIGURE_COMMAND ${CMAKE_CURRENT_SOURCE_DIR}/json-c/configure ${PRE_FLAGS} 
)

ExternalProject_Add(
  icu
  DEPENDS autogen
  SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/icu/source
  BINARY_DIR ${CMAKE_BINARY_DIR}/icu/.build
  CMAKE_COMMAND ""
  CONFIGURE_COMMAND ${CMAKE_CURRENT_SOURCE_DIR}/icu/source/configure ${PRE_FLAGS} 
)

ExternalProject_Add(
  libfam
  DEPENDS autogen
  SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/fam
  BUILD_IN_SOURCE 1
  CMAKE_COMMAND ""
  CONFIGURE_COMMAND ${CMAKE_CURRENT_SOURCE_DIR}/fam/configure ${PRE_FLAGS}
  INSTALL_COMMAND $(MAKE) install install-data
)

ExternalProject_Add(
  openssl
  DEPENDS zlib
  PREFIX ${CMAKE_BINARY_DIR}/openssl/.prefix
  SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/openssl
  BUILD_IN_SOURCE 1
  CMAKE_COMMAND ""
  CONFIGURE_COMMAND ${CMAKE_CURRENT_SOURCE_DIR}/openssl/config ${PRE_FLAGS} threads zlib-dynamic shared --libdir=lib
  BUILD_COMMAND make
)

ExternalProject_Add(
  openblas
  SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/OpenBLAS
  BUILD_IN_SOURCE 1
  CMAKE_COMMAND ""
  CONFIGURE_COMMAND ""
  INSTALL_COMMAND $(MAKE) install PREFIX=${CMAKE_INSTALL_PREFIX}
)

ExternalProject_Add_Step(
  openblas
  after_install
  DEPENDEES install
  COMMAND cd ${CMAKE_INSTALL_PREFIX}/lib && ln -sf libopenblas.so libblas.so && ln -sf libopenblas.so liblapack.so && ln -sf libopenblas.so libatlas.so
)

# The python interpreter. Get that up soon
ExternalProject_Add(
  Python
  DEPENDS libffi openssl
  PREFIX ${CMAKE_BINARY_DIR}/Python/.prefix
  SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/Python
  BINARY_DIR ${CMAKE_BINARY_DIR}/Python/.build
  CMAKE_COMMAND ""
  CONFIGURE_COMMAND ${CMAKE_CURRENT_SOURCE_DIR}/Python/configure ${PRE_FLAGS} --enable-shared
)
ExternalProject_Add_Step(
  ex_python
  after_install
  DEPENDEES install
  COMMAND cd ${CMAKE_INSTALL_PREFIX}/bin && ln -sf python${PYVERSION} python && ln -sf python${PYVERSION}-config python-config
)

ExternalProject_Add(
  lib_xz
  # Dependencies just to force build order
  DEPENDS lib_z lib_bzip2 ex_python
  PREFIX ${CMAKE_BINARY_DIR}/xz/.prefix
  SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/xz
  BINARY_DIR ${CMAKE_BINARY_DIR}/xz/.build
  CMAKE_COMMAND ""
  CONFIGURE_COMMAND ${CMAKE_CURRENT_SOURCE_DIR}/xz/configure ${PRE_FLAGS}
)

ExternalProject_Add(
  lib_xml2
  DEPENDS lib_xz lib_icu
  PREFIX ${CMAKE_BINARY_DIR}/libxml2/.prefix
  SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/libxml2
  BINARY_DIR ${CMAKE_BINARY_DIR}/libxml2/.build
  CMAKE_COMMAND ""
  CONFIGURE_COMMAND ${CMAKE_CURRENT_SOURCE_DIR}/libxml2/configure ${PRE_FLAGS} --with-python=${CMAKE_INSTALL_PREFIX} --with-icu --with-xpath LDFLAGS=$(LDFLAGS)
  INSTALL_COMMAND $(MAKE) install
)

ExternalProject_Add(
  lib_archive
  DEPENDS lib_xml2 open_ssl
  PREFIX ${CMAKE_BINARY_DIR}/libarchive/.prefix
  SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/libarchive
  BINARY_DIR ${CMAKE_BINARY_DIR}/libarchive/.build
  CMAKE_COMMAND ""
  CONFIGURE_COMMAND ${CMAKE_CURRENT_SOURCE_DIR}/libarchive/configure ${PRE_FLAGS}
)

ExternalProject_Add(
  ex_curl
  DEPENDS lib_archive
  PREFIX ${CMAKE_BINARY_DIR}/curl/.prefix
  SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/curl
  BINARY_DIR ${CMAKE_BINARY_DIR}/curl/.build
  CMAKE_COMMAND ""
  CONFIGURE_COMMAND env LIBS=-lcrypto LDFLAGS=-lssl ${CMAKE_CURRENT_SOURCE_DIR}/curl/configure ${PRE_FLAGS} --enable-http --enable-ftp --enable-file --with-ssl=${CMAKE_INSTALL_PREFIX}
)

ExternalProject_Add(
  lib_xslt
  DEPENDS ex_python lib_xml2
  PREFIX ${CMAKE_BINARY_DIR}/libxslt/.prefix
  SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/libxslt
  BINARY_DIR ${CMAKE_BINARY_DIR}/libxslt/.build
  CMAKE_COMMAND ""
  CONFIGURE_COMMAND ${CMAKE_CURRENT_SOURCE_DIR}/libxslt/configure ${PRE_FLAGS}
  INSTALL_COMMAND $(MAKE) install 
)

ExternalProject_Add(
  open_mpi
  PREFIX ${CMAKE_BINARY_DIR}/openmpi/.prefix
  SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/openmpi
  BINARY_DIR ${CMAKE_BINARY_DIR}/openmpi/.build
  CMAKE_COMMAND ""
  # Disable vt because of compile error in combination with cuda
  CONFIGURE_COMMAND ${CMAKE_CURRENT_SOURCE_DIR}/openmpi/configure ${PRE_FLAGS} --enable-cxx-exceptions --disable-vt
)

ExternalProject_Add(
  ex_boost
  DEPENDS ex_python open_mpi lib_archive lib_icu open_ssl
  PREFIX ${CMAKE_BINARY_DIR}/boost/.prefix
  SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/boost
  BUILD_IN_SOURCE 1
  CMAKE_COMMAND ""
  CONFIGURE_COMMAND ./bootstrap.sh ${PRE_FLAGS} --with-python=${CMAKE_INSTALL_PREFIX}/bin/python --with-icu=${CMAKE_INSTALL_PREFIX}
  BUILD_COMMAND ./b2 -q stage variant=release link=shared runtime-link=shared threading=multi cxxflags=$(CXXFLAGS) cflags=$(CFLAGS) linkflags=$(LDFLAGS)
  INSTALL_COMMAND ./b2 -q install variant=release link=shared runtime-link=shared threading=multi cxxflags=$(CXXFLAGS) cflags=$(CFLAGS) linkflags=$(LDFLAGS)
)

ExternalProject_Add(
  setup_tools
  DEPENDS ex_python
  PREFIX ${CMAKE_BINARY_DIR}/setuptools/.prefix
  SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/setuptools
  BUILD_IN_SOURCE 1
  CMAKE_COMMAND ""
  CONFIGURE_COMMAND ""
  BUILD_COMMAND ${CMAKE_INSTALL_PREFIX}/bin/python setup.py build
  INSTALL_COMMAND ${CMAKE_INSTALL_PREFIX}/bin/python setup.py install
)

ExternalProject_Add(
  num_py
  DEPENDS setup_tools open_blas
  PREFIX ${CMAKE_BINARY_DIR}/numpy/.prefix
  SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/numpy
  BUILD_IN_SOURCE 1
  CMAKE_COMMAND ""
  CONFIGURE_COMMAND ""
  BUILD_COMMAND LDFLAGS=-shared ${CMAKE_INSTALL_PREFIX}/bin/${PYTHON} setup.py build
  INSTALL_COMMAND LDFLAGS=-shared ${CMAKE_INSTALL_PREFIX}/bin/${PYTHON} setup.py install
)

ExternalProject_Add(
  i_python
  DEPENDS ex_python setup_tools
  PREFIX ${CMAKE_BINARY_DIR}/ipython/.prefix
  SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/ipython
  BUILD_IN_SOURCE 1
  CMAKE_COMMAND ""
  CONFIGURE_COMMAND ""
  BUILD_COMMAND ${CMAKE_INSTALL_PREFIX}/bin/${PYTHON} setup.py build
  INSTALL_COMMAND ${CMAKE_INSTALL_PREFIX}/bin/${PYTHON} setup.py install
)

ExternalProject_Add_Step(
  i_python
  after_install
  DEPENDEES install
  COMMAND cd ${CMAKE_INSTALL_PREFIX}/bin && ln -sf ipython3 ipython
)


ExternalProject_Add(
  cpp_unit
  PREFIX ${CMAKE_BINARY_DIR}/cppunit/.prefix
  SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/cppunit
  BINARY_DIR ${CMAKE_BINARY_DIR}/cppunit/.build
  CONFIGURE_COMMAND ${CMAKE_CURRENT_SOURCE_DIR}/cppunit/configure ${PRE_FLAGS} 
)

ExternalProject_Add(
  lu_sol
  PREFIX ${CMAKE_BINARY_DIR}/lusol/csrc/.prefix
  SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/lusol/csrc
  BUILD_IN_SOURCE 1
  CMAKE_COMMAND ""
  CONFIGURE_COMMAND ""
  INSTALL_COMMAND INSTALL_PREFIX=${CMAKE_INSTALL_PREFIX} $(MAKE) install
)

ExternalProject_Add(
  col_pack
  PREFIX ${CMAKE_BINARY_DIR}/ColPack/.prefix
  SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/ColPack
  BUILD_IN_SOURCE 1
  CMAKE_COMMAND ""
  CONFIGURE_COMMAND ./configure ${PRE_FLAGS} --libdir=${CMAKE_INSTALL_PREFIX}/lib
)

ExternalProject_Add(
  cx_sparse
  PREFIX ${CMAKE_BINARY_DIR}/CXSparse/.prefix
  SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/CXSparse
  BUILD_IN_SOURCE 1
  CMAKE_COMMAND ""
  CONFIGURE_COMMAND ""
  INSTALL_COMMAND INSTALL_LIB=${CMAKE_INSTALL_PREFIX}/lib INSTALL_INCLUDE=${CMAKE_INSTALL_PREFIX}/include $(MAKE) install
)

ExternalProject_Add(
  i_popt
  DEPENDS open_blas
  PREFIX ${CMAKE_BINARY_DIR}/Ipopt/.prefix
  SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/Ipopt
  BUILD_IN_SOURCE 1
  CMAKE_COMMAND ""
  CONFIGURE_COMMAND ./configure ${PRE_FLAGS} --enable-static
)

ExternalProject_Add(
  adol_c
  DEPENDS col_pack
  PREFIX ${CMAKE_BINARY_DIR}/ADOL-C/.prefix
  SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/ADOL-C
  BUILD_IN_SOURCE 1
  CMAKE_COMMAND ""
  CONFIGURE_COMMAND ./configure ${PRE_FLAGS} --libdir=${CMAKE_INSTALL_PREFIX}/lib --with-colpack=${CMAKE_INSTALL_PREFIX} --enable-sparse
)

ExternalProject_Add(
  ps_opt
  DEPENDS lu_sol cx_sparse i_popt adol_c
  PREFIX ${CMAKE_BINARY_DIR}/Psopt3/.prefix
  SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/Psopt3
  BUILD_IN_SOURCE 1
  CMAKE_COMMAND ""
  CONFIGURE_COMMAND ""
  BUILD_COMMAND IPOPT=${CMAKE_INSTALL_PREFIX} CXSPARSE=${CMAKE_INSTALL_PREFIX} ADOLC=${CMAKE_INSTALL_PREFIX} $(MAKE)
  INSTALL_COMMAND INSTALL_PREFIX=${CMAKE_INSTALL_PREFIX} $(MAKE) install
)

ExternalProject_Add(
  geo_s
  DEPENDS json_c
  PREFIX ${CMAKE_BINARY_DIR}/geos/.prefix
  SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/geos
  BINARY_DIR ${CMAKE_BINARY_DIR}/geos/.build
  CONFIGURE_COMMAND ${CMAKE_CURRENT_SOURCE_DIR}/geos/configure ${PRE_FLAGS} 
)

ExternalProject_Add(
  lib_tiff
  DEPENDS lib_jpeg open_ssl lib_z lib_xz
  PREFIX ${CMAKE_BINARY_DIR}/tiff/.prefix
  SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/tiff
  BINARY_DIR ${CMAKE_BINARY_DIR}/tiff/.build
  CMAKE_COMMAND ""
  CONFIGURE_COMMAND ${CMAKE_CURRENT_SOURCE_DIR}/tiff/configure ${PRE_FLAGS} 
)

ExternalProject_Add(
  ex_gdal
  DEPENDS num_py open_jp2 open_jpeg lib_png lib_jpeg lib_tiff geo_s lib_pcre ex_curl lib_xml2 lib_expat lib_jasper json_c sql_lite
  PREFIX ${CMAKE_BINARY_DIR}/gdal/.prefix
  SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/gdal
  BUILD_IN_SOURCE 1
  CMAKE_COMMAND ""
  CONFIGURE_COMMAND ./configure ${PRE_FLAGS} --with-python=${CMAKE_INSTALL_PREFIX}/bin/${PYTHON} ${OPENCL_FLAGS} --with-openjpeg=${CMAKE_INSTALL_PREFIX} --with-png=${CMAKE_INSTALL_PREFIX} --with-expat=${CMAKE_INSTALL_PREFIX} --with-jasper=${CMAKE_INSTALL_PREFIX} --with-libjson-c=${CMAKE_INSTALL_PREFIX} --with-curl=${CMAKE_INSTALL_PREFIX} --with-geos=yes --with-pcre LDFLAGS=$(LDFLAGS) CPPFLAGS=${CL_INCLUDES} LIBS=${CL_LIBS}
)

ExternalProject_Add(
  grib_api
  DEPENDS open_jpeg num_py 
  PREFIX ${CMAKE_BINARY_DIR}/grib_api/.prefix
  SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/grib_api
  BUILD_IN_SOURCE 1
  CMAKE_COMMAND ""
  CONFIGURE_COMMAND ./configure ${PRE_FLAGS} --with-openjpeg=${CMAKE_INSTALL_PREFIX} --enable-python PYTHON_CONFIG=${CMAKE_INSTALL_PREFIX}/bin/${PYTHON}-config
)

ExternalProject_Add(
  nl_opt
  DEPENDS num_py lib_tiff
  PREFIX ${CMAKE_BINARY_DIR}/nlopt/.prefix
  SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/nlopt
  BINARY_DIR ${CMAKE_BINARY_DIR}/nlopt/.build
  CMAKE_COMMAND ""
  CONFIGURE_COMMAND ${CMAKE_CURRENT_SOURCE_DIR}/nlopt/configure ${PRE_FLAGS} --without-matlab --without-octave PYTHON=${CMAKE_INSTALL_PREFIX}/bin/${PYTHON} PYTHON_CONFIG=${CMAKE_INSTALL_PREFIX}/bin/${PYTHON}-config
)



ExternalProject_Add(
  lib_boost_numpy 
  DEPENDS ex_boost num_py
  PREFIX ${CMAKE_BINARY_DIR}/Boost.NumPy/.prefix
  SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/Boost.NumPy
  BUILD_IN_SOURCE 1
  CMAKE_ARGS -D BOOST_ROOT=${CMAKE_INSTALL_PREFIX} -D PYTHON_EXECUTABLE=${CMAKE_INSTALL_PREFIX}/bin/${PYTHON} -D CMAKE_INSTALL_PREFIX=${CMAKE_INSTALL_PREFIX} ${CMAKE_COMPILERS} .
)

ExternalProject_Add(
  ex_swig
  DEPENDS ex_python lib_pcre
  PREFIX ${CMAKE_BINARY_DIR}/swig/.prefix
  SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/swig
  BINARY_DIR ${CMAKE_BINARY_DIR}/swig/.build
  CMAKE_COMMAND ""
  CONFIGURE_COMMAND ${CMAKE_CURRENT_SOURCE_DIR}/swig/configure ${PRE_FLAGS} --with-python=${CMAKE_INSTALL_PREFIX}/bin/${PYTHON}
)

ExternalProject_Add(
  pix_man
  DEPENDS lib_png
  PREFIX ${CMAKE_BINARY_DIR}/pixman/.prefix
  SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/pixman
  BINARY_DIR ${CMAKE_BINARY_DIR}/pixman/.build
  CONFIGURE_COMMAND ${CMAKE_CURRENT_SOURCE_DIR}/pixman/configure ${PRE_FLAGS} 
)

ExternalProject_Add(
  get_text
  DEPENDS lib_xml2 lib_bzip2
  PREFIX ${CMAKE_BINARY_DIR}/gettext/.prefix
  SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/gettext
  BINARY_DIR ${CMAKE_BINARY_DIR}/gettext/.build
  CONFIGURE_COMMAND ${CMAKE_CURRENT_SOURCE_DIR}/gettext/configure ${PRE_FLAGS} 
)

ExternalProject_Add(
  g_lib
  DEPENDS ex_python lib_fam lib_xslt lib_pcre open_ssl get_text
  PREFIX ${CMAKE_BINARY_DIR}/glib/.prefix
  SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/glib
  BINARY_DIR ${CMAKE_BINARY_DIR}/glib/.build
  CONFIGURE_COMMAND ${CMAKE_CURRENT_SOURCE_DIR}/glib/configure ${GO_FLAGS} --disable-selinux --with-pcre=system 
)

ExternalProject_Add(
  gobject_introspection
  DEPENDS g_lib ex_python
  PREFIX ${CMAKE_BINARY_DIR}/gobject-introspection/.prefix
  SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/gobject-introspection
  BINARY_DIR ${CMAKE_BINARY_DIR}/gobject-introspection/.build
  CONFIGURE_COMMAND ${CMAKE_CURRENT_SOURCE_DIR}/gobject-introspection/configure ${GO_FLAGS} PYTHON=${CMAKE_INSTALL_PREFIX}/bin/${PYTHON}
)
ExternalProject_Add(
  free_type
  DEPENDS gobject_introspection lib_xml2 lib_png lib_tiff
  PREFIX ${CMAKE_BINARY_DIR}/freetype/.prefix
  SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/freetype
  BINARY_DIR ${CMAKE_BINARY_DIR}/freetype/.build
  CONFIGURE_COMMAND ${CMAKE_CURRENT_SOURCE_DIR}/freetype/configure ${PRE_FLAGS}
)

ExternalProject_Add(
  font_config
  DEPENDS lib_xml2 free_type
  PREFIX ${CMAKE_BINARY_DIR}/fontconfig/.prefix
  SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/fontconfig
  BINARY_DIR ${CMAKE_BINARY_DIR}/fontconfig/.build
  CONFIGURE_COMMAND ${CMAKE_CURRENT_SOURCE_DIR}/fontconfig/configure ${PRE_FLAGS} --enable-libxml2 --disable-docs
)

ExternalProject_Add(
  lib_cairo
  DEPENDS pix_man gobject_introspection free_type lib_png font_config lib_tiff
  PREFIX ${CMAKE_BINARY_DIR}/cairo/.prefix
  SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/cairo
  BINARY_DIR ${CMAKE_BINARY_DIR}/cairo/.build
  CONFIGURE_COMMAND ${CMAKE_CURRENT_SOURCE_DIR}/cairo/configure ${PRE_FLAGS} --enable-ft=yes --enable-fc=yes ${CAIRO_GL_FLAGS} --disable-static
)

ExternalProject_Add(
  a_tk
  DEPENDS gobject_introspection
  PREFIX ${CMAKE_BINARY_DIR}/atk/.prefix
  SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/atk
  BINARY_DIR ${CMAKE_BINARY_DIR}/atk/.build
  CONFIGURE_COMMAND ${CMAKE_CURRENT_SOURCE_DIR}/atk/configure ${GO_FLAGS}
)

ExternalProject_Add(
  ex_ragel
  PREFIX ${CMAKE_BINARY_DIR}/ragel/.prefix
  SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/ragel
  BINARY_DIR ${CMAKE_BINARY_DIR}/ragel/.build
  CONFIGURE_COMMAND ${CMAKE_CURRENT_SOURCE_DIR}/ragel/configure ${PRE_FLAGS}
)

ExternalProject_Add(
  harf_buzz
  DEPENDS ex_ragel free_type
  PREFIX ${CMAKE_BINARY_DIR}/harfbuzz/.prefix
  SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/harfbuzz
  BINARY_DIR ${CMAKE_BINARY_DIR}/harfbuzz/.build
  CONFIGURE_COMMAND ${CMAKE_CURRENT_SOURCE_DIR}/harfbuzz/configure ${PRE_FLAGS} --with-gobject
)


ExternalProject_Add(
  pan_go
  DEPENDS lib_cairo gobject_introspection harf_buzz
  PREFIX ${CMAKE_BINARY_DIR}/pango/.prefix
  SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/pango
  BINARY_DIR ${CMAKE_BINARY_DIR}/pango/.build
  CONFIGURE_COMMAND ${CMAKE_CURRENT_SOURCE_DIR}/pango/configure ${GO_FLAGS}
)

ExternalProject_Add(
  gdk_pixbuf 
  DEPENDS gobject_introspection lib_png lib_jpeg
  PREFIX ${CMAKE_BINARY_DIR}/gdk-pixbuf/.prefix
  SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/gdk-pixbuf
  # Problems building out of source
  BUILD_IN_SOURCE 1
  CONFIGURE_COMMAND ./configure ${GO_FLAGS} --without-libtiff BASE_DEPENDENCIES_CFLAGS=$(CFLAGS)
)

ExternalProject_Add(
  gtkp
  DEPENDS gobject_introspection lib_cairo pan_go a_tk gdk_pixbuf
  PREFIX ${CMAKE_BINARY_DIR}/gtk+/.prefix
  SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/gtk+
  BINARY_DIR ${CMAKE_BINARY_DIR}/gtk+/.build
  CONFIGURE_COMMAND ${CMAKE_CURRENT_SOURCE_DIR}/gtk+/configure ${GO_FLAGS}
)

ExternalProject_Add(
  lib_cogl
  DEPENDS gtkp
  PREFIX ${CMAKE_BINARY_DIR}/cogl/.prefix
  SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/cogl
  BINARY_DIR ${CMAKE_BINARY_DIR}/colg/.build
  CONFIGURE_COMMAND ${CMAKE_CURRENT_SOURCE_DIR}/cogl/configure ${GO_FLAGS}
)

ExternalProject_Add(
  json_glib
  DEPENDS gtkp json_c
  PREFIX ${CMAKE_BINARY_DIR}/json-glib/.prefix
  SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/json-glib
  BINARY_DIR ${CMAKE_BINARY_DIR}/json-glib/.build
  CONFIGURE_COMMAND ${CMAKE_CURRENT_SOURCE_DIR}/json-glib/configure ${GO_FLAGS}
)

ExternalProject_Add(
  lib_clutter
  DEPENDS lib_cogl json_glib
  PREFIX ${CMAKE_BINARY_DIR}/clutter/.prefix
  SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/clutter
  BINARY_DIR ${CMAKE_BINARY_DIR}/clutter/.build
  CONFIGURE_COMMAND ${CMAKE_CURRENT_SOURCE_DIR}/clutter/configure ${GO_FLAGS}
)

ExternalProject_Add(
  clutter_gtk
  DEPENDS lib_clutter
  PREFIX ${CMAKE_BINARY_DIR}/clutter-gtk/.prefix
  SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/clutter-gtk
  BINARY_DIR ${CMAKE_BINARY_DIR}/clutter-gtk/.build
  CONFIGURE_COMMAND ${CMAKE_CURRENT_SOURCE_DIR}/clutter-gtk/configure ${GO_FLAGS}
)

ExternalProject_Add(
  lib_sigcpp
  PREFIX ${CMAKE_BINARY_DIR}/libsigc++/.prefix
  SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/libsigc++
  BINARY_DIR ${CMAKE_BINARY_DIR}/libsigc++/.build
  CONFIGURE_COMMAND ${CMAKE_CURRENT_SOURCE_DIR}/libsigc++/configure ${PRE_FLAGS} --disable-documentation
)

ExternalProject_Add(
  glib_mm
  DEPENDS gtkp ex_boost lib_sigcpp
  PREFIX ${CMAKE_BINARY_DIR}/glibmm/.prefix
  SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/glibmm
  BINARY_DIR ${CMAKE_BINARY_DIR}/glibmm/.build
  CONFIGURE_COMMAND ${CMAKE_CURRENT_SOURCE_DIR}/glibmm/configure ${GO_FLAGS}
)

ExternalProject_Add(
  cairo_mm
  DEPENDS glib_mm
  PREFIX ${CMAKE_BINARY_DIR}/cairomm/.prefix
  SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/cairomm
  BINARY_DIR ${CMAKE_BINARY_DIR}/cairomm/.build
  CONFIGURE_COMMAND ${CMAKE_CURRENT_SOURCE_DIR}/cairomm/configure ${GO_FLAGS}
)

ExternalProject_Add(
  atk_mm
  DEPENDS glib_mm
  PREFIX ${CMAKE_BINARY_DIR}/atkmm/.prefix
  SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/atkmm
  BINARY_DIR ${CMAKE_BINARY_DIR}/atkmm/.build
  CONFIGURE_COMMAND ${CMAKE_CURRENT_SOURCE_DIR}/atkmm/configure ${GO_FLAGS}
)

ExternalProject_Add(
  pango_mm
  DEPENDS cairo_mm
  PREFIX ${CMAKE_BINARY_DIR}/pangomm/.prefix
  SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/pangomm
  BINARY_DIR ${CMAKE_BINARY_DIR}/pangomm/.build
  CONFIGURE_COMMAND ${CMAKE_CURRENT_SOURCE_DIR}/pangomm/configure ${GO_FLAGS}
)

ExternalProject_Add(
  gtk_mm
  DEPENDS pango_mm atk_mm
  PREFIX ${CMAKE_BINARY_DIR}/gtkmm/.prefix
  SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/gtkmm
  BINARY_DIR ${CMAKE_BINARY_DIR}/gtkmm/.build
  CONFIGURE_COMMAND ${CMAKE_CURRENT_SOURCE_DIR}/gtkmm/configure ${GO_FLAGS}
)

ExternalProject_Add(
  sci_py
  DEPENDS num_py get_text
  PREFIX ${CMAKE_BINARY_DIR}/scipy/.prefix
  SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/scipy
  BUILD_IN_SOURCE 1
  CMAKE_COMMAND ""
  CONFIGURE_COMMAND ""
  BUILD_COMMAND LDFLAGS=-shared ${CMAKE_INSTALL_PREFIX}/bin/${PYTHON} setup.py build
  INSTALL_COMMAND LDFLAGS=-shared ${CMAKE_INSTALL_PREFIX}/bin/${PYTHON} setup.py install
)

ExternalProject_Add(
  intl_tool
  DEPENDS get_text
  PREFIX ${CMAKE_BINARY_DIR}/intltool/.prefix
  SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/intltool
  BINARY_DIR ${CMAKE_BINARY_DIR}/intltool/.build
  CONFIGURE_COMMAND ${CMAKE_CURRENT_SOURCE_DIR}/intltool/configure ${PRE_FLAGS} 
)

ExternalProject_Add(
  glib_networking
  DEPENDS gtkp intl_tool
  PREFIX ${CMAKE_BINARY_DIR}/glib-networking/.prefix
  SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/glib-networking
  BINARY_DIR ${CMAKE_BINARY_DIR}/glib-networking/.build
  # We'll have to see if building without TLS will fly
  CONFIGURE_COMMAND ${CMAKE_CURRENT_SOURCE_DIR}/glib-networking/configure ${GO_FLAGS} --without-gnutls
)

ExternalProject_Add(
  lib_soup
  DEPENDS glib_networking 
  PREFIX ${CMAKE_BINARY_DIR}/libsoup/.prefix
  SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/libsoup
  BINARY_DIR ${CMAKE_BINARY_DIR}/libsoup/.build
  # We'll have to see if building without TLS will fly
  CONFIGURE_COMMAND ${CMAKE_CURRENT_SOURCE_DIR}/libsoup/configure ${GO_FLAGS} --disable-tls-check
)

ExternalProject_Add(
  lib_champlain
  DEPENDS gtk_mm clutter_gtk ex_python lib_soup
  PREFIX ${CMAKE_BINARY_DIR}/libchamplain/.prefix
  SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/libchamplain
  BINARY_DIR ${CMAKE_BINARY_DIR}/libchamplain/.build
  CONFIGURE_COMMAND ${CMAKE_CURRENT_SOURCE_DIR}/libchamplain/configure ${GO_FLAGS}
)

ExternalProject_Add(
  py_cairo
  DEPENDS setup_tools lib_cairo
  PREFIX ${CMAKE_BINARY_DIR}/pycairo/.prefix
  SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/pycairo
  BUILD_IN_SOURCE 1
  CONFIGURE_COMMAND ./waf configure ${PRE_FLAGS}
  BUILD_COMMAND ./waf build
  INSTALL_COMMAND ./waf install
)

ExternalProject_Add(
  py_gobject
  DEPENDS gtkp num_py py_cairo setup_tools
  PREFIX ${CMAKE_BINARY_DIR}/pygobject/.prefix
  SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/pygobject
  BINARY_DIR ${CMAKE_BINARY_DIR}/pygobject/.build
  CONFIGURE_COMMAND ${CMAKE_CURRENT_SOURCE_DIR}/pygobject/configure ${PRE_FLAGS} --with-python=${CMAKE_INSTALL_PREFIX}/bin/python
)

ExternalProject_Add(
  py_nose
  DEPENDS setup_tools
  PREFIX ${CMAKE_BINARY_DIR}/nose/.prefix
  SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/nose
  BUILD_IN_SOURCE 1
  CMAKE_COMMAND ""
  CONFIGURE_COMMAND ""
  BUILD_COMMAND ${CMAKE_INSTALL_PREFIX}/bin/python setup.py build
  INSTALL_COMMAND ${CMAKE_INSTALL_PREFIX}/bin/python setup.py install
)

ExternalProject_Add(
  py_six
  DEPENDS setup_tools
  PREFIX ${CMAKE_BINARY_DIR}/six/.prefix
  SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/six
  BUILD_IN_SOURCE 1
  CMAKE_COMMAND ""
  CONFIGURE_COMMAND ""
  BUILD_COMMAND ${CMAKE_INSTALL_PREFIX}/bin/python setup.py build
  INSTALL_COMMAND ${CMAKE_INSTALL_PREFIX}/bin/python setup.py install
)

ExternalProject_Add(
  py_tornado
  DEPENDS setup_tools
  PREFIX ${CMAKE_BINARY_DIR}/tornado/.prefix
  SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/tornado
  BUILD_IN_SOURCE 1
  CMAKE_COMMAND ""
  CONFIGURE_COMMAND ""
  BUILD_COMMAND ${CMAKE_INSTALL_PREFIX}/bin/python setup.py build
  INSTALL_COMMAND ${CMAKE_INSTALL_PREFIX}/bin/python setup.py install
)

ExternalProject_Add(
  py_parsing
  DEPENDS setup_tools
  PREFIX ${CMAKE_BINARY_DIR}/pyparsing/.prefix
  SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/pyparsing
  BUILD_IN_SOURCE 1
  CMAKE_COMMAND ""
  CONFIGURE_COMMAND ""
  BUILD_COMMAND ${CMAKE_INSTALL_PREFIX}/bin/python setup.py build
  INSTALL_COMMAND ${CMAKE_INSTALL_PREFIX}/bin/python setup.py install
)

ExternalProject_Add(
  py_dateutil
  DEPENDS py_six
  PREFIX ${CMAKE_BINARY_DIR}/python-dateutil/.prefix
  SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/python-dateutil
  BUILD_IN_SOURCE 1
  CMAKE_COMMAND ""
  CONFIGURE_COMMAND ""
  BUILD_COMMAND ${CMAKE_INSTALL_PREFIX}/bin/python setup.py build
  INSTALL_COMMAND ${CMAKE_INSTALL_PREFIX}/bin/python setup.py install
)

ExternalProject_Add(
  py_opengl
  DEPENDS setup_tools
  PREFIX ${CMAKE_BINARY_DIR}/PyOpenGL/.prefix
  SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/PyOpenGL
  BUILD_IN_SOURCE 1
  CMAKE_COMMAND ""
  CONFIGURE_COMMAND ""
  BUILD_COMMAND ${CMAKE_INSTALL_PREFIX}/bin/python setup.py build
  INSTALL_COMMAND ${CMAKE_INSTALL_PREFIX}/bin/python setup.py install
)

ExternalProject_Add(
  py_py
  DEPENDS setup_tools
  PREFIX ${CMAKE_BINARY_DIR}/pypy/.prefix
  SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/pypy
  BUILD_IN_SOURCE 1
  CMAKE_COMMAND ""
  CONFIGURE_COMMAND ""
  BUILD_COMMAND ${CMAKE_INSTALL_PREFIX}/bin/python setup.py build
  INSTALL_COMMAND ${CMAKE_INSTALL_PREFIX}/bin/python setup.py install
)

ExternalProject_Add(
  py_decorator
  DEPENDS setup_tools
  PREFIX ${CMAKE_BINARY_DIR}/decorator/.prefix
  SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/decorator
  BUILD_IN_SOURCE 1
  CMAKE_COMMAND ""
  CONFIGURE_COMMAND ""
  BUILD_COMMAND ${CMAKE_INSTALL_PREFIX}/bin/python setup.py build
  INSTALL_COMMAND ${CMAKE_INSTALL_PREFIX}/bin/python setup.py install
)

ExternalProject_Add(
  py_tools
  DEPENDS py_decorator
  PREFIX ${CMAKE_BINARY_DIR}/pytools/.prefix
  SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/pytools
  BUILD_IN_SOURCE 1
  CMAKE_COMMAND ""
  CONFIGURE_COMMAND ""
  BUILD_COMMAND ${CMAKE_INSTALL_PREFIX}/bin/python setup.py build
  INSTALL_COMMAND ${CMAKE_INSTALL_PREFIX}/bin/python setup.py install
)

ExternalProject_Add(
  py_test
  DEPENDS py_py
  PREFIX ${CMAKE_BINARY_DIR}/pytest/.prefix
  SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/pytest
  BUILD_IN_SOURCE 1
  CMAKE_COMMAND ""
  CONFIGURE_COMMAND ""
  BUILD_COMMAND ${CMAKE_INSTALL_PREFIX}/bin/python setup.py build
  INSTALL_COMMAND ${CMAKE_INSTALL_PREFIX}/bin/python setup.py install
)

if(HAVE_OPENCL_INC)
ExternalProject_Add(
  py_opencl
  DEPENDS num_py py_decorator
  PREFIX ${CMAKE_BINARY_DIR}/pyopencl/.prefix
  SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/pyopencl
  BUILD_IN_SOURCE 1
  CMAKE_COMMAND ""
  CONFIGURE_COMMAND ${CMAKE_INSTALL_PREFIX}/bin/python configure.py --python-exe=${CMAKE_INSTALL_PREFIX}/bin/python --cl-inc-dir=${CL_INCLUDE_DIR} --cl-lib-dir=${CL_LIB_DIR} --cxxflags=-I${CMAKE_INSTALL_PREFIX}/include,-L${CMAKE_INSTALL_PREFIX}/lib,--std=c++11
  BUILD_COMMAND ${CMAKE_INSTALL_PREFIX}/bin/python setup.py build 
  INSTALL_COMMAND ${CMAKE_INSTALL_PREFIX}/bin/python setup.py install
)
else()
ExternalProject_Add(
  py_opencl
  PREFIX ${CMAKE_BINARY_DIR}/pyopencl/.prefix
  SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/pyopencl
  BUILD_IN_SOURCE 1
  CMAKE_COMMAND ""
  CONFIGURE_COMMAND ""
  BUILD_COMMAND ""
  INSTALL_COMMAND ""
)
endif()

ExternalProject_Add(
  matplot_lib
  DEPENDS py_gobject py_nose py_dateutil py_parsing py_tornado
  PREFIX ${CMAKE_BINARY_DIR}/matplotlib/.prefix
  SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/matplotlib
  BUILD_IN_SOURCE 1
  CMAKE_COMMAND ""
  CONFIGURE_COMMAND ""
  BUILD_COMMAND ${CMAKE_INSTALL_PREFIX}/bin/python setup.py build
  INSTALL_COMMAND ${CMAKE_INSTALL_PREFIX}/bin/python setup.py install
)


ExternalProject_Add(
  zope_interface
  DEPENDS setup_tools
  PREFIX ${CMAKE_BINARY_DIR}/zope.interface/.prefix
  SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/zope.interface
  BUILD_IN_SOURCE 1
  CMAKE_COMMAND ""
  CONFIGURE_COMMAND ""
  BUILD_COMMAND ${CMAKE_INSTALL_PREFIX}/bin/python setup.py build
  INSTALL_COMMAND ${CMAKE_INSTALL_PREFIX}/bin/python setup.py install
)

ExternalProject_Add(
  py_twisted
  DEPENDS ex_python zope_interface
  PREFIX ${CMAKE_BINARY_DIR}/Twisted/.prefix
  SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/Twisted
  BUILD_IN_SOURCE 1
  CMAKE_COMMAND ""
  CONFIGURE_COMMAND ""
  BUILD_COMMAND ${CMAKE_INSTALL_PREFIX}/bin/python setup.py build
  INSTALL_COMMAND ${CMAKE_INSTALL_PREFIX}/bin/python setup.py install
)

ExternalProject_Add(
  postgre_sql
  DEPENDS lib_xslt open_ssl
  PREFIX ${CMAKE_BINARY_DIR}/postgresql/.prefix
  SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/postgresql
  BUILD_IN_SOURCE 1
  CONFIGURE_COMMAND ${CMAKE_CURRENT_SOURCE_DIR}/postgresql/configure ${PRE_FLAGS}
)

ExternalProject_Add(
  py_django
  DEPENDS py_twisted postgre_sql
  PREFIX ${CMAKE_BINARY_DIR}/Django/.prefix
  SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/Django
  BUILD_IN_SOURCE 1
  CMAKE_COMMAND ""
  CONFIGURE_COMMAND ""
  BUILD_COMMAND ${CMAKE_INSTALL_PREFIX}/bin/python setup.py build
  INSTALL_COMMAND ${CMAKE_INSTALL_PREFIX}/bin/python setup.py install
)


ExternalProject_Add(
  qt_4
  DEPENDS lib_png lib_tiff open_jp2 open_jpeg lib_xslt gtkp postgre_sql g_lib gtkp
  PREFIX ${CMAKE_BINARY_DIR}/qt4/.prefix
  SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/qt4
  BUILD_IN_SOURCE 1
  CONFIGURE_COMMAND LDFLAGS= ./configure ${PRE_FLAGS} -no-qt3support ${QT_POSTGRES} ${QT_GL_FLAGS} -no-nis -no-openvg -no-phonon -no-phonon-backend -no-libmng -no-pch -opensource -confirm-license -nomake examples -nomake demos -nomake docs -xmlpatterns -glib -gtkstyle
)

ExternalProject_Add(
  shi_boken
  DEPENDS qt_4 
  PREFIX ${CMAKE_BINARY_DIR}/shiboken/.prefix
  SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/shiboken
  BINARY_DIR ${CMAKE_BINARY_DIR}/shiboken/.build
  CMAKE_ARGS -D USE_PYTHON3=1 -D PYTHON3_EXECUTABLE=${CMAKE_INSTALL_PREFIX}/bin/${PYTHON} -D CMAKE_INSTALL_PREFIX=${CMAKE_INSTALL_PREFIX} ${CMAKE_COMPILERS} ..
)

ExternalProject_Add(
  py_side
  DEPENDS shi_boken
  PREFIX ${CMAKE_BINARY_DIR}/pyside/.prefix
  SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/pyside
  BINARY_DIR ${CMAKE_BINARY_DIR}/pyside/.build
  CMAKE_ARGS -D PYTHON_EXECUTABLE=${CMAKE_INSTALL_PREFIX}/bin/${PYTHON} -D CMAKE_INSTALL_PREFIX=${CMAKE_INSTALL_PREFIX} ${CMAKE_COMPILERS} ..
)

ExternalProject_Add(
  py_side_tools
  DEPENDS py_side
  PREFIX ${CMAKE_BINARY_DIR}/pyside-tools/.prefix
  SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/pyside-tools
  BINARY_DIR ${CMAKE_BINARY_DIR}/pyside-tools/.build
  CMAKE_ARGS -D PYTHON_EXECUTABLE=${CMAKE_INSTALL_PREFIX}/bin/${PYTHON} -D CMAKE_INSTALL_PREFIX=${CMAKE_INSTALL_PREFIX} ${CMAKE_COMPILERS} ..
)


ExternalProject_Add(
  proj_4
  PREFIX ${CMAKE_BINARY_DIR}/proj-4/.prefix
  SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/proj-4
  BINARY_DIR ${CMAKE_BINARY_DIR}/proj-4/.build
  CMAKE_COMMAND ""
  CONFIGURE_COMMAND ${CMAKE_CURRENT_SOURCE_DIR}/proj-4/configure ${PRE_FLAGS}
)

ExternalProject_Add(
  map_nik
  DEPENDS sql_lite postgre_sql qt_4 ex_gdal ex_boost lib_tiff lib_xml2 lib_png lib_icu py_cairo proj_4 py_six
  PREFIX ${CMAKE_BINARY_DIR}/mapnik/.prefix
  SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/mapnik
  BUILD_IN_SOURCE 1
  CONFIGURE_COMMAND ${CMAKE_CURRENT_SOURCE_DIR}/mapnik/configure PREFIX=${CMAKE_INSTALL_PREFIX} CUSTOM_CFLAGS=$(CFLAGS) CUSTOM_CXXFLAGS=$(CXXFLAGS) CUSTOM_LDFLAGS=$(LDFLAGS) BOOST_INCLUDES=${CMAKE_INSTALL_PREFIX}/include BOOST_LIBS=${CMAKE_INSTALL_PREFIX}/lib JOBS=2 PKG_CONFIG_PATH=$(PKG_CONFIG_PATH)
  BUILD_COMMAND JOBS=6 $(MAKE) JOBS=6
)

ExternalProject_Add(
  py_mapnik
  DEPENDS map_nik
  PREFIX ${CMAKE_BINARY_DIR}/python-mapnik/.prefix
  SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/python-mapnik
  BUILD_IN_SOURCE 1
  CMAKE_COMMAND ""
  CONFIGURE_COMMAND ""
  BUILD_COMMAND ${CMAKE_INSTALL_PREFIX}/bin/python setup.py build
  INSTALL_COMMAND ${CMAKE_INSTALL_PREFIX}/bin/python setup.py install
)

ExternalProject_Add(
  post_gis
  DEPENDS postgre_sql geo_s ex_gdal
  PREFIX ${CMAKE_BINARY_DIR}/postgis/.prefix
  SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/postgis
  BUILD_IN_SOURCE 1
  CONFIGURE_COMMAND ./configure ${PRE_FLAGS} 
)

ExternalProject_Add(
  osm_2_pgsql
  DEPENDS post_gis map_nik
  PREFIX ${CMAKE_BINARY_DIR}/osm2pgsql/.prefix
  SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/osm2pgsql
  BINARY_DIR ${CMAKE_BINARY_DIR}/osm2pgsql/.build
  CONFIGURE_COMMAND ${CMAKE_CURRENT_SOURCE_DIR}/osm2pgsql/configure ${PRE_FLAGS} --with-proj=${CMAKE_INSTALL_PREFIX} --with-zlib=${CMAKE_INSTALL_PREFIX} --with-bzip2=${CMAKE_INSTALL_PREFIX} --with-boost=${CMAKE_INSTALL_PREFIX}
)

ExternalProject_Add(
  wx_widgets
  DEPENDS gtkp lib_tiff lib_png lib_xml2 lib_icu lib_bzip2 
  PREFIX ${CMAKE_BINARY_DIR}/wxWidgets/.prefix
  SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/wxWidgets
  BINARY_DIR ${CMAKE_BINARY_DIR}/wxWidgets/.build
  CONFIGURE_COMMAND ${CMAKE_CURRENT_SOURCE_DIR}/wxWidgets/configure ${PRE_FLAGS} --with-gtk=3 --with-libjpeg=sys --with-libtiff=sys --with-libpng=sys --with-zlib=sys --enable-unicode --disable-webview --with-opengl LDFLAGS=$(LDFLAGS)
)

ExternalProject_Add(
  wx_python
  DEPENDS wx_widgets
  PREFIX ${CMAKE_BINARY_DIR}/wxPython/.prefix
  SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/wxPython
  BUILD_IN_SOURCE 1
  CMAKE_COMMAND ""
  CONFIGURE_COMMAND ""
  BUILD_COMMAND ${CMAKE_INSTALL_PREFIX}/bin/python build.py build_py --use_syswx --no_magic
  INSTALL_COMMAND ${CMAKE_INSTALL_PREFIX}/bin/python build.py install_py --use_syswx --no_magic
)

endif(0)


#ExternalProject_Add(
#  open_cpn 
#  DEPENDS wx_widgets  ex_gdal
#  PREFIX ${CMAKE_BINARY_DIR}/OpenCPN/.prefix
#  SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/OpenCPN
#  BINARY_DIR ${CMAKE_BINARY_DIR}/OpenCPN/.build
#  CMAKE_ARGS -D CMAKE_INSTALL_PREFIX=${CMAKE_INSTALL_PREFIX} CMAKE_${CMAKE_CURRENT_SOURCE_DIR}/OpenCPN
#)

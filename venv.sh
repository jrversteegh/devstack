
# Appended by devstack

export BOOSTROOT=$VIRTUAL_ENV
export BOOST_ROOT=$VIRTUAL_ENV

bindir=$VIRTUAL_ENV/bin
libdir=$VIRTUAL_ENV/lib
sharedir=$VIRTUAL_ENV/share
export PREFIX="$VIRTUAL_ENV$DEVSTACK_TARGET"
export PATH=$bindir:$PATH
if [ -z $LD_LIBRARY_PATH ]; then
  export LD_LIBRARY_PATH=$libdir
else
  export LD_LIBRARY_PATH=$libdir:$LD_LIBRARY_PATH
fi
if [ -z $PKG_CONFIG_PATH ]; then
  export PKG_CONFIG_PATH=$libdir/pkgconfig
else
  export PKG_CONFIG_PATH=$libdir/pkgconfig:$PKG_CONFIG_PATH
fi
if [ -z $XDG_DATA_DIRS ]; then
  export XDG_DATA_DIRS=$sharedir:/usr/local/share/:/usr/share/
else
  export XDG_DATA_DIRS=$sharedir:$XDG_DATA_DIRS:/usr/local/share/:/usr/share/
fi

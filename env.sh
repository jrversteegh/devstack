curdir=`dirname $BASH_SOURCE`
curdir=`readlink -f $curdir`
bindir=$curdir/bin
libdir=$curdir/lib
lib64dir=$curdir/lib64
if [ -z $USING_DEVSTACK ]; then
  export USING_DEVSTACK=1
  export PATH=$bindir:$PATH
  export LD_LIBRARY_PATH=$lib64dir:$libdir:$LD_LIBRARY_PATH
  export PKG_CONFIG_PATH=$libdir/pkgconfig:$PKG_CONFIG_PATH
fi

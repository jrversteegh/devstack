# Author: Jaap Versteegh <j.r.versteegh@gmail.com>

curdir=`dirname $BASH_SOURCE`
curdir=`readlink -f $curdir`
bindir=$curdir/root/bin
libdir=$curdir/root/lib
if [ -z $USING_DEVSTACK ]; then
  export USING_DEVSTACK=1
  export PATH=$bindir:$PATH
  export LD_LIBRARY_PATH=$libdir:$LD_LIBRARY_PATH
  export PKG_CONFIG_PATH=$libdir/pkgconfig:$PKG_CONFIG_PATH
fi

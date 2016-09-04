# Author: Jaap Versteegh <j.r.versteegh@gmail.com>

curfile=`readlink -f $BASH_SOURCE`
curdir=`dirname $curfile`

if [ -z "$DEVSTACK_TARGET" ]; then
  if [ -d $curdir/root ]; then
    DEVSTACK_TARGET=$curdir/root
  else
    DEVSTACK_TARGET=$curdir
  fi
fi
export DEVSTACK_TARGET

bindir=$DEVSTACK_TARGET/bin
libdir=$DEVSTACK_TARGET/lib
sharedir=$DEVSTACK_TARGET/share
if [ -z $USING_DEVSTACK ]; then
  export USING_DEVSTACK=1
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
fi

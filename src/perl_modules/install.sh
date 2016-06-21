#!/bin/bash

# Author: Jaap Versteegh <j.r.versteegh@gmail.com>
export HOME=`pwd`
echo |cpan App::cpanminus
cpanm XML::Parser

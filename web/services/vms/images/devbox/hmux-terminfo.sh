# hmux Cloud devbox terminfo lookup. Put the overlay first, then retain the
# distro's compiled-in directories for TERM values hmux does not define.
unset TERMINFO
export TERMINFO_DIRS=/etc/terminfo:

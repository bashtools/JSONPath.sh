#!/usr/bin/env make
#
# JSONPath.sh -  JSONPath implementation written in Bash

#############
# utilities #
#############

INSTALL= install
SHELL= bash

######################
# target information #
######################

DESTDIR= /usr/local/bin

TARGETS= JSONPath.sh

######################################
# all - default rule - must be first #
######################################

all: ${TARGETS}

#################################################
# .PHONY list of rules that do not create files #
#################################################

.PHONY: all configure clean clobber install

###################################
# standard Makefile utility rules #
###################################

configure:

clean:

clobber: clean

install: all
	${INSTALL} -m 0555 ${TARGETS} ${DESTDIR}

# $Id: meta.stage.mk,v 1.15 2012/10/14 02:50:38 sjg Exp $
#
#	@(#) Copyright (c) 2011, Simon J. Gerraty
#
#	This file is provided in the hope that it will
#	be of use.  There is absolutely NO WARRANTY.
#	Permission to copy, redistribute or otherwise
#	use this file is hereby granted provided that 
#	the above copyright notice and this notice are
#	left intact. 
#      
#	Please send copies of changes and bug-fixes to:
#	sjg@crufty.net
#

.if !target(__${.PARSEFILE}__)
__${.PARSEFILE}__:

.if ${.MAKE.DEPENDFILE_PREFERENCE:U${.MAKE.DEPENDFILE}:M*.${MACHINE}} != ""
# this is generally safer anyway
_dirdep = ${RELDIR}.${MACHINE}
.else
_dirdep = ${RELDIR}
.endif

# this allows us to trace dependencies back to their src dir
.dirdep:
	@echo '${_dirdep}' > $@

.if defined(NO_POSIX_SHELL) || ${type printf:L:sh:Mbuiltin} == ""
_stage_file_basename = `basename $$f`
_stage_target_dirname = `dirname $$t`
.else
_stage_file_basename = $${f\#\#*/}
_stage_target_dirname = $${t%/*}
.endif

_objroot ?= ${_OBJROOT:tA}
# make sure this is global
_STAGED_DIRS ?=
.export _STAGED_DIRS
# add each dir we stage to to _STAGED_DIRS
# and make sure we have absolute paths so that bmake
# will match against .MAKE.META.BAILIWICK
STAGE_DIR_FILTER = tA:@d@$${_STAGED_DIRS::+=$$d}$$d@
# convert _STAGED_DIRS into suitable filters
GENDIRDEPS_FILTER += Nnot-empty-is-important \
	${_STAGED_DIRS:O:u:M${OBJTOP}*:S,${OBJTOP}/,N,} \
	${_STAGED_DIRS:O:u:N${OBJTOP}*:S,${_objroot},,:C,^([^/]+)/(.*),N\2.\1,:S,${HOST_TARGET},.host,}

# it is an error for more than one src dir to try and stage
# the same file
STAGE_DIRDEP_SCRIPT = StageDirdep() { \
  t=$$1; \
  if [ -s $$t.dirdep ]; then \
	cmp -s .dirdep $$t.dirdep && return; \
	echo "ERROR: $$t installed by `cat $$t.dirdep` not ${_dirdep}" >&2; \
	exit 1; \
  fi; \
  ln .dirdep $$t.dirdep 2> /dev/null || \
  cp .dirdep $$t.dirdep; }

# common logic for staging files
# this all relies on RELDIR being set to a subdir of SRCTOP
# we use ln(1) if we can, else cp(1)
STAGE_FILE_SCRIPT = ${STAGE_DIRDEP_SCRIPT}; StageFiles() { \
  dest=$$1; shift; \
  mkdir -p $$dest; \
  [ -s .dirdep ] || echo '${_dirdep}' > .dirdep; \
  for f in "$$@"; do \
	case "$$f" in */*) t=$$dest/${_stage_file_basename};; *) t=$$dest/$$f;; esac; \
	StageDirdep $$t; \
	rm -f $$t; \
	{ ln $$f $$t 2> /dev/null || \
	cp -p $$f $$t; }; \
  done; :; }

STAGE_LINKS_SCRIPT = ${STAGE_DIRDEP_SCRIPT}; StageLinks() { \
  case "$$1" in --) shift;; -*) lnf=$$1; shift;; esac; \
  dest=$$1; shift; \
  mkdir -p $$dest; \
  [ -s .dirdep ] || echo '${_dirdep}' > .dirdep; \
  while test $$\# -ge 2; do \
	l=$$1; shift; \
	t=$$dest/$$1; \
	case "$$1" in */*) mkdir -p ${_stage_target_dirname};; esac; \
	shift; \
	StageDirdep $$t; \
	rm -f $$t 2>/dev/null; \
	ln $$lnf $$l $$t; \
  done; :; }

STAGE_AS_SCRIPT = ${STAGE_DIRDEP_SCRIPT}; StageAs() { \
  dest=$$1; shift; \
  mkdir -p $$dest; \
  [ -s .dirdep ] || echo '${_dirdep}' > .dirdep; \
  while test $$\# -ge 2; do \
	s=$$1; shift; \
	t=$$dest/$$1; \
	case "$$1" in */*) mkdir -p ${_stage_target_dirname};; esac; \
	shift; \
	StageDirdep $$t; \
	rm -f $$t; \
	{ ln $$s $$t 2> /dev/null || \
	cp -p $$s $$t; }; \
  done; :; }

# this is simple, a list of the "staged" files depends on this,
_STAGE_BASENAME_USE:	.USE ${.TARGET:T}
	@${STAGE_FILE_SCRIPT}; StageFiles ${.TARGET:H:${STAGE_DIR_FILTER}} ${.TARGET:T}

.if !empty(STAGE_INCSDIR)
CLEANFILES += stage_incs

STAGE_INCS ?= ${.ALLSRC:N.dirdep}

stage_incs:	.dirdep
	@${STAGE_FILE_SCRIPT}; StageFiles ${STAGE_INCSDIR:${STAGE_DIR_FILTER}} ${STAGE_INCS}
	@touch $@
.endif

.if !empty(STAGE_LIBDIR)
CLEANFILES += stage_libs

STAGE_LIBS ?= ${.ALLSRC:N.dirdep}

stage_libs:	.dirdep
	@${STAGE_FILE_SCRIPT}; StageFiles ${STAGE_LIBDIR:${STAGE_DIR_FILTER}} ${STAGE_LIBS}
.if !empty(SHLIB_LINKS)
	@${STAGE_LINKS_SCRIPT}; StageLinks -s ${STAGE_LIBDIR:${STAGE_DIR_FILTER}} \
	${SHLIB_LINKS:@t@${STAGE_LIBS:T:M$t.*} $t@}
.elif !empty(SHLIB_LINK) && !empty(SHLIB_NAME)
	@${STAGE_LINKS_SCRIPT}; StageLinks -s ${STAGE_LIBDIR:${STAGE_DIR_FILTER}} ${SHLIB_NAME} ${SHLIB_LINK} ${SYMLINKS:T}
.endif
	@touch $@
.endif

.if !empty(STAGE_DIR)
STAGE_SETS += _default
STAGE_DIR._default = ${STAGE_DIR}
STAGE_SYMLINKS_DIR._default = ${STAGE_SYMLINKS_DIR:U${STAGE_DIR}}
STAGE_FILES._default = ${STAGE_FILES}
STAGE_SYMLINKS._default = ${STAGE_SYMLINKS}
STAGE_FILES ?= ${.ALLSRC:N.dirdep:Nstage_*}
STAGE_SYMLINKS ?= ${.ALLSRC:T:N.dirdep:Nstage_*}
.endif

.if !empty(STAGE_SETS)

CLEANFILES += ${STAGE_SETS:@s@stage*$s@}

# some makefiles need to populate multiple directories
.for s in ${STAGE_SETS:O:u}
STAGE_FILES.$s ?= ${.ALLSRC:N.dirdep}
STAGE_SYMLINKS.$s ?= ${.ALLSRC:N.dirdep}

.if $s != "_default"
stage_files:	stage_files.$s
stage_files.$s:	.dirdep
.else
stage_files:	.dirdep
.endif
	@${STAGE_FILE_SCRIPT}; StageFiles ${STAGE_FILES_DIR.$s:U${STAGE_DIR.$s}:${STAGE_DIR_FILTER}} ${STAGE_FILES.$s}
	@touch $@

.if $s != "_default"
stage_symlinks:	stage_symlinks.$s
stage_symlinks.$s:	.dirdep
.else
stage_symlinks:	.dirdep
.endif
	@${STAGE_LINKS_SCRIPT}; StageLinks -s ${STAGE_SYMLINKS_DIR.$s:U${STAGE_DIR.$s}:${STAGE_DIR_FILTER}} ${STAGE_SYMLINKS.$s}
	@touch $@

.endfor
.endif

.if !empty(STAGE_AS_SETS)

CLEANFILES += ${STAGE_AS_SETS:@s@stage*$s@}

# sometimes things need to be renamed as they are staged
# each ${file} will be staged as ${STAGE_AS_${file:T}}
# one could achieve the same with SYMLINKS
.for s in ${STAGE_AS_SETS:O:u}
STAGE_AS.$s ?= ${.ALLSRC:N.dirdep}

stage_as:	stage_as.$s
stage_as.$s:	.dirdep
	@${STAGE_AS_SCRIPT}; StageAs ${STAGE_FILES_DIR.$s:U${STAGE_DIR.$s}:${STAGE_DIR_FILTER}} ${STAGE_AS.$s:@f@$f ${STAGE_AS_${f:T}:U${f:T}}@}
	@touch $@

.endfor
.endif

.endif